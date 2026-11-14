import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lockleaf/core/crypto/cipher_algorithm.dart';
import 'package:lockleaf/core/crypto/cipher_service.dart';
import 'package:lockleaf/core/crypto/managed_secret_key.dart';
import 'package:lockleaf/core/crypto/secure_random_service.dart';
import 'package:lockleaf/features/sync/data/cloud_sync_transport.dart';
import 'package:lockleaf/features/sync/data/sync_storage_repository.dart';
import 'package:lockleaf/features/sync/domain/sync_engine.dart';
import 'package:lockleaf/features/sync/domain/sync_status.dart';
import 'package:lockleaf/features/vault/domain/encrypted_entry_record.dart';
import 'package:lockleaf/features/vault/domain/vault_entry.dart';
import 'package:lockleaf/features/vault/domain/vault_entry_category.dart';
import 'package:lockleaf/features/vault/domain/vault_session.dart';

import '../vault/in_memory_vault_storage.dart';

void main() {
  late InMemorySyncTransport sharedTransport;
  late ManagedSecretKey sharedDek;
  late VaultSession sessionAlpha;
  late VaultSession sessionBeta;

  late InMemoryVaultStorage vaultStorageAlpha;
  late InMemorySyncStorageRepository syncStorageAlpha;
  late SyncEngine engineAlpha;

  late InMemoryVaultStorage vaultStorageBeta;
  late InMemorySyncStorageRepository syncStorageBeta;
  late SyncEngine engineBeta;

  const vaultId = 'shared-vault-uuid-001';

  setUp(() {
    sharedTransport = InMemorySyncTransport();
    final random = SecureRandomService();
    final dekBytes = random.generateBytes(32);
    sharedDek = ManagedSecretKey.fromBytes(dekBytes);

    sessionAlpha = VaultSession(
      vaultId: vaultId,
      dek: ManagedSecretKey.fromBytes(dekBytes),
      cipherAlgorithm: VaultCipherAlgorithm.xchacha20Poly1305,
    );
    sessionBeta = VaultSession(
      vaultId: vaultId,
      dek: ManagedSecretKey.fromBytes(dekBytes),
      cipherAlgorithm: VaultCipherAlgorithm.xchacha20Poly1305,
    );

    vaultStorageAlpha = InMemoryVaultStorage();
    syncStorageAlpha = InMemorySyncStorageRepository();
    engineAlpha = SyncEngine(
      vaultStorage: vaultStorageAlpha,
      syncStorage: syncStorageAlpha,
      transport: sharedTransport,
      localDeviceId: 'device-alpha',
    );

    vaultStorageBeta = InMemoryVaultStorage();
    syncStorageBeta = InMemorySyncStorageRepository();
    engineBeta = SyncEngine(
      vaultStorage: vaultStorageBeta,
      syncStorage: syncStorageBeta,
      transport: sharedTransport,
      localDeviceId: 'device-beta',
    );
  });

  tearDown(() {
    sharedDek.destroy();
    sessionAlpha.lock();
    sessionBeta.lock();
  });

  EncryptedEntryRecord encryptToRecord(VaultSession session, VaultEntry entry) {
    final cipher = CipherService();
    final jsonBytes = Uint8List.fromList(
      utf8.encode(jsonEncode(entry.toJson())),
    );
    final payloadFuture = cipher.encryptBytes(
      plaintext: jsonBytes,
      key: session.activeKey,
      algorithm: session.cipherAlgorithm,
      associatedData: utf8.encode(session.entryAad(entry.id)),
    );
    // Use synchronous await via test helper
    EncryptedEntryRecord? record;
    payloadFuture.then((p) {
      record = EncryptedEntryRecord(
        id: entry.id,
        encryptedBlob: p.toBytes(),
        createdAt: entry.createdAt,
        updatedAt: entry.updatedAt,
      );
    });
    return record!;
  }

  group('SyncEngine multi-device convergence', () {
    test('syncs new entry from Device Alpha to Device Beta', () async {
      final now = DateTime.utc(2026, 11, 14, 10, 0, 0);
      final newEntry = VaultEntry(
        id: 'entry-uuid-github',
        title: 'GitHub',
        username: 'alice',
        password: 'SuperSecretGitHubPassword!',
        category: VaultEntryCategory.login,
        createdAt: now,
        updatedAt: now,
      );

      final cipher = CipherService();
      final jsonBytes = Uint8List.fromList(
        utf8.encode(jsonEncode(newEntry.toJson())),
      );
      final payload = await cipher.encryptBytes(
        plaintext: jsonBytes,
        key: sessionAlpha.activeKey,
        algorithm: sessionAlpha.cipherAlgorithm,
        associatedData: utf8.encode(sessionAlpha.entryAad(newEntry.id)),
      );
      await vaultStorageAlpha.upsertEntry(
        EncryptedEntryRecord(
          id: newEntry.id,
          encryptedBlob: payload.toBytes(),
          createdAt: newEntry.createdAt,
          updatedAt: newEntry.updatedAt,
        ),
      );
      await syncStorageAlpha.enqueueAction(
        entryId: newEntry.id,
        vaultId: vaultId,
        action: SyncAction.create,
      );

      expect(await syncStorageAlpha.getPendingQueueCount(vaultId), equals(1));

      // 2. Alpha syncs -> pushes to cloud
      final alphaResult = await engineAlpha.synchronize(session: sessionAlpha);
      expect(alphaResult.isSuccess, isTrue);
      expect(alphaResult.pushedCount, equals(1));
      expect(await syncStorageAlpha.getPendingQueueCount(vaultId), equals(0));

      // 3. Beta syncs -> pulls and decrypts entry
      final betaResult = await engineBeta.synchronize(session: sessionBeta);
      expect(betaResult.isSuccess, isTrue);
      expect(betaResult.pulledCount, equals(1));
      expect(betaResult.appliedRemoteCount, equals(1));

      // Verify entry exists in Beta's local vault
      final betaRecord = await vaultStorageBeta.getEntryById(newEntry.id);
      expect(betaRecord, isNotNull);
    });

    test('propagates deletion tombstones across devices', () async {
      final now = DateTime.utc(2026, 11, 14, 10, 0, 0);
      final entry = VaultEntry(
        id: 'entry-to-delete',
        title: 'Old Service',
        username: 'alice',
        password: 'OldPassword',
        category: VaultEntryCategory.login,
        createdAt: now,
        updatedAt: now,
      );

      final cipher = CipherService();
      final jsonBytes = Uint8List.fromList(
        utf8.encode(jsonEncode(entry.toJson())),
      );
      final payload = await cipher.encryptBytes(
        plaintext: jsonBytes,
        key: sessionAlpha.activeKey,
        algorithm: sessionAlpha.cipherAlgorithm,
        associatedData: utf8.encode(sessionAlpha.entryAad(entry.id)),
      );
      await vaultStorageAlpha.upsertEntry(
        EncryptedEntryRecord(
          id: entry.id,
          encryptedBlob: payload.toBytes(),
          createdAt: entry.createdAt,
          updatedAt: entry.updatedAt,
        ),
      );
      await syncStorageAlpha.enqueueAction(
        entryId: entry.id,
        vaultId: vaultId,
        action: SyncAction.create,
      );
      await engineAlpha.synchronize(session: sessionAlpha);

      // Beta pulls it
      await engineBeta.synchronize(session: sessionBeta);
      expect(await vaultStorageBeta.getEntryById(entry.id), isNotNull);

      // Alpha deletes it locally and enqueues delete
      await vaultStorageAlpha.deleteEntry(entry.id);
      await syncStorageAlpha.enqueueAction(
        entryId: entry.id,
        vaultId: vaultId,
        action: SyncAction.delete,
      );
      await engineAlpha.synchronize(session: sessionAlpha);

      // Beta syncs and should have deleted it locally
      final betaDeleteResult = await engineBeta.synchronize(
        session: sessionBeta,
      );
      expect(betaDeleteResult.isSuccess, isTrue);
      expect(betaDeleteResult.deletedLocalCount, equals(1));
      expect(await vaultStorageBeta.getEntryById(entry.id), isNull);
    });

    test('handles offline state without clearing local queue', () async {
      await syncStorageAlpha.enqueueAction(
        entryId: 'offline-item',
        vaultId: vaultId,
        action: SyncAction.create,
      );

      sharedTransport.isHealthy = false;

      final result = await engineAlpha.synchronize(session: sessionAlpha);
      expect(result.state, equals(SyncState.offline));
      expect(await syncStorageAlpha.getPendingQueueCount(vaultId), equals(1));
    });
  });
}
