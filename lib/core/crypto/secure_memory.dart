/// Utilities for scrubbing sensitive buffers and avoiding timing leaks.
abstract class SecureMemory {
  /// Overwrites every byte of [buffer] with zeros in place.
  ///
  /// Callers should pass mutable buffers such as `Uint8List` or growable
  /// `List<int>` instances holding plaintext passwords or raw key material.
  static void wipeBytes(List<int> buffer) {
    if (buffer.isEmpty) {
      return;
    }
    buffer.fillRange(0, buffer.length, 0);
  }

  /// Compares two equal-length byte lists in constant time to avoid timing leaks.
  static bool constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) {
      return false;
    }
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= (a[i] ^ b[i]) & 0xff;
    }
    return diff == 0;
  }
}
