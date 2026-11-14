import 'dart:convert';
import 'dart:typed_data';

import 'package:lockleaf/core/crypto/cipher_service.dart';
import 'package:lockleaf/core/crypto/encrypted_payload.dart';
import 'package:lockleaf/core/crypto/secure_memory.dart';
import 'package:lockleaf/core/errors/app_exception.dart';
import 'package:lockleaf/features/sync/data/cloud_sync_transport.dart';
import 'package:lockleaf/features/sync/data/sync_storage_repository.dart';
import 'package:lockleaf/features/sync/domain/encrypted_sync_record.dart';
import 'package:lockleaf/features/sync/domain/sync_conflict_resolver.dart';
import 'package:lockleaf/features/sync/domain/sync_status.dart';
import 'package:lockleaf/features/vault/data/vault_storage_repository.dart';
import 'package:lockleaf/features/vault/domain/encrypted_entry_record.dart';
import 'package:lockleaf/features/vault/domain/vault_entry.dart';
import 'package:lockleaf/features/vault/domain/vault_session.dart';

/// Result summary of an end-to-end synchronization cycle.
class SyncResult {
  final SyncState state;
  final int pulledCount;
  final int appliedRemoteCount;
  final int deletedLocalCount;
  final int pushedCount;
  final String? errorMessage;

  const SyncResult({
    required this.state,
    this.pulledCount = 0,
    this.appliedRemoteCount = 0,
    this.deletedLocalCount = 0,
    this.pushedCount = 0,
    this.errorMessage,
  });

  bool get isSuccess => state == SyncState.success;
}

/// Orchestrates zero-knowledge bi-directional vault synchronization.
class SyncEngine {
  final VaultStorageRepository _vaultStorage;
  final SyncStorageRepository _syncStorage;
  final CloudSyncTransport _transport;
  final CipherService _cipherService;
  final String _localDeviceId;
  final SyncConflictResolver _conflictResolver;

  SyncEngine({
    required VaultStorageRepository vaultStorage,
    required SyncStorageRepository syncStorage,
    required CloudSyncTransport transport,
    required String localDeviceId,
    CipherService? cipherService,
    SyncConflictResolver? conflictResolver,
  })  : _vaultStorage = vaultStorage,
        _syncStorage = syncStorage,
        _transport = transport,
        _localDeviceId = localDeviceId,
        _cipherService = cipherService ?? CipherService(),
        _conflictResolver =
            conflictResolver ?? SyncConflictResolver(localDeviceId: localDeviceId);

  String get localDeviceId => _localDeviceId;
  CloudSyncTransport get transport => _transport;

  /// Executes a full pull-resolve-apply-push synchronization cycle.
  Future<SyncResult> synchronize({required VaultSession session}) async {
    if (!session.isActive) {
      throw const VaultLockedException();
    }

    final vaultId = session.vaultId;

    // Check transport connectivity
    final isHealthy = await _transport.checkHealth();
    if (!isHealthy) {
      return const SyncResult(
        state: SyncState.offline,
        errorMessage: 'Sync server unreachable or offline.',
      );
    }

    // Load or initialize sync metadata
    var metadata = await _syncStorage.getMetadata(vaultId);
    metadata ??= SyncMetadata(
      vaultId: vaultId,
      deviceId: _localDeviceId,
    );

    var pulledCount = 0;
    var appliedRemote = 0;
    var deletedLocal = 0;
    var pushedCount = 0;

    try {
      // -------------------------------------------------------------
      // 1. PULL PHASE
      // -------------------------------------------------------------
      final pullResponse = await _transport.pullChanges(
        vaultId: vaultId,
        sinceCursor: metadata.syncCursor,
      );
      pulledCount = pullResponse.records.length;

      for (final record in pullResponse.records) {
        // Skip echo changes produced by this same device
        if (record.deviceId == _localDeviceId) {
          continue;
        }

        final localEntry = await _loadLocalEntry(session, record.id);
        VaultEntry? decryptedRemote;

        if (!record.isDeleted && record.encryptedBlob.isNotEmpty) {
          decryptedRemote = await _decryptSyncRecord(session, record);
        }

        final resolution = _conflictResolver.resolve(
          localEntry: localEntry,
          remoteRecord: record,
          decryptedRemoteEntry: decryptedRemote,
        );

        switch (resolution.decision) {
          case ConflictDecision.applyRemote:
            if (decryptedRemote != null) {
              await _saveLocalEntry(session, decryptedRemote);
              await _syncStorage.removeQueueItem(decryptedRemote.id);
              appliedRemote++;
            }
            break;

          case ConflictDecision.deleteLocal:
            await _vaultStorage.deleteEntry(record.id);
            await _syncStorage.removeQueueItem(record.id);
            deletedLocal++;
            break;

          case ConflictDecision.keepLocal:
          case ConflictDecision.ignoreRemote:
            // Local state preserved; any pending local changes remain in queue
            break;
        }
      }

      // -------------------------------------------------------------
      // 2. PUSH PHASE
      // -------------------------------------------------------------
      final pendingItems = await _syncStorage.getPendingQueue(vaultId);
      final recordsToPush = <EncryptedSyncRecord>[];

      for (final item in pendingItems) {
        if (item.action == SyncAction.delete) {
          recordsToPush.add(
            EncryptedSyncRecord(
              id: item.entryId,
              vaultId: vaultId,
              version: metadata.remoteVersion + 1,
              deviceId: _localDeviceId,
              updatedAt: item.queuedAt,
              isDeleted: true,
              encryptedBlob: const <int>[],
            ),
          );
        } else {
          final entry = await _loadLocalEntry(session, item.entryId);
          if (entry != null) {
            final encryptedBlob = await _encryptEntryForSync(session, entry);
            recordsToPush.add(
              EncryptedSyncRecord(
                id: entry.id,
                vaultId: vaultId,
                version: metadata.remoteVersion + 1,
                deviceId: _localDeviceId,
                updatedAt: entry.updatedAt,
                isDeleted: false,
                encryptedBlob: encryptedBlob,
              ),
            );
          }
        }
      }

      String? newCursor = pullResponse.nextCursor;
      var newServerVersion = pullResponse.serverVersion;

      if (recordsToPush.isNotEmpty) {
        final pushResponse = await _transport.pushChanges(
          vaultId: vaultId,
          records: recordsToPush,
        );

        if (!pushResponse.success) {
          return SyncResult(
            state: SyncState.error,
            pulledCount: pulledCount,
            appliedRemoteCount: appliedRemote,
            deletedLocalCount: deletedLocal,
            errorMessage: pushResponse.errorMessage ?? 'Failed to push changes.',
          );
        }

        pushedCount = pushResponse.acceptedCount;
        for (final item in pendingItems) {
          await _syncStorage.removeQueueItem(item.entryId);
        }

        newCursor = pushResponse.newCursor ?? newCursor;
        newServerVersion = pushResponse.serverVersion;
      }

      // Update sync metadata
      final updatedMeta = metadata.copyWith(
        lastSyncedAt: DateTime.now().toUtc(),
        syncCursor: newCursor,
        remoteVersion: newServerVersion,
        pendingUploadCount: 0,
        syncState: SyncState.success,
        clearLastError: true,
      );
      await _syncStorage.saveMetadata(updatedMeta);

      return SyncResult(
        state: SyncState.success,
        pulledCount: pulledCount,
        appliedRemoteCount: appliedRemote,
        deletedLocalCount: deletedLocal,
        pushedCount: pushedCount,
      );
    } catch (e) {
      final errorMsg = e is AppException ? e.message : e.toString();
      final failedMeta = metadata.copyWith(
        syncState: SyncState.error,
        lastError: errorMsg,
      );
      await _syncStorage.saveMetadata(failedMeta);

      return SyncResult(
        state: SyncState.error,
        pulledCount: pulledCount,
        appliedRemoteCount: appliedRemote,
        deletedLocalCount: deletedLocal,
        pushedCount: pushedCount,
        errorMessage: errorMsg,
      );
    }
  }

