import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockleaf/core/errors/app_exception.dart';
import 'package:lockleaf/features/tools/domain/base32.dart';

void main() {
  group('Base32 RFC 4648 Test Vectors', () {
    test('encodes empty buffer to empty string', () {
      expect(Base32.encode([]), equals(''));
      expect(Base32.decode(''), isEmpty);
    });

    test('encodes standard RFC 4648 test vectors without padding', () {
      expect(Base32.encode(utf8.encode('f')), equals('MY'));
      expect(Base32.encode(utf8.encode('fo')), equals('MZXQ'));
      expect(Base32.encode(utf8.encode('foo')), equals('MZXW6'));
      expect(Base32.encode(utf8.encode('foob')), equals('MZXW6YQ'));
      expect(Base32.encode(utf8.encode('fooba')), equals('MZXW6YTB'));
      expect(Base32.encode(utf8.encode('foobar')), equals('MZXW6YTBOI'));
    });

    test('encodes standard RFC 4648 test vectors with padding', () {
      expect(Base32.encode(utf8.encode('f'), pad: true), equals('MY======'));
      expect(Base32.encode(utf8.encode('fo'), pad: true), equals('MZXQ===='));
      expect(Base32.encode(utf8.encode('foo'), pad: true), equals('MZXW6==='));
      expect(Base32.encode(utf8.encode('foob'), pad: true), equals('MZXW6YQ='));
      expect(Base32.encode(utf8.encode('fooba'), pad: true), equals('MZXW6YTB'));
      expect(
        Base32.encode(utf8.encode('foobar'), pad: true),
        equals('MZXW6YTBOI======'),
      );
    });

    test('decodes standard RFC 4648 test vectors', () {
      expect(utf8.decode(Base32.decode('MY')), equals('f'));
      expect(utf8.decode(Base32.decode('MY======')), equals('f'));
      expect(utf8.decode(Base32.decode('MZXQ')), equals('fo'));
      expect(utf8.decode(Base32.decode('MZXW6')), equals('foo'));
      expect(utf8.decode(Base32.decode('MZXW6YQ')), equals('foob'));
      expect(utf8.decode(Base32.decode('MZXW6YTB')), equals('fooba'));
      expect(utf8.decode(Base32.decode('MZXW6YTBOI')), equals('foobar'));
      expect(utf8.decode(Base32.decode('MZXW6YTBOI======')), equals('foobar'));
    });

    test('ignores whitespace, hyphens, and casing during decoding', () {
      expect(utf8.decode(Base32.decode('mzxw6ytb')), equals('fooba'));
      expect(utf8.decode(Base32.decode('mzxw-6ytb')), equals('fooba'));
      expect(utf8.decode(Base32.decode(' M Z X W 6 Y T B ')), equals('fooba'));
      expect(utf8.decode(Base32.decode('MZXW-6YTB-OI==')), equals('foobar'));
    });

    test('throws ValidationException on invalid Base32 characters', () {
      expect(() => Base32.decode('INVALID!'), throwsA(isA<ValidationException>()));
      // '1', '8', '9', '0' are not in standard RFC 4648 Base32 alphabet
      expect(() => Base32.decode('MZXW1'), throwsA(isA<ValidationException>()));
      expect(() => Base32.decode('MZXW8'), throwsA(isA<ValidationException>()));
      expect(() => Base32.decode('MZXW9'), throwsA(isA<ValidationException>()));
      expect(() => Base32.decode('MZXW0'), throwsA(isA<ValidationException>()));
    });
  });
}
