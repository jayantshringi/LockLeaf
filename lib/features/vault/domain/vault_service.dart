import 'dart:convert';
import 'dart:typed_data';

import 'package:lockleaf/core/constants/security_constants.dart';
import 'package:lockleaf/core/crypto/argon2id_kdf_service.dart';
import 'package:lockleaf/core/crypto/cipher_algorithm.dart';
import 'package:lockleaf/core/crypto/cipher_service.dart';
import 'package:lockleaf/core/crypto/encrypted_payload.dart';
import 'package:lockleaf/core/crypto/kdf_params.dart';
import 'package:lockleaf/core/crypto/managed_secret_key.dart';
import 'package:lockleaf/core/crypto/secure_memory.dart';
import 'package:lockleaf/core/crypto/secure_random_service.dart';
import 'package:lockleaf/core/errors/app_exception.dart';
import 'package:lockleaf/features/backup/domain/recovery_key.dart';
import 'package:lockleaf/features/backup/domain/recovery_key_service.dart';
import 'package:lockleaf/features/sync/data/sync_storage_repository.dart';
import 'package:lockleaf/features/sync/domain/sync_status.dart';
import 'package:lockleaf/features/vault/data/vault_storage_repository.dart';
import 'package:lockleaf/features/vault/domain/encrypted_entry_record.dart';
import 'package:lockleaf/features/vault/domain/vault_entry.dart';
import 'package:lockleaf/features/vault/domain/vault_entry_category.dart';
import 'package:lockleaf/features/vault/domain/vault_metadata.dart';
import 'package:lockleaf/features/vault/domain/vault_session.dart';
import 'package:uuid/uuid.dart';

/// Orchestrates zero-knowledge vault authentication, key wrapping, and entry CRUD.
class VaultService {
  static const String _dekWrapHkdfContext = 'lockleaf-dek-wrap-v1';

  final VaultStorageRepository _storage;
  final Argon2idKdfService _kdfService;
  final CipherService _cipherService;
  final SecureRandomService _randomService;
  final RecoveryKeyService _recoveryKeyService;
  final SyncStorageRepository? _syncStorage;
  final Uuid _uuid;

  VaultSession? _session;

  /// Creates a [VaultService] backed by [storage].
  VaultService({
    required VaultStorageRepository storage,
    Argon2idKdfService? kdfService,
    CipherService? cipherService,
    SecureRandomService? randomService,
    RecoveryKeyService? recoveryKeyService,
    SyncStorageRepository? syncStorage,
    Uuid? uuid,
  })  : _storage = storage,
        _kdfService = kdfService ?? Argon2idKdfService(),
        _randomService = randomService ?? SecureRandomService(),
        _cipherService = cipherService ??
            CipherService(
              randomService: randomService ?? SecureRandomService(),
            ),
        _recoveryKeyService = recoveryKeyService ??
            RecoveryKeyService(
              kdfService: kdfService,
              cipherService: cipherService,
              randomService: randomService,
            ),
        _syncStorage = syncStorage,
        _uuid = uuid ?? const Uuid();

  /// Whether a vault session is currently unlocked with a live DEK.
  bool get isUnlocked => _session?.isActive ?? false;

  /// Active unlocked session, or null if locked.
  VaultSession? get activeSession => _session;

  /// Identifier of the active unlocked vault, or null if locked.
  String? get activeVaultId => isUnlocked ? _session?.vaultId : null;

  /// Returns true if a vault has already been initialized in local storage.
  Future<bool> isVaultInitialized() => _storage.hasVault();

  /// Returns the initialized vault identifier, or null if no vault exists.
  Future<String?> getInitializedVaultId() async {
    final metadata = await _storage.getMetadata();
    return metadata?.vaultId;
  }

