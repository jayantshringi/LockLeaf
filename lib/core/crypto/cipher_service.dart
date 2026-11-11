import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:lockleaf/core/constants/security_constants.dart';
import 'package:lockleaf/core/crypto/cipher_algorithm.dart';
import 'package:lockleaf/core/crypto/encrypted_payload.dart';
import 'package:lockleaf/core/crypto/managed_secret_key.dart';
import 'package:lockleaf/core/crypto/secure_memory.dart';
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

  /// Decrypts and authenticates an [EncryptedPayload] using [key].
  ///
  /// Throws a [CryptoException] if the MAC tag fails verification, the wrong
  /// key is provided, or [associatedData] does not match encryption time.
  Future<Uint8List> decryptBytes({
    required EncryptedPayload payload,
    required ManagedSecretKey key,
    List<int>? associatedData,
  }) async {
    _validateKey(key);

    final cipher = payload.algorithm.createCipher();
    try {
      final clearBytes = await cipher.decrypt(
        payload.toSecretBox(),
        secretKey: key.secretKey,
        aad: associatedData ?? const <int>[],
      );
      return Uint8List.fromList(clearBytes);
    } on SecretBoxAuthenticationError {
      throw const CryptoException(
        'Authentication failed: ciphertext, key, or AAD is invalid.',
      );
    } catch (error) {
      throw CryptoException(
        'AEAD decryption failed.',
        error.runtimeType.toString(),
      );
    }
  }

  /// Encrypts a UTF-8 [plaintext] string, scrubbing temporary byte buffers.
  Future<EncryptedPayload> encryptString({
    required String plaintext,
    required ManagedSecretKey key,
    VaultCipherAlgorithm algorithm = VaultCipherAlgorithm.xchacha20Poly1305,
    String? associatedData,
  }) async {
    final plainBytes = Uint8List.fromList(utf8.encode(plaintext));
    final aadBytes =
        associatedData == null ? null : utf8.encode(associatedData);
    try {
      return await encryptBytes(
        plaintext: plainBytes,
        key: key,
        algorithm: algorithm,
        associatedData: aadBytes,
      );
    } finally {
      SecureMemory.wipeBytes(plainBytes);
    }
  }

  /// Decrypts an [EncryptedPayload] back into a UTF-8 string.
  Future<String> decryptString({
    required EncryptedPayload payload,
    required ManagedSecretKey key,
    String? associatedData,
  }) async {
    final aadBytes =
        associatedData == null ? null : utf8.encode(associatedData);
    final clearBytes = await decryptBytes(
      payload: payload,
      key: key,
      associatedData: aadBytes,
    );
    try {
      return utf8.decode(clearBytes);
    } on FormatException {
      throw const CryptoException('Decrypted payload is not valid UTF-8.');
    } finally {
      SecureMemory.wipeBytes(clearBytes);
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
