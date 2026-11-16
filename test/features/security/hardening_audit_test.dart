import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lockleaf/core/crypto/secure_memory.dart';
import 'package:lockleaf/core/errors/app_exception.dart';
import 'package:lockleaf/features/tools/domain/totp_config.dart';
import 'package:lockleaf/features/vault/domain/vault_entry.dart';
import 'package:lockleaf/features/vault/domain/vault_entry_category.dart';

void main() {
  group('Security Hardening & Zeroization Audit', () {
    test('SecureMemory.wipeBytes zeroes out sensitive byte buffers in-place',
        () {
      final buffer = Uint8List.fromList([1, 2, 3, 4, 5, 255, 128, 42]);
      SecureMemory.wipeBytes(buffer);

      for (var i = 0; i < buffer.length; i++) {
        expect(buffer[i], equals(0), reason: 'Byte at index $i was not wiped');
      }
    });

    test('SecureMemory.wipeBytes handles empty buffer gracefully', () {
      final emptyBuffer = Uint8List(0);
      expect(() => SecureMemory.wipeBytes(emptyBuffer), returnsNormally);
    });

    test('SecureMemory.constantTimeEquals compares buffers in constant time',
        () {
      final a = [10, 20, 30, 40, 50];
      final b = [10, 20, 30, 40, 50];
      final c = [10, 20, 30, 40, 51];
      final d = [10, 20, 30];

      expect(SecureMemory.constantTimeEquals(a, b), isTrue);
      expect(SecureMemory.constantTimeEquals(a, c), isFalse);
      expect(SecureMemory.constantTimeEquals(a, d), isFalse);
    });

    test('Zero Plaintext Leakage: VaultEntry.toString() redacts all secrets',
        () {
      const plaintextPassword = 'SuperSecretPlaintextPassword!99#';
      const totpSecret = 'JBSWY3DPEHPK3PXP';
      const privateNote = 'Highly classified sensitive note';
      const privateUrl = 'https://internal-bank.example.com';

      final entry = VaultEntry(
        id: 'secure-entry-uuid-1',
        title: 'Banking Portal',
        username: 'alice_admin',
        password: plaintextPassword,
        url: privateUrl,
        notes: privateNote,
        totpSecret: totpSecret,
        category: VaultEntryCategory.login,
        isFavorite: true,
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      );

      final representation = entry.toString();

      expect(representation, isNot(contains(plaintextPassword)));
      expect(representation, isNot(contains(totpSecret)));
      expect(representation, isNot(contains(privateNote)));
      expect(representation, isNot(contains(privateUrl)));
      expect(representation, isNot(contains('alice_admin')));
      expect(representation, isNot(contains('Banking Portal')));
      expect(representation, contains('hasTotp: true'));
    });

    test('Zero Plaintext Leakage: TotpConfig.toString() redacts secret key',
        () {
      const secret = 'JBSWY3DPEHPK3PXP';
      final config = TotpConfig(
        secret: secret,
        issuer: 'Google',
        accountName: 'user@gmail.com',
      );

      final representation = config.toString();
      expect(representation, isNot(contains(secret)));
      expect(representation, contains('[REDACTED]'));
    });

    test('Exceptions do not inadvertently leak credentials', () {
      const rateLimitEx = RateLimitException(
        'Too many failed attempts. Locked out for 60 seconds.',
        remainingCooldown: Duration(seconds: 60),
      );
      expect(rateLimitEx.toString(), isNot(contains('password')));
      expect(rateLimitEx.lockoutSeconds, equals(60));

      const validationEx = ValidationException('Entry title cannot be empty.');
      expect(validationEx.toString(), contains('Entry title cannot be empty.'));
    });
  });
}
