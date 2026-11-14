import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lockleaf/core/crypto/secure_random_service.dart';
import 'package:lockleaf/core/errors/app_exception.dart';
import 'package:lockleaf/features/vault/domain/vault_entry.dart';
import 'package:lockleaf/features/vault/domain/vault_entry_category.dart';

void main() {
  late SecureRandomService randomService;

  String randomToken() => base64Url.encode(randomService.generateBytes(12));

  setUp(() {
    randomService = SecureRandomService();
  });

  group('VaultEntry', () {
    test('round-trips JSON losslessly', () {
      final now = DateTime.utc(2026, 11, 11, 10, 0, 0);
      final entry = VaultEntry(
        id: 'entry-001',
        title: 'Sample Service',
        username: 'user_${randomToken()}',
        password: randomToken(),
        url: 'https://example.invalid',
        notes: 'note_${randomToken()}',
        category: VaultEntryCategory.login,
        isFavorite: true,
        createdAt: now,
        updatedAt: now,
      );

      final decoded = VaultEntry.fromJson(entry.toJson());

      expect(decoded, equals(entry));
    });

    test('validates required ID and title', () {
      final now = DateTime.now().toUtc();

      expect(
        () => VaultEntry(
          id: '   ',
          title: 'Valid Title',
          username: 'user',
          password: randomToken(),
          createdAt: now,
          updatedAt: now,
        ),
        throwsA(isA<ValidationException>()),
      );

      expect(
        () => VaultEntry(
          id: 'entry-1',
          title: '   ',
          username: 'user',
          password: randomToken(),
          createdAt: now,
          updatedAt: now,
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('copyWith updates and clears optional nullable fields', () {
      final now = DateTime.now().toUtc();
      final original = VaultEntry(
        id: 'entry-002',
        title: 'Original',
        username: 'user',
        password: randomToken(),
        url: 'https://example.invalid',
        notes: 'some note',
        createdAt: now,
        updatedAt: now,
      );

      final updated = original.copyWith(
        title: 'Updated',
        clearUrl: true,
        clearNotes: true,
        category: VaultEntryCategory.secureNote,
        isFavorite: true,
      );

      expect(updated.title, equals('Updated'));
      expect(updated.url, isNull);
      expect(updated.notes, isNull);
      expect(updated.category, equals(VaultEntryCategory.secureNote));
      expect(updated.isFavorite, isTrue);
    });

    test('toString redacts all sensitive entry fields', () {
      final now = DateTime.now().toUtc();
      final secretValue = randomToken();
      final userValue = 'acct_${randomToken()}';
      final noteValue = 'memo_${randomToken()}';

      final entry = VaultEntry(
        id: 'entry-redacted',
        title: 'Private Title',
        username: userValue,
        password: secretValue,
        url: 'https://private.invalid',
        notes: noteValue,
        createdAt: now,
        updatedAt: now,
      );

      final rendered = entry.toString();

      expect(rendered, contains('entry-redacted'));
      expect(rendered, isNot(contains(secretValue)));
      expect(rendered, isNot(contains(userValue)));
      expect(rendered, isNot(contains(noteValue)));
      expect(rendered, isNot(contains('Private Title')));
      expect(rendered, isNot(contains('private.invalid')));
    });

    test('rejects invalid JSON structures', () {
      expect(
        () => VaultEntry.fromJson(const <String, dynamic>{'id': 'only-id'}),
        throwsA(isA<ValidationException>()),
      );
    });
  });
}
