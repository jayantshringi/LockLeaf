import 'package:flutter/material.dart';
import 'package:lockleaf/core/errors/app_exception.dart';
import 'package:lockleaf/features/auth/presentation/vault_controller.dart';
import 'package:lockleaf/features/sync/data/cloud_sync_transport.dart';
import 'package:lockleaf/features/sync/data/sync_storage_repository.dart';
import 'package:lockleaf/features/sync/domain/sync_engine.dart';
import 'package:lockleaf/features/sync/domain/sync_status.dart';
import 'package:lockleaf/features/vault/domain/vault_service.dart';

/// Manages reactive synchronization state and coordinates background/manual sync.
class SyncController extends ChangeNotifier {
  final VaultService _vaultService;
  final VaultController _vaultController;
  final SyncStorageRepository _syncStorage;
  SyncEngine _syncEngine;

  SyncState _state = SyncState.idle;
  DateTime? _lastSyncedAt;
  int _pendingCount = 0;
  String? _errorMessage;

  SyncController({
    required VaultService vaultService,
    required VaultController vaultController,
    required SyncStorageRepository syncStorage,
    required SyncEngine syncEngine,
  })  : _vaultService = vaultService,
        _vaultController = vaultController,
        _syncStorage = syncStorage,
        _syncEngine = syncEngine;

  SyncState get state => _state;
  DateTime? get lastSyncedAt => _lastSyncedAt;
  int get pendingCount => _pendingCount;
  String? get errorMessage => _errorMessage;
  bool get isSyncing => _state == SyncState.syncing;
  String get deviceId => _syncEngine.localDeviceId;
  CloudSyncTransport get transport => _syncEngine.transport;

  /// Loads initial sync metadata and pending counts from local storage.
  Future<void> initialize() async {
    final vaultId = _vaultService.activeVaultId;
    if (vaultId == null) return;

    try {
      final meta = await _syncStorage.getMetadata(vaultId);
      if (meta != null) {
        _lastSyncedAt = meta.lastSyncedAt;
        _pendingCount = meta.pendingUploadCount;
      }
      notifyListeners();
    } catch (_) {
      // Ignored during background load
    }
  }

  /// Triggers an immediate bi-directional synchronization cycle.
  Future<SyncResult> triggerSync() async {
    final session = _vaultService.activeSession;
    if (session == null || !session.isActive) {
      _state = SyncState.error;
      _errorMessage = 'Vault is locked. Unlock before syncing.';
      notifyListeners();
      return const SyncResult(
        state: SyncState.error,
        errorMessage: 'Vault is locked.',
      );
    }

    _state = SyncState.syncing;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _syncEngine.synchronize(session: session);
      _state = result.state;
      _errorMessage = result.errorMessage;

      if (result.isSuccess) {
        _lastSyncedAt = DateTime.now().toUtc();
        _pendingCount = 0;
        // If remote changes were pulled, refresh entries in the UI
        if (result.appliedRemoteCount > 0 || result.deletedLocalCount > 0) {
          await _vaultController.refreshEntries();
        }
      } else {
        _pendingCount = await _syncStorage.getPendingQueueCount(session.vaultId);
      }

      notifyListeners();
      return result;
    } on AppException catch (e) {
      _state = SyncState.error;
      _errorMessage = e.message;
      notifyListeners();
      return SyncResult(state: SyncState.error, errorMessage: e.message);
    } catch (e) {
      _state = SyncState.error;
      _errorMessage = e.toString();
      notifyListeners();
      return SyncResult(state: SyncState.error, errorMessage: e.toString());
    }
  }

  /// Updates the active sync engine instance.
  void setSyncEngine(SyncEngine engine) {
    _syncEngine = engine;
    notifyListeners();
  }
}
