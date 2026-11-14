import 'package:equatable/equatable.dart';

/// Top-level state of the synchronization subsystem.
enum SyncState {
  /// Sync engine is idle and not currently transferring data.
  idle,

  /// Actively pulling or pushing encrypted changesets.
  syncing,

  /// Last sync completed successfully.
  success,

  /// Device is offline or sync server is unreachable.
  offline,

  /// Sync failed due to an error.
  error,
}

/// Action performed on a local vault entry that requires synchronization.
enum SyncAction {
  /// Entry was newly created locally.
  create,

  /// Existing entry was updated locally.
  update,

  /// Entry was deleted locally and requires a tombstone upload.
  delete;

  /// Serializes the action name.
  String toValue() => name;

  /// Parses action name from database string.
  static SyncAction fromValue(String value) {
    switch (value.toLowerCase()) {
      case 'create':
        return SyncAction.create;
      case 'update':
        return SyncAction.update;
      case 'delete':
        return SyncAction.delete;
      default:
        return SyncAction.update;
    }
  }
}

/// Persistent metadata tracking synchronization progress and device identity.
class SyncMetadata extends Equatable {
  /// Unique identifier of the synchronized vault.
  final String vaultId;

  /// Unique stable identifier of this local client installation.
  final String deviceId;

  /// UTC timestamp of the last successful synchronization, or null if never synced.
  final DateTime? lastSyncedAt;

  /// High-water mark cursor returned by the remote backend for delta syncs.
  final String? syncCursor;

  /// Highest sequence or revision number confirmed by the remote backend.
  final int remoteVersion;

  /// Number of local changes waiting in the sync queue.
  final int pendingUploadCount;

  /// Current runtime state of synchronization.
  final SyncState syncState;

  /// Human-readable description of the last sync error, if any.
  final String? lastError;

  const SyncMetadata({
    required this.vaultId,
    required this.deviceId,
    this.lastSyncedAt,
    this.syncCursor,
    this.remoteVersion = 0,
    this.pendingUploadCount = 0,
    this.syncState = SyncState.idle,
    this.lastError,
  });

  /// Creates a copy of [SyncMetadata] with updated fields.
  SyncMetadata copyWith({
    String? vaultId,
    String? deviceId,
    DateTime? lastSyncedAt,
    bool clearLastSyncedAt = false,
    String? syncCursor,
    bool clearSyncCursor = false,
    int? remoteVersion,
    int? pendingUploadCount,
    SyncState? syncState,
    String? lastError,
    bool clearLastError = false,
  }) {
    return SyncMetadata(
      vaultId: vaultId ?? this.vaultId,
      deviceId: deviceId ?? this.deviceId,
      lastSyncedAt:
          clearLastSyncedAt ? null : (lastSyncedAt ?? this.lastSyncedAt),
      syncCursor: clearSyncCursor ? null : (syncCursor ?? this.syncCursor),
      remoteVersion: remoteVersion ?? this.remoteVersion,
      pendingUploadCount: pendingUploadCount ?? this.pendingUploadCount,
      syncState: syncState ?? this.syncState,
      lastError: clearLastError ? null : (lastError ?? this.lastError),
    );
  }

  /// Serializes to SQLite column map.
  Map<String, Object?> toMap() {
    return <String, Object?>{
      'vault_id': vaultId,
      'device_id': deviceId,
      'last_synced_at': lastSyncedAt?.toUtc().millisecondsSinceEpoch,
      'sync_cursor': syncCursor,
      'remote_version': remoteVersion,
    };
  }

  /// Restores [SyncMetadata] from a SQLite column map.
  factory SyncMetadata.fromMap(
    Map<String, Object?> map, {
    int pendingCount = 0,
    SyncState state = SyncState.idle,
    String? error,
  }) {
    final vaultId = map['vault_id'] as String? ?? '';
    final deviceId = map['device_id'] as String? ?? '';
    final lastSyncedMillis = map['last_synced_at'] as int?;
    final syncCursor = map['sync_cursor'] as String?;
    final remoteVersion = map['remote_version'] as int? ?? 0;

    return SyncMetadata(
      vaultId: vaultId,
      deviceId: deviceId,
      lastSyncedAt: lastSyncedMillis == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(lastSyncedMillis, isUtc: true),
      syncCursor: syncCursor,
      remoteVersion: remoteVersion,
      pendingUploadCount: pendingCount,
      syncState: state,
      lastError: error,
    );
  }

  @override
  List<Object?> get props => [
        vaultId,
        deviceId,
        lastSyncedAt,
        syncCursor,
        remoteVersion,
        pendingUploadCount,
        syncState,
        lastError,
      ];
}
