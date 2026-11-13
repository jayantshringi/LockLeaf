import 'dart:typed_data';

import 'package:lockleaf/core/crypto/secure_memory.dart';
import 'package:lockleaf/core/crypto/secure_random_service.dart';
import 'package:lockleaf/core/errors/app_exception.dart';
import 'package:lockleaf/features/backup/domain/crockford_base32.dart';

/// Immutable representation of a 144-bit cryptographic vault recovery key with
/// a built-in CRC-16 error-detection checksum.
///
/// Encoded using Crockford's Base32 alphabet and formatted as:
/// `LL-XXXX-XXXX-XXXX-XXXX-XXXX-XXXX-XXXX-XXXX`
class RecoveryKey {
  /// Expected number of pure entropy bytes (144 bits).
  static const int entropyByteLength = 18;

  /// Checksum length in bytes (16-bit CRC-CCITT).
  static const int checksumByteLength = 2;

  /// Total binary payload size (20 bytes = 160 bits = 32 Crockford Base32 characters).
  static const int totalByteLength = entropyByteLength + checksumByteLength;

  /// Number of Crockford Base32 characters in the unformatted recovery key.
  static const int encodedCharLength = 32;

  /// Canonical human-readable prefix.
  static const String keyPrefix = 'LL';

  final Uint8List _entropy;
  final int _checksum;
  final String _formatted;
  bool _destroyed = false;

  RecoveryKey._({
    required Uint8List entropy,
    required int checksum,
    required String formatted,
  })  : _entropy = entropy,
        _checksum = checksum,
        _formatted = formatted;

  /// Generates a new cryptographically secure [RecoveryKey] using [randomService].
  factory RecoveryKey.generate({SecureRandomService? randomService}) {
    final rng = randomService ?? SecureRandomService();
    final entropy = rng.generateBytes(entropyByteLength);

    final checksum = CrockfordBase32.crc16Ccitt(entropy);
    final combined = Uint8List(totalByteLength);
    combined.setRange(0, entropyByteLength, entropy);
    combined[entropyByteLength] = (checksum >> 8) & 0xFF;
    combined[entropyByteLength + 1] = checksum & 0xFF;

    final encoded = CrockfordBase32.encode(combined);
    final formatted = _formatEncodedString(encoded);

    return RecoveryKey._(
      entropy: entropy,
      checksum: checksum,
      formatted: formatted,
    );
  }

  /// Parses and validates a user-provided recovery key string.
  ///
  /// Automatically strips whitespace, hyphens, and optional `LL-` prefix,
  /// normalizes ambiguous characters (`I/L/1` and `O/0`), and checks the
  /// CRC-16 checksum to reject transcription typos immediately.
  factory RecoveryKey.fromString(String input) {
    var raw = input.trim();
    if (raw.toUpperCase().startsWith('$keyPrefix-')) {
      raw = raw.substring(keyPrefix.length + 1);
    } else if (raw.toUpperCase().startsWith(keyPrefix)) {
      raw = raw.substring(keyPrefix.length);
    }

    final normalized = CrockfordBase32.normalize(raw);
    if (normalized.length != encodedCharLength) {
      throw ValidationException(
        'Invalid recovery key length. Expected $encodedCharLength characters, '
        'got ${normalized.length}.',
      );
    }

    final bytes = CrockfordBase32.decode(normalized);
    if (bytes.length < totalByteLength) {
      throw const ValidationException('Corrupted recovery key binary representation.');
    }

    final entropy = Uint8List.fromList(bytes.sublist(0, entropyByteLength));
    final expectedChecksum = (bytes[entropyByteLength] << 8) | bytes[entropyByteLength + 1];
    final actualChecksum = CrockfordBase32.crc16Ccitt(entropy);

    if (actualChecksum != expectedChecksum) {
      SecureMemory.wipeBytes(entropy);
      throw const ValidationException(
        'Invalid recovery key checksum. Please verify for mistyped characters.',
      );
    }

    final formatted = _formatEncodedString(normalized);

    return RecoveryKey._(
      entropy: entropy,
      checksum: actualChecksum,
      formatted: formatted,
    );
  }

  /// Returns the canonical human-friendly formatted string.
  ///
  /// Example: `LL-A1B2-C3D4-E5F6-G7H8-J9K0-MNPQ-RSTV-WXYZ`
  String get formatted {
    _checkDestroyed();
    return _formatted;
  }

  /// Returns a defensive copy of the raw 144-bit entropy bytes.
  Uint8List get entropyBytes {
    _checkDestroyed();
    return Uint8List.fromList(_entropy);
  }

  /// Returns the 16-bit CRC checksum.
  int get checksum {
    _checkDestroyed();
    return _checksum;
  }

  /// Whether this key has been zeroized in memory.
  bool get isDestroyed => _destroyed;

  /// Destroys and zeroizes the sensitive entropy bytes in memory.
  void destroy() {
    if (!_destroyed) {
      SecureMemory.wipeBytes(_entropy);
      _destroyed = true;
    }
  }

  void _checkDestroyed() {
    if (_destroyed) {
      throw const StateError('RecoveryKey has been destroyed and wiped from memory.');
    }
  }

  /// Constant-time comparison to prevent timing attacks.
  bool constantTimeEquals(RecoveryKey other) {
    if (_destroyed || other._destroyed) return false;
    return SecureMemory.constantTimeEquals(_entropy, other._entropy);
  }

  static String _formatEncodedString(String encoded32Chars) {
    final buffer = StringBuffer('$keyPrefix-');
    for (var i = 0; i < encoded32Chars.length; i += 4) {
      if (i > 0) buffer.write('-');
      buffer.write(encoded32Chars.substring(i, i + 4));
    }
    return buffer.toString();
  }

  @override
  String toString() => 'RecoveryKey($keyPrefix-****-****-****-****-****-****-****-****)';
}
