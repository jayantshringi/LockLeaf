import 'dart:convert';
import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:lockleaf/core/crypto/cipher_algorithm.dart';
import 'package:lockleaf/core/crypto/encrypted_payload.dart';
import 'package:lockleaf/core/crypto/kdf_params.dart';
import 'package:lockleaf/core/errors/app_exception.dart';
import 'package:lockleaf/features/vault/domain/vault_entry.dart';

/// Unencrypted header information extracted from a LockLeaf encrypted backup file.
class EncryptedBackupHeader extends Equatable {
  /// Format identifier magic string.
  static const String expectedMagic = 'LOCKLEAF_BACKUP';

  /// Supported backup format version.
  static const int currentVersion = 1;

  /// Identifier of the vault that created this backup.
  final String vaultId;

  /// Schema version of the backup format.
  final int formatVersion;

  /// UTC timestamp when the backup was exported.
  final DateTime createdAt;

  /// Number of vault entries contained in the backup.
  final int entryCount;

  /// Argon2id parameters used to derive the backup encryption key.
  final KdfParams kdfParams;

  /// Cipher algorithm used to encrypt the payload.
  final VaultCipherAlgorithm cipherAlgorithm;

  /// Optional unencrypted user note attached to the backup.
  final String? notes;

  const EncryptedBackupHeader({
    required this.vaultId,
    required this.formatVersion,
    required this.createdAt,
    required this.entryCount,
    required this.kdfParams,
    required this.cipherAlgorithm,
    this.notes,
  });

  @override
  List<Object?> get props => [
    vaultId,
    formatVersion,
    createdAt,
    entryCount,
    kdfParams,
    cipherAlgorithm,
    notes,
  ];
}

/// Representation of an authenticated zero-knowledge LockLeaf encrypted backup.
class EncryptedBackupPayload extends Equatable {
  /// Standard LockLeaf backup file extension.
  static const String fileExtension = '.llbak';

  /// Associated data context string bound into the AEAD authentication tag.
  static String backupAad(String vaultId) => 'lockleaf:backup:v1:$vaultId';

  final EncryptedBackupHeader _header;
  final Uint8List _salt;
  final EncryptedPayload _encryptedPayload;

  EncryptedBackupPayload._({
    required EncryptedBackupHeader header,
    required Uint8List salt,
    required EncryptedPayload encryptedPayload,
  }) : _header = header,
       _salt = salt,
       _encryptedPayload = encryptedPayload;

  /// Creates a new [EncryptedBackupPayload].
  factory EncryptedBackupPayload({
    required String vaultId,
    int formatVersion = EncryptedBackupHeader.currentVersion,
    required DateTime createdAt,
    required int entryCount,
    required List<int> salt,
    required KdfParams kdfParams,
    required VaultCipherAlgorithm cipherAlgorithm,
    required EncryptedPayload encryptedPayload,
    String? notes,
  }) {
    if (salt.length < 16) {
      throw const ValidationException('Backup salt must be at least 16 bytes.');
    }
    if (entryCount < 0) {
      throw const ValidationException('Entry count cannot be negative.');
    }

    final header = EncryptedBackupHeader(
      vaultId: vaultId.trim(),
      formatVersion: formatVersion,
      createdAt: createdAt.toUtc(),
      entryCount: entryCount,
      kdfParams: kdfParams,
      cipherAlgorithm: cipherAlgorithm,
      notes: notes?.trim(),
    );

    return EncryptedBackupPayload._(
      header: header,
      salt: Uint8List.fromList(salt),
      encryptedPayload: encryptedPayload,
    );
  }

  /// Backup header containing public metadata.
  EncryptedBackupHeader get header => _header;

  /// Vault identifier.
  String get vaultId => _header.vaultId;

  /// Format version.
  int get formatVersion => _header.formatVersion;

  /// Creation timestamp in UTC.
  DateTime get createdAt => _header.createdAt;

  /// Total entries stored.
  int get entryCount => _header.entryCount;

  /// KDF derivation parameters.
  KdfParams get kdfParams => _header.kdfParams;

  /// Cipher algorithm used.
  VaultCipherAlgorithm get cipherAlgorithm => _header.cipherAlgorithm;

  /// Optional backup notes.
  String? get notes => _header.notes;

  /// Defensive copy of the random 32-byte salt.
  Uint8List get salt => Uint8List.fromList(_salt);

  /// Authenticated encrypted vault ciphertext and nonce.
  EncryptedPayload get encryptedPayload => _encryptedPayload;

  /// Inspects raw backup JSON without requiring the backup password.
  static EncryptedBackupHeader inspect(String jsonString) {
    try {
      final decoded = jsonDecode(jsonString);
      if (decoded is! Map<String, dynamic>) {
        throw const ValidationException(
          'Invalid backup: Root is not a JSON object.',
        );
      }
      return _parseHeader(decoded);
    } on FormatException {
      throw const ValidationException('Malformed backup JSON string.');
    }
  }

