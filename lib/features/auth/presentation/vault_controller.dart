import 'package:flutter/material.dart';
import 'package:lockleaf/core/crypto/kdf_params.dart';
import 'package:lockleaf/core/errors/app_exception.dart';
import 'package:lockleaf/features/vault/domain/vault_service.dart';

/// Top-level authentication flow states driving app navigation.
enum AuthFlowStage {
  /// Checking local storage for an existing encrypted vault.
  loading,

  /// First-run experience when no vault exists on device.
  onboarding,

  /// Vault exists on disk and requires master password unlock.
  locked,

  /// Active unlocked vault session with decrypted entries in memory.
  unlocked,
}

/// Reactive application controller managing auth state, theme, and vault state.
class VaultController extends ChangeNotifier {
  final VaultService _vaultService;
  final KdfParams _kdfParams;

  AuthFlowStage _stage = AuthFlowStage.loading;
  ThemeMode _themeMode;
  bool _isBusy = false;
  String? _errorMessage;

  /// Creates a [VaultController] backed by [vaultService].
  VaultController({
    required VaultService vaultService,
    KdfParams kdfParams = const KdfParams.standard(),
    ThemeMode initialThemeMode = ThemeMode.dark,
  })  : _vaultService = vaultService,
        _kdfParams = kdfParams,
        _themeMode = initialThemeMode;

  /// Current authentication stage.
  AuthFlowStage get stage => _stage;

  /// Active app theme mode.
  ThemeMode get themeMode => _themeMode;

  /// Convenience getter indicating whether dark theme is active.
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  /// Whether an asynchronous KDF or storage operation is in progress.
  bool get isBusy => _isBusy;

  /// User-safe error message from the last failed operation, if any.
  String? get errorMessage => _errorMessage;

  /// Inspects local storage to determine onboarding vs lock screen launch.
  Future<void> initialize() async {
    _isBusy = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final initialized = await _vaultService.isVaultInitialized();
      if (!initialized) {
        _stage = AuthFlowStage.onboarding;
      } else {
        _stage = _vaultService.isUnlocked
            ? AuthFlowStage.unlocked
            : AuthFlowStage.locked;
      }
    } on AppException catch (error) {
      _errorMessage = error.message;
      _stage = AuthFlowStage.locked;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  /// Creates a new zero-knowledge vault protected by [masterPassword].
  Future<bool> createMasterPassword(String masterPassword) async {
    return _runBusyAction(() async {
      await _vaultService.createVault(
        masterPassword: masterPassword,
        kdfParams: _kdfParams,
      );
      _stage = AuthFlowStage.unlocked;
    });
  }

  /// Attempts to unlock the existing vault with [masterPassword].
  Future<bool> unlock(String masterPassword) async {
    return _runBusyAction(() async {
      await _vaultService.unlockVault(masterPassword);
      _stage = AuthFlowStage.unlocked;
    });
  }

  /// Immediately locks the vault and zeroes in-memory keys.
  void lock() {
    _vaultService.lockVault();
    _errorMessage = null;
    _stage = AuthFlowStage.locked;
    notifyListeners();
  }

  /// Toggles between dark and light theme modes.
  void toggleDarkMode() {
    _themeMode =
        _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
  }

  /// Explicitly updates [themeMode].
  void setThemeMode(ThemeMode mode) {
    if (_themeMode == mode) {
      return;
    }
    _themeMode = mode;
    notifyListeners();
  }

  /// Clears any displayed error banner.
  void clearError() {
    if (_errorMessage == null) {
      return;
    }
    _errorMessage = null;
    notifyListeners();
  }

  Future<bool> _runBusyAction(Future<void> Function() action) async {
    if (_isBusy) {
      return false;
    }
    _isBusy = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await action();
      return true;
    } on AppException catch (error) {
      _errorMessage = error.message;
      return false;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _vaultService.lockVault();
    super.dispose();
  }
}
