import 'package:flutter_test/flutter_test.dart';
import 'package:lockleaf/core/constants/security_constants.dart';
import 'package:lockleaf/core/crypto/secure_random_service.dart';
import 'package:lockleaf/core/errors/app_exception.dart';

void main() {
  late SecureRandomService randomService;

  setUp(() {
    randomService = SecureRandomService();
  });

  group('SecureRandomService', () {
    test('generates requested byte length', () {
      final bytes = randomService.generateBytes(32);

      expect(bytes.length, equals(32));
    });

    test('throws CryptoException for non-positive byte length', () {
      expect(
        () => randomService.generateBytes(0),
        throwsA(isA<CryptoException>()),
      );
      expect(
        () => randomService.generateBytes(-4),
        throwsA(isA<CryptoException>()),
      );
    });

    test('generates unique 32-byte salts by default', () {
      final salt1 = randomService.generateSalt();
      final salt2 = randomService.generateSalt();

      expect(salt1.length, equals(SecurityConstants.saltLengthBytes));
      expect(salt2.length, equals(SecurityConstants.saltLengthBytes));
      expect(salt1, isNot(equals(salt2)));
    });

    test('rejects weak salt lengths below 16 bytes', () {
      expect(
        () => randomService.generateSalt(length: 15),
        throwsA(isA<CryptoException>()),
      );
    });

    test('generates unique nonces of valid length', () {
      final nonce1 =
          randomService.generateNonce(SecurityConstants.xchacha20NonceBytes);
      final nonce2 =
          randomService.generateNonce(SecurityConstants.xchacha20NonceBytes);

      expect(nonce1.length, equals(SecurityConstants.xchacha20NonceBytes));
      expect(nonce2.length, equals(SecurityConstants.xchacha20NonceBytes));
      expect(nonce1, isNot(equals(nonce2)));
    });

    test('rejects nonce lengths below 12 bytes', () {
      expect(
        () => randomService.generateNonce(8),
        throwsA(isA<CryptoException>()),
      );
    });

    test('nextInt generates values within range and rejects non-positive max',
        () {
      for (var i = 0; i < 50; i++) {
        final value = randomService.nextInt(10);
        expect(value, greaterThanOrEqualTo(0));
        expect(value, lessThan(10));
      }

      expect(
        () => randomService.nextInt(0),
        throwsA(isA<CryptoException>()),
      );
    });
  });
}

