import 'package:flutter_test/flutter_test.dart';
import 'package:lockleaf/core/crypto/kdf_params.dart';
import 'package:lockleaf/core/errors/app_exception.dart';
import 'package:lockleaf/features/backup/domain/backup_service.dart';
import 'package:lockleaf/features/vault/domain/vault_entry_category.dart';
import 'package:lockleaf/features/vault/domain/vault_service.dart';

import '../vault/in_memory_vault_storage.dart';

void main() {
  late InMemoryVaultStorage storage;
  late VaultService vaultService;
  late BackupService backupService;

  const testMasterPassword = 'MasterPassword123!';
  const testBackupPassword = 'BackupPassword456!';
  const fastParams = KdfParams.testFast();

  setUp(() async {
    storage = InMemoryVaultStorage();
    vaultService = VaultService(storage: storage);
    backupService = BackupService();

    await vaultService.createVault(
      masterPassword: testMasterPassword,
      kdfParams: fastParams,
    );
  });

  tearDown(() {
    vaultService.lockVault();
  });

  group('BackupService', () {
    test('exports, inspects, and restores backup with fidelity', () async {
      await vaultService.createEntry(
        title: 'Work Email',
        username: 'alice@company.com',
        password: 'SuperSecretCompanyPassword1',
        url: 'https://mail.company.com',
        category: VaultEntryCategory.login,
      );
      await vaultService.createEntry(
        title: 'Safe Note',
        username: '',
        password: 'SecretPasscode',
        notes: 'Door code: 4321',
        category: VaultEntryCategory.secureNote,
      );

      final backupJson = await backupService.exportEncryptedBackup(
        vaultService: vaultService,
        backupPassword: testBackupPassword,
        notes: 'My Q4 Backup',
        kdfParams: fastParams,
      );

      // Inspect without password
      final header = backupService.inspectBackup(backupJson);
      expect(header.vaultId, equals(vaultService.activeVaultId));
      expect(header.entryCount, equals(2));
      expect(header.notes, equals('My Q4 Backup'));

      // Clean local entries and restore with overwrite
      final restored = await backupService.restoreBackup(
        backupJson: backupJson,
        backupPassword: testBackupPassword,
        vaultService: vaultService,
        overwriteExisting: true,
      );

      expect(restored.length, equals(2));
      final currentEntries = await vaultService.getAllEntries();
      expect(currentEntries.length, equals(2));
      expect(currentEntries.any((e) => e.title == 'Work Email'), isTrue);
      expect(currentEntries.any((e) => e.title == 'Safe Note'), isTrue);
    });

    test('rejects restore with wrong password', () async {
      await vaultService.createEntry(
        title: 'Bank',
        username: 'alice',
        password: 'BankPassword123',
      );

      final backupJson = await backupService.exportEncryptedBackup(
        vaultService: vaultService,
        backupPassword: testBackupPassword,
        kdfParams: fastParams,
      );

      expect(
        () => backupService.restoreBackup(
          backupJson: backupJson,
          backupPassword: 'WrongPassword999!',
          vaultService: vaultService,
        ),
        throwsA(isA<AuthenticationException>()),
      );
    });

    test('throws VaultLockedException when exporting locked vault', () async {
      vaultService.lockVault();

      expect(
        () => backupService.exportEncryptedBackup(
          vaultService: vaultService,
          backupPassword: testBackupPassword,
        ),
        throwsA(isA<VaultLockedException>()),
      );
    });

    test('restores backup to brand new vault on fresh device', () async {
      await vaultService.createEntry(
        title: 'Personal Cloud',
        username: 'alice',
        password: 'CloudPassword1!',
      );

      final backupJson = await backupService.exportEncryptedBackup(
        vaultService: vaultService,
        backupPassword: testBackupPassword,
        kdfParams: fastParams,
      );

      // Simulate new fresh device storage
      final freshStorage = InMemoryVaultStorage();
      final freshVaultService = VaultService(storage: freshStorage);

      final restored = await backupService.restoreToNewVault(
        backupJson: backupJson,
        backupPassword: testBackupPassword,
        newMasterPassword: 'BrandNewMasterPassword789!',
        vaultService: freshVaultService,
      );

      expect(restored.length, equals(1));
      expect(freshVaultService.isUnlocked, isTrue);

      final entries = await freshVaultService.getAllEntries();
      expect(entries.length, equals(1));
      expect(entries.first.title, equals('Personal Cloud'));
    });
  });
}
