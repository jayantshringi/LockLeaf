import 'dart:convert';
import 'dart:typed_data';

import 'package:lockleaf/core/constants/security_constants.dart';
import 'package:lockleaf/core/crypto/argon2id_kdf_service.dart';
import 'package:lockleaf/core/crypto/cipher_algorithm.dart';
import 'package:lockleaf/core/crypto/cipher_service.dart';
import 'package:lockleaf/core/crypto/kdf_params.dart';
import 'package:lockleaf/core/crypto/managed_secret_key.dart';
import 'package:lockleaf/core/crypto/secure_memory.dart';
import 'package:lockleaf/core/crypto/secure_random_service.dart';
import 'package:lockleaf/core/errors/app_exception.dart';
import 'package:lockleaf/features/vault/data/vault_storage_repository.dart';
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
  final Uuid _uuid;

  VaultSession? _session;

  /// Creates a [VaultService] backed by [storage].
  VaultService({
    required VaultStorageRepository storage,
    Argon2idKdfService? kdfService,
    CipherService? cipherService,
    SecureRandomService? randomService,
    Uuid? uuid,
  })  : _storage = storage,
        _kdfService = kdfService ?? Argon2idKdfService(),
        _randomService = randomService ?? SecureRandomService(),
        _cipherService = cipherService ??
            CipherService(
              randomService: randomService ?? SecureRandomService(),
            ),
        _uuid = uuid ?? const Uuid();

  /// Whether a vault session is currently unlocked with a live DEK.
  bool get isUnlocked => _session?.isActive ?? false;

  /// Identifier of the active unlocked vault, or null if locked.
  String? get activeVaultId => isUnlocked ? _session?.vaultId : null;

  /// Returns true if a vault has already been initialized in local storage.
  Future<bool> isVaultInitialized() => _storage.hasVault();

  /// Initializes a new zero-knowledge vault protected by [masterPassword].
  ///
  /// Generates a random 256-bit DEK, wraps it with an Argon2id+HKDF wrapping key,
  /// stores only public KDF metadata and the wrapped DEK, and opens an active
  /// unlocked session.
  Future<void> createVault({
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

      final metadata = VaultMetadata(
        vaultId: vaultId,
        salt: salt,
        kdfParams: kdfParams,
        cipherAlgorithm: cipherAlgorithm,
        wrappedDek: wrappedDek,
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

  /// Locks the vault and immediately zeroes the in-memory DEK.
  void lockVault() {
    _session?.lock();
    _session = null;
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
