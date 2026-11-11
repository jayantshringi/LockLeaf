import 'dart:math';
import 'dart:typed_data';

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
}
