import 'dart:typed_data';

import 'package:lockleaf/core/errors/app_exception.dart';

/// RFC 4648 compliant Base32 encoder and decoder for standard authenticator secrets.
abstract class Base32 {
  static const String _alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
  static final Map<String, int> _decodeMap = {
    for (var i = 0; i < _alphabet.length; i++) _alphabet[i]: i,
  };

  /// Decodes an RFC 4648 [input] Base32 string into raw bytes.
  ///
  /// Strips hyphens, spaces, and padding `=` characters. Case-insensitive.
  /// Throws [ValidationException] if [input] contains invalid characters.
  static Uint8List decode(String input) {
    final cleaned = input.toUpperCase().replaceAll(RegExp(r'[\s\-=]'), '');
    if (cleaned.isEmpty) {
      return Uint8List(0);
    }

    var buffer = 0;
    var bitsLeft = 0;
    final result = <int>[];

    for (var i = 0; i < cleaned.length; i++) {
      final char = cleaned[i];
      final val = _decodeMap[char];
      if (val == null) {
        throw ValidationException('Invalid Base32 character: "$char"');
      }

      buffer = (buffer << 5) | val;
      bitsLeft += 5;

      if (bitsLeft >= 8) {
        bitsLeft -= 8;
        result.add((buffer >> bitsLeft) & 0xff);
      }
    }

    return Uint8List.fromList(result);
  }

  /// Encodes [bytes] into an RFC 4648 Base32 string.
  static String encode(List<int> bytes, {bool pad = false}) {
    if (bytes.isEmpty) {
      return '';
    }

    var buffer = 0;
    var bitsLeft = 0;
    final out = StringBuffer();

    for (final b in bytes) {
      buffer = (buffer << 8) | (b & 0xff);
      bitsLeft += 8;

      while (bitsLeft >= 5) {
        bitsLeft -= 5;
        out.write(_alphabet[(buffer >> bitsLeft) & 0x1f]);
      }
    }

    if (bitsLeft > 0) {
      buffer = (buffer << (5 - bitsLeft)) & 0x1f;
      out.write(_alphabet[buffer]);
    }

    if (pad) {
      while (out.length % 8 != 0) {
        out.write('=');
      }
    }

    return out.toString();
  }
}
