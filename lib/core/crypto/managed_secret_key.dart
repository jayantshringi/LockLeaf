import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:lockleaf/core/crypto/secure_memory.dart';
import 'package:lockleaf/core/errors/app_exception.dart';

/// Lifecycle-managed in-memory cryptographic key supporting explicit zeroization.
class ManagedSecretKey {
  final Uint8List _backingBuffer;
  final SecretKeyData _keyData;
  final int length;
  bool _destroyed = false;

  ManagedSecretKey._(this._backingBuffer, this._keyData)
      : length = _backingBuffer.length;

  /// Creates a [ManagedSecretKey] from raw [bytes], taking an isolated copy.
  ///
  /// Throws a [CryptoException] if [bytes] is empty.
  factory ManagedSecretKey.fromBytes(List<int> bytes) {
    if (bytes.isEmpty) {
      throw const CryptoException('Secret key bytes cannot be empty.');
    }
    final buffer = Uint8List.fromList(bytes);
    final keyData = SecretKeyData(
      buffer,
      overwriteWhenDestroyed: true,
    );
    return ManagedSecretKey._(buffer, keyData);
  }

  /// Whether this key has been wiped from memory.
  bool get isDestroyed => _destroyed;

  /// Returns the underlying [SecretKey] for use with `package:cryptography`.
  ///
  /// Throws a [CryptoException] if the key has already been destroyed.
  SecretKey get secretKey {
    _ensureActive();
    return _keyData;
  }

  /// Returns a fresh mutable copy of the key bytes.
  ///
  /// Callers must call [SecureMemory.wipeBytes] on the returned buffer as soon
  /// as it is no longer needed.
  Uint8List copyBytes() {
    _ensureActive();
    return Uint8List.fromList(_backingBuffer);
  }

  /// Overwrites key material in memory with zeros and invalidates future use.
  void destroy() {
    if (_destroyed) {
      return;
    }
    _destroyed = true;
    SecureMemory.wipeBytes(_backingBuffer);
    _keyData.destroy();
  }

  void _ensureActive() {
    if (_destroyed) {
      throw const CryptoException('Cannot use secret key after destruction.');
    }
  }
}

