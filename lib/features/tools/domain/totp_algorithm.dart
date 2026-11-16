import 'package:cryptography/cryptography.dart';
import 'package:lockleaf/core/errors/app_exception.dart';

/// Hash algorithm used for HMAC-based TOTP code derivation (RFC 6238).
enum TotpAlgorithm {
  /// HMAC-SHA-1 (standard default across Google Authenticator and Authy).
  sha1('SHA1'),

  /// HMAC-SHA-256.
  sha256('SHA256'),

  /// HMAC-SHA-512.
  sha512('SHA512');

  final String standardName;

  const TotpAlgorithm(this.standardName);

  /// Resolves a [TotpAlgorithm] from its uppercase name (e.g. 'SHA1', 'SHA256').
  ///
  /// Defaults to [TotpAlgorithm.sha1] if [name] is null or blank.
  /// Throws [ValidationException] if an unsupported algorithm is specified.
  static TotpAlgorithm fromName(String? name) {
    if (name == null || name.trim().isEmpty) {
      return TotpAlgorithm.sha1;
    }
    final normalized = name.trim().toUpperCase().replaceAll('-', '');
    switch (normalized) {
      case 'SHA1':
        return TotpAlgorithm.sha1;
      case 'SHA256':
        return TotpAlgorithm.sha256;
      case 'SHA512':
        return TotpAlgorithm.sha512;
      default:
        throw ValidationException(
          'Unsupported TOTP algorithm: "$name". Must be SHA1, SHA256, or SHA512.',
        );
    }
  }

  /// Instantiates the corresponding `package:cryptography` [Hmac] instance.
  Hmac toHmac() {
    switch (this) {
      case TotpAlgorithm.sha1:
        return Hmac.sha1();
      case TotpAlgorithm.sha256:
        return Hmac.sha256();
      case TotpAlgorithm.sha512:
        return Hmac.sha512();
    }
  }
}
