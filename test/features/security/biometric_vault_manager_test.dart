import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lockleaf/core/crypto/kdf_params.dart';
import 'package:lockleaf/core/crypto/secure_random_service.dart';
import 'package:lockleaf/core/errors/app_exception.dart';
import 'package:lockleaf/features/security/domain/biometric_vault_manager.dart';
import 'package:lockleaf/features/vault/domain/vault_service.dart';

import '../vault/in_memory_vault_storage.dart';
import 'security_test_doubles.dart';

void main() {
  late SecureRandomService randomService;
  late InMemoryVaultStorage vaultStorage;
  late InMemorySecureKeyStorage keyStorage;
  late FakeBiometricAuthService biometricAuth;
  late VaultService vaultService;
  late BiometricVaultManager biometricManager;
  late KdfParams fastParams;

  String randomToken({int length = 18}) {
    final codes = List<int>.generate(
      length,
      (_) => 97 + randomService.nextInt(26),
    );
    return String.fromCharCodes(codes);
  }

  setUp(() {
    randomService = SecureRandomService();
    vaultStorage = InMemoryVaultStorage();
    keyStorage = InMemorySecureKeyStorage();
    biometricAuth = FakeBiometricAuthService();
    vaultService = VaultService(
      storage: vaultStorage,
      randomService: randomService,
    );
    biometricManager = BiometricVaultManager(
      vaultService: vaultService,
      secureStorage: keyStorage,
      biometricAuth: biometricAuth,
      randomService: randomService,
    );
    fastParams = KdfParams(memoryKiB: 256, iterations: 1, parallelism: 1);
  });

  tearDown(() {
    vaultService.lockVault();
  });

  group('BiometricVaultManager', () {
    test('seals DEK in secure storage without storing master password', () async {
      final masterPass = randomToken();
      final entrySecret = randomToken();

      await vaultService.createVault(
        masterPassword: masterPass,
        kdfParams: fastParams,
      );
      final entry = await vaultService.createEntry(
        title: 'Bank Login',
        username: 'user@example.invalid',
        password: entrySecret,
      );

      expect(await biometricManager.isBiometricUnlockEnabled(), isFalse);

      await biometricManager.enableBiometricUnlock();
      expect(await biometricManager.isBiometricUnlockEnabled(), isTrue);

      // Verify master password and entry secret never touch Keystore/Keychain.
      final storedDump = jsonEncode(keyStorage.entries);
      expect(storedDump, isNot(contains(masterPass)));
      expect(storedDump, isNot(contains(entrySecret)));

      vaultService.lockVault();
      expect(vaultService.isUnlocked, isFalse);

      final unlocked = await biometricManager.unlockWithBiometrics();
      expect(unlocked, isTrue);
      expect(vaultService.isUnlocked, isTrue);

      final restored = await vaultService.getEntryById(entry.id);
      expect(restored?.password, equals(entrySecret));
    });

    test(
      'keeps vault locked when biometric prompt fails or is canceled',
      () async {
        await vaultService.createVault(
          masterPassword: randomToken(),
          kdfParams: fastParams,
        );
        await biometricManager.enableBiometricUnlock();
        vaultService.lockVault();

        biometricAuth.shouldAuthenticate = false;
        final unlocked = await biometricManager.unlockWithBiometrics();

        expect(unlocked, isFalse);
        expect(vaultService.isUnlocked, isFalse);
      },
    );

    test('rejects enrollment when vault is locked', () async {
      await vaultService.createVault(
        masterPassword: randomToken(),
        kdfParams: fastParams,
      );
      vaultService.lockVault();

      await expectLater(
        biometricManager.enableBiometricUnlock(),
        throwsA(isA<VaultLockedException>()),
      );
    });

    test(
      'disabling biometrics clears Keystore entries and blocks unlock',
      () async {
        await vaultService.createVault(
          masterPassword: randomToken(),
          kdfParams: fastParams,
        );
        await biometricManager.enableBiometricUnlock();
        expect(keyStorage.entries, isNotEmpty);

        await biometricManager.disableBiometricUnlock();
        expect(keyStorage.entries, isEmpty);
        expect(await biometricManager.isBiometricUnlockEnabled(), isFalse);

        vaultService.lockVault();
        await expectLater(
          biometricManager.unlockWithBiometrics(),
          throwsA(isA<AuthenticationException>()),
        );
      },
    );
  });
}
