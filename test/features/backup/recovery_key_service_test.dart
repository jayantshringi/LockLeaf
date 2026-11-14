import 'package:flutter_test/flutter_test.dart';
import 'package:lockleaf/core/crypto/cipher_algorithm.dart';
import 'package:lockleaf/core/crypto/encrypted_payload.dart';
import 'package:lockleaf/core/crypto/kdf_params.dart';
import 'package:lockleaf/core/crypto/secure_random_service.dart';
import 'package:lockleaf/core/errors/app_exception.dart';
import 'package:lockleaf/features/backup/domain/recovery_key.dart';
import 'package:lockleaf/features/backup/domain/recovery_key_service.dart';
import 'package:lockleaf/features/vault/domain/vault_metadata.dart';

void main() {
  final randomService = SecureRandomService();
  late RecoveryKeyService recoveryService;

  setUp(() {
    recoveryService = RecoveryKeyService();
  });

  group('RecoveryKeyService', () {
    test(
      'successfully wraps and unwraps DEK using valid recovery key',
      () async {
        final dekBytes = randomService.generateBytes(32);
        final recoveryKey = RecoveryKey.generate();
        const vaultId = 'vault-test-1234';
        const kdfParams = KdfParams.testFast();

        final wrapResult = await recoveryService.wrapDek(
          recoveryKey: recoveryKey,
          dekBytes: dekBytes,
          vaultId: vaultId,
          cipherAlgorithm: VaultCipherAlgorithm.xchacha20Poly1305,
          params: kdfParams,
        );

        final dummyMasterSalt = randomService.generateSalt();
        final metadata = VaultMetadata(
          vaultId: vaultId,
          salt: dummyMasterSalt,
          kdfParams: kdfParams,
          cipherAlgorithm: VaultCipherAlgorithm.xchacha20Poly1305,
          wrappedDek: wrapResult.wrappedDek,
          recoverySalt: wrapResult.recoverySalt,
          recoveryWrappedDek: wrapResult.wrappedDek,
          createdAt: DateTime.now().toUtc(),
          updatedAt: DateTime.now().toUtc(),
        );

        final unwrappedDek = await recoveryService.unwrapDek(
          recoveryKey: recoveryKey,
          metadata: metadata,
        );

        expect(unwrappedDek, equals(dekBytes));
      },
    );

    test('rejects wrong recovery key with AuthenticationException', () async {
      final dekBytes = randomService.generateBytes(32);
      final key1 = RecoveryKey.generate();
      final key2 = RecoveryKey.generate();
      const vaultId = 'vault-test-wrong-key';
      const kdfParams = KdfParams.testFast();

      final wrapResult = await recoveryService.wrapDek(
        recoveryKey: key1,
        dekBytes: dekBytes,
        vaultId: vaultId,
        cipherAlgorithm: VaultCipherAlgorithm.xchacha20Poly1305,
        params: kdfParams,
      );

      final metadata = VaultMetadata(
        vaultId: vaultId,
        salt: randomService.generateSalt(),
        kdfParams: kdfParams,
        cipherAlgorithm: VaultCipherAlgorithm.xchacha20Poly1305,
        wrappedDek: wrapResult.wrappedDek,
        recoverySalt: wrapResult.recoverySalt,
        recoveryWrappedDek: wrapResult.wrappedDek,
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      );

      expect(
        () => recoveryService.unwrapDek(recoveryKey: key2, metadata: metadata),
        throwsA(
          isA<AuthenticationException>().having(
            (e) => e.message,
            'message',
            contains('Invalid recovery key'),
          ),
        ),
      );
    });

    test(
      'throws ValidationException when metadata has no recovery key configured',
      () async {
        final key = RecoveryKey.generate();
        final dummyWrappedDek = EncryptedPayload(
          version: 1,
          algorithm: VaultCipherAlgorithm.xchacha20Poly1305,
          nonce: randomService.generateNonce(24),
          cipherText: randomService.generateBytes(32),
          mac: randomService.generateBytes(16),
        );

        final metadata = VaultMetadata(
          vaultId: 'vault-no-rek',
          salt: randomService.generateSalt(),
          kdfParams: const KdfParams.testFast(),
          cipherAlgorithm: VaultCipherAlgorithm.xchacha20Poly1305,
          wrappedDek: dummyWrappedDek,
          createdAt: DateTime.now().toUtc(),
          updatedAt: DateTime.now().toUtc(),
        );

        expect(
          () => recoveryService.unwrapDek(recoveryKey: key, metadata: metadata),
          throwsA(isA<ValidationException>()),
        );
      },
    );
  });
}
