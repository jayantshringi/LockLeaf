import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:lockleaf/core/constants/security_constants.dart';
import 'package:lockleaf/core/crypto/secure_memory.dart';
import 'package:lockleaf/features/tools/domain/base32.dart';
import 'package:lockleaf/features/tools/domain/totp_algorithm.dart';
import 'package:lockleaf/features/tools/domain/totp_config.dart';

/// Engine for generating and validating RFC 6238 / RFC 4226 Time-Based
/// One-Time Password (TOTP) codes with memory scrubbing.
abstract class TotpGenerator {
  /// Generates a rolling TOTP code for the provided [secret].
  ///
  /// If [timestampSeconds] is omitted, uses the current epoch time in seconds.
  /// Zeroizes the decoded secret bytes from memory upon completion.
  static Future<String> generateCode({
    required String secret,
    int? timestampSeconds,
    int period = SecurityConstants.totpDefaultPeriodSeconds,
    int digits = SecurityConstants.totpDefaultDigits,
    TotpAlgorithm algorithm = TotpAlgorithm.sha1,
  }) async {
    final nowSeconds = timestampSeconds ?? (DateTime.now().millisecondsSinceEpoch ~/ 1000);
    final counter = nowSeconds ~/ period;

    final secretBytes = Base32.decode(secret);
    try {
      final counterBytes = Uint8List(8);
      var temp = counter;
      for (var i = 7; i >= 0; i--) {
        counterBytes[i] = temp & 0xff;
        temp = temp >> 8;
      }

      final hmac = algorithm.toHmac();
      final mac = await hmac.calculateMac(
        counterBytes,
        secretKey: SecretKey(secretBytes),
      );
      final hash = mac.bytes;

      // RFC 4226 dynamic truncation:
      final offset = hash[hash.length - 1] & 0x0f;
      final binary = ((hash[offset] & 0x7f) << 24) |
          ((hash[offset + 1] & 0xff) << 16) |
          ((hash[offset + 2] & 0xff) << 8) |
          (hash[offset + 3] & 0xff);

      final pow10 = math.pow(10, digits).toInt();
      final otp = binary % pow10;
      return otp.toString().padLeft(digits, '0');
    } finally {
      SecureMemory.wipeBytes(secretBytes);
    }
  }

  /// Generates a rolling TOTP code for the specified [config].
  static Future<String> generate(
    TotpConfig config, {
    int? timestampSeconds,
  }) {
    return generateCode(
      secret: config.secret,
      timestampSeconds: timestampSeconds,
      period: config.period,
      digits: config.digits,
      algorithm: config.algorithm,
    );
  }

  /// Verifies a user-supplied [candidateCode] in constant time across a drift window.
  ///
  /// Checks counter steps `[-driftSteps, +driftSteps]` around the current time.
  static Future<bool> verifyCode({
    required String candidateCode,
    required String secret,
    int? timestampSeconds,
    int period = SecurityConstants.totpDefaultPeriodSeconds,
    int digits = SecurityConstants.totpDefaultDigits,
    TotpAlgorithm algorithm = TotpAlgorithm.sha1,
    int driftSteps = SecurityConstants.totpAllowedDriftSteps,
  }) async {
    final cleanCandidate = candidateCode.replaceAll(RegExp(r'\s+'), '');
    if (cleanCandidate.length != digits) {
      return false;
    }

    final candidateBytes = utf8.encode(cleanCandidate);
    final nowSeconds = timestampSeconds ?? (DateTime.now().millisecondsSinceEpoch ~/ 1000);

    var matched = false;
    for (var step = -driftSteps; step <= driftSteps; step++) {
      final stepSeconds = nowSeconds + (step * period);
      final expectedCode = await generateCode(
        secret: secret,
        timestampSeconds: stepSeconds,
        period: period,
        digits: digits,
        algorithm: algorithm,
      );
      final expectedBytes = utf8.encode(expectedCode);
      if (SecureMemory.constantTimeEquals(candidateBytes, expectedBytes)) {
        matched = true;
      }
    }

    return matched;
  }

  /// Returns remaining seconds until the current token expires.
  static int remainingSeconds({
    int? timestampSeconds,
    int period = SecurityConstants.totpDefaultPeriodSeconds,
  }) {
    final nowSeconds = timestampSeconds ?? (DateTime.now().millisecondsSinceEpoch ~/ 1000);
    final elapsed = nowSeconds % period;
    final remaining = period - elapsed;
    return remaining == 0 ? period : remaining;
  }

  /// Returns current progress fraction [0.0, 1.0] representing remaining life of code.
  static double progressFraction({
    int? timestampSeconds,
    int period = SecurityConstants.totpDefaultPeriodSeconds,
  }) {
    final remaining = remainingSeconds(
      timestampSeconds: timestampSeconds,
      period: period,
    );
    return remaining / period;
  }

  /// Formats a raw numeric code into readable spaced blocks (e.g. `123 456` or `1234 5678`).
  static String formatCode(String code) {
    final clean = code.replaceAll(RegExp(r'\s+'), '');
    if (clean.length == 6) {
      return '${clean.substring(0, 3)} ${clean.substring(3)}';
    }
    if (clean.length == 8) {
      return '${clean.substring(0, 4)} ${clean.substring(4)}';
    }
    return clean;
  }
}