  /// Initializes a new zero-knowledge vault protected by [masterPassword].
  ///
  /// Generates a random 256-bit DEK, wraps it with an Argon2id+HKDF master key
  /// and with a freshly generated [RecoveryKey], stores only public KDF metadata
  /// and the wrapped DEK payloads, and opens an active unlocked session.
  ///
  /// Returns the newly generated [RecoveryKey] so the user can store it safely.
  Future<RecoveryKey> createVault({
    required String masterPassword,
    KdfParams kdfParams = const KdfParams.standard(),
    VaultCipherAlgorithm cipherAlgorithm = VaultCipherAlgorithm.xchacha20Poly1305,
  }) async {
    if (await _storage.hasVault()) {
      throw const ValidationException(
        'A vault is already initialized on this device.',
      );
    }
    _validateNewPassword(masterPassword);

    final now = DateTime.now().toUtc();
    final vaultId = _uuid.v4();
    final salt = _randomService.generateSalt();
    final dekBytes = _randomService.generateBytes(
      SecurityConstants.derivedKeyLengthBytes,
    );

    ManagedSecretKey? wrappingKey;
    try {
      wrappingKey = await _deriveWrappingKey(
        password: masterPassword,
        salt: salt,
        params: kdfParams,
      );

      final wrappedDek = await _cipherService.encryptBytes(
        plaintext: dekBytes,
        key: wrappingKey,
        algorithm: cipherAlgorithm,
        associatedData: utf8.encode(VaultSession.dekWrapAad(vaultId)),
      );

      final recoveryKey = RecoveryKey.generate(randomService: _randomService);
      final recoveryWrap = await _recoveryKeyService.wrapDek(
        recoveryKey: recoveryKey,
        dekBytes: dekBytes,
        vaultId: vaultId,
        cipherAlgorithm: cipherAlgorithm,
        params: kdfParams,
      );

      final metadata = VaultMetadata(
        vaultId: vaultId,
        salt: salt,
        kdfParams: kdfParams,
        cipherAlgorithm: cipherAlgorithm,
        wrappedDek: wrappedDek,
        recoverySalt: recoveryWrap.recoverySalt,
        recoveryWrappedDek: recoveryWrap.wrappedDek,
        createdAt: now,
        updatedAt: now,
      );

      await _storage.saveMetadata(metadata);

      lockVault();
      _session = VaultSession(
        vaultId: vaultId,
        dek: ManagedSecretKey.fromBytes(dekBytes),
        cipherAlgorithm: cipherAlgorithm,
        unlockedAt: now,
      );

      return recoveryKey;
    } finally {
      wrappingKey?.destroy();
      SecureMemory.wipeBytes(dekBytes);
    }
  }

  /// Derives the key-wrapping key from [masterPassword] and unlocks the vault.
  ///
  /// Throws [AuthenticationException] if the master password is incorrect.
  Future<void> unlockVault(String masterPassword) async {
    if (masterPassword.isEmpty) {
      throw const AuthenticationException('Master password cannot be empty.');
    }

    final metadata = await _storage.getMetadata();
    if (metadata == null) {
      throw const StorageException('No initialized vault found.');
    }

    final dekBytes = await _unwrapDek(
      metadata: metadata,
      password: masterPassword,
    );
    try {
      lockVault();
      _session = VaultSession(
        vaultId: metadata.vaultId,
        dek: ManagedSecretKey.fromBytes(dekBytes),
        cipherAlgorithm: metadata.cipherAlgorithm,
      );
    } finally {
      SecureMemory.wipeBytes(dekBytes);
    }
  }

  /// Re-wraps the vault DEK under a new [newPassword] and fresh salt.
  ///
  /// Existing encrypted vault entries remain untouched because only the DEK
  /// wrapper changes. Verifies [currentPassword] before rotating.
  Future<void> changeMasterPassword({
    required String currentPassword,
    required String newPassword,
    KdfParams? newKdfParams,
  }) async {
    if (currentPassword.isEmpty) {
      throw const AuthenticationException('Current password cannot be empty.');
    }
    _validateNewPassword(newPassword);

    final metadata = await _storage.getMetadata();
    if (metadata == null) {
      throw const StorageException('No initialized vault found.');
    }

    final dekBytes = await _unwrapDek(
      metadata: metadata,
      password: currentPassword,
    );

    ManagedSecretKey? newWrappingKey;
    try {
      final newSalt = _randomService.generateSalt();
      final effectiveParams = newKdfParams ?? metadata.kdfParams;
      newWrappingKey = await _deriveWrappingKey(
        password: newPassword,
        salt: newSalt,
        params: effectiveParams,
      );

      final rewrappedDek = await _cipherService.encryptBytes(
        plaintext: dekBytes,
        key: newWrappingKey,
        algorithm: metadata.cipherAlgorithm,
        associatedData: utf8.encode(VaultSession.dekWrapAad(metadata.vaultId)),
      );

      final updatedMetadata = metadata.copyWith(
        salt: newSalt,
        kdfParams: effectiveParams,
        wrappedDek: rewrappedDek,
        updatedAt: DateTime.now().toUtc(),
      );
      await _storage.saveMetadata(updatedMetadata);
    } finally {
      newWrappingKey?.destroy();
      SecureMemory.wipeBytes(dekBytes);
    }
  }

