/// DDL statements and table schemas for cloud synchronization.
abstract class SyncDatabaseSchema {
  /// Table storing synchronization progress and device metadata.
  static const String stateTable = 'sync_state';

  /// Table storing locally queued entry changes waiting to be pushed.
  static const String queueTable = 'sync_queue';

  /// Creates [stateTable].
  static const String createStateTableSql = '''
CREATE TABLE IF NOT EXISTS $stateTable (
  vault_id TEXT PRIMARY KEY,
  device_id TEXT NOT NULL,
  last_synced_at INTEGER,
  sync_cursor TEXT,
  remote_version INTEGER NOT NULL DEFAULT 0
);
''';

  /// Creates [queueTable].
  static const String createQueueTableSql = '''
CREATE TABLE IF NOT EXISTS $queueTable (
  entry_id TEXT PRIMARY KEY,
  vault_id TEXT NOT NULL,
  action TEXT NOT NULL,
  queued_at INTEGER NOT NULL,
  retry_count INTEGER NOT NULL DEFAULT 0
);
''';

  /// Index on [queueTable] by vault_id and queued_at timestamp.
  static const String createQueueIndexSql = '''
CREATE INDEX IF NOT EXISTS idx_sync_queue_vault_queued
ON $queueTable (vault_id, queued_at ASC);
''';
}
