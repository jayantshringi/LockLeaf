/// SQLite schema constants and DDL statements for the LockLeaf local vault.
abstract class VaultDatabaseSchema {
  /// Default SQLite database filename stored inside app-private storage.
  static const String databaseName = 'lockleaf_vault.db';

  /// Current SQLite schema version.
  static const int databaseVersion = 2;

  /// Table storing public KDF parameters and the wrapped vault DEK.
  static const String metadataTable = 'vault_metadata';

  /// Table storing opaque AEAD-encrypted vault entry blobs.
  static const String entriesTable = 'vault_entries';

  /// Creates the [metadataTable] storing zero plaintext secrets.
  static const String createMetadataTableSql = '''
CREATE TABLE $metadataTable (
  vault_id TEXT PRIMARY KEY,
  schema_version INTEGER NOT NULL,
  salt BLOB NOT NULL,
  kdf_params_json TEXT NOT NULL,
  cipher_algorithm TEXT NOT NULL,
  wrapped_dek BLOB NOT NULL,
  recovery_salt BLOB,
  recovery_wrapped_dek BLOB,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
)
''';

  /// DDL upgrade statements from version 1 to 2.
  static const String upgradeV1ToV2AddRecoverySaltSql =
      'ALTER TABLE $metadataTable ADD COLUMN recovery_salt BLOB;';
  static const String upgradeV1ToV2AddRecoveryDekSql =
      'ALTER TABLE $metadataTable ADD COLUMN recovery_wrapped_dek BLOB;';

  /// Creates the [entriesTable] holding opaque encrypted entry payloads.
  static const String createEntriesTableSql = '''
CREATE TABLE $entriesTable (
  id TEXT PRIMARY KEY,
  encrypted_blob BLOB NOT NULL,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
)
''';

  /// Index ordering encrypted entries by modification timestamp.
  static const String createEntriesUpdatedAtIndexSql = '''
CREATE INDEX idx_vault_entries_updated_at
ON $entriesTable (updated_at DESC)
''';
}
