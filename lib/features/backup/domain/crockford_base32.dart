import 'dart:typed_data';

import 'package:lockleaf/core/errors/app_exception.dart';

/// Crockford Base32 encoder and decoder with error detection and normalization.
///
/// Crockford's alphabet uses 32 characters: 0-9 and A-Z excluding I, L, O, and U
/// to prevent visual ambiguity and accidental obscenity. Normalization maps
/// 'O'/'o' to '0', and 'I'/'i'/'L'/'l' to '1'.
abstract class CrockfordBase32 {
  /// The 32 Crockford Base32 symbols.
  static const String alphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';

  static final Map<String, int> _decodeMap = {
    for (var i = 0; i < alphabet.length; i++) alphabet[i]: i,
    'O': 0,
    'o': 0,
    'I': 1,
    'i': 1,
    'L': 1,
    'l': 1,
  };

  /// Normalizes a human-entered string by removing spaces, dashes, and mapping
  /// visually ambiguous characters to their canonical digit equivalents.
  static String normalize(String input) {
    final buffer = StringBuffer();
    for (var i = 0; i < input.length; i++) {
      final char = input[i];
      if (char == '-' || char == ' ' || char == '\t' || char == '\n') {
        continue;
      }
      final upper = char.toUpperCase();
      if (upper == 'O') {
        buffer.write('0');
      } else if (upper == 'I' || upper == 'L') {
        buffer.write('1');
      } else if (_decodeMap.containsKey(upper)) {
        buffer.write(upper);
      } else {
        throw ValidationException('Invalid character in recovery key: $char');
      }
    }
    return buffer.toString();
  }

  /// Encodes [bytes] into Crockford Base32 without padding.
  static String encode(Uint8List bytes) {
    if (bytes.isEmpty) return '';

    final buffer = StringBuffer();
    var bitBuffer = 0;
    var bitCount = 0;

    for (final byte in bytes) {
      bitBuffer = (bitBuffer << 8) | (byte & 0xFF);
      bitCount += 8;

      while (bitCount >= 5) {
        bitCount -= 5;
        final index = (bitBuffer >> bitCount) & 0x1F;
        buffer.write(alphabet[index]);
      }
    }

    if (bitCount > 0) {
      final index = (bitBuffer << (5 - bitCount)) & 0x1F;
      buffer.write(alphabet[index]);
    }

    return buffer.toString();
  }

  /// Decodes a normalized Crockford Base32 string into raw bytes.
  static Uint8List decode(String input) {
    final normalized = normalize(input);
    if (normalized.isEmpty) return Uint8List(0);

    var bitBuffer = 0;
    var bitCount = 0;
    final outBytes = <int>[];

    for (var i = 0; i < normalized.length; i++) {
      final val = _decodeMap[normalized[i]];
      if (val == null) {
        throw ValidationException(
          'Invalid character in recovery key: ${normalized[i]}',
        );
      }
      bitBuffer = (bitBuffer << 5) | val;
      bitCount += 5;

      if (bitCount >= 8) {
        bitCount -= 8;
        outBytes.add((bitBuffer >> bitCount) & 0xFF);
      }
    }

    return Uint8List.fromList(outBytes);
  }

  /// Computes a standard 16-bit CRC-CCITT (polynomial 0x1021, init 0xFFFF).
  static int crc16Ccitt(List<int> bytes) {
    var crc = 0xFFFF;
    for (final byte in bytes) {
      crc ^= (byte & 0xFF) << 8;
      for (var i = 0; i < 8; i++) {
        if ((crc & 0x8000) != 0) {
          crc = ((crc << 1) ^ 0x1021) & 0xFFFF;
        } else {
          crc = (crc << 1) & 0xFFFF;
        }
      }
    }
    return crc & 0xFFFF;
  }
}
