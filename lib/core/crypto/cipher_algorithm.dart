import 'package:cryptography/cryptography.dart';
import 'package:lockleaf/core/constants/security_constants.dart';
import 'package:lockleaf/core/errors/app_exception.dart';

/// Supported AEAD ciphers for encrypting LockLeaf vault data.
enum VaultCipherAlgorithm {
  /// XChaCha20-Poly1305 with extended 192-bit (24-byte) random nonce.
  xchacha20Poly1305(
    wireId: 1,
    id: 'xchacha20-poly1305',
    nonceLength: SecurityConstants.xchacha20NonceBytes,
    macLength: SecurityConstants.macTagLengthBytes,
  ),

  /// AES-256-GCM with 96-bit (12-byte) random nonce.
  aes256Gcm(
    wireId: 2,
    id: 'aes-256-gcm',
    nonceLength: SecurityConstants.aesGcmNonceBytes,
    macLength: SecurityConstants.macTagLengthBytes,
  );

  /// Compact 1-byte numeric identifier embedded in binary envelopes.
  final int wireId;

  /// Human-readable identifier used in JSON metadata and backups.
  final String id;

  /// Expected random nonce length in bytes.
  final int nonceLength;

  /// Expected authentication tag (MAC) length in bytes.
  final int macLength;

  const VaultCipherAlgorithm({
    required this.wireId,
    required this.id,
    required this.nonceLength,
    required this.macLength,
  });

  /// Instantiates the corresponding vetted `package:cryptography` [Cipher].
  Cipher createCipher() {
    switch (this) {
      case VaultCipherAlgorithm.xchacha20Poly1305:
        return Xchacha20.poly1305Aead();
      case VaultCipherAlgorithm.aes256Gcm:
        return AesGcm.with256bits();
    }
  }

  /// Resolves an algorithm from its binary [wireId].
  static VaultCipherAlgorithm fromWireId(int wireId) {
    for (final algorithm in VaultCipherAlgorithm.values) {
      if (algorithm.wireId == wireId) {
        return algorithm;
      }
    }
    throw const CryptoException('Unsupported cipher wire identifier.');
  }

  /// Resolves an algorithm from its string [id].
  static VaultCipherAlgorithm fromId(String id) {
    for (final algorithm in VaultCipherAlgorithm.values) {
      if (algorithm.id == id) {
        return algorithm;
      }
    }
    throw const CryptoException('Unsupported cipher algorithm identifier.');
  }
}
