import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lockleaf/core/crypto/cipher_algorithm.dart';
import 'package:lockleaf/core/crypto/encrypted_payload.dart';
import 'package:lockleaf/core/crypto/kdf_params.dart';
import 'package:lockleaf/core/crypto/secure_random_service.dart';
import 'package:lockleaf/core/errors/app_exception.dart';
import 'package:lockleaf/features/backup/domain/encrypted_backup_payload.dart';
import 'package:lockleaf/features/vault/domain/vault_entry.dart';
import 'package:lockleaf/features/vault/domain/vault_entry_category.dart';

void main() {
  final randomService = SecureRandomService();

  EncryptedBackupPayload createSamplePayload({
    String? vaultId,
    int entryCount = 2,
    String? notes,
  }) {
    final salt = randomService.generateSalt();
    final dummyEncrypted = EncryptedPayload(
      version: 1,
      algorithm: VaultCipherAlgorithm.xchacha20Poly1305,
      nonce: randomService.generateBytes(24),
      ciphertext: randomService.generateBytes(48),
      mac: randomService.generateBytes(16),
    );

    return EncryptedBackupPayload(
      vaultId: vaultId ?? 'test-vault-uuid-1234',
      createdAt: DateTime.now().toUtc(),
      entryCount: entryCount,
      salt: salt,
      kdfParams: const KdfParams.testFast(),
      cipherAlgorithm: VaultCipherAlgorithm.xchacha20Poly1305,
      encryptedPayload: dummyEncrypted,
      notes: notes,
    );
  }

  group('EncryptedBackupPayload', () {
    test('serializes and deserializes from JSON string faithfully', () {
      final original = createSamplePayload(notes: 'My secure backup');
      final jsonStr = original.toJsonString(pretty: true);

      final reconstructed = EncryptedBackupPayload.fromJsonString(jsonStr);

      expect(reconstructed.vaultId, equals(original.vaultId));
      expect(reconstructed.formatVersion, equals(original.formatVersion));
      expect(reconstructed.entryCount, equals(original.entryCount));
      expect(reconstructed.notes, equals('My secure backup'));
      expect(reconstructed.salt, equals(original.salt));
      expect(reconstructed.kdfParams, equals(original.kdfParams));
      expect(reconstructed.cipherAlgorithm, equals(original.cipherAlgorithm));
      expect(
        reconstructed.encryptedPayload.ciphertext,
        equals(original.encryptedPayload.ciphertext),
      );
    });

    test('inspect extracts header without touching encrypted payload', () {
      final payload = createSamplePayload(vaultId: 'v-9988', entryCount: 42);
      final jsonStr = payload.toJsonString();

      final header = EncryptedBackupPayload.inspect(jsonStr);

      expect(header.vaultId, equals('v-9988'));
      expect(header.entryCount, equals(42));
      expect(header.formatVersion, equals(1));
      expect(header.kdfParams, equals(payload.kdfParams));
      expect(header.cipherAlgorithm, equals(payload.cipherAlgorithm));
    });

    test('rejects corrupted magic header', () {
      final payload = createSamplePayload();
      final map = jsonDecode(payload.toJsonString()) as Map<String, dynamic>;
      map['magic'] = 'INVALID_MAGIC';
      final tampered = jsonEncode(map);

      expect(
        () => EncryptedBackupPayload.inspect(tampered),
        throwsA(
          isA<ValidationException>().having(
            (e) => e.message,
            'message',
            contains('Unrecognized magic header'),
          ),
        ),
      );
    });

    test('rejects unsupported backup versions', () {
      final payload = createSamplePayload();
      final map = jsonDecode(payload.toJsonString()) as Map<String, dynamic>;
      map['version'] = 999;
      final tampered = jsonEncode(map);

      expect(
        () => EncryptedBackupPayload.inspect(tampered),
        throwsA(
          isA<ValidationException>().having(
            (e) => e.message,
            'message',
            contains('Unsupported backup format version'),
          ),
        ),
      );
    });

    test('rejects invalid or too short salt', () {
      final dummyEncrypted = EncryptedPayload(
        version: 1,
        algorithm: VaultCipherAlgorithm.xchacha20Poly1305,
        nonce: Uint8List(24),
        ciphertext: Uint8List(32),
        mac: Uint8List(16),
      );

      expect(
        () => EncryptedBackupPayload(
          vaultId: 'vault-1',
          createdAt: DateTime.now().toUtc(),
          entryCount: 1,
          salt: [1, 2, 3], // < 16 bytes
          kdfParams: const KdfParams.testFast(),
          cipherAlgorithm: VaultCipherAlgorithm.xchacha20Poly1305,
          encryptedPayload: dummyEncrypted,
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('backupAad formats consistent context string', () {
      final aad = EncryptedBackupPayload.backupAad('vault-xyz');
      expect(aad, equals('lockleaf:backup:v1:vault-xyz'));
    });
  });

  group('BackupBundle', () {
    test('serializes and deserializes cleartext entry list correctly', () {
      final now = DateTime.now().toUtc();
      final entries = [
        VaultEntry(
          id: 'entry-1',
          title: 'GitHub',
          username: 'octocat',
          password: 'SecretPassword123!',
          url: 'https://github.com',
          category: VaultEntryCategory.login,
          createdAt: now,
          updatedAt: now,
        ),
        VaultEntry(
          id: 'entry-2',
          title: 'WiFi Note',
          username: '',
          password: 'WifiSecretPassword',
          category: VaultEntryCategory.secureNote,
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final bundle = BackupBundle(
        vaultId: 'vault-1',
        exportedAt: now,
        entries: entries,
      );

      final jsonMap = bundle.toJson();
      final restored = BackupBundle.fromJson(jsonMap);

      expect(restored.vaultId, equals('vault-1'));
      expect(restored.entries.length, equals(2));
      expect(restored.entries[0].title, equals('GitHub'));
      expect(restored.entries[0].password, equals('SecretPassword123!'));
      expect(
        restored.entries[1].category,
        equals(VaultEntryCategory.secureNote),
      );
    });
  });
}
