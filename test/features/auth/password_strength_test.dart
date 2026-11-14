import 'package:flutter_test/flutter_test.dart';
import 'package:lockleaf/core/crypto/secure_random_service.dart';
import 'package:lockleaf/features/auth/domain/password_strength.dart';

void main() {
  late SecureRandomService randomService;

  String randomChars(String alphabet, int count) {
    final buffer = StringBuffer();
    for (var i = 0; i < count; i++) {
      buffer.write(alphabet[randomService.nextInt(alphabet.length)]);
    }
    return buffer.toString();
  }

  setUp(() {
    randomService = SecureRandomService();
  });

  group('PasswordStrengthEvaluator', () {
    test('returns score 0 for empty input', () {
      final result = PasswordStrengthEvaluator.evaluate('');

      expect(result.score, equals(0));
      expect(result.level, equals(PasswordStrengthLevel.weak));
      expect(result.estimatedEntropyBits, equals(0));
      expect(result.feedback, isNotEmpty);
    });

    test('classifies short input below 12 chars as weak', () {
      final shortMixed =
          '${randomChars('abcdef', 4)}'
          '${randomChars('ABCDEF', 2)}'
          '${randomChars('0123456789', 2)}';

      final result = PasswordStrengthEvaluator.evaluate(shortMixed);

      expect(result.level, equals(PasswordStrengthLevel.weak));
      expect(result.score, equals(1));
      expect(
        result.feedback.any((String msg) => msg.contains('12 characters')),
        isTrue,
      );
    });

    test(
      'classifies 12-char lowercase-only input as fair with diversity hints',
      () {
        final lowerOnly = randomChars('abcdefghijklmnopqrstuvwxyz', 12);

        final result = PasswordStrengthEvaluator.evaluate(lowerOnly);

        expect(result.level, equals(PasswordStrengthLevel.fair));
        expect(result.score, equals(2));
        expect(
          result.feedback.any((String msg) => msg.contains('uppercase')),
          isTrue,
        );
      },
    );

    test('classifies 13-char mixed-case input as good', () {
      final mixedCase =
          '${randomChars('abcdefghijklmnopqrstuvwxyz', 7)}'
          '${randomChars('ABCDEFGHIJKLMNOPQRSTUVWXYZ', 6)}';

      final result = PasswordStrengthEvaluator.evaluate(mixedCase);

      expect(result.level, equals(PasswordStrengthLevel.good));
      expect(result.score, equals(3));
    });

    test('classifies 18-char all-class random input as strong', () {
      final strongInput =
          '${randomChars('abcdefghijklmnopqrstuvwxyz', 6)}'
          '${randomChars('ABCDEFGHIJKLMNOPQRSTUVWXYZ', 5)}'
          '${randomChars('0123456789', 4)}'
          '${randomChars('!@#%^&*', 3)}';

      final result = PasswordStrengthEvaluator.evaluate(strongInput);

      expect(result.level, equals(PasswordStrengthLevel.strong));
      expect(result.score, equals(4));
      expect(result.estimatedEntropyBits, greaterThanOrEqualTo(85));
    });

    test('penalizes repeated character sequences', () {
      final repeated = 'aaaa${randomChars('bcdefghij', 10)}';

      final result = PasswordStrengthEvaluator.evaluate(repeated);

      expect(
        result.feedback.any((String msg) => msg.contains('repeated')),
        isTrue,
      );
    });
  });
}
