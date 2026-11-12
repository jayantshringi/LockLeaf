import 'package:flutter_test/flutter_test.dart';
import 'package:lockleaf/core/crypto/secure_random_service.dart';
import 'package:lockleaf/core/errors/app_exception.dart';
import 'package:lockleaf/features/vault/domain/encrypted_entry_record.dart';

void main() {
  late SecureRandomService randomService;

  setUp(() {
    randomService = SecureRandomService();
  });

  group('EncryptedEntryRecord', () {
    test('round-trips SQLite map serialization', () {
      final now = DateTime.utc(2026, 11, 11, 10, 10, 0);
      final record = EncryptedEntryRecord(
        id: 'entry-uuid-123',
        encryptedBlob: randomService.generateBytes(64),
        createdAt: now,
        updatedAt: now,
      );

      final parsed = EncryptedEntryRecord.fromMap(record.toMap());

      expect(parsed, equals(record));
    });

    test('isolates internal blob bytes from external mutations', () {
      final now = DateTime.now().toUtc();
      final source = randomService.generateBytes(32);
      final record = EncryptedEntryRecord(
        id: 'entry-isolated',
        encryptedBlob: source,
        createdAt: now,
        updatedAt: now,
      );

      source[0] ^= 0xff;
      final copy = record.encryptedBlob;
      copy[1] ^= 0xff;

      expect(record.encryptedBlob[0], isNot(equals(source[0])));
      expect(record.encryptedBlob[1], isNot(equals(copy[1])));
    });

    test('validates required ID and non-empty blob', () {
      final now = DateTime.now().toUtc();

      expect(
        () => EncryptedEntryRecord(
          id: '  ',
          encryptedBlob: randomService.generateBytes(16),
          createdAt: now,
          updatedAt: now,
        ),
        throwsA(isA<ValidationException>()),
      );

      expect(
        () => EncryptedEntryRecord(
          id: 'entry-1',
          encryptedBlob: const <int>[],
          createdAt: now,
          updatedAt: now,
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('throws StorageException on corrupt row map', () {
      expect(
        () => EncryptedEntryRecord.fromMap(<String, Object?>{'id': 'entry-1'}),
        throwsA(isA<StorageException>()),
      );
    });
  });
}
