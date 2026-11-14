import 'dart:convert';
import 'dart:typed_data';

import 'package:lockleaf/core/crypto/argon2id_kdf_service.dart';
import 'package:lockleaf/core/crypto/cipher_algorithm.dart';
import 'package:lockleaf/core/crypto/cipher_service.dart';
import 'package:lockleaf/core/crypto/kdf_params.dart';
import 'package:lockleaf/core/crypto/managed_secret_key.dart';
import 'package:lockleaf/core/crypto/secure_memory.dart';
import 'package:lockleaf/core/crypto/secure_random_service.dart';
import 'package:lockleaf/core/errors/app_exception.dart';
import 'package:lockleaf/features/backup/domain/encrypted_backup_payload.dart';
import 'package:lockleaf/features/vault/domain/vault_entry.dart';
import 'package:lockleaf/features/vault/domain/vault_service.dart';

/// Orchestrates encrypted vault export, pre-flight inspection, and authenticated restoration.
class BackupService {
  /// HKDF domain-separation context for encrypted backups.
  static const String backupHkdfContext = 'lockleaf-backup-wrap-v1';

  final Argon2idKdfService _kdfService;
  final CipherService _cipherService;
  final SecureRandomService _randomService;

  BackupService({
    Argon2idKdfService? kdfService,
    CipherService? cipherService,
    SecureRandomService? randomService,
  })  : _kdfService = kdfService ?? Argon2idKdfService(),
        _randomService = randomService ?? SecureRandomService(),
        _cipherService = cipherService ??
            CipherService(
                randomService: randomService ?? SecureRandomService());

  /// Exports an authenticated, encrypted `.llbak` JSON backup file.
  ///
  /// Requires an unlocked [vaultService] session.
  Future<String> exportEncryptedBackup({
    required VaultService vaultService,
    required String backupPassword,
    String? notes,
    KdfParams kdfParams = const KdfParams.standard(),
  }) async {
    if (!vaultService.isUnlocked) {
      throw const VaultLockedException();
    }
    if (backupPassword.isEmpty) {
      throw const ValidationException('Backup password cannot be empty.');
    }

    final vaultId = vaultService.activeVaultId;
    if (vaultId == null) {
      throw const StorageException('No active vault session found.');
    }

    final entries = await vaultService.getAllEntries();
    final now = DateTime.now().toUtc();
    final bundle = BackupBundle(
      vaultId: vaultId,
      exportedAt: now,
      entries: entries,
    );

    final rawJson = jsonEncode(bundle.toJson());
    final rawBytes = Uint8List.fromList(utf8.encode(rawJson));
    final salt = _randomService.generateSalt();

    ManagedSecretKey? backupKey;
    try {
      backupKey = await _deriveBackupKey(
        password: backupPassword,
        salt: salt,
        params: kdfParams,
      );

      final encryptedPayload = await _cipherService.encryptBytes(
        plaintext: rawBytes,
        key: backupKey,
        algorithm: VaultCipherAlgorithm.xchacha20Poly1305,
        associatedData: utf8.encode(EncryptedBackupPayload.backupAad(vaultId)),
      );

      final backup = EncryptedBackupPayload(
        vaultId: vaultId,
        createdAt: now,
        entryCount: entries.length,
        salt: salt,
        kdfParams: kdfParams,
        cipherAlgorithm: VaultCipherAlgorithm.xchacha20Poly1305,
        encryptedPayload: encryptedPayload,
        notes: notes,
      );

      return backup.toJsonString(pretty: true);
    } finally {
      backupKey?.destroy();
      SecureMemory.wipeBytes(rawBytes);
    }
  }

  /// Inspects the unencrypted header of [backupJson] without requiring a password.
  EncryptedBackupHeader inspectBackup(String backupJson) {
    return EncryptedBackupPayload.inspect(backupJson);
  }

