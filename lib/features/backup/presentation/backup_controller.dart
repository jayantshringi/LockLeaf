import 'package:flutter/material.dart';
import 'package:lockleaf/core/crypto/kdf_params.dart';
import 'package:lockleaf/core/errors/app_exception.dart';
import 'package:lockleaf/features/auth/presentation/vault_controller.dart';
import 'package:lockleaf/features/backup/domain/backup_service.dart';
import 'package:lockleaf/features/backup/domain/encrypted_backup_payload.dart';
import 'package:lockleaf/features/vault/domain/vault_service.dart';

/// Manages backup export, file inspection, and authenticated vault restoration workflows.
class BackupController extends ChangeNotifier {
  final BackupService _backupService;
  final VaultService _vaultService;
  final VaultController _vaultController;
  final KdfParams _kdfParams;

  bool _isBusy = false;
  String? _errorMessage;
  String? _statusMessage;
  String? _exportedBackupJson;
  EncryptedBackupHeader? _inspectedHeader;
  int? _lastRestoredCount;

  BackupController({
    BackupService? backupService,
    required VaultService vaultService,
    required VaultController vaultController,
    KdfParams kdfParams = const KdfParams.standard(),
  }) : _backupService = backupService ?? BackupService(),
       _vaultService = vaultService,
       _vaultController = vaultController,
       _kdfParams = kdfParams;

  bool get isBusy => _isBusy;
  String? get errorMessage => _errorMessage;
  String? get statusMessage => _statusMessage;
  String? get exportedBackupJson => _exportedBackupJson;
  EncryptedBackupHeader? get inspectedHeader => _inspectedHeader;
  int? get lastRestoredCount => _lastRestoredCount;

  /// Exports an authenticated, encrypted `.llbak` JSON backup.
  Future<bool> exportBackup({
    required String backupPassword,
    String? notes,
  }) async {
    _setBusy(true);
    _clearMessages();
    try {
      final jsonOutput = await _backupService.exportEncryptedBackup(
        vaultService: _vaultService,
        backupPassword: backupPassword,
        notes: notes,
        kdfParams: _kdfParams,
      );
      _exportedBackupJson = jsonOutput;
      _statusMessage = 'Encrypted backup created successfully.';
      return true;
    } on AppException catch (e) {
      _errorMessage = e.message;
      return false;
    } finally {
      _setBusy(false);
    }
  }

  /// Inspects raw backup JSON without requiring the backup password.
  bool inspectBackupJson(String rawJson) {
    _clearMessages();
    try {
      _inspectedHeader = _backupService.inspectBackup(rawJson);
      notifyListeners();
      return true;
    } on AppException catch (e) {
      _errorMessage = e.message;
      _inspectedHeader = null;
      notifyListeners();
      return false;
    }
  }

  /// Restores entries from [backupJson] into the current unlocked vault.
  Future<bool> restoreBackup({
    required String backupJson,
    required String backupPassword,
    bool overwriteExisting = false,
  }) async {
    _setBusy(true);
    _clearMessages();
    try {
      final restored = await _backupService.restoreBackup(
        backupJson: backupJson,
        backupPassword: backupPassword,
        vaultService: _vaultService,
        overwriteExisting: overwriteExisting,
      );
      _lastRestoredCount = restored.length;
      await _vaultController.refreshEntries();
      _statusMessage = 'Restored ${restored.length} entries.';
      return true;
    } on AppException catch (e) {
      _errorMessage = e.message;
      return false;
    } finally {
      _setBusy(false);
    }
  }

  /// Restores a backup onto a fresh device with no existing vault.
  Future<bool> restoreToNewVault({
    required String backupJson,
    required String backupPassword,
    required String newMasterPassword,
  }) async {
    _setBusy(true);
    _clearMessages();
    try {
      final restored = await _backupService.restoreToNewVault(
        backupJson: backupJson,
        backupPassword: backupPassword,
        newMasterPassword: newMasterPassword,
        vaultService: _vaultService,
      );
      _lastRestoredCount = restored.length;
      await _vaultController.completeExternalUnlock();
      _statusMessage = 'Vault restored with ${restored.length} entries.';
      return true;
    } on AppException catch (e) {
      _errorMessage = e.message;
      return false;
    } finally {
      _setBusy(false);
    }
  }

  /// Clears temporary exported backup and inspection artifacts.
  void clearState() {
    _clearMessages();
    _exportedBackupJson = null;
    _inspectedHeader = null;
    _lastRestoredCount = null;
    notifyListeners();
  }

  void _setBusy(bool value) {
    _isBusy = value;
    notifyListeners();
  }

  void _clearMessages() {
    _errorMessage = null;
    _statusMessage = null;
  }
}
