import 'package:flutter_test/flutter_test.dart';
import 'package:lockleaf/core/errors/app_exception.dart';
import 'package:lockleaf/features/security/domain/login_rate_limiter.dart';

void main() {
  group('LoginRateLimiter', () {
    late DateTime simulatedTime;
    late LoginRateLimiter rateLimiter;

    setUp(() {
      simulatedTime = DateTime.utc(2026, 11, 16, 10, 0, 0);
      rateLimiter = LoginRateLimiter(
        maxFailedAttempts: 5,
        initialCooldownSeconds: 60,
        maxCooldownSeconds: 900,
        clock: () => simulatedTime,
      );
    });

    test('initializes with zero failed attempts and unlocked state', () {
      expect(rateLimiter.failedAttempts, equals(0));
      expect(rateLimiter.isLockedOut, isFalse);
      expect(rateLimiter.remainingCooldown, equals(Duration.zero));
      expect(rateLimiter.remainingCooldownSeconds, equals(0));
      expect(() => rateLimiter.checkLockout(), returnsNormally);
    });

    test('tracks failed attempts below threshold without locking out', () {
      for (var i = 1; i <= 4; i++) {
        rateLimiter.recordAttempt(success: false);
        expect(rateLimiter.failedAttempts, equals(i));
        expect(rateLimiter.isLockedOut, isFalse);
        expect(rateLimiter.remainingCooldownSeconds, equals(0));
        expect(() => rateLimiter.checkLockout(), returnsNormally);
      }
    });

    test('triggers lockout on reaching max failed attempts threshold', () {
      for (var i = 1; i <= 5; i++) {
        rateLimiter.recordAttempt(success: false);
      }

      expect(rateLimiter.failedAttempts, equals(5));
      expect(rateLimiter.isLockedOut, isTrue);
      expect(rateLimiter.consecutiveLockouts, equals(1));
      expect(rateLimiter.remainingCooldownSeconds, equals(60));

      expect(
        () => rateLimiter.checkLockout(),
        throwsA(
          isA<RateLimitException>().having(
            (e) => e.remainingCooldown.inSeconds,
            'remainingCooldown',
            equals(60),
          ),
        ),
      );
    });

    test('expires lockout after cooldown period elapses', () {
      for (var i = 1; i <= 5; i++) {
        rateLimiter.recordAttempt(success: false);
      }
      expect(rateLimiter.isLockedOut, isTrue);

      // Advance clock by 30 seconds
      simulatedTime = simulatedTime.add(const Duration(seconds: 30));
      expect(rateLimiter.isLockedOut, isTrue);
      expect(rateLimiter.remainingCooldownSeconds, equals(30));

      // Advance clock past 60 seconds
      simulatedTime = simulatedTime.add(const Duration(seconds: 31));
      expect(rateLimiter.isLockedOut, isFalse);
      expect(rateLimiter.remainingCooldownSeconds, equals(0));
      expect(() => rateLimiter.checkLockout(), returnsNormally);
    });

    test('applies exponential backoff on consecutive lockouts', () {
      // First lockout (60s)
      for (var i = 1; i <= 5; i++) {
        rateLimiter.recordAttempt(success: false);
      }
      expect(rateLimiter.consecutiveLockouts, equals(1));
      expect(rateLimiter.remainingCooldownSeconds, equals(60));

      // Wait out first cooldown
      simulatedTime = simulatedTime.add(const Duration(seconds: 61));
      expect(rateLimiter.isLockedOut, isFalse);

      // Immediate subsequent failure triggers 2x cooldown (120s)
      rateLimiter.recordAttempt(success: false);
      expect(rateLimiter.consecutiveLockouts, equals(2));
      expect(rateLimiter.remainingCooldownSeconds, equals(120));

      // Wait out second cooldown
      simulatedTime = simulatedTime.add(const Duration(seconds: 121));
      expect(rateLimiter.isLockedOut, isFalse);

      // Next failure triggers 4x cooldown (240s)
      rateLimiter.recordAttempt(success: false);
      expect(rateLimiter.consecutiveLockouts, equals(3));
      expect(rateLimiter.remainingCooldownSeconds, equals(240));
    });

    test('successful login resets failure counter and lockouts', () {
      for (var i = 1; i <= 4; i++) {
        rateLimiter.recordAttempt(success: false);
      }
      expect(rateLimiter.failedAttempts, equals(4));

      rateLimiter.recordAttempt(success: true);
      expect(rateLimiter.failedAttempts, equals(0));
      expect(rateLimiter.isLockedOut, isFalse);
      expect(rateLimiter.consecutiveLockouts, equals(0));
    });
  });
}