  /// Resets the vault master password using [recoveryKey] without data loss.
  ///
  /// Unwraps the existing vault DEK using [recoveryKey], re-wraps it with
  /// [newPassword] and fresh salt, generates a fresh [RecoveryKey],
  /// updates vault metadata, and opens an active unlocked session.
  Future<RecoveryKey> resetMasterPasswordWithRecoveryKey({
    required RecoveryKey recoveryKey,
    required String newPassword,
    KdfParams? newKdfParams,
  }) async {
    _validateNewPassword(newPassword);

    final metadata = await _storage.getMetadata();
    if (metadata == null) {
      throw const StorageException('No initialized vault found.');
    }

    final dekBytes = await _recoveryKeyService.unwrapDek(
      recoveryKey: recoveryKey,
      metadata: metadata,
    );

    ManagedSecretKey? newWrappingKey;
    try {
      final newSalt = _randomService.generateSalt();
      final effectiveParams = newKdfParams ?? metadata.kdfParams;
      newWrappingKey = await _deriveWrappingKey(
        password: newPassword,
        salt: newSalt,
        params: effectiveParams,
      );

      final rewrappedDek = await _cipherService.encryptBytes(
        plaintext: dekBytes,
        key: newWrappingKey,
        algorithm: metadata.cipherAlgorithm,
        associatedData: utf8.encode(VaultSession.dekWrapAad(metadata.vaultId)),
      );

      final newRecoveryKey = RecoveryKey.generate(randomService: _randomService);
      final newRecoveryWrap = await _recoveryKeyService.wrapDek(
        recoveryKey: newRecoveryKey,
        dekBytes: dekBytes,
        vaultId: metadata.vaultId,
        cipherAlgorithm: metadata.cipherAlgorithm,
        params: effectiveParams,
      );

      final updatedMetadata = metadata.copyWith(
        salt: newSalt,
        kdfParams: effectiveParams,
        wrappedDek: rewrappedDek,
        recoverySalt: newRecoveryWrap.recoverySalt,
        recoveryWrappedDek: newRecoveryWrap.wrappedDek,
        updatedAt: DateTime.now().toUtc(),
      );

      await _storage.saveMetadata(updatedMetadata);

      lockVault();
      _session = VaultSession(
        vaultId: metadata.vaultId,
        dek: ManagedSecretKey.fromBytes(dekBytes),
        cipherAlgorithm: metadata.cipherAlgorithm,
      );

      return newRecoveryKey;
    } finally {
      newWrappingKey?.destroy();
      SecureMemory.wipeBytes(dekBytes);
    }
  }

  /// Rotates the vault recovery key while vault is unlocked or with [masterPassword].
  Future<RecoveryKey> rotateRecoveryKey({String? masterPassword}) async {
    final metadata = await _storage.getMetadata();
    if (metadata == null) {
      throw const StorageException('No initialized vault found.');
    }

    Uint8List dekBytes;
    var needsWiping = false;
    if (_session != null && _session!.isActive) {
      dekBytes = _session!.activeKey.copyBytes();
      needsWiping = true;
    } else if (masterPassword != null && masterPassword.isNotEmpty) {
      dekBytes = await _unwrapDek(metadata: metadata, password: masterPassword);
      needsWiping = true;
    } else {
      throw const VaultLockedException();
    }

    try {
      final newRecoveryKey = RecoveryKey.generate(randomService: _randomService);
      final newWrap = await _recoveryKeyService.wrapDek(
        recoveryKey: newRecoveryKey,
        dekBytes: dekBytes,
        vaultId: metadata.vaultId,
        cipherAlgorithm: metadata.cipherAlgorithm,
        params: metadata.kdfParams,
      );

      final updatedMetadata = metadata.copyWith(
        recoverySalt: newWrap.recoverySalt,
        recoveryWrappedDek: newWrap.wrappedDek,
        updatedAt: DateTime.now().toUtc(),
      );
      await _storage.saveMetadata(updatedMetadata);

      return newRecoveryKey;
    } finally {
      if (needsWiping) {
        SecureMemory.wipeBytes(dekBytes);
      }
    }
  }

