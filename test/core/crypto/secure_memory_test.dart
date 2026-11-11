import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lockleaf/core/crypto/secure_memory.dart';

void main() {
  group('SecureMemory.wipeBytes', () {
    test('overwrites all bytes in a mutable buffer with zeros', () {
      final buffer = Uint8List.fromList(List<int>.generate(32, (i) => i + 1));

      SecureMemory.wipeBytes(buffer);

      expect(buffer.every((byte) => byte == 0), isTrue);
    });

    test('handles empty buffers safely', () {
      final empty = Uint8List(0);

      SecureMemory.wipeBytes(empty);

      expect(empty, isEmpty);
    });
  });

  group('SecureMemory.constantTimeEquals', () {
    test('returns true for identical byte sequences', () {
      final a = Uint8List.fromList(List<int>.generate(16, (i) => i * 3));
      final b = Uint8List.fromList(List<int>.generate(16, (i) => i * 3));

      expect(SecureMemory.constantTimeEquals(a, b), isTrue);
    });

    test('returns false when a single byte differs', () {
      final a = Uint8List.fromList(List<int>.generate(16, (i) => i));
      final b = Uint8List.fromList(List<int>.generate(16, (i) => i));
      b[15] ^= 0x01;

      expect(SecureMemory.constantTimeEquals(a, b), isFalse);
    });

    test('returns false when lengths differ', () {
      final a = Uint8List.fromList(<int>[1, 2, 3]);
      final b = Uint8List.fromList(<int>[1, 2, 3, 4]);

      expect(SecureMemory.constantTimeEquals(a, b), isFalse);
    });
  });
}

