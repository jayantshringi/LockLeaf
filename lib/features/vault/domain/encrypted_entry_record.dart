import 'dart:convert';
import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:lockleaf/core/errors/app_exception.dart';

/// Opaque encrypted database record for a single vault entry.
///
/// Only the UUID and non-sensitive timestamps are stored outside the
/// authenticated ciphertext blob.
class EncryptedEntryRecord extends Equatable {
  /// Stable UUID v4 entry identifier.
  final String id;

  final Uint8List _encryptedBlob;

  /// UTC timestamp when the record was first inserted.
  final DateTime createdAt;

  /// UTC timestamp of the last update.
  final DateTime updatedAt;

  EncryptedEntryRecord._({
    required this.id,
    required Uint8List encryptedBlob,
    required DateTime createdAt,
    required DateTime updatedAt,
  })  : _encryptedBlob = encryptedBlob,
        createdAt = createdAt.toUtc(),
        updatedAt = updatedAt.toUtc();

  /// Creates and validates an [EncryptedEntryRecord].
  factory EncryptedEntryRecord({
    required String id,
    required List<int> encryptedBlob,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) {
    if (id.trim().isEmpty) {
      throw const ValidationException('Encrypted entry ID cannot be empty.');
    }
    if (encryptedBlob.isEmpty) {
      throw const ValidationException('Encrypted entry blob cannot be empty.');
    }
    return EncryptedEntryRecord._(
      id: id.trim(),
      encryptedBlob: Uint8List.fromList(encryptedBlob),
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  /// Defensive copy of the serialized `EncryptedPayload` bytes.
  Uint8List get encryptedBlob => Uint8List.fromList(_encryptedBlob);

  /// Serializes this record into a SQLite column map.
  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'encrypted_blob': encryptedBlob,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  /// Parses an [EncryptedEntryRecord] from a SQLite row map.
  factory EncryptedEntryRecord.fromMap(Map<String, Object?> map) {
    final id = map['id'];
    final blobRaw = map['encrypted_blob'];
    final createdAtMillis = map['created_at'];
    final updatedAtMillis = map['updated_at'];

    if (id is! String ||
        blobRaw is! List<int> ||
        createdAtMillis is! int ||
        updatedAtMillis is! int) {
      throw const StorageException('Corrupt encrypted entry row in database.');
    }

    return EncryptedEntryRecord(
      id: id,
      encryptedBlob: blobRaw,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        createdAtMillis,
        isUtc: true,
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        updatedAtMillis,
        isUtc: true,
      ),
    );
  }

  @override
  String toString() =>
      'EncryptedEntryRecord(id: $id, bytes: ${_encryptedBlob.length})';

  @override
  List<Object?> get props => [
        id,
        base64Url.encode(_encryptedBlob),
        createdAt,
        updatedAt,
      ];
}
