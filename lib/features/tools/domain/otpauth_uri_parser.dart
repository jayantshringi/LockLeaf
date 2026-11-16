import 'package:lockleaf/core/constants/security_constants.dart';
import 'package:lockleaf/core/errors/app_exception.dart';
import 'package:lockleaf/features/tools/domain/totp_algorithm.dart';
import 'package:lockleaf/features/tools/domain/totp_config.dart';

/// Parser for standard Key URI format (`otpauth://totp/...`) widely used
/// by Google Authenticator, Bitwarden, 1Password, and Authy.
abstract class OtpauthUriParser {
  /// Parses an `otpauth://totp/...` URI or bare Base32 secret into a [TotpConfig].
  ///
  /// Throws [ValidationException] if the input cannot be parsed or lacks a secret.
  static TotpConfig parse(String rawInput) {
    final trimmed = rawInput.trim();
    if (trimmed.isEmpty) {
      throw const ValidationException('Input cannot be empty.');
    }

    // Bare secret key fallback (e.g. user pasted raw Base32 secret directly)
    if (!trimmed.toLowerCase().startsWith('otpauth://')) {
      return TotpConfig(secret: trimmed);
    }

    final Uri uri;
    try {
      uri = Uri.parse(trimmed);
    } catch (e) {
      throw ValidationException('Invalid otpauth URI structure: $e');
    }

    if (uri.scheme.toLowerCase() != 'otpauth') {
      throw const ValidationException('URI scheme must be "otpauth".');
    }

    // Host should be "totp" (we do not support counter-based hotp in this release)
    final type = uri.host.toLowerCase();
    if (type != 'totp') {
      throw ValidationException(
        'Unsupported OTP type: "$type". Only time-based "totp" is supported.',
      );
    }

    final query = uri.queryParameters;
    final secret = query['secret'];
    if (secret == null || secret.trim().isEmpty) {
      throw const ValidationException('Missing required "secret" parameter.');
    }

    // Path may contain "/[issuer:]accountName"
    var pathLabel = uri.path;
    if (pathLabel.startsWith('/')) {
      pathLabel = pathLabel.substring(1);
    }
    pathLabel = Uri.decodeComponent(pathLabel).trim();

    String? parsedIssuer;
    String? parsedAccount;

    if (pathLabel.contains(':')) {
      final parts = pathLabel.split(':');
      parsedIssuer = parts[0].trim();
      parsedAccount = parts.sublist(1).join(':').trim();
    } else if (pathLabel.isNotEmpty) {
      parsedAccount = pathLabel;
    }

    // Explicit query param takes precedence
    final queryIssuer = query['issuer']?.trim();
    final issuer = (queryIssuer != null && queryIssuer.isNotEmpty)
        ? queryIssuer
        : (parsedIssuer != null && parsedIssuer.isNotEmpty ? parsedIssuer : null);

    final algoParam = query['algorithm'];
    final algorithm = TotpAlgorithm.fromName(algoParam);

    final digitsParam = query['digits'];
    final digits = digitsParam != null
        ? int.tryParse(digitsParam) ?? SecurityConstants.totpDefaultDigits
        : SecurityConstants.totpDefaultDigits;

    final periodParam = query['period'];
    final period = periodParam != null
        ? int.tryParse(periodParam) ?? SecurityConstants.totpDefaultPeriodSeconds
        : SecurityConstants.totpDefaultPeriodSeconds;

    return TotpConfig(
      secret: secret,
      algorithm: algorithm,
      digits: digits,
      period: period,
      issuer: issuer,
      accountName: parsedAccount?.isNotEmpty == true ? parsedAccount : null,
    );
  }
}
