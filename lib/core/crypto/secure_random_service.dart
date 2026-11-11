import 'dart:math';
import 'dart:typed_data';

import 'package:lockleaf/core/constants/security_constants.dart';
import 'package:lockleaf/core/errors/app_exception.dart';

/// Cryptographically secure random number generator backed by OS entropy.
class SecureRandomService {
  final Random _random;

  /// Creates a random service strictly backed by `Random.secure()`.
  SecureRandomService() : _random = Random.secure();

  /// Generates [length] cryptographically secure random bytes.
  ///
  /// Throws a [CryptoException] if [length] is not positive.
  Uint8List generateBytes(int length) {
    if (length <= 0) {
      throw const CryptoException('Random byte length must be positive.');
    }
    final bytes = Uint8List(length);
    for (var i = 0; i < length; i++) {
      bytes[i] = _random.nextInt(256);
    }
    return bytes;
  }

  /// Generates a unique cryptographic salt for key derivation.
  ///
  /// Defaults to [SecurityConstants.saltLengthBytes] (32 bytes / 256 bits)
  /// and enforces a minimum of 16 bytes.
  Uint8List generateSalt({int length = SecurityConstants.saltLengthBytes}) {
    if (length < 16) {
      throw const CryptoException('Salt length must be at least 16 bytes.');
    }
    return generateBytes(length);
  }

  /// Generates a fresh cryptographic nonce of [length] bytes.
  ///
  /// Enforces at least 12 bytes (96 bits) to prevent nonce-reuse hazards.
  Uint8List generateNonce(int length) {
    if (length < SecurityConstants.aesGcmNonceBytes) {
      throw const CryptoException('Nonce length must be at least 12 bytes.');
    }
    return generateBytes(length);
  }

  /// Returns a cryptographically random integer in the range `[0, max)`.
  int nextInt(int max) {
    if (max <= 0) {
      throw const CryptoException('Upper bound must be positive.');
    }
    return _random.nextInt(max);
  }
}
