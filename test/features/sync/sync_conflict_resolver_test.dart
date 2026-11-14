import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lockleaf/features/sync/domain/encrypted_sync_record.dart';
import 'package:lockleaf/features/sync/domain/sync_conflict_resolver.dart';
import 'package:lockleaf/features/vault/domain/vault_entry.dart';
import 'package:lockleaf/features/vault/domain/vault_entry_category.dart';

void main() {
  const localDeviceId = 'device-alpha';
  const remoteDeviceId = 'device-beta';
  late SyncConflictResolver resolver;

  setUp(() {
    resolver = const SyncConflictResolver(localDeviceId: localDeviceId);
  });

  VaultEntry makeEntry({
    required String id,
    required DateTime updatedAt,
    String title = 'Test Title',
    int schemaVersion = 1,
  }) {
    return VaultEntry(
      id: id,
      title: title,
      username: 'user@example.com',
      password: 'password123',
      category: VaultEntryCategory.login,
      schemaVersion: schemaVersion,
      createdAt: updatedAt.subtract(const Duration(days: 1)),
      updatedAt: updatedAt,
    );
  }

  EncryptedSyncRecord makeSyncRecord({
    required String id,
    required DateTime updatedAt,
    required bool isDeleted,
    int version = 1,
    String deviceId = remoteDeviceId,
  }) {
    return EncryptedSyncRecord(
      id: id,
      vaultId: 'vault-uuid-test',
      version: version,
      deviceId: deviceId,
      updatedAt: updatedAt,
      isDeleted: isDeleted,
      encryptedBlob: Uint8List(0),
    );
  }

  group('SyncConflictResolver', () {
    test('applies new remote entry when local entry is absent', () {
      final now = DateTime.utc(2026, 11, 14, 10, 0, 0);
      final remoteRecord = makeSyncRecord(id: 'entry-1', updatedAt: now, isDeleted: false);
      final remoteEntry = makeEntry(id: 'entry-1', updatedAt: now);

      final result = resolver.resolve(
        localEntry: null,
        remoteRecord: remoteRecord,
        decryptedRemoteEntry: remoteEntry,
      );

      expect(result.decision, equals(ConflictDecision.applyRemote));
    });

    test('ignores remote tombstone when local entry is already absent', () {
      final now = DateTime.utc(2026, 11, 14, 10, 0, 0);
      final remoteRecord = makeSyncRecord(id: 'entry-2', updatedAt: now, isDeleted: true);

      final result = resolver.resolve(
        localEntry: null,
        remoteRecord: remoteRecord,
      );

      expect(result.decision, equals(ConflictDecision.ignoreRemote));
    });

    test('deletes local entry when remote tombstone is newer or equal', () {
      final localTime = DateTime.utc(2026, 11, 14, 10, 0, 0);
      final remoteTime = DateTime.utc(2026, 11, 14, 11, 0, 0);

      final localEntry = makeEntry(id: 'entry-3', updatedAt: localTime);
      final remoteRecord = makeSyncRecord(id: 'entry-3', updatedAt: remoteTime, isDeleted: true);

      final result = resolver.resolve(
        localEntry: localEntry,
        remoteRecord: remoteRecord,
      );

      expect(result.decision, equals(ConflictDecision.deleteLocal));
    });

    test('keeps local entry when local update is newer than remote tombstone', () {
      final localTime = DateTime.utc(2026, 11, 14, 12, 0, 0);
      final remoteTime = DateTime.utc(2026, 11, 14, 10, 0, 0);

      final localEntry = makeEntry(id: 'entry-4', updatedAt: localTime);
      final remoteRecord = makeSyncRecord(id: 'entry-4', updatedAt: remoteTime, isDeleted: true);

      final result = resolver.resolve(
        localEntry: localEntry,
        remoteRecord: remoteRecord,
      );

      expect(result.decision, equals(ConflictDecision.keepLocal));
    });

    test('applies remote when remote update is strictly newer', () {
      final localTime = DateTime.utc(2026, 11, 14, 9, 0, 0);
      final remoteTime = DateTime.utc(2026, 11, 14, 10, 0, 0);

      final localEntry = makeEntry(id: 'entry-5', updatedAt: localTime);
      final remoteEntry = makeEntry(id: 'entry-5', updatedAt: remoteTime, title: 'Updated Remotely');
      final remoteRecord = makeSyncRecord(id: 'entry-5', updatedAt: remoteTime, isDeleted: false);

      final result = resolver.resolve(
        localEntry: localEntry,
        remoteRecord: remoteRecord,
        decryptedRemoteEntry: remoteEntry,
      );

      expect(result.decision, equals(ConflictDecision.applyRemote));
    });

    test('keeps local when local update is strictly newer', () {
      final localTime = DateTime.utc(2026, 11, 14, 11, 0, 0);
      final remoteTime = DateTime.utc(2026, 11, 14, 10, 0, 0);

      final localEntry = makeEntry(id: 'entry-6', updatedAt: localTime, title: 'Updated Locally');
      final remoteEntry = makeEntry(id: 'entry-6', updatedAt: remoteTime);
      final remoteRecord = makeSyncRecord(id: 'entry-6', updatedAt: remoteTime, isDeleted: false);

      final result = resolver.resolve(
        localEntry: localEntry,
        remoteRecord: remoteRecord,
        decryptedRemoteEntry: remoteEntry,
      );

      expect(result.decision, equals(ConflictDecision.keepLocal));
    });

    test('tie-breaks equal timestamps by higher version', () {
      final sameTime = DateTime.utc(2026, 11, 14, 10, 0, 0);

      final localEntry = makeEntry(id: 'entry-7', updatedAt: sameTime, schemaVersion: 2);
      final remoteEntry = makeEntry(id: 'entry-7', updatedAt: sameTime, schemaVersion: 3);
      final remoteRecord = makeSyncRecord(
        id: 'entry-7',
        updatedAt: sameTime,
        isDeleted: false,
        version: 3,
      );

      final result = resolver.resolve(
        localEntry: localEntry,
        remoteRecord: remoteRecord,
        decryptedRemoteEntry: remoteEntry,
      );

      expect(result.decision, equals(ConflictDecision.applyRemote));
    });

    test('tie-breaks equal timestamps and versions by deviceId lexicographically', () {
      final sameTime = DateTime.utc(2026, 11, 14, 10, 0, 0);

      final localEntry = makeEntry(id: 'entry-8', updatedAt: sameTime, schemaVersion: 1);
      final remoteEntry = makeEntry(id: 'entry-8', updatedAt: sameTime, schemaVersion: 1);

      // 'device-beta' > 'device-alpha' -> remote wins
      final remoteRecord = makeSyncRecord(
        id: 'entry-8',
        updatedAt: sameTime,
        isDeleted: false,
        version: 1,
        deviceId: 'device-beta',
      );

      final result = resolver.resolve(
        localEntry: localEntry,
        remoteRecord: remoteRecord,
        decryptedRemoteEntry: remoteEntry,
      );

      expect(result.decision, equals(ConflictDecision.applyRemote));
    });
  });
}
