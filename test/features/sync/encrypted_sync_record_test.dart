import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lockleaf/core/errors/app_exception.dart';
import 'package:lockleaf/features/sync/domain/encrypted_sync_record.dart';

void main() {
  group('EncryptedSyncRecord', () {
    test('round-trips JSON serialization faithfully', () {
      final now = DateTime.utc(2026, 11, 14, 10, 0, 0);
      final rawBlob = Uint8List.fromList([0xDE, 0xAD, 0xBE, 0xEF, 0x42]);

      final record = EncryptedSyncRecord(
        id: 'entry-uuid-1',
        vaultId: 'vault-uuid-a',
        version: 5,
        deviceId: 'device-client-123',
        updatedAt: now,
        isDeleted: false,
        encryptedBlob: rawBlob,
      );

      final json = record.toJson();
      final restored = EncryptedSyncRecord.fromJson(json);

      expect(restored.id, equals('entry-uuid-1'));
      expect(restored.vaultId, equals('vault-uuid-a'));
      expect(restored.version, equals(5));
      expect(restored.deviceId, equals('device-client-123'));
      expect(restored.updatedAt, equals(now));
      expect(restored.isDeleted, isFalse);
      expect(restored.encryptedBlob, equals(rawBlob));
      expect(restored, equals(record));
    });

    test('preserves tombstone deletion flag', () {
      final now = DateTime.now().toUtc();
      final tombstone = EncryptedSyncRecord(
        id: 'deleted-entry-1',
        vaultId: 'vault-uuid-b',
        version: 12,
        deviceId: 'device-bob',
        updatedAt: now,
        isDeleted: true,
        encryptedBlob: const <int>[],
      );

      final json = tombstone.toJson();
      final restored = EncryptedSyncRecord.fromJson(json);

      expect(restored.isDeleted, isTrue);
      expect(restored.encryptedBlob, isEmpty);
    });

    test('validates required fields and rejects invalid inputs', () {
      final now = DateTime.now().toUtc();

      expect(
        () => EncryptedSyncRecord(
          id: '   ',
          vaultId: 'vault-1',
          version: 1,
          deviceId: 'dev-1',
          updatedAt: now,
          isDeleted: false,
          encryptedBlob: const [],
        ),
        throwsA(isA<ValidationException>()),
      );

      expect(
        () => EncryptedSyncRecord(
          id: 'id-1',
          vaultId: '',
          version: 1,
          deviceId: 'dev-1',
          updatedAt: now,
          isDeleted: false,
          encryptedBlob: const [],
        ),
        throwsA(isA<ValidationException>()),
      );

      expect(
        () => EncryptedSyncRecord(
          id: 'id-1',
          vaultId: 'v-1',
          version: -1,
          deviceId: 'dev-1',
          updatedAt: now,
          isDeleted: false,
          encryptedBlob: const [],
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('syncAad returns correct context format', () {
      final aad = EncryptedSyncRecord.syncAad('vault-123', 'entry-456');
      expect(aad, equals('lockleaf:sync:v1:vault-123:entry-456'));
    });

    test('defensively copies encryptedBlob bytes', () {
      final mutable = Uint8List.fromList([1, 2, 3]);
      final record = EncryptedSyncRecord(
        id: 'e1',
        vaultId: 'v1',
        version: 1,
        deviceId: 'd1',
        updatedAt: DateTime.now().toUtc(),
        isDeleted: false,
        encryptedBlob: mutable,
      );

      mutable[0] = 99;
      expect(record.encryptedBlob[0], equals(1));
    });
  });
}
