import 'package:flutter_test/flutter_test.dart';
import 'package:lockleaf/core/errors/app_exception.dart';
import 'package:lockleaf/features/tools/domain/otpauth_uri_parser.dart';
import 'package:lockleaf/features/tools/domain/totp_algorithm.dart';
import 'package:lockleaf/features/tools/domain/totp_config.dart';

void main() {
  group('OtpauthUriParser', () {
    test('parses standard Google Authenticator URI', () {
      const uri =
          'otpauth://totp/GitHub:alice?secret=JBSWY3DPEHPK3PXP&issuer=GitHub';
      final config = OtpauthUriParser.parse(uri);

      expect(config.secret, equals('JBSWY3DPEHPK3PXP'));
      expect(config.issuer, equals('GitHub'));
      expect(config.accountName, equals('alice'));
      expect(config.algorithm, equals(TotpAlgorithm.sha1));
      expect(config.digits, equals(6));
      expect(config.period, equals(30));
    });

    test('parses URI with URL-encoded parameters and explicit SHA256/8-digits', () {
      const uri =
          'otpauth://totp/Acme%20Corp:bob%40example.com?secret=JBSWY3DPEHPK3PXP&issuer=Acme%20Corp&algorithm=SHA256&digits=8&period=60';
      final config = OtpauthUriParser.parse(uri);

      expect(config.secret, equals('JBSWY3DPEHPK3PXP'));
      expect(config.issuer, equals('Acme Corp'));
      expect(config.accountName, equals('bob@example.com'));
      expect(config.algorithm, equals(TotpAlgorithm.sha256));
      expect(config.digits, equals(8));
      expect(config.period, equals(60));
    });

    test('supports bare Base32 secret string', () {
      final config = OtpauthUriParser.parse('JBSWY3DPEHPK3PXP');
      expect(config.secret, equals('JBSWY3DPEHPK3PXP'));
      expect(config.issuer, isNull);
      expect(config.accountName, isNull);
      expect(config.algorithm, equals(TotpAlgorithm.sha1));
      expect(config.digits, equals(6));
      expect(config.period, equals(30));
    });

    test('cleans whitespace, dashes and lowercase in bare secret', () {
      final config = OtpauthUriParser.parse(' jbsw-y3dp-ehpk-3pxp ');
      expect(config.secret, equals('JBSWY3DPEHPK3PXP'));
    });

    test('round-trips TotpConfig toUri and parse', () {
      final original = TotpConfig(
        secret: 'JBSWY3DPEHPK3PXP',
        issuer: 'LockLeaf',
        accountName: 'alice@example.com',
        algorithm: TotpAlgorithm.sha256,
        digits: 8,
        period: 60,
      );

      final uri = original.toUri();
      final parsed = OtpauthUriParser.parse(uri.toString());

      expect(parsed.secret, equals(original.secret));
      expect(parsed.issuer, equals(original.issuer));
      expect(parsed.accountName, equals(original.accountName));
      expect(parsed.algorithm, equals(original.algorithm));
      expect(parsed.digits, equals(original.digits));
      expect(parsed.period, equals(original.period));
    });

    test('throws ValidationException on invalid input', () {
      expect(() => OtpauthUriParser.parse(''), throwsA(isA<ValidationException>()));
      expect(
        () => OtpauthUriParser.parse('https://example.com/totp?secret=ABC'),
        throwsA(isA<ValidationException>()),
      );
      expect(
        () => OtpauthUriParser.parse('otpauth://hotp/alice?secret=ABC&counter=1'),
        throwsA(isA<ValidationException>()),
      );
      expect(
        () => OtpauthUriParser.parse('otpauth://totp/alice'),
        throwsA(isA<ValidationException>()),
      );
      expect(
        () => OtpauthUriParser.parse('otpauth://totp/alice?secret=INVALID!!!'),
        throwsA(isA<ValidationException>()),
      );
    });
  });
}
