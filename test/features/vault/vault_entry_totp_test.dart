import 'package:flutter_test/flutter_test.dart';
import 'package:lockleaf/features/vault/domain/vault_entry.dart';
import 'package:lockleaf/features/vault/domain/vault_entry_category.dart';

void main() {
  group('VaultEntry TOTP Integration', () {
    final now = DateTime.utc(2026, 11, 16, 12, 0, 0);

    test('supports optional totpSecret in constructor and getters', () {
      final entryWithoutTotp = VaultEntry(
        id: 'entry-1',
        title: 'GitHub',
        username: 'alice',
        password: 'password123',
        createdAt: now,
        updatedAt: now,
      );
      expect(entryWithoutTotp.totpSecret, isNull);
      expect(entryWithoutTotp.hasTotp, isFalse);

      final entryWithTotp = VaultEntry(
        id: 'entry-2',
        title: 'GitHub',
        username: 'alice',
        password: 'password123',
        totpSecret: 'JBSWY3DPEHPK3PXP',
        createdAt: now,
        updatedAt: now,
      );
      expect(entryWithTotp.totpSecret, equals('JBSWY3DPEHPK3PXP'));
      expect(entryWithTotp.hasTotp, isTrue);
    });

    test('serializes and deserializes totpSecret in JSON', () {
      final entry = VaultEntry(
        id: 'entry-3',
        title: 'AWS Console',
        username: 'bob',
        password: 'secretPassword!',
        totpSecret: 'JBSWY3DPEHPK3PXP',
        category: VaultEntryCategory.login,
        isFavorite: true,
        createdAt: now,
        updatedAt: now,
      );

      final json = entry.toJson();
      expect(json['totpSecret'], equals('JBSWY3DPEHPK3PXP'));

      final restored = VaultEntry.fromJson(json);
      expect(restored.totpSecret, equals('JBSWY3DPEHPK3PXP'));
      expect(restored.hasTotp, isTrue);
      expect(restored, equals(entry));
    });

    test('updates totpSecret via copyWith and supports clearTotpSecret', () {
      final initial = VaultEntry(
        id: 'entry-4',
        title: 'GitLab',
        username: 'dev',
        password: 'pass',
        createdAt: now,
        updatedAt: now,
      );

      final withTotp = initial.copyWith(totpSecret: 'JBSWY3DPEHPK3PXP');
      expect(withTotp.hasTotp, isTrue);
      expect(withTotp.totpSecret, equals('JBSWY3DPEHPK3PXP'));

      final cleared = withTotp.copyWith(clearTotpSecret: true);
      expect(cleared.hasTotp, isFalse);
      expect(cleared.totpSecret, isNull);
    });

    test('redacts totpSecret in toString() representation', () {
      final entry = VaultEntry(
        id: 'entry-5',
        title: 'ProtonMail',
        username: 'user',
        password: 'sensitiveMasterPassword',
        totpSecret: 'JBSWY3DPEHPK3PXP',
        createdAt: now,
        updatedAt: now,
      );

      final stringified = entry.toString();
      expect(stringified, isNot(contains('sensitiveMasterPassword')));
      expect(stringified, isNot(contains('JBSWY3DPEHPK3PXP')));
      expect(stringified, contains('hasTotp: true'));
    });
  });
}
