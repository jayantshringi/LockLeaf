import 'package:equatable/equatable.dart';
import 'package:lockleaf/features/sync/data/sync_database_schema.dart';
import 'package:lockleaf/features/sync/domain/sync_status.dart';
import 'package:sqflite/sqflite.dart';

/// Item in the local sync queue representing an unpushed local change.
class SyncQueueItem extends Equatable {
  final String entryId;
  final String vaultId;
  final SyncAction action;
  final DateTime queuedAt;
  final int retryCount;

  const SyncQueueItem({
    required this.entryId,
    required this.vaultId,
    required this.action,
    required this.queuedAt,
    this.retryCount = 0,
  });

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'entry_id': entryId,
      'vault_id': vaultId,
      'action': action.toValue(),
      'queued_at': queuedAt.toUtc().millisecondsSinceEpoch,
      'retry_count': retryCount,
    };
  }

  factory SyncQueueItem.fromMap(Map<String, Object?> map) {
    return SyncQueueItem(
      entryId: map['entry_id'] as String? ?? '',
      vaultId: map['vault_id'] as String? ?? '',
      action: SyncAction.fromValue(map['action'] as String? ?? 'update'),
      queuedAt: DateTime.fromMillisecondsSinceEpoch(
        map['queued_at'] as int? ?? 0,
        isUtc: true,
      ),
      retryCount: map['retry_count'] as int? ?? 0,
    );
  }

  @override
  List<Object?> get props => [entryId, vaultId, action, queuedAt, retryCount];
}

/// Abstract contract for managing local sync metadata and the pending sync queue.
abstract class SyncStorageRepository {
  /// Retrieves the synchronization metadata for [vaultId], or null if unconfigured.
  Future<SyncMetadata?> getMetadata(String vaultId);

  /// Saves or updates the synchronization metadata for [vaultId].
  Future<void> saveMetadata(SyncMetadata metadata);

  /// Enqueues a local change action for [entryId].
  Future<void> enqueueAction({
    required String entryId,
    required String vaultId,
    required SyncAction action,
  });

  /// Retrieves all pending items in the sync queue for [vaultId].
  Future<List<SyncQueueItem>> getPendingQueue(String vaultId);

  /// Removes an entry from the sync queue after successful push.
  Future<void> removeQueueItem(String entryId);

  /// Clears all queued sync items for [vaultId].
  Future<void> clearQueue(String vaultId);

  /// Returns the number of unpushed changes queued for [vaultId].
  Future<int> getPendingQueueCount(String vaultId);
}

/// SQLite-backed implementation of [SyncStorageRepository].
class SqliteSyncStorageRepository implements SyncStorageRepository {
  final Database Function() _getDatabase;

  SqliteSyncStorageRepository({required Database Function() getDatabase})
      : _getDatabase = getDatabase;

  @override
  Future<SyncMetadata?> getMetadata(String vaultId) async {
    final db = _getDatabase();
    final rows = await db.query(
      SyncDatabaseSchema.stateTable,
      where: 'vault_id = ?',
      whereArgs: [vaultId],
      limit: 1,
    );
    if (rows.isEmpty) return null;

    final pending = await getPendingQueueCount(vaultId);
    return SyncMetadata.fromMap(rows.first, pendingCount: pending);
  }

  @override
  Future<void> saveMetadata(SyncMetadata metadata) async {
    final db = _getDatabase();
    await db.insert(
      SyncDatabaseSchema.stateTable,
      metadata.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> enqueueAction({
    required String entryId,
    required String vaultId,
    required SyncAction action,
  }) async {
    final db = _getDatabase();
    final item = SyncQueueItem(
      entryId: entryId,
      vaultId: vaultId,
      action: action,
      queuedAt: DateTime.now().toUtc(),
    );
    await db.insert(
      SyncDatabaseSchema.queueTable,
      item.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<List<SyncQueueItem>> getPendingQueue(String vaultId) async {
    final db = _getDatabase();
    final rows = await db.query(
      SyncDatabaseSchema.queueTable,
      where: 'vault_id = ?',
      whereArgs: [vaultId],
      orderBy: 'queued_at ASC',
    );
    return rows.map((r) => SyncQueueItem.fromMap(r)).toList(growable: false);
  }

  @override
  Future<void> removeQueueItem(String entryId) async {
    final db = _getDatabase();
    await db.delete(
      SyncDatabaseSchema.queueTable,
      where: 'entry_id = ?',
      whereArgs: [entryId],
    );
  }

  @override
  Future<void> clearQueue(String vaultId) async {
    final db = _getDatabase();
    await db.delete(
      SyncDatabaseSchema.queueTable,
      where: 'vault_id = ?',
      whereArgs: [vaultId],
    );
  }

  @override
  Future<int> getPendingQueueCount(String vaultId) async {
    final db = _getDatabase();
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM ${SyncDatabaseSchema.queueTable} WHERE vault_id = ?',
      [vaultId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }
}

/// In-memory implementation of [SyncStorageRepository] for fast testing.
class InMemorySyncStorageRepository implements SyncStorageRepository {
  final Map<String, SyncMetadata> _metadataMap = {};
  final Map<String, SyncQueueItem> _queueMap = {};

  @override
  Future<SyncMetadata?> getMetadata(String vaultId) async {
    final meta = _metadataMap[vaultId];
    if (meta == null) return null;
    final count = await getPendingQueueCount(vaultId);
    return meta.copyWith(pendingUploadCount: count);
  }

  @override
  Future<void> saveMetadata(SyncMetadata metadata) async {
    _metadataMap[metadata.vaultId] = metadata;
  }

  @override
  Future<void> enqueueAction({
    required String entryId,
    required String vaultId,
    required SyncAction action,
  }) async {
    _queueMap[entryId] = SyncQueueItem(
      entryId: entryId,
      vaultId: vaultId,
      action: action,
      queuedAt: DateTime.now().toUtc(),
    );
  }

  @override
  Future<List<SyncQueueItem>> getPendingQueue(String vaultId) async {
    return _queueMap.values
        .where((item) => item.vaultId == vaultId)
        .toList(growable: false);
  }

  @override
  Future<void> removeQueueItem(String entryId) async {
    _queueMap.remove(entryId);
  }

  @override
  Future<void> clearQueue(String vaultId) async {
    _queueMap.removeWhere((_, item) => item.vaultId == vaultId);
  }

  @override
  Future<int> getPendingQueueCount(String vaultId) async {
    return _queueMap.values.where((item) => item.vaultId == vaultId).length;
  }
}

