import 'dart:convert';
import 'dart:typed_data';

import 'package:lockleaf/core/crypto/argon2id_kdf_service.dart';
import 'package:lockleaf/core/crypto/cipher_algorithm.dart';
import 'package:lockleaf/core/crypto/cipher_service.dart';
import 'package:lockleaf/core/crypto/encrypted_payload.dart';
import 'package:lockleaf/core/crypto/kdf_params.dart';
import 'package:lockleaf/core/crypto/managed_secret_key.dart';
import 'package:lockleaf/core/crypto/secure_memory.dart';
import 'package:lockleaf/core/crypto/secure_random_service.dart';
import 'package:lockleaf/core/errors/app_exception.dart';
import 'package:lockleaf/features/backup/domain/recovery_key.dart';
import 'package:lockleaf/features/vault/domain/vault_metadata.dart';

/// Bundle containing recovery salt and the AEAD-wrapped DEK.
class RecoveryWrapResult {
  final Uint8List _recoverySalt;
  final EncryptedPayload wrappedDek;

  RecoveryWrapResult({
    required List<int> recoverySalt,
    required this.wrappedDek,
  }) : _recoverySalt = Uint8List.fromList(recoverySalt);

  /// Defensive copy of the 32-byte recovery salt.
  Uint8List get recoverySalt => Uint8List.fromList(_recoverySalt);
}

/// Orchestrates cryptographic key derivation and DEK wrapping/unwrapping for recovery keys.
class RecoveryKeyService {
  /// HKDF domain-separation context for recovery key DEK wrapping.
  static const String rekWrapHkdfContext = 'lockleaf-rek-wrap-v1';

  final Argon2idKdfService _kdfService;
  final CipherService _cipherService;
  final SecureRandomService _randomService;

  RecoveryKeyService({
    Argon2idKdfService? kdfService,
    CipherService? cipherService,
    SecureRandomService? randomService,
  })  : _kdfService = kdfService ?? Argon2idKdfService(),
        _randomService = randomService ?? SecureRandomService(),
        _cipherService = cipherService ??
            CipherService(randomService: randomService ?? SecureRandomService());

  /// Derives the 256-bit recovery wrapping subkey from a [RecoveryKey] and [recoverySalt].
  Future<ManagedSecretKey> deriveWrappingKey({
    required RecoveryKey recoveryKey,
    required List<int> recoverySalt,
    required KdfParams params,
  }) async {
    final entropy = recoveryKey.entropyBytes;
    final pseudoPassword = base64Url.encode(entropy);
    try {
      final masterKey = await _kdfService.deriveMasterKey(
        masterPassword: pseudoPassword,
        salt: recoverySalt,
        params: params,
      );
      try {
        return await _kdfService.deriveSubkey(
          masterKey: masterKey,
          context: rekWrapHkdfContext,
        );
      } finally {
        masterKey.destroy();
      }
    } finally {
      SecureMemory.wipeBytes(entropy);
    }
  }

  /// Wraps [dekBytes] under a fresh [recoveryKey] with a newly generated salt.
  Future<RecoveryWrapResult> wrapDek({
    required RecoveryKey recoveryKey,
    required Uint8List dekBytes,
    required String vaultId,
    required VaultCipherAlgorithm cipherAlgorithm,
    required KdfParams params,
  }) async {
    final recoverySalt = _randomService.generateSalt();
    ManagedSecretKey? wrappingKey;
    try {
      wrappingKey = await deriveWrappingKey(
        recoveryKey: recoveryKey,
        recoverySalt: recoverySalt,
        params: params,
      );

      final wrappedDek = await _cipherService.encryptBytes(
        plaintext: dekBytes,
        key: wrappingKey,
        algorithm: cipherAlgorithm,
        associatedData: utf8.encode(VaultMetadata.recoveryDekWrapAad(vaultId)),
      );

      return RecoveryWrapResult(
        recoverySalt: recoverySalt,
        wrappedDek: wrappedDek,
      );
    } finally {
      wrappingKey?.destroy();
    }
  }

  /// Unwraps the vault DEK from [metadata] using [recoveryKey].
  ///
  /// Throws [AuthenticationException] if the recovery key is incorrect or
  /// [ValidationException] if the vault metadata does not have a recovery key configured.
  /// The caller MUST wipe the returned DEK bytes when finished.
  Future<Uint8List> unwrapDek({
    required RecoveryKey recoveryKey,
    required VaultMetadata metadata,
  }) async {
    final recoverySalt = metadata.recoverySalt;
    final recoveryWrappedDek = metadata.recoveryWrappedDek;

    if (recoverySalt == null || recoveryWrappedDek == null) {
      throw const ValidationException(
        'This vault has not configured a recovery key.',
      );
    }

    ManagedSecretKey? wrappingKey;
    try {
      wrappingKey = await deriveWrappingKey(
        recoveryKey: recoveryKey,
        recoverySalt: recoverySalt,
        params: metadata.kdfParams,
      );

      try {
        return await _cipherService.decryptBytes(
          payload: recoveryWrappedDek,
          key: wrappingKey,
          associatedData: utf8.encode(
            VaultMetadata.recoveryDekWrapAad(metadata.vaultId),
          ),
        );
      } on CryptoException {
        throw const AuthenticationException(
          'Invalid recovery key. Unable to decrypt vault key.',
        );
      }
    } finally {
      wrappingKey?.destroy();
    }
  }
}