  Future<VaultEntry?> _loadLocalEntry(VaultSession session, String id) async {
    final record = await _vaultStorage.getEntryById(id);
    if (record == null) return null;

    final payload = EncryptedPayload.fromBytes(record.encryptedBlob);
    final clearBytes = await _cipherService.decryptBytes(
      payload: payload,
      key: session.activeKey,
      associatedData: utf8.encode(session.entryAad(id)),
    );
    try {
      final jsonMap = jsonDecode(utf8.decode(clearBytes)) as Map<String, dynamic>;
      return VaultEntry.fromJson(jsonMap);
    } finally {
      SecureMemory.wipeBytes(clearBytes);
    }
  }

  Future<void> _saveLocalEntry(VaultSession session, VaultEntry entry) async {
    final jsonBytes = Uint8List.fromList(utf8.encode(jsonEncode(entry.toJson())));
    try {
      final payload = await _cipherService.encryptBytes(
        plaintext: jsonBytes,
        key: session.activeKey,
        algorithm: session.cipherAlgorithm,
        associatedData: utf8.encode(session.entryAad(entry.id)),
      );
      final record = EncryptedEntryRecord(
        id: entry.id,
        encryptedBlob: payload.toBytes(),
        createdAt: entry.createdAt,
        updatedAt: entry.updatedAt,
      );
      await _vaultStorage.upsertEntry(record);
    } finally {
      SecureMemory.wipeBytes(jsonBytes);
    }
  }

  Future<VaultEntry> _decryptSyncRecord(
    VaultSession session,
    EncryptedSyncRecord record,
  ) async {
    final payload = EncryptedPayload.fromBytes(record.encryptedBlob);
    final clearBytes = await _cipherService.decryptBytes(
      payload: payload,
      key: session.activeKey,
      associatedData: utf8.encode(
        EncryptedSyncRecord.syncAad(session.vaultId, record.id),
      ),
    );
    try {
      final jsonMap = jsonDecode(utf8.decode(clearBytes)) as Map<String, dynamic>;
      return VaultEntry.fromJson(jsonMap);
    } finally {
      SecureMemory.wipeBytes(clearBytes);
    }
  }

  Future<Uint8List> _encryptEntryForSync(
    VaultSession session,
    VaultEntry entry,
  ) async {
    final jsonBytes = Uint8List.fromList(utf8.encode(jsonEncode(entry.toJson())));
    try {
      final payload = await _cipherService.encryptBytes(
        plaintext: jsonBytes,
        key: session.activeKey,
        algorithm: session.cipherAlgorithm,
        associatedData: utf8.encode(
          EncryptedSyncRecord.syncAad(session.vaultId, entry.id),
        ),
      );
      return payload.toBytes();
    } finally {
      SecureMemory.wipeBytes(jsonBytes);
    }
  }
}
