import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lockleaf/core/errors/app_exception.dart';
import 'package:lockleaf/features/backup/domain/crockford_base32.dart';
import 'package:lockleaf/features/backup/domain/recovery_key.dart';

void main() {
  group('CrockfordBase32', () {
    test('normalizes spaces, hyphens, and ambiguous characters', () {
      final input = ' ll-o1il-9a ';
      final normalized = CrockfordBase32.normalize(input);
      // 'll' -> '11', 'o' -> '0', '1' -> '1', 'i' -> '1', 'l' -> '1', '-' stripped
      expect(normalized, equals('1101119A'));
    });

    test('encodes and decodes arbitrary byte sequences', () {
      final data = Uint8List.fromList([0x00, 0xFF, 0x42, 0x13, 0x37]);
      final encoded = CrockfordBase32.encode(data);
      expect(encoded.isNotEmpty, isTrue);

      final decoded = CrockfordBase32.decode(encoded);
      expect(decoded.sublist(0, data.length), equals(data));
    });

    test('rejects illegal characters with ValidationException', () {
      expect(
        () => CrockfordBase32.normalize('ABC@123'),
        throwsA(isA<ValidationException>()),
      );
      expect(
        () => CrockfordBase32.normalize('KEY#VALUE'),
        throwsA(isA<ValidationException>()),
      );
    });

    test('crc16Ccitt calculates consistent check values', () {
      final data1 = Uint8List.fromList([1, 2, 3, 4, 5]);
      final data2 = Uint8List.fromList([1, 2, 3, 4, 6]);
      final crc1 = CrockfordBase32.crc16Ccitt(data1);
      final crc2 = CrockfordBase32.crc16Ccitt(data2);

      expect(crc1, isNot(equals(crc2)));
      expect(crc1, equals(CrockfordBase32.crc16Ccitt(data1)));
    });
  });

  group('RecoveryKey', () {
    test('generates key matching canonical format', () {
      final key = RecoveryKey.generate();
      expect(key.formatted.startsWith('LL-'), isTrue);
      final parts = key.formatted.split('-');
      // 'LL' + 8 groups of 4 characters = 9 parts
      expect(parts.length, equals(9));
      expect(parts[0], equals('LL'));
      for (var i = 1; i < parts.length; i++) {
        expect(parts[i].length, equals(4));
      }
      expect(key.entropyBytes.length, equals(RecoveryKey.entropyByteLength));
      expect(key.isDestroyed, isFalse);
    });

    test('parses and validates round-trip of generated key', () {
      final original = RecoveryKey.generate();
      final parsed = RecoveryKey.fromString(original.formatted);

      expect(parsed.constantTimeEquals(original), isTrue);
      expect(parsed.formatted, equals(original.formatted));
      expect(parsed.checksum, equals(original.checksum));
    });

    test('accepts lowercase input without prefix or with spaces', () {
      final original = RecoveryKey.generate();
      final rawWithoutPrefix = original.formatted
          .replaceFirst('LL-', '')
          .toLowerCase()
          .replaceAll('-', ' ');

      final parsed = RecoveryKey.fromString(rawWithoutPrefix);
      expect(parsed.constantTimeEquals(original), isTrue);
    });

    test('rejects single character alteration due to checksum mismatch', () {
      final original = RecoveryKey.generate();
      final formatted = original.formatted;

      // Replace a character in the middle
      final charToFlip = formatted[7] == 'A' ? 'B' : 'A';
      final tampered = formatted.replaceRange(7, 8, charToFlip);

      expect(
        () => RecoveryKey.fromString(tampered),
        throwsA(
          isA<ValidationException>().having(
            (e) => e.message,
            'message',
            contains('checksum'),
          ),
        ),
      );
    });

    test('rejects transposed characters due to checksum mismatch', () {
      final original = RecoveryKey.generate();
      final formatted = original.formatted;

      // Transpose characters at index 5 and 6
      final c1 = formatted[5];
      final c2 = formatted[6];
      if (c1 != c2) {
        final tampered = formatted.replaceRange(5, 7, '$c2$c1');
        expect(
          () => RecoveryKey.fromString(tampered),
          throwsA(isA<ValidationException>()),
        );
      }
    });

    test('rejects invalid length keys', () {
      expect(
        () => RecoveryKey.fromString('LL-1234-5678'),
        throwsA(
          isA<ValidationException>().having(
            (e) => e.message,
            'message',
            contains('length'),
          ),
        ),
      );
    });

    test('destroys and wipes entropy bytes', () {
      final key = RecoveryKey.generate();
      expect(key.isDestroyed, isFalse);
      key.destroy();
      expect(key.isDestroyed, isTrue);

      expect(() => key.formatted, throwsStateError);
      expect(() => key.entropyBytes, throwsStateError);
    });

    test('redacts toString output and never leaks entropy', () {
      final key = RecoveryKey.generate();
      final stringRep = key.toString();
      expect(stringRep, contains('LL-****'));
      expect(stringRep.contains(key.formatted), isFalse);
    });
  });
}
