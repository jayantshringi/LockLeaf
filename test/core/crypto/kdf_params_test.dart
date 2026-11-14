import 'package:flutter_test/flutter_test.dart';
import 'package:lockleaf/core/constants/security_constants.dart';
import 'package:lockleaf/core/crypto/kdf_params.dart';
import 'package:lockleaf/core/errors/app_exception.dart';

void main() {
  group('KdfParams', () {
    test('standard constructor matches SecurityConstants', () {
      const params = KdfParams.standard();

      expect(params.memoryKiB, equals(SecurityConstants.argon2MemoryKiB));
      expect(params.iterations, equals(SecurityConstants.argon2Iterations));
      expect(params.parallelism, equals(SecurityConstants.argon2Parallelism));
      expect(
        params.hashLength,
        equals(SecurityConstants.derivedKeyLengthBytes),
      );
      expect(params.meetsProductionBaseline, isTrue);
    });

    test('validates RFC 9106 bounds and rejects weak configs', () {
      expect(
        () => KdfParams(memoryKiB: 16, iterations: 1, parallelism: 4),
        throwsA(isA<CryptoException>()),
      );
      expect(
        () => KdfParams(memoryKiB: 1024, iterations: 0, parallelism: 1),
        throwsA(isA<CryptoException>()),
      );
      expect(
        () => KdfParams(memoryKiB: 1024, iterations: 1, parallelism: 0),
        throwsA(isA<CryptoException>()),
      );
      expect(
        () => KdfParams(
          memoryKiB: 1024,
          iterations: 1,
          parallelism: 1,
          hashLength: 8,
        ),
        throwsA(isA<CryptoException>()),
      );
    });

    test('identifies lightweight test params as below production baseline', () {
      final lightweight = KdfParams(
        memoryKiB: 1024,
        iterations: 1,
        parallelism: 1,
      );

      expect(lightweight.meetsProductionBaseline, isFalse);
    });

    test('round-trips to and from JSON', () {
      const original = KdfParams.standard();
      final json = original.toJson();
      final decoded = KdfParams.fromJson(json);

      expect(decoded, equals(original));
    });

    test('throws CryptoException on invalid JSON', () {
      expect(
        () => KdfParams.fromJson(const <String, dynamic>{'memoryKiB': 65536}),
        throwsA(isA<CryptoException>()),
      );
    });
  });
}
