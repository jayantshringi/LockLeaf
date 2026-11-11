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
}