  /// Locks the vault and immediately zeroes the in-memory DEK.
  void lockVault() {
    _session?.lock();
    _session = null;
  }

  /// Executes [action] with a temporary copy of the active DEK bytes, wiping
  /// the copy immediately once [action] completes.
  Future<T> withSessionDek<T>(
    Future<T> Function(
      String vaultId,
      VaultCipherAlgorithm algorithm,
      Uint8List dekBytes,
    ) action,
  ) async {
    final session = _requireSession();
    final dekBytes = session.activeKey.copyBytes();
    try {
      return await action(session.vaultId, session.cipherAlgorithm, dekBytes);
    } finally {
      SecureMemory.wipeBytes(dekBytes);
    }
  }

  /// Opens a vault session directly from unwrapped [dekBytes] (e.g. biometrics
  /// or recovery key), verifying [expectedVaultId] matches metadata.
  Future<void> unlockWithDekBytes({
    required String expectedVaultId,
    required List<int> dekBytes,
  }) async {
    if (dekBytes.length != SecurityConstants.derivedKeyLengthBytes) {
      throw const CryptoException('Invalid DEK length for vault unlock.');
    }
    final metadata = await _storage.getMetadata();
    if (metadata == null) {
      throw const StorageException('No initialized vault found.');
    }
    if (metadata.vaultId != expectedVaultId) {
      throw const AuthenticationException(
        'Wrapped key does not belong to the active vault.',
      );
    }
    lockVault();
    _session = VaultSession(
      vaultId: metadata.vaultId,
      dek: ManagedSecretKey.fromBytes(dekBytes),
      cipherAlgorithm: metadata.cipherAlgorithm,
    );
  }

  /// Creates, encrypts, and stores a new [VaultEntry].
  ///
  /// Throws [VaultLockedException] if the vault is currently locked.
  Future<VaultEntry> createEntry({
    required String title,
    required String username,
    required String password,
    String? url,
    String? notes,
    VaultEntryCategory category = VaultEntryCategory.login,
    bool isFavorite = false,
  }) async {
    final session = _requireSession();
    final now = DateTime.now().toUtc();
    final entry = VaultEntry(
      id: _uuid.v4(),
      title: title,
      username: username,
      password: password,
      url: url,
      notes: notes,
      category: category,
      isFavorite: isFavorite,
      createdAt: now,
      updatedAt: now,
    );

    final record = await _encryptEntry(session, entry);
    await _storage.upsertEntry(record);
    await _syncStorage?.enqueueAction(
      entryId: entry.id,
      vaultId: session.vaultId,
      action: SyncAction.create,
    );
    return entry;
  }

  /// Decrypts and returns all entries stored in the unlocked vault.
  Future<List<VaultEntry>> getAllEntries() async {
    final session = _requireSession();
    final records = await _storage.getAllEntries();
    final entries = <VaultEntry>[];
    for (final record in records) {
      entries.add(await _decryptRecord(session, record));
    }
    return entries;
  }

  /// Decrypts and returns a single entry by [id], or null if not found.
  Future<VaultEntry?> getEntryById(String id) async {
    final session = _requireSession();
    final record = await _storage.getEntryById(id);
    if (record == null) {
      return null;
    }
    return _decryptRecord(session, record);
  }

