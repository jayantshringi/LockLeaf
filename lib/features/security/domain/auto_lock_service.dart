import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:lockleaf/core/constants/security_constants.dart';
import 'package:lockleaf/core/errors/app_exception.dart';

/// Enforces automatic vault locking on idle inactivity or backgrounding.
class AutoLockService {
  final VoidCallback _onLock;
  Duration _timeout;
  bool _lockOnBackground;
  Timer? _idleTimer;
  bool _isRunning = false;

  /// Creates an [AutoLockService] invoking [onLock] when triggered.
  AutoLockService({
    required VoidCallback onLock,
    Duration? timeout,
    bool lockOnBackground = true,
  })  : _onLock = onLock,
        _timeout = timeout ??
            const Duration(
              seconds: SecurityConstants.defaultAutoLockTimeoutSeconds,
            ),
        _lockOnBackground = lockOnBackground {
    if (_timeout <= Duration.zero) {
      throw const ValidationException('Auto-lock timeout must be positive.');
    }
  }

  /// Active inactivity duration before auto-lock fires.
  Duration get timeout => _timeout;

  /// Whether moving the app to background immediately locks the vault.
  bool get lockOnBackground => _lockOnBackground;

  /// Whether the idle countdown timer is currently active.
  bool get isRunning => _isRunning;

  /// Starts or resets the inactivity timer (call when vault unlocks).
  void start() {
    _isRunning = true;
    _restartTimer();
  }

  /// Resets the inactivity countdown in response to user interaction.
  void recordActivity() {
    if (!_isRunning) {
      return;
    }
    _restartTimer();
  }

  /// Stops the inactivity timer (call when vault locks).
  void stop() {
    _isRunning = false;
    _idleTimer?.cancel();
    _idleTimer = null;
  }

  /// Updates the idle [newTimeout] and restarts the timer if active.
  void updateTimeout(Duration newTimeout) {
    if (newTimeout <= Duration.zero) {
      throw const ValidationException('Auto-lock timeout must be positive.');
    }
    _timeout = newTimeout;
    if (_isRunning) {
      _restartTimer();
    }
  }

  /// Enables or disables immediate locking when backgrounded.
  void setLockOnBackground(bool enabled) {
    _lockOnBackground = enabled;
  }

  /// Responds to OS lifecycle transitions, locking immediately if backgrounded.
  void handleLifecycleState(AppLifecycleState state) {
    if (!_isRunning || !_lockOnBackground) {
      return;
    }
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _triggerLock();
    }
  }

  void _restartTimer() {
    _idleTimer?.cancel();
    _idleTimer = Timer(_timeout, _triggerLock);
  }

  void _triggerLock() {
    stop();
    _onLock();
  }

  /// Releases timer resources.
  void dispose() {
    stop();
  }
}