  /// Restores entries from [backupJson] into an existing unlocked [vaultService].
  ///
  /// If [overwriteExisting] is true, removes current entries before importing.
  /// Otherwise, merges by inserting new entries and updating existing items
  /// when the restored copy has a newer `updatedAt`.
  Future<List<VaultEntry>> restoreBackup({
    required String backupJson,
    required String backupPassword,
    required VaultService vaultService,
    bool overwriteExisting = false,
  }) async {
    if (!vaultService.isUnlocked) {
      throw const VaultLockedException();
    }

    final bundle = await _decryptBackupBundle(
      backupJson: backupJson,
      backupPassword: backupPassword,
    );

    final restored = <VaultEntry>[];
    if (overwriteExisting) {
      final existing = await vaultService.getAllEntries();
      for (final e in existing) {
        await vaultService.deleteEntry(e.id);
      }
      for (final entry in bundle.entries) {
        await vaultService.createEntry(
          title: entry.title,
          username: entry.username,
          password: entry.password,
          url: entry.url,
          notes: entry.notes,
          category: entry.category,
          isFavorite: entry.isFavorite,
        );
        restored.add(entry);
      }
    } else {
      final existingEntries = await vaultService.getAllEntries();
      final existingMap = {for (final e in existingEntries) e.id: e};

      for (final entry in bundle.entries) {
        final current = existingMap[entry.id];
        if (current == null) {
          // Check if an entry with identical title and username already exists
          final duplicate = existingEntries.any(
            (e) => e.title == entry.title && e.username == entry.username,
          );
          if (!duplicate) {
            await vaultService.createEntry(
              title: entry.title,
              username: entry.username,
              password: entry.password,
              url: entry.url,
              notes: entry.notes,
              category: entry.category,
              isFavorite: entry.isFavorite,
            );
            restored.add(entry);
          }
        } else if (entry.updatedAt.isAfter(current.updatedAt)) {
          await vaultService.updateEntry(entry);
          restored.add(entry);
        }
      }
    }

    return restored;
  }

  /// Restores a backup onto a fresh device with no existing local vault.
  ///
  /// Initializes a new vault protected by [newMasterPassword] and inserts all
  /// decrypted entries from [backupJson].
  Future<List<VaultEntry>> restoreToNewVault({
    required String backupJson,
    required String backupPassword,
    required String newMasterPassword,
    required VaultService vaultService,
  }) async {
    if (await vaultService.isVaultInitialized()) {
      throw const ValidationException(
        'A vault already exists on this device. Use regular restore instead.',
      );
    }

    final bundle = await _decryptBackupBundle(
      backupJson: backupJson,
      backupPassword: backupPassword,
    );

    await vaultService.createVault(masterPassword: newMasterPassword);

    final restored = <VaultEntry>[];
    for (final entry in bundle.entries) {
      await vaultService.createEntry(
        title: entry.title,
        username: entry.username,
        password: entry.password,
        url: entry.url,
        notes: entry.notes,
        category: entry.category,
        isFavorite: entry.isFavorite,
      );
      restored.add(entry);
    }

    return restored;
  }

  Future<BackupBundle> _decryptBackupBundle({
    required String backupJson,
    required String backupPassword,
  }) async {
    if (backupPassword.isEmpty) {
      throw const AuthenticationException('Backup password cannot be empty.');
    }

    final payload = EncryptedBackupPayload.fromJsonString(backupJson);

    ManagedSecretKey? backupKey;
    Uint8List? clearBytes;
    try {
      backupKey = await _deriveBackupKey(
        password: backupPassword,
        salt: payload.salt,
        params: payload.kdfParams,
      );

      try {
        clearBytes = await _cipherService.decryptBytes(
          payload: payload.encryptedPayload,
          key: backupKey,
          associatedData: utf8.encode(
            EncryptedBackupPayload.backupAad(payload.vaultId),
          ),
        );
      } on CryptoException {
        throw const AuthenticationException(
          'Invalid backup password or corrupted backup file.',
        );
      }

      final jsonMap = jsonDecode(utf8.decode(clearBytes));
      if (jsonMap is! Map<String, dynamic>) {
        throw const CryptoException('Decrypted backup bundle is invalid JSON.');
      }
      return BackupBundle.fromJson(jsonMap);
    } on FormatException {
      throw const CryptoException('Malformed JSON structure inside backup.');
    } finally {
      backupKey?.destroy();
      if (clearBytes != null) {
        SecureMemory.wipeBytes(clearBytes);
      }
    }
  }

  Future<ManagedSecretKey> _deriveBackupKey({
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
        context: backupHkdfContext,
      );
    } finally {
      masterKey.destroy();
    }
  }
}
