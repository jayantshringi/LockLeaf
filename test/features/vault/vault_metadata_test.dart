import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lockleaf/core/crypto/cipher_algorithm.dart';
import 'package:lockleaf/core/crypto/encrypted_payload.dart';
import 'package:lockleaf/core/crypto/kdf_params.dart';
import 'package:lockleaf/core/crypto/secure_random_service.dart';
import 'package:lockleaf/core/errors/app_exception.dart';
import 'package:lockleaf/features/vault/domain/vault_metadata.dart';

void main() {
  late SecureRandomService randomService;

  setUp(() {
    randomService = SecureRandomService();
  });

  EncryptedPayload makeSyntheticWrappedDek() {
    return EncryptedPayload(
      algorithm: VaultCipherAlgorithm.xchacha20Poly1305,
      nonce: randomService.generateNonce(
        VaultCipherAlgorithm.xchacha20Poly1305.nonceLength,
      ),
      cipherText: randomService.generateBytes(32),
      mac: randomService.generateBytes(16),
    );
  }

  group('VaultMetadata', () {
    test('round-trips SQLite map serialization', () {
      final now = DateTime.utc(2026, 11, 11, 10, 5, 0);
      final metadata = VaultMetadata(
        vaultId: 'vault-uuid-001',
        salt: randomService.generateSalt(),
        kdfParams: const KdfParams.standard(),
        cipherAlgorithm: VaultCipherAlgorithm.xchacha20Poly1305,
        wrappedDek: makeSyntheticWrappedDek(),
        createdAt: now,
        updatedAt: now,
      );

      final parsed = VaultMetadata.fromMap(metadata.toMap());

      expect(parsed, equals(metadata));
      expect(parsed.hasRecoveryKey, isFalse);
    });

    test('round-trips recovery salt and recovery wrapped DEK serialization', () {
      final now = DateTime.utc(2026, 11, 13, 11, 0, 0);
      final recoverySalt = randomService.generateSalt();
      final recoveryDek = makeSyntheticWrappedDek();
      final metadata = VaultMetadata(
        vaultId: 'vault-uuid-recovery',
        salt: randomService.generateSalt(),
        kdfParams: const KdfParams.standard(),
        cipherAlgorithm: VaultCipherAlgorithm.xchacha20Poly1305,
        wrappedDek: makeSyntheticWrappedDek(),
        recoverySalt: recoverySalt,
        recoveryWrappedDek: recoveryDek,
        createdAt: now,
        updatedAt: now,
      );

      expect(metadata.hasRecoveryKey, isTrue);

      final parsed = VaultMetadata.fromMap(metadata.toMap());
      expect(parsed, equals(metadata));
      expect(parsed.hasRecoveryKey, isTrue);
      expect(parsed.recoverySalt, equals(recoverySalt));
      expect(parsed.recoveryWrappedDek, equals(recoveryDek));
    });

    test('validates vaultId, schemaVersion, and salt length', () {
      final now = DateTime.now().toUtc();
      final wrapped = makeSyntheticWrappedDek();

      expect(
        () => VaultMetadata(
          vaultId: '   ',
          salt: randomService.generateSalt(),
          kdfParams: const KdfParams.standard(),
          cipherAlgorithm: VaultCipherAlgorithm.xchacha20Poly1305,
          wrappedDek: wrapped,
          createdAt: now,
          updatedAt: now,
        ),
        throwsA(isA<ValidationException>()),
      );

      expect(
        () => VaultMetadata(
          vaultId: 'vault-1',
          schemaVersion: 0,
          salt: randomService.generateSalt(),
          kdfParams: const KdfParams.standard(),
          cipherAlgorithm: VaultCipherAlgorithm.xchacha20Poly1305,
          wrappedDek: wrapped,
          createdAt: now,
          updatedAt: now,
        ),
        throwsA(isA<ValidationException>()),
      );

      expect(
        () => VaultMetadata(
          vaultId: 'vault-1',
          salt: Uint8List(8),
          kdfParams: const KdfParams.standard(),
          cipherAlgorithm: VaultCipherAlgorithm.xchacha20Poly1305,
          wrappedDek: wrapped,
          createdAt: now,
          updatedAt: now,
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('rejects corrupt database row maps', () {
      expect(
        () => VaultMetadata.fromMap(<String, Object?>{'vault_id': 'only-id'}),
        throwsA(isA<StorageException>()),
      );

      final invalidJsonRow = <String, Object?>{
        'vault_id': 'vault-1',
        'schema_version': 1,
        'salt': randomService.generateSalt(),
        'kdf_params_json': '{not-valid-json',
        'cipher_algorithm': VaultCipherAlgorithm.xchacha20Poly1305.id,
        'wrapped_dek': makeSyntheticWrappedDek().toBytes(),
        'created_at': 1000,
        'updated_at': 1000,
      };
      expect(
        () => VaultMetadata.fromMap(invalidJsonRow),
        throwsA(isA<StorageException>()),
      );
    });
  });
}
