import 'dart:convert';
import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:lockleaf/core/crypto/cipher_algorithm.dart';
import 'package:lockleaf/core/crypto/encrypted_payload.dart';
import 'package:lockleaf/core/crypto/kdf_params.dart';
import 'package:lockleaf/core/errors/app_exception.dart';

/// Public cryptographic metadata needed to derive keys and unlock a vault.
///
/// Contains zero secrets: only the public random salt, KDF parameters,
/// cipher identifier, and the AEAD-wrapped Data Encryption Key (DEK).
class VaultMetadata extends Equatable {
  /// Current vault metadata schema version.
  static const int currentSchemaVersion = 1;

  /// Stable UUID v4 identifying this vault instance (used in AAD binding).
  final String vaultId;

  /// Metadata format version.
  final int schemaVersion;

  final Uint8List _salt;

  /// Argon2id parameters required to re-derive the master key on unlock.
  final KdfParams kdfParams;

  /// Primary AEAD cipher used to encrypt vault entries.
  final VaultCipherAlgorithm cipherAlgorithm;

  /// Random 256-bit vault DEK encrypted under the master key-wrapping subkey.
  final EncryptedPayload wrappedDek;

  /// UTC timestamp when the vault was initialized.
  final DateTime createdAt;

  /// UTC timestamp when metadata or key wrapping was last rotated.
  final DateTime updatedAt;

  VaultMetadata._({
    required this.vaultId,
    required this.schemaVersion,
    required Uint8List salt,
    required this.kdfParams,
    required this.cipherAlgorithm,
    required this.wrappedDek,
    required DateTime createdAt,
    required DateTime updatedAt,
  })  : _salt = salt,
        createdAt = createdAt.toUtc(),
        updatedAt = updatedAt.toUtc();

  /// Creates and validates [VaultMetadata].
  factory VaultMetadata({
    required String vaultId,
    int schemaVersion = currentSchemaVersion,
    required List<int> salt,
    required KdfParams kdfParams,
    required VaultCipherAlgorithm cipherAlgorithm,
    required EncryptedPayload wrappedDek,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) {
    if (vaultId.trim().isEmpty) {
      throw const ValidationException('Vault ID cannot be empty.');
    }
    if (schemaVersion < 1) {
      throw const ValidationException('Schema version must be at least 1.');
    }
    if (salt.length < 16) {
      throw const ValidationException('Vault salt must be at least 16 bytes.');
    }
    return VaultMetadata._(
      vaultId: vaultId.trim(),
      schemaVersion: schemaVersion,
      salt: Uint8List.fromList(salt),
      kdfParams: kdfParams,
      cipherAlgorithm: cipherAlgorithm,
      wrappedDek: wrappedDek,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  /// Defensive copy of the KDF salt bytes.
  Uint8List get salt => Uint8List.fromList(_salt);

  /// Creates an updated copy (e.g., when rotating master password or KDF cost).
  VaultMetadata copyWith({
    List<int>? salt,
    KdfParams? kdfParams,
    VaultCipherAlgorithm? cipherAlgorithm,
    EncryptedPayload? wrappedDek,
    DateTime? updatedAt,
  }) {
    return VaultMetadata(
      vaultId: vaultId,
      schemaVersion: schemaVersion,
      salt: salt ?? _salt,
      kdfParams: kdfParams ?? this.kdfParams,
      cipherAlgorithm: cipherAlgorithm ?? this.cipherAlgorithm,
      wrappedDek: wrappedDek ?? this.wrappedDek,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Serializes metadata into a SQLite-compatible column map.
  Map<String, Object?> toMap() {
    return <String, Object?>{
      'vault_id': vaultId,
      'schema_version': schemaVersion,
      'salt': salt,
      'kdf_params_json': jsonEncode(kdfParams.toJson()),
      'cipher_algorithm': cipherAlgorithm.id,
      'wrapped_dek': wrappedDek.toBytes(),
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  /// Restores [VaultMetadata] from a SQLite row map.
  factory VaultMetadata.fromMap(Map<String, Object?> map) {
    final vaultId = map['vault_id'];
    final schemaVersion = map['schema_version'];
    final saltRaw = map['salt'];
    final kdfParamsJson = map['kdf_params_json'];
    final cipherId = map['cipher_algorithm'];
    final wrappedDekRaw = map['wrapped_dek'];
    final createdAtMillis = map['created_at'];
    final updatedAtMillis = map['updated_at'];

    if (vaultId is! String ||
        schemaVersion is! int ||
        saltRaw is! List<int> ||
        kdfParamsJson is! String ||
        cipherId is! String ||
        wrappedDekRaw is! List<int> ||
        createdAtMillis is! int ||
        updatedAtMillis is! int) {
      throw const StorageException('Corrupt vault metadata row in database.');
    }

    try {
      final decodedKdf = jsonDecode(kdfParamsJson);
      if (decodedKdf is! Map<String, dynamic>) {
        throw const StorageException('Invalid KDF JSON in vault metadata.');
      }
      return VaultMetadata(
        vaultId: vaultId,
        schemaVersion: schemaVersion,
        salt: saltRaw,
        kdfParams: KdfParams.fromJson(decodedKdf),
        cipherAlgorithm: VaultCipherAlgorithm.fromId(cipherId),
        wrappedDek: EncryptedPayload.fromBytes(wrappedDekRaw),
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          createdAtMillis,
          isUtc: true,
        ),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(
          updatedAtMillis,
          isUtc: true,
        ),
      );
    } on AppException {
      rethrow;
    } on FormatException {
      throw const StorageException('Malformed KDF JSON in vault metadata.');
    }
  }

  @override
  String toString() =>
      'VaultMetadata(vaultId: $vaultId, schemaVersion: $schemaVersion, cipher: ${cipherAlgorithm.id})';

  @override
  List<Object?> get props => [
        vaultId,
        schemaVersion,
        base64Url.encode(_salt),
        kdfParams,
        cipherAlgorithm,
        wrappedDek.toBase64(),
        createdAt,
        updatedAt,
      ];
}
