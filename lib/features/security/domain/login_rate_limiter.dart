import 'dart:math' as math;

import 'package:lockleaf/core/constants/security_constants.dart';
import 'package:lockleaf/core/errors/app_exception.dart';

/// Tracks failed master password attempts and enforces exponential backoff cooldowns
/// to prevent offline brute-force and resource-exhaustion attacks.
class LoginRateLimiter {
  final int maxFailedAttempts;
  final int initialCooldownSeconds;
  final int maxCooldownSeconds;
  final DateTime Function() _clock;

  int _failedAttempts = 0;
  DateTime? _lockoutUntil;
  int _consecutiveLockouts = 0;

  /// Creates a [LoginRateLimiter] with configurable thresholds.
  LoginRateLimiter({
    this.maxFailedAttempts = SecurityConstants.maxFailedLoginAttempts,
    this.initialCooldownSeconds = SecurityConstants.failedAttemptLockoutSeconds,
    this.maxCooldownSeconds = SecurityConstants.maxLockoutSeconds,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  /// Current consecutive failed login attempts before successful authentication.
  int get failedAttempts => _failedAttempts;

  /// Total number of times the rate limiter entered lockout status.
  int get consecutiveLockouts => _consecutiveLockouts;

  /// Whether the user is actively locked out from attempting authentication.
  bool get isLockedOut {
    if (_lockoutUntil == null) {
      return false;
    }
    return _clock().toUtc().isBefore(_lockoutUntil!);
  }

  /// Remaining cooldown duration until another authentication attempt is permitted.
  Duration get remainingCooldown {
    if (!isLockedOut) {
      return Duration.zero;
    }
    final remaining = _lockoutUntil!.difference(_clock().toUtc());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// Remaining cooldown in whole seconds.
  int get remainingCooldownSeconds {
    final secs = remainingCooldown.inSeconds;
    // If there is any fractional millisecond remaining, round up so timer doesn't display 0 prematurely
    if (secs == 0 && remainingCooldown.inMilliseconds > 0) {
      return 1;
    }
    return secs;
  }

  /// Verifies whether an attempt is allowed; throws [RateLimitException] if locked out.
  void checkLockout() {
    if (isLockedOut) {
      final secs = remainingCooldownSeconds;
      throw RateLimitException(
        'Too many failed attempts. Try again in ${secs}s.',
        remainingCooldown: remainingCooldown,
      );
    }
  }

  /// Records the result of an authentication attempt.
  void recordAttempt({required bool success}) {
    if (success) {
      reset();
      return;
    }

    _failedAttempts++;
    if (_failedAttempts >= maxFailedAttempts) {
      _consecutiveLockouts++;
      final factor = math.pow(2, _consecutiveLockouts - 1).toInt();
      final penaltySeconds = math.min(
        initialCooldownSeconds * factor,
        maxCooldownSeconds,
      );
      _lockoutUntil = _clock().toUtc().add(Duration(seconds: penaltySeconds));
    }
  }

  /// Resets all failure counters and active lockouts upon successful authentication.
  void reset() {
    _failedAttempts = 0;
    _lockoutUntil = null;
    _consecutiveLockouts = 0;
  }
}
