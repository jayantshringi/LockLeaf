import 'dart:convert';
import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:lockleaf/core/errors/app_exception.dart';

/// An authenticated, end-to-end encrypted record representing a vault entry change
/// or deletion tombstone for cloud synchronization.
class EncryptedSyncRecord extends Equatable {
  /// Context string bound into the AEAD tag for cryptographic entry binding.
  static String syncAad(String vaultId, String entryId) =>
      'lockleaf:sync:v1:$vaultId:$entryId';

  /// Stable identifier of the vault entry.
  final String id;

  /// Identifier of the owning vault.
  final String vaultId;

  /// Monotonically increasing revision sequence number.
  final int version;

  /// Unique client installation identifier that produced this record.
  final String deviceId;

  /// UTC timestamp when this change was committed locally.
  final DateTime updatedAt;

  /// Whether this record represents a deletion tombstone.
  final bool isDeleted;

  final Uint8List _encryptedBlob;

  EncryptedSyncRecord._({
    required this.id,
    required this.vaultId,
    required this.version,
    required this.deviceId,
    required DateTime updatedAt,
    required this.isDeleted,
    required Uint8List encryptedBlob,
  })  : updatedAt = updatedAt.toUtc(),
        _encryptedBlob = encryptedBlob;

  /// Creates and validates a new [EncryptedSyncRecord].
  factory EncryptedSyncRecord({
    required String id,
    required String vaultId,
    required int version,
    required String deviceId,
    required DateTime updatedAt,
    required bool isDeleted,
    required List<int> encryptedBlob,
  }) {
    if (id.trim().isEmpty) {
      throw const ValidationException('Sync record ID cannot be empty.');
    }
    if (vaultId.trim().isEmpty) {
      throw const ValidationException('Sync record vaultId cannot be empty.');
    }
    if (version < 0) {
      throw const ValidationException(
        'Sync record version cannot be negative.',
      );
    }

    return EncryptedSyncRecord._(
      id: id.trim(),
      vaultId: vaultId.trim(),
      version: version,
      deviceId: deviceId.trim(),
      updatedAt: updatedAt,
      isDeleted: isDeleted,
      encryptedBlob: Uint8List.fromList(encryptedBlob),
    );
  }

  /// Defensive copy of the raw ciphertext bytes.
  Uint8List get encryptedBlob => Uint8List.fromList(_encryptedBlob);

  /// Serializes into a JSON-encodable map for cloud transmission.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'vault_id': vaultId,
      'version': version,
      'device_id': deviceId,
      'updated_at': updatedAt.toIso8601String(),
      'is_deleted': isDeleted,
      'encrypted_blob': base64.encode(_encryptedBlob),
    };
  }

  /// Restores an [EncryptedSyncRecord] from a decoded JSON map.
  factory EncryptedSyncRecord.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final vaultId = json['vault_id'];
    final version = json['version'];
    final deviceId = json['device_id'];
    final updatedAtRaw = json['updated_at'];
    final isDeleted = json['is_deleted'];
    final blobBase64 = json['encrypted_blob'];

    if (id is! String ||
        vaultId is! String ||
        version is! int ||
        deviceId is! String ||
        updatedAtRaw is! String ||
        isDeleted is! bool ||
        blobBase64 is! String) {
      throw const ValidationException(
        'Invalid or missing fields in sync record JSON.',
      );
    }

    final parsedUpdatedAt = DateTime.tryParse(updatedAtRaw)?.toUtc();
    if (parsedUpdatedAt == null) {
      throw const ValidationException(
        'Invalid ISO timestamp in sync record JSON.',
      );
    }

    final blobBytes = base64.decode(blobBase64);

    return EncryptedSyncRecord(
      id: id,
      vaultId: vaultId,
      version: version,
      deviceId: deviceId,
      updatedAt: parsedUpdatedAt,
      isDeleted: isDeleted,
      encryptedBlob: blobBytes,
    );
  }

  @override
  List<Object?> get props => [
        id,
        vaultId,
        version,
        deviceId,
        updatedAt,
        isDeleted,
        base64.encode(_encryptedBlob),
      ];
}
