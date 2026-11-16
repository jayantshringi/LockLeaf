import 'package:equatable/equatable.dart';
import 'package:lockleaf/core/constants/security_constants.dart';
import 'package:lockleaf/core/errors/app_exception.dart';
import 'package:lockleaf/features/tools/domain/base32.dart';
import 'package:lockleaf/features/tools/domain/totp_algorithm.dart';

/// Configuration parameters for an RFC 6238 Time-Based One-Time Password token.
class TotpConfig extends Equatable {
  /// Base32-encoded shared secret key.
  final String secret;

  /// HMAC digest algorithm (RFC 6238 default: SHA1).
  final TotpAlgorithm algorithm;

  /// Output token length in digits (typically 6 or 8).
  final int digits;

  /// Time-step interval in seconds (default: 30).
  final int period;

  /// Optional token issuer (e.g. 'GitHub', 'Google', 'AWS').
  final String? issuer;

  /// Optional account identifier or email (e.g. 'alice@example.com').
  final String? accountName;

  /// Creates and validates a [TotpConfig].
  TotpConfig({
    required String secret,
    this.algorithm = TotpAlgorithm.sha1,
    this.digits = SecurityConstants.totpDefaultDigits,
    this.period = SecurityConstants.totpDefaultPeriodSeconds,
    this.issuer,
    this.accountName,
  }) : secret = secret.replaceAll(RegExp(r'[\s\-=]'), '').toUpperCase() {
    if (this.secret.isEmpty) {
      throw const ValidationException('TOTP secret key cannot be empty.');
    }
    // Verify valid Base32 decoding
    try {
      Base32.decode(this.secret);
    } catch (_) {
      throw const ValidationException(
        'TOTP secret contains invalid Base32 characters.',
      );
    }
    if (digits < 6 || digits > 8) {
      throw ValidationException(
        'TOTP digit count must be between 6 and 8. Received: $digits.',
      );
    }
    if (period <= 0 || period > 300) {
      throw ValidationException(
        'TOTP period must be between 1 and 300 seconds. Received: $period.',
      );
    }
  }

  /// Copies this config with modified fields.
  TotpConfig copyWith({
    String? secret,
    TotpAlgorithm? algorithm,
    int? digits,
    int? period,
    String? issuer,
    bool clearIssuer = false,
    String? accountName,
    bool clearAccountName = false,
  }) {
    return TotpConfig(
      secret: secret ?? this.secret,
      algorithm: algorithm ?? this.algorithm,
      digits: digits ?? this.digits,
      period: period ?? this.period,
      issuer: clearIssuer ? null : (issuer ?? this.issuer),
      accountName:
          clearAccountName ? null : (accountName ?? this.accountName),
    );
  }

  /// Formats this configuration into a standard `otpauth://totp/` URI.
  Uri toUri() {
    final effectiveIssuer = issuer?.trim();
    final effectiveAccount = accountName?.trim() ?? 'SecretKey';
    final label = (effectiveIssuer != null && effectiveIssuer.isNotEmpty)
        ? '$effectiveIssuer:$effectiveAccount'
        : effectiveAccount;

    final queryParams = <String, String>{
      'secret': secret,
      if (effectiveIssuer != null && effectiveIssuer.isNotEmpty)
        'issuer': effectiveIssuer,
      if (algorithm != TotpAlgorithm.sha1)
        'algorithm': algorithm.standardName,
      if (digits != SecurityConstants.totpDefaultDigits)
        'digits': digits.toString(),
      if (period != SecurityConstants.totpDefaultPeriodSeconds)
        'period': period.toString(),
    };

    return Uri(
      scheme: 'otpauth',
      host: 'totp',
      path: '/$label',
      queryParameters: queryParams,
    );
  }

  /// Redacted string representation preventing accidental key logging.
  @override
  String toString() =>
      'TotpConfig(issuer: $issuer, accountName: $accountName, '
      'digits: $digits, period: ${period}s, algorithm: ${algorithm.standardName}, '
      'secret: [REDACTED])';

  @override
  List<Object?> get props => [
        secret,
        algorithm,
        digits,
        period,
        issuer,
        accountName,
      ];
}
