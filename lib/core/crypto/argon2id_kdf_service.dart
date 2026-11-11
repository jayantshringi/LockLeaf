import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:lockleaf/core/crypto/kdf_params.dart';
import 'package:lockleaf/core/crypto/managed_secret_key.dart';
import 'package:lockleaf/core/crypto/secure_memory.dart';
import 'package:lockleaf/core/errors/app_exception.dart';

/// Derives cryptographic master keys from user passphrases using Argon2id.
class Argon2idKdfService {
  static const int _minimumSaltBytes = 16;

  /// Derives a [ManagedSecretKey] from a UTF-8 [masterPassword] and [salt].
  ///
  /// Temporary UTF-8 password bytes are wiped immediately after derivation.
  Future<ManagedSecretKey> deriveMasterKey({
    required String masterPassword,
    required List<int> salt,
    KdfParams params = const KdfParams.standard(),
  }) async {
    if (masterPassword.isEmpty) {
      throw const CryptoException('Master password cannot be empty.');
    }
    final passwordBytes = Uint8List.fromList(utf8.encode(masterPassword));
    try {
      return await deriveKeyFromBytes(
        secretBytes: passwordBytes,
        salt: salt,
        params: params,
      );
    } finally {
      SecureMemory.wipeBytes(passwordBytes);
    }
  }

  /// Derives a [ManagedSecretKey] from raw [secretBytes] and [salt].
  Future<ManagedSecretKey> deriveKeyFromBytes({
    required List<int> secretBytes,
    required List<int> salt,
    KdfParams params = const KdfParams.standard(),
  }) async {
    if (secretBytes.isEmpty) {
      throw const CryptoException('Input secret bytes cannot be empty.');
    }
    if (salt.length < _minimumSaltBytes) {
      throw const CryptoException('KDF salt must be at least 16 bytes.');
    }

    final inputBuffer = Uint8List.fromList(secretBytes);
    final inputKey = SecretKeyData(
      inputBuffer,
      overwriteWhenDestroyed: true,
    );

    try {
      final algorithm = Argon2id(
        parallelism: params.parallelism,
        memory: params.memoryKiB,
        iterations: params.iterations,
        hashLength: params.hashLength,
      );

      final derivedKey = await algorithm.deriveKey(
        secretKey: inputKey,
        nonce: salt,
      );

      final extracted = Uint8List.fromList(await derivedKey.extractBytes());
      try {
        if (derivedKey is SecretKeyData) {
          derivedKey.destroy();
        }
        return ManagedSecretKey.fromBytes(extracted);
      } finally {
        SecureMemory.wipeBytes(extracted);
      }
    } on CryptoException {
      rethrow;
    } catch (error) {
      throw CryptoException(
        'Argon2id key derivation failed.',
        error.runtimeType.toString(),
      );
    } finally {
      SecureMemory.wipeBytes(inputBuffer);
      inputKey.destroy();
    }
  }
}
