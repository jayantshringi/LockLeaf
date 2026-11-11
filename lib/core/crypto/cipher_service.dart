import 'package:lockleaf/core/constants/security_constants.dart';
import 'package:lockleaf/core/crypto/cipher_algorithm.dart';
import 'package:lockleaf/core/crypto/encrypted_payload.dart';
import 'package:lockleaf/core/crypto/managed_secret_key.dart';
import 'package:lockleaf/core/crypto/secure_random_service.dart';
import 'package:lockleaf/core/errors/app_exception.dart';

/// Authenticated encryption service backed by vetted AEAD ciphers.
///
/// Generates a fresh cryptographic random nonce for every encryption operation.
class CipherService {
  final SecureRandomService _randomService;

  /// Creates a [CipherService] using [SecureRandomService] for unique nonces.
  CipherService({SecureRandomService? randomService})
      : _randomService = randomService ?? SecureRandomService();

  /// Encrypts [plaintext] bytes using [key] and [algorithm].
  ///
  /// Always generates a unique random nonce. Optional [associatedData] (AAD)
  /// is authenticated without being encrypted to bind ciphertext to context.
  Future<EncryptedPayload> encryptBytes({
    required List<int> plaintext,
    required ManagedSecretKey key,
    VaultCipherAlgorithm algorithm = VaultCipherAlgorithm.xchacha20Poly1305,
    List<int>? associatedData,
  }) async {
    _validateKey(key);

    final nonce = _randomService.generateNonce(algorithm.nonceLength);
    final cipher = algorithm.createCipher();

    try {
      final secretBox = await cipher.encrypt(
        plaintext,
        secretKey: key.secretKey,
        nonce: nonce,
        aad: associatedData ?? const <int>[],
      );
      return EncryptedPayload.fromSecretBox(
        algorithm: algorithm,
        secretBox: secretBox,
      );
    } catch (error) {
      throw CryptoException(
        'AEAD encryption failed.',
        error.runtimeType.toString(),
      );
    }
  }

  void _validateKey(ManagedSecretKey key) {
    if (key.isDestroyed) {
      throw const CryptoException('Cannot perform crypto with destroyed key.');
    }
    if (key.length != SecurityConstants.derivedKeyLengthBytes) {
      throw const CryptoException(
        'Encryption requires a 256-bit (32-byte) secret key.',
      );
    }
  }
}
