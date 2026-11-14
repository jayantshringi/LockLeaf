import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:lockleaf/core/constants/security_constants.dart';
import 'package:lockleaf/core/errors/app_exception.dart';
import 'package:lockleaf/features/auth/presentation/vault_controller.dart';
import 'package:lockleaf/features/security/data/screenshot_protection_service.dart';
import 'package:lockleaf/features/security/domain/auto_lock_service.dart';
import 'package:lockleaf/features/security/domain/biometric_vault_manager.dart';
import 'package:lockleaf/features/security/domain/secure_clipboard_service.dart';

/// Coordinates device-level security policies: biometrics, Keystore/Keychain,
/// auto-lock timer, 30s clipboard clearing, and screenshot blocking.
class SecurityController extends ChangeNotifier {
  final VaultController _vaultController;
  final BiometricVaultManager _biometricManager;
  final SecureClipboardService _clipboard;
  final ScreenshotProtectionService _screenshotProtection;
  late final AutoLockService _autoLock;

  bool _biometricSupported = false;
  bool _biometricEnabled = false;
  bool _screenshotBlockingEnabled = true;
  bool _isPrivacyOverlayVisible = false;
  bool _isBiometricPromptActive = false;
  String? _securityError;
  AuthFlowStage? _lastObservedStage;

  /// Creates a [SecurityController] attached to [vaultController].
  SecurityController({
    required VaultController vaultController,
    required BiometricVaultManager biometricManager,
    SecureClipboardService? clipboard,
    ScreenshotProtectionService? screenshotProtection,
    AutoLockService? autoLock,
  })  : _vaultController = vaultController,
        _biometricManager = biometricManager,
        _clipboard = clipboard ?? SecureClipboardService(),
        _screenshotProtection =
            screenshotProtection ?? PlatformScreenshotProtectionService() {
    _autoLock = autoLock ?? AutoLockService(onLock: _vaultController.lock);
    _lastObservedStage = _vaultController.stage;
    _vaultController.addListener(_onVaultStateChanged);
    if (_vaultController.stage == AuthFlowStage.unlocked) {
      _autoLock.start();
    }
  }

  /// Whether hardware biometrics with enrolled credentials are available.
  bool get biometricSupported => _biometricSupported;

  /// Whether biometric quick unlock is currently enrolled for this vault.
  bool get biometricEnabled => _biometricEnabled;

  /// Current idle auto-lock timeout.
  Duration get autoLockTimeout => _autoLock.timeout;

  /// Whether the vault locks immediately when backgrounded.
  bool get lockOnBackground => _autoLock.lockOnBackground;

  /// Whether Android `FLAG_SECURE` and app-switcher privacy overlay are active.
  bool get screenshotBlockingEnabled => _screenshotBlockingEnabled;

  /// Whether the privacy overlay should mask the app right now.
  bool get isPrivacyOverlayVisible => _isPrivacyOverlayVisible;

  /// Last device-security error message, if any.
  String? get securityError => _securityError;

  /// Probes biometric capabilities and applies initial screenshot protection.
  Future<void> initialize() async {
    _biometricSupported = await _biometricManager.isBiometricsSupported();
    _biometricEnabled = await _biometricManager.isBiometricUnlockEnabled();
    await _screenshotProtection.setEnabled(_screenshotBlockingEnabled);
    notifyListeners();
  }

  /// Refreshes biometric enrollment status (e.g., after creating a new vault).
  Future<void> refreshBiometricStatus() async {
    _biometricSupported = await _biometricManager.isBiometricsSupported();
    _biometricEnabled = await _biometricManager.isBiometricUnlockEnabled();
    notifyListeners();
  }

  /// Enables or disables biometric quick unlock using Keystore/Keychain wrapping.
  Future<bool> toggleBiometricUnlock(bool enable) async {
    _securityError = null;
    _isBiometricPromptActive = true;
    notifyListeners();

    try {
      if (enable) {
        await _biometricManager.enableBiometricUnlock();
      } else {
        await _biometricManager.disableBiometricUnlock();
      }
      _biometricEnabled = await _biometricManager.isBiometricUnlockEnabled();
      return true;
    } on AppException catch (error) {
      _securityError = error.message;
      return false;
    } finally {
      _isBiometricPromptActive = false;
      notifyListeners();
    }
  }

  /// Prompts device biometrics and unlocks the vault via the sealed DEK.
  Future<bool> unlockWithBiometrics() async {
    _securityError = null;
    _isBiometricPromptActive = true;
    notifyListeners();

    try {
      final authenticated = await _biometricManager.unlockWithBiometrics();
      if (!authenticated) {
        return false;
      }
      return await _vaultController.completeExternalUnlock();
    } on AppException catch (error) {
      _vaultController.reportError(error.message);
      _securityError = error.message;
      return false;
    } finally {
      _isBiometricPromptActive = false;
      notifyListeners();
    }
  }

  /// Copies [secret] and schedules clipboard clearing after 30 seconds.
  Future<void> copySecret(
    String secret, {
    Duration clearAfter = const Duration(
      seconds: SecurityConstants.clipboardClearDelaySeconds,
    ),
  }) async {
    recordUserActivity();
    await _clipboard.copySecret(secret, clearAfter: clearAfter);
  }

  /// Immediately clears any pending copied secret from clipboard.
  Future<void> clearClipboardNow() => _clipboard.clearNow();

  /// Updates the idle auto-lock timeout duration.
  void updateAutoLockTimeout(Duration timeout) {
    _autoLock.updateTimeout(timeout);
    notifyListeners();
  }

  /// Enables or disables locking immediately on app backgrounding.
  void setLockOnBackground(bool enabled) {
    _autoLock.setLockOnBackground(enabled);
    notifyListeners();
  }

  /// Toggles screenshot and app-switcher protection (`FLAG_SECURE` / overlay).
  Future<void> setScreenshotBlocking(bool enabled) async {
    _screenshotBlockingEnabled = enabled;
    if (!enabled) {
      _isPrivacyOverlayVisible = false;
    }
    await _screenshotProtection.setEnabled(enabled);
    notifyListeners();
  }

  /// Resets the inactivity countdown in response to user interaction.
  void recordUserActivity() {
    _autoLock.recordActivity();
  }

  /// Updates privacy shield visibility and triggers background auto-lock.
  void handleLifecycleState(AppLifecycleState state) {
    if (_isBiometricPromptActive) {
      return;
    }

    final shouldShield = _screenshotBlockingEnabled &&
        (state == AppLifecycleState.inactive ||
            state == AppLifecycleState.paused ||
            state == AppLifecycleState.hidden);

    if (state == AppLifecycleState.resumed && _isPrivacyOverlayVisible) {
      _isPrivacyOverlayVisible = false;
      notifyListeners();
    } else if (shouldShield && !_isPrivacyOverlayVisible) {
      _isPrivacyOverlayVisible = true;
      notifyListeners();
    }

    _autoLock.handleLifecycleState(state);
  }

  void _onVaultStateChanged() {
    final stage = _vaultController.stage;
    if (stage == _lastObservedStage) {
      return;
    }
    _lastObservedStage = stage;

    if (stage == AuthFlowStage.unlocked) {
      _autoLock.start();
    } else {
      _autoLock.stop();
      unawaited(_clipboard.clearNow());
    }
  }

  @override
  void dispose() {
    _vaultController.removeListener(_onVaultStateChanged);
    _autoLock.dispose();
    _clipboard.dispose();
    super.dispose();
  }
}
