import 'package:lockleaf/features/sync/domain/encrypted_sync_record.dart';

/// Response payload received after pulling remote changes from a sync server.
class SyncPullResponse {
  final List<EncryptedSyncRecord> records;
  final String? nextCursor;
  final int serverVersion;

  const SyncPullResponse({
    required this.records,
    this.nextCursor,
    this.serverVersion = 0,
  });
}

/// Response payload received after pushing local changes to a sync server.
class SyncPushResponse {
  final bool success;
  final int acceptedCount;
  final int serverVersion;
  final String? newCursor;
  final String? errorMessage;

  const SyncPushResponse({
    required this.success,
    required this.acceptedCount,
    this.serverVersion = 0,
    this.newCursor,
    this.errorMessage,
  });
}

/// Abstract contract for zero-knowledge cloud transport implementations.
abstract class CloudSyncTransport {
  /// Name or identifier of this cloud transport implementation.
  String get name;

  /// Verifies connectivity and authentication with the remote endpoint.
  Future<bool> checkHealth();

  /// Pulls remote encrypted changesets modified after [sinceCursor].
  Future<SyncPullResponse> pullChanges({
    required String vaultId,
    required String? sinceCursor,
  });

  /// Pushes local encrypted records to the remote endpoint.
  Future<SyncPushResponse> pushChanges({
    required String vaultId,
    required List<EncryptedSyncRecord> records,
  });
}

/// In-memory implementation of [CloudSyncTransport] simulating a zero-knowledge cloud server.
class InMemorySyncTransport implements CloudSyncTransport {
  @override
  final String name = 'In-Memory Simulated Cloud';

  bool isHealthy = true;
  int _currentVersion = 0;

  /// Map of `vaultId` -> Map of `entryId` -> `EncryptedSyncRecord`.
  final Map<String, Map<String, EncryptedSyncRecord>> _remoteVaults = {};

  @override
  Future<bool> checkHealth() async => isHealthy;

  @override
  Future<SyncPullResponse> pullChanges({
    required String vaultId,
    required String? sinceCursor,
  }) async {
    final vault = _remoteVaults[vaultId] ?? <String, EncryptedSyncRecord>{};
    final sinceVersion = int.tryParse(sinceCursor ?? '') ?? 0;

    final records = vault.values
        .where((record) => record.version > sinceVersion)
        .toList(growable: false);

    return SyncPullResponse(
      records: records,
      nextCursor: _currentVersion.toString(),
      serverVersion: _currentVersion,
    );
  }

  @override
  Future<SyncPushResponse> pushChanges({
    required String vaultId,
    required List<EncryptedSyncRecord> records,
  }) async {
    if (!isHealthy) {
      return const SyncPushResponse(
        success: false,
        acceptedCount: 0,
        errorMessage: 'Simulated cloud server unreachable.',
      );
    }

    final vault = _remoteVaults.putIfAbsent(
      vaultId,
      () => <String, EncryptedSyncRecord>{},
    );

    var accepted = 0;
    for (final record in records) {
      _currentVersion++;
      final serverRecord = EncryptedSyncRecord(
        id: record.id,
        vaultId: record.vaultId,
        version: _currentVersion,
        deviceId: record.deviceId,
        updatedAt: record.updatedAt,
        isDeleted: record.isDeleted,
        encryptedBlob: record.encryptedBlob,
      );
      vault[record.id] = serverRecord;
      accepted++;
    }

    return SyncPushResponse(
      success: true,
      acceptedCount: accepted,
      serverVersion: _currentVersion,
      newCursor: _currentVersion.toString(),
    );
  }

  /// Resets simulated remote storage.
  void reset() {
    _remoteVaults.clear();
    _currentVersion = 0;
    isHealthy = true;
  }
}
