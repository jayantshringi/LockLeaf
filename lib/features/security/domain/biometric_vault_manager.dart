import 'dart:convert';
import 'dart:typed_data';

import 'package:lockleaf/core/constants/security_constants.dart';
import 'package:lockleaf/core/crypto/cipher_algorithm.dart';
import 'package:lockleaf/core/crypto/cipher_service.dart';
import 'package:lockleaf/core/crypto/encrypted_payload.dart';
import 'package:lockleaf/core/crypto/managed_secret_key.dart';
import 'package:lockleaf/core/crypto/secure_memory.dart';
import 'package:lockleaf/core/crypto/secure_random_service.dart';
import 'package:lockleaf/core/errors/app_exception.dart';
import 'package:lockleaf/features/security/data/biometric_auth_service.dart';
import 'package:lockleaf/features/security/data/secure_key_storage.dart';
import 'package:lockleaf/features/vault/domain/vault_service.dart';

/// Manages hardware-backed biometric unlock without ever storing the master password.
///
/// Enrolling biometrics seals the vault DEK under a fresh 256-bit wrapping key
/// stored in Android Keystore / iOS Keychain.
class BiometricVaultManager {
  static const String _kekStorageKey = 'lockleaf_bio_kek_v1';
  static const String _wrappedDekStorageKey = 'lockleaf_bio_wrapped_dek_v1';
  static const String _vaultIdStorageKey = 'lockleaf_bio_vault_id_v1';

  final VaultService _vaultService;
  final SecureKeyStorage _secureStorage;
  final BiometricAuthService _biometricAuth;
  final CipherService _cipherService;
  final SecureRandomService _randomService;

  /// Creates a [BiometricVaultManager].
  BiometricVaultManager({
    required VaultService vaultService,
    required SecureKeyStorage secureStorage,
    required BiometricAuthService biometricAuth,
    CipherService? cipherService,
    SecureRandomService? randomService,
  }) : _vaultService = vaultService,
       _secureStorage = secureStorage,
       _biometricAuth = biometricAuth,
       _randomService = randomService ?? SecureRandomService(),
       _cipherService =
           cipherService ??
           CipherService(randomService: randomService ?? SecureRandomService());

  /// Returns true if biometric hardware and enrolled credentials exist.
  Future<bool> isBiometricsSupported() =>
      _biometricAuth.isBiometricsAvailable();

  /// Returns true if biometric unlock is configured for the active vault.
  Future<bool> isBiometricUnlockEnabled() async {
    final currentVaultId = await _vaultService.getInitializedVaultId();
    if (currentVaultId == null) {
      return false;
    }
    final storedVaultId = await _secureStorage.read(_vaultIdStorageKey);
    final storedKek = await _secureStorage.read(_kekStorageKey);
    final storedWrappedDek = await _secureStorage.read(_wrappedDekStorageKey);

    return storedVaultId == currentVaultId &&
        storedKek != null &&
        storedWrappedDek != null;
  }

  /// Prompts biometrics and seals the active vault DEK in secure hardware storage.
  Future<void> enableBiometricUnlock() async {
    final verified = await _biometricAuth.authenticate(
      reason: 'Confirm biometrics to enable quick LockLeaf unlock',
    );
    if (!verified) {
      throw const AuthenticationException(
        'Biometric verification was canceled or failed.',
      );
    }

    await _vaultService.withSessionDek<void>((
      String vaultId,
      VaultCipherAlgorithm algorithm,
      Uint8List dekBytes,
    ) async {
      final kekBytes = _randomService.generateBytes(
        SecurityConstants.derivedKeyLengthBytes,
      );
      final bioKek = ManagedSecretKey.fromBytes(kekBytes);

      try {
        final wrapped = await _cipherService.encryptBytes(
          plaintext: dekBytes,
          key: bioKek,
          algorithm: algorithm,
          associatedData: utf8.encode(_bioAad(vaultId)),
        );

        await _secureStorage.write(
          key: _kekStorageKey,
          value: base64Url.encode(kekBytes),
        );
        await _secureStorage.write(
          key: _wrappedDekStorageKey,
          value: wrapped.toBase64(),
        );
        await _secureStorage.write(key: _vaultIdStorageKey, value: vaultId);
      } finally {
        SecureMemory.wipeBytes(kekBytes);
        bioKek.destroy();
      }
    });
  }

  /// Removes all biometric-wrapped key material from Keystore / Keychain.
  Future<void> disableBiometricUnlock() async {
    await _secureStorage.delete(_kekStorageKey);
    await _secureStorage.delete(_wrappedDekStorageKey);
    await _secureStorage.delete(_vaultIdStorageKey);
  }

  /// Authenticates via biometrics and unlocks the vault using the sealed DEK.
  Future<bool> unlockWithBiometrics() async {
    final enabled = await isBiometricUnlockEnabled();
    if (!enabled) {
      throw const AuthenticationException(
        'Biometric unlock is not enabled for this vault.',
      );
    }

    final authenticated = await _biometricAuth.authenticate(
      reason: 'Unlock your LockLeaf vault',
    );
    if (!authenticated) {
      return false;
    }

    final kekEncoded = await _secureStorage.read(_kekStorageKey);
    final wrappedEncoded = await _secureStorage.read(_wrappedDekStorageKey);
    final vaultId = await _secureStorage.read(_vaultIdStorageKey);

    if (kekEncoded == null || wrappedEncoded == null || vaultId == null) {
      throw const StorageException('Biometric key material is missing.');
    }

    final Uint8List kekBytes;
    try {
      kekBytes = Uint8List.fromList(base64Url.decode(kekEncoded));
    } on FormatException {
      throw const StorageException('Stored biometric key is malformed.');
    }

    final bioKek = ManagedSecretKey.fromBytes(kekBytes);
    Uint8List? dekBytes;
    try {
      final wrappedPayload = EncryptedPayload.fromBase64(wrappedEncoded);
      dekBytes = await _cipherService.decryptBytes(
        payload: wrappedPayload,
        key: bioKek,
        associatedData: utf8.encode(_bioAad(vaultId)),
      );
      await _vaultService.unlockWithDekBytes(
        expectedVaultId: vaultId,
        dekBytes: dekBytes,
      );
      return true;
    } finally {
      SecureMemory.wipeBytes(kekBytes);
      if (dekBytes != null) {
        SecureMemory.wipeBytes(dekBytes);
      }
      bioKek.destroy();
    }
  }

  String _bioAad(String vaultId) => 'lockleaf:bio-dek:v1:$vaultId';
}
