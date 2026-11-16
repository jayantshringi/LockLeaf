import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockleaf/features/tools/domain/base32.dart';
import 'package:lockleaf/features/tools/domain/totp_algorithm.dart';
import 'package:lockleaf/features/tools/domain/totp_config.dart';
import 'package:lockleaf/features/tools/domain/totp_generator.dart';

void main() {
  group('RFC 6238 Appendix B Official Test Vectors', () {
    // RFC 6238 shared secrets:
    // SHA1 Seed: 20 bytes "12345678901234567890" (ASCII)
    final sha1Secret = Base32.encode(utf8.encode('12345678901234567890'));

    // SHA256 Seed: 32 bytes "12345678901234567890123456789012"
    final sha256Secret =
        Base32.encode(utf8.encode('12345678901234567890123456789012'));

    // SHA512 Seed: 64 bytes "1234567890123456789012345678901234567890123456789012345678901234"
    final sha512Secret = Base32.encode(utf8.encode(
      '1234567890123456789012345678901234567890123456789012345678901234',
    ));

    test('validates RFC 6238 Appendix B table for HMAC-SHA-1', () async {
      final expectations = <int, String>{
        59: '94287082',
        1111111109: '07081804',
        1111111111: '14050471',
        1234567890: '89005924',
        2000000000: '69279037',
        20000000000: '65353130',
      };

      for (final entry in expectations.entries) {
        final code = await TotpGenerator.generateCode(
          secret: sha1Secret,
          timestampSeconds: entry.key,
          digits: 8,
          period: 30,
          algorithm: TotpAlgorithm.sha1,
        );
        expect(code, equals(entry.value),
            reason: 'Failed at time ${entry.key}');
      }
    });

    test('validates RFC 6238 Appendix B table for HMAC-SHA-256', () async {
      final expectations = <int, String>{
        59: '46119246',
        1111111109: '68084774',
        1111111111: '67062674',
        1234567890: '91819424',
        2000000000: '90698825',
        20000000000: '77737706',
      };

      for (final entry in expectations.entries) {
        final code = await TotpGenerator.generateCode(
          secret: sha256Secret,
          timestampSeconds: entry.key,
          digits: 8,
          period: 30,
          algorithm: TotpAlgorithm.sha256,
        );
        expect(code, equals(entry.value),
            reason: 'Failed at time ${entry.key}');
      }
    });

    test('validates RFC 6238 Appendix B table for HMAC-SHA-512', () async {
      final expectations = <int, String>{
        59: '90693936',
        1111111109: '25091201',
        1111111111: '99943326',
        1234567890: '93441116',
        2000000000: '38618901',
        20000000000: '47863826',
      };

      for (final entry in expectations.entries) {
        final code = await TotpGenerator.generateCode(
          secret: sha512Secret,
          timestampSeconds: entry.key,
          digits: 8,
          period: 30,
          algorithm: TotpAlgorithm.sha512,
        );
        expect(code, equals(entry.value),
            reason: 'Failed at time ${entry.key}');
      }
    });

    test('generates standard 6-digit codes correctly', () async {
      // For Time = 59 and SHA1, 8-digit is 94287082, so 6-digit is 287082
      final code = await TotpGenerator.generateCode(
        secret: sha1Secret,
        timestampSeconds: 59,
        digits: 6,
        period: 30,
        algorithm: TotpAlgorithm.sha1,
      );
      expect(code, equals('287082'));
    });

    test('verifies candidate codes within drift window', () async {
      const fixedTime = 1234567890;
      final currentCode = await TotpGenerator.generateCode(
        secret: sha1Secret,
        timestampSeconds: fixedTime,
      );
      final prevCode = await TotpGenerator.generateCode(
        secret: sha1Secret,
        timestampSeconds: fixedTime - 30,
      );
      final nextCode = await TotpGenerator.generateCode(
        secret: sha1Secret,
        timestampSeconds: fixedTime + 30,
      );
      final twoStepsAwayCode = await TotpGenerator.generateCode(
        secret: sha1Secret,
        timestampSeconds: fixedTime + 60,
      );

      // Matches current step
      expect(
        await TotpGenerator.verifyCode(
          candidateCode: currentCode,
          secret: sha1Secret,
          timestampSeconds: fixedTime,
        ),
        isTrue,
      );

      // Matches ±1 drift window
      expect(
        await TotpGenerator.verifyCode(
          candidateCode: prevCode,
          secret: sha1Secret,
          timestampSeconds: fixedTime,
        ),
        isTrue,
      );
      expect(
        await TotpGenerator.verifyCode(
          candidateCode: nextCode,
          secret: sha1Secret,
          timestampSeconds: fixedTime,
        ),
        isTrue,
      );

      // Rejects ±2 drift steps when driftSteps=1
      expect(
        await TotpGenerator.verifyCode(
          candidateCode: twoStepsAwayCode,
          secret: sha1Secret,
          timestampSeconds: fixedTime,
          driftSteps: 1,
        ),
        isFalse,
      );

      // Rejects invalid codes
      expect(
        await TotpGenerator.verifyCode(
          candidateCode: '000000',
          secret: sha1Secret,
          timestampSeconds: fixedTime,
        ),
        isFalse,
      );
    });

    test('calculates countdown remaining seconds and progress', () {
      // 59 seconds: 59 % 30 = 29 elapsed, 1 remaining
      expect(TotpGenerator.remainingSeconds(timestampSeconds: 59, period: 30),
          equals(1));
      expect(
        TotpGenerator.progressFraction(timestampSeconds: 59, period: 30),
        closeTo(1 / 30, 0.001),
      );

      // 60 seconds: 60 % 30 = 0 elapsed, 30 remaining
      expect(TotpGenerator.remainingSeconds(timestampSeconds: 60, period: 30),
          equals(30));
      expect(
        TotpGenerator.progressFraction(timestampSeconds: 60, period: 30),
        closeTo(1.0, 0.001),
      );
    });

    test('formats code blocks cleanly', () {
      expect(TotpGenerator.formatCode('123456'), equals('123 456'));
      expect(TotpGenerator.formatCode('12345678'), equals('1234 5678'));
      expect(TotpGenerator.formatCode('  123 456  '), equals('123 456'));
    });

    test('generates via TotpConfig model', () async {
      final config = TotpConfig(
        secret: sha1Secret,
        issuer: 'LockLeaf',
        accountName: 'alice@example.com',
      );
      final code = await TotpGenerator.generate(config, timestampSeconds: 59);
      expect(code, equals('287082'));
    });
  });
}