  /// Re-encrypts [entry] with a fresh nonce and updates local storage.
  ///
  /// Throws [StorageException] if no entry with `entry.id` exists.
  Future<VaultEntry> updateEntry(VaultEntry entry) async {
    final session = _requireSession();
    final existing = await _storage.getEntryById(entry.id);
    if (existing == null) {
      throw const StorageException('Cannot update missing vault entry.');
    }

    final updated = entry.copyWith(updatedAt: DateTime.now().toUtc());
    final record = await _encryptEntry(session, updated);
    await _storage.upsertEntry(record);
    await _syncStorage?.enqueueAction(
      entryId: updated.id,
      vaultId: session.vaultId,
      action: SyncAction.update,
    );
    return updated;
  }

  /// Deletes the entry identified by [id].
  Future<bool> deleteEntry(String id) async {
    final session = _requireSession();
    final deleted = await _storage.deleteEntry(id);
    if (deleted) {
      await _syncStorage?.enqueueAction(
        entryId: id,
        vaultId: session.vaultId,
        action: SyncAction.delete,
      );
    }
    return deleted;
  }

  VaultSession _requireSession() {
    final session = _session;
    if (session == null || !session.isActive) {
      _session = null;
      throw const VaultLockedException();
    }
    return session;
  }

  Future<EncryptedEntryRecord> _encryptEntry(
    VaultSession session,
    VaultEntry entry,
  ) async {
    final jsonBytes = Uint8List.fromList(utf8.encode(jsonEncode(entry.toJson())));
    try {
      final payload = await _cipherService.encryptBytes(
        plaintext: jsonBytes,
        key: session.activeKey,
        algorithm: session.cipherAlgorithm,
        associatedData: utf8.encode(session.entryAad(entry.id)),
      );
      return EncryptedEntryRecord(
        id: entry.id,
        encryptedBlob: payload.toBytes(),
        createdAt: entry.createdAt,
        updatedAt: entry.updatedAt,
      );
    } finally {
      SecureMemory.wipeBytes(jsonBytes);
    }
  }

  Future<VaultEntry> _decryptRecord(
    VaultSession session,
    EncryptedEntryRecord record,
  ) async {
    final payload = EncryptedPayload.fromBytes(record.encryptedBlob);
    final clearBytes = await _cipherService.decryptBytes(
      payload: payload,
      key: session.activeKey,
      associatedData: utf8.encode(session.entryAad(record.id)),
    );
    try {
      final decoded = jsonDecode(utf8.decode(clearBytes));
      if (decoded is! Map<String, dynamic>) {
        throw const CryptoException('Decrypted entry is not a JSON object.');
      }
      final entry = VaultEntry.fromJson(decoded);
      if (entry.id != record.id) {
        throw const CryptoException('Entry ID mismatch in decrypted payload.');
      }
      return entry;
    } on FormatException {
      throw const CryptoException('Decrypted entry JSON is malformed.');
    } finally {
      SecureMemory.wipeBytes(clearBytes);
    }
  }

  Future<Uint8List> _unwrapDek({
    required VaultMetadata metadata,
    required String password,
  }) async {
    ManagedSecretKey? wrappingKey;
    try {
      wrappingKey = await _deriveWrappingKey(
        password: password,
        salt: metadata.salt,
        params: metadata.kdfParams,
      );
      try {
        return await _cipherService.decryptBytes(
          payload: metadata.wrappedDek,
          key: wrappingKey,
          associatedData:
              utf8.encode(VaultSession.dekWrapAad(metadata.vaultId)),
        );
      } on CryptoException {
        throw const AuthenticationException('Invalid master password.');
      }
    } finally {
      wrappingKey?.destroy();
    }
  }

  Future<ManagedSecretKey> _deriveWrappingKey({
    required String password,
    required List<int> salt,
    required KdfParams params,
  }) async {
    final masterKey = await _kdfService.deriveMasterKey(
      masterPassword: password,
      salt: salt,
      params: params,
    );
    try {
      return await _kdfService.deriveSubkey(
        masterKey: masterKey,
        context: _dekWrapHkdfContext,
      );
    } finally {
      masterKey.destroy();
    }
  }

  void _validateNewPassword(String password) {
    if (password.length < SecurityConstants.minMasterPasswordLength) {
      throw const ValidationException(
        'Master password must be at least '
        '${SecurityConstants.minMasterPasswordLength} characters long.',
      );
    }
  }
}