  /// Parses an [EncryptedBackupPayload] from a JSON string.
  factory EncryptedBackupPayload.fromJsonString(String jsonString) {
    try {
      final decoded = jsonDecode(jsonString);
      if (decoded is! Map<String, dynamic>) {
        throw const ValidationException(
          'Invalid backup: Root is not a JSON object.',
        );
      }

      final header = _parseHeader(decoded);

      final saltBase64 = decoded['salt'];
      if (saltBase64 is! String) {
        throw const ValidationException('Missing or invalid salt in backup.');
      }
      final saltBytes = base64.decode(saltBase64);

      final payloadRaw = decoded['payload'];
      if (payloadRaw is! String) {
        throw const ValidationException(
          'Missing or invalid encrypted payload in backup.',
        );
      }
      final encryptedPayload = EncryptedPayload.fromBase64(payloadRaw);

      return EncryptedBackupPayload._(
        header: header,
        salt: Uint8List.fromList(saltBytes),
        encryptedPayload: encryptedPayload,
      );
    } on FormatException {
      throw const ValidationException('Malformed backup file format.');
    }
  }

  static EncryptedBackupHeader _parseHeader(Map<String, dynamic> map) {
    final magic = map['magic'];
    if (magic != EncryptedBackupHeader.expectedMagic) {
      throw const ValidationException(
        'Invalid backup file: Unrecognized magic header.',
      );
    }

    final version = map['version'];
    if (version != EncryptedBackupHeader.currentVersion) {
      throw ValidationException('Unsupported backup format version: $version');
    }

    final vaultId = map['vault_id'];
    if (vaultId is! String || vaultId.trim().isEmpty) {
      throw const ValidationException('Missing or invalid vault_id in backup.');
    }

    final createdAtStr = map['created_at'];
    if (createdAtStr is! String) {
      throw const ValidationException(
        'Missing or invalid created_at timestamp in backup.',
      );
    }
    final createdAt = DateTime.tryParse(createdAtStr)?.toUtc();
    if (createdAt == null) {
      throw const ValidationException('Invalid ISO timestamp in backup.');
    }

    final entryCount = map['entry_count'];
    if (entryCount is! int || entryCount < 0) {
      throw const ValidationException(
        'Missing or invalid entry_count in backup.',
      );
    }

    final kdfMap = map['kdf_params'];
    if (kdfMap is! Map<String, dynamic>) {
      throw const ValidationException(
        'Missing or invalid kdf_params in backup.',
      );
    }
    final kdfParams = KdfParams.fromJson(kdfMap);

    final cipherId = map['cipher_algorithm'];
    if (cipherId is! String) {
      throw const ValidationException(
        'Missing or invalid cipher_algorithm in backup.',
      );
    }
    final cipher = VaultCipherAlgorithm.fromId(cipherId);

    final notes = map['notes'] as String?;

    return EncryptedBackupHeader(
      vaultId: vaultId.trim(),
      formatVersion: version,
      createdAt: createdAt,
      entryCount: entryCount,
      kdfParams: kdfParams,
      cipherAlgorithm: cipher,
      notes: notes,
    );
  }

  /// Serializes into a pretty or compact JSON string suitable for `.llbak` storage.
  String toJsonString({bool pretty = false}) {
    final map = <String, Object?>{
      'magic': EncryptedBackupHeader.expectedMagic,
      'version': formatVersion,
      'vault_id': vaultId,
      'created_at': createdAt.toIso8601String(),
      'entry_count': entryCount,
      'notes': notes,
      'salt': base64.encode(_salt),
      'kdf_params': kdfParams.toJson(),
      'cipher_algorithm': cipherAlgorithm.id,
      'payload': encryptedPayload.toBase64(),
    };

    if (pretty) {
      return const JsonEncoder.withIndent('  ').convert(map);
    }
    return jsonEncode(map);
  }

  @override
  List<Object?> get props => [
    _header,
    base64.encode(_salt),
    _encryptedPayload.toBase64(),
  ];
}

/// Plaintext bundle of decrypted vault entries before encryption or after restoration.
class BackupBundle extends Equatable {
  /// Bundle format version.
  static const int currentBundleVersion = 1;

  final String vaultId;
  final DateTime exportedAt;
  final List<VaultEntry> entries;

  const BackupBundle({
    required this.vaultId,
    required this.exportedAt,
    required this.entries,
  });

  /// Serializes the cleartext bundle into a JSON-encodable map.
  Map<String, dynamic> toJson() => {
    'version': currentBundleVersion,
    'vault_id': vaultId,
    'exported_at': exportedAt.toUtc().toIso8601String(),
    'entries': entries.map((e) => e.toJson()).toList(growable: false),
  };

  /// Restores a cleartext bundle from a decoded JSON map.
  factory BackupBundle.fromJson(Map<String, dynamic> json) {
    final vaultId = json['vault_id'];
    if (vaultId is! String || vaultId.isEmpty) {
      throw const ValidationException(
        'Missing vault_id in decrypted backup bundle.',
      );
    }

    final exportedAtStr = json['exported_at'];
    if (exportedAtStr is! String) {
      throw const ValidationException(
        'Missing exported_at in decrypted backup bundle.',
      );
    }
    final exportedAt =
        DateTime.tryParse(exportedAtStr)?.toUtc() ?? DateTime.now().toUtc();

    final rawEntries = json['entries'];
    if (rawEntries is! List) {
      throw const ValidationException(
        'Missing entries list in decrypted backup bundle.',
      );
    }

    final entries = <VaultEntry>[];
    for (final raw in rawEntries) {
      if (raw is Map<String, dynamic>) {
        entries.add(VaultEntry.fromJson(raw));
      }
    }

    return BackupBundle(
      vaultId: vaultId,
      exportedAt: exportedAt,
      entries: List.unmodifiable(entries),
    );
  }

  @override
  List<Object?> get props => [vaultId, exportedAt, entries];
}
