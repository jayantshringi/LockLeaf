import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lockleaf/core/crypto/managed_secret_key.dart';
import 'package:lockleaf/core/crypto/secure_memory.dart';
import 'package:lockleaf/core/crypto/secure_random_service.dart';
import 'package:lockleaf/core/errors/app_exception.dart';

void main() {
  late SecureRandomService randomService;

  setUp(() {
    randomService = SecureRandomService();
  });

  group('ManagedSecretKey', () {
    test('isolates internal key bytes from external buffer mutations', () {
      final sourceBytes = randomService.generateBytes(32);
      final expected = Uint8List.fromList(sourceBytes);
      final key = ManagedSecretKey.fromBytes(sourceBytes);

      SecureMemory.wipeBytes(sourceBytes);
      final copied = key.copyBytes();

      try {
        expect(key.length, equals(32));
        expect(key.isDestroyed, isFalse);
        expect(copied, equals(expected));
      } finally {
        SecureMemory.wipeBytes(copied);
        SecureMemory.wipeBytes(expected);
        key.destroy();
      }
    });

    test('rejects empty key bytes', () {
      expect(
        () => ManagedSecretKey.fromBytes(<int>[]),
        throwsA(isA<CryptoException>()),
      );
    });

    test('destroy invalidates key and blocks subsequent accesses', () {
      final raw = randomService.generateBytes(32);
      final key = ManagedSecretKey.fromBytes(raw);
      SecureMemory.wipeBytes(raw);

      key.destroy();
      key.destroy(); // Idempotent second call

      expect(key.isDestroyed, isTrue);
      expect(() => key.secretKey, throwsA(isA<CryptoException>()));
      expect(() => key.copyBytes(), throwsA(isA<CryptoException>()));
    });
  });
}

