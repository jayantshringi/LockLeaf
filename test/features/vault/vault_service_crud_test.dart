import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lockleaf/core/crypto/kdf_params.dart';
import 'package:lockleaf/core/crypto/secure_random_service.dart';
import 'package:lockleaf/core/errors/app_exception.dart';
import 'package:lockleaf/features/vault/domain/encrypted_entry_record.dart';
import 'package:lockleaf/features/vault/domain/vault_entry.dart';
import 'package:lockleaf/features/vault/domain/vault_entry_category.dart';
import 'package:lockleaf/features/vault/domain/vault_service.dart';

import 'in_memory_vault_storage.dart';

void main() {
  late InMemoryVaultStorage storage;
  late SecureRandomService randomService;
  late VaultService vaultService;

  String generateToken({int length = 18}) {
    final codes = List<int>.generate(
      length,
      (_) => 97 + randomService.nextInt(26),
    );
    return String.fromCharCodes(codes);
  }

  setUp(() async {
    storage = InMemoryVaultStorage();
    randomService = SecureRandomService();
    vaultService = VaultService(storage: storage, randomService: randomService);
    await vaultService.createVault(
      masterPassword: generateToken(),
      kdfParams: KdfParams(memoryKiB: 256, iterations: 1, parallelism: 1),
    );
  });

  tearDown(() {
    vaultService.lockVault();
  });

  group('VaultService entry CRUD and encryption', () {
    test('creates, reads, updates, and deletes encrypted entries', () async {
      final secret1 = generateToken(length: 20);
      final secret2 = generateToken(length: 20);

      final created = await vaultService.createEntry(
        title: 'UniqueServiceTitle',
        username: 'unique_user_handle',
        password: secret1,
        url: 'https://unique-domain.invalid',
        notes: 'UniquePrivateMemo',
        category: VaultEntryCategory.login,
        isFavorite: true,
      );

      final fetched = await vaultService.getEntryById(created.id);
      expect(fetched, equals(created));

      final all = await vaultService.getAllEntries();
      expect(all, hasLength(1));
      expect(all.first, equals(created));

      // Verify raw stored bytes contain zero plaintext fields.
      final rawRecord = await storage.getEntryById(created.id);
      expect(rawRecord, isNotNull);
      final rawText = utf8.decode(
        rawRecord!.encryptedBlob,
        allowMalformed: true,
      );
      expect(rawText, isNot(contains('UniqueServiceTitle')));
      expect(rawText, isNot(contains('unique_user_handle')));
      expect(rawText, isNot(contains(secret1)));
      expect(rawText, isNot(contains('unique-domain.invalid')));
      expect(rawText, isNot(contains('UniquePrivateMemo')));

      // Update entry and verify ciphertext & nonce rotate.
      final updated = await vaultService.updateEntry(
        created.copyWith(
          password: secret2,
          category: VaultEntryCategory.other,
          isFavorite: false,
        ),
      );
      final updatedRecord = await storage.getEntryById(created.id);
      expect(updated.password, equals(secret2));
      expect(updated.category, equals(VaultEntryCategory.other));
      expect(
        updatedRecord!.encryptedBlob,
        isNot(equals(rawRecord.encryptedBlob)),
      );

      final deleted = await vaultService.deleteEntry(created.id);
      expect(deleted, isTrue);
      expect(await vaultService.getEntryById(created.id), isNull);
      expect(await vaultService.deleteEntry(created.id), isFalse);
    });

    test('blocks all entry operations when vault is locked', () async {
      final entry = await vaultService.createEntry(
        title: 'Locked Test Entry',
        username: 'user',
        password: generateToken(),
      );

      vaultService.lockVault();

      await expectLater(
        vaultService.createEntry(
          title: 'Blocked',
          username: 'user',
          password: generateToken(),
        ),
        throwsA(isA<VaultLockedException>()),
      );
      await expectLater(
        vaultService.getAllEntries(),
        throwsA(isA<VaultLockedException>()),
      );
      await expectLater(
        vaultService.getEntryById(entry.id),
        throwsA(isA<VaultLockedException>()),
      );
      await expectLater(
        vaultService.updateEntry(entry),
        throwsA(isA<VaultLockedException>()),
      );
      await expectLater(
        vaultService.deleteEntry(entry.id),
        throwsA(isA<VaultLockedException>()),
      );
    });

    test('throws StorageException when updating missing entry', () async {
      final now = DateTime.now().toUtc();
      final missing = VaultEntry(
        id: 'missing-id-000',
        title: 'Ghost Entry',
        username: 'user',
        password: generateToken(),
        createdAt: now,
        updatedAt: now,
      );

      await expectLater(
        vaultService.updateEntry(missing),
        throwsA(isA<StorageException>()),
      );
    });

    test('rejects swapped ciphertext blobs across entry IDs via AAD', () async {
      final entryA = await vaultService.createEntry(
        title: 'Entry Alpha',
        username: 'alpha',
        password: generateToken(),
      );
      final entryB = await vaultService.createEntry(
        title: 'Entry Beta',
        username: 'beta',
        password: generateToken(),
      );

      final recordA = (await storage.getEntryById(entryA.id))!;
      final swappedRecordB = EncryptedEntryRecord(
        id: entryB.id,
        encryptedBlob: Uint8List.fromList(recordA.encryptedBlob),
        createdAt: entryB.createdAt,
        updatedAt: entryB.updatedAt,
      );
      await storage.upsertEntry(swappedRecordB);

      await expectLater(
        vaultService.getEntryById(entryB.id),
        throwsA(isA<CryptoException>()),
      );
    });
  });
}
