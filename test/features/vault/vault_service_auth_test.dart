import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lockleaf/core/crypto/kdf_params.dart';
import 'package:lockleaf/core/crypto/secure_random_service.dart';
import 'package:lockleaf/core/errors/app_exception.dart';
import 'package:lockleaf/features/vault/domain/vault_service.dart';

import 'in_memory_vault_storage.dart';

void main() {
  late InMemoryVaultStorage storage;
  late SecureRandomService randomService;
  late VaultService vaultService;
  late KdfParams fastParams;

  String generateEphemeralInput({int length = 18}) {
    final codes = List<int>.generate(
      length,
      (_) => 97 + randomService.nextInt(26),
    );
    return String.fromCharCodes(codes);
  }

  setUp(() {
    storage = InMemoryVaultStorage();
    randomService = SecureRandomService();
    vaultService = VaultService(
      storage: storage,
      randomService: randomService,
    );
    fastParams = KdfParams(
      memoryKiB: 256,
      iterations: 1,
      parallelism: 1,
    );
  });

  tearDown(() {
    vaultService.lockVault();
  });

  group('VaultService lifecycle and authentication', () {
    test('creates vault, locks, and unlocks with matching password', () async {
      final passphrase = generateEphemeralInput();

      expect(await vaultService.isVaultInitialized(), isFalse);
      expect(vaultService.isUnlocked, isFalse);

      await vaultService.createVault(
        masterPassword: passphrase,
        kdfParams: fastParams,
      );

      expect(await vaultService.isVaultInitialized(), isTrue);
      expect(vaultService.isUnlocked, isTrue);
      expect(vaultService.activeVaultId, isNotNull);

      final rawMetaJson = jsonEncode(storage.rawMetadataRow);
      expect(rawMetaJson, isNot(contains(passphrase)));

      vaultService.lockVault();
      expect(vaultService.isUnlocked, isFalse);
      expect(vaultService.activeVaultId, isNull);

      await vaultService.unlockVault(passphrase);
      expect(vaultService.isUnlocked, isTrue);
    });

    test('rejects short master passwords and duplicate initialization',
        () async {
      await expectLater(
        vaultService.createVault(
          masterPassword: generateEphemeralInput(length: 8),
          kdfParams: fastParams,
        ),
        throwsA(isA<ValidationException>()),
      );

      final validPassphrase = generateEphemeralInput();
      await vaultService.createVault(
        masterPassword: validPassphrase,
        kdfParams: fastParams,
      );

      await expectLater(
        vaultService.createVault(
          masterPassword: validPassphrase,
          kdfParams: fastParams,
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('rejects wrong or empty master password on unlock', () async {
      final correctPass = generateEphemeralInput();
      final wrongPass = generateEphemeralInput();

      await vaultService.createVault(
        masterPassword: correctPass,
        kdfParams: fastParams,
      );
      vaultService.lockVault();

      await expectLater(
        vaultService.unlockVault(''),
        throwsA(isA<AuthenticationException>()),
      );

      await expectLater(
        vaultService.unlockVault(wrongPass),
        throwsA(isA<AuthenticationException>()),
      );
      expect(vaultService.isUnlocked, isFalse);
    });

    test('throws StorageException when unlocking uninitialized vault', () async {
      await expectLater(
        vaultService.unlockVault(generateEphemeralInput()),
        throwsA(isA<StorageException>()),
      );
    });

    test('rotates master password without losing encrypted entries', () async {
      final oldPass = generateEphemeralInput();
      final newPass = generateEphemeralInput();
      final entrySecret = generateEphemeralInput(length: 16);

      await vaultService.createVault(
        masterPassword: oldPass,
        kdfParams: fastParams,
      );
      final created = await vaultService.createEntry(
        title: 'Cloud Account',
        username: 'acct@example.invalid',
        password: entrySecret,
      );

      await expectLater(
        vaultService.changeMasterPassword(
          currentPassword: generateEphemeralInput(),
          newPassword: newPass,
        ),
        throwsA(isA<AuthenticationException>()),
      );

      await vaultService.changeMasterPassword(
        currentPassword: oldPass,
        newPassword: newPass,
      );
      vaultService.lockVault();

      await expectLater(
        vaultService.unlockVault(oldPass),
        throwsA(isA<AuthenticationException>()),
      );

      await vaultService.unlockVault(newPass);
      final restored = await vaultService.getEntryById(created.id);
      expect(restored, isNotNull);
      expect(restored?.password, equals(entrySecret));
    });
  });
}
