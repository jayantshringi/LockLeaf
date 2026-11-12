import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockleaf/core/errors/app_exception.dart';
import 'package:lockleaf/features/security/domain/auto_lock_service.dart';

void main() {
  group('AutoLockService', () {
    test('rejects non-positive timeout durations', () {
      expect(
        () => AutoLockService(
          onLock: () {},
          timeout: Duration.zero,
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('triggers onLock after idle timeout expires', () async {
      var lockCount = 0;
      final service = AutoLockService(
        onLock: () => lockCount++,
        timeout: const Duration(milliseconds: 40),
      );
      addTearDown(service.dispose);

      service.start();
      expect(service.isRunning, isTrue);

      await Future<void>.delayed(const Duration(milliseconds: 80));

      expect(lockCount, equals(1));
      expect(service.isRunning, isFalse);
    });

    test('recordActivity resets idle timer countdown', () async {
      var lockCount = 0;
      final service = AutoLockService(
        onLock: () => lockCount++,
        timeout: const Duration(milliseconds: 70),
      );
      addTearDown(service.dispose);

      service.start();
      await Future<void>.delayed(const Duration(milliseconds: 40));
      service.recordActivity();
      await Future<void>.delayed(const Duration(milliseconds: 40));

      // 80ms elapsed total, but only 40ms since last activity.
      expect(lockCount, equals(0));

      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(lockCount, equals(1));
    });

    test('locks immediately on background lifecycle when enabled', () {
      var lockCount = 0;
      final service = AutoLockService(
        onLock: () => lockCount++,
        timeout: const Duration(minutes: 5),
        lockOnBackground: true,
      );
      addTearDown(service.dispose);

      service.start();
      service.handleLifecycleState(AppLifecycleState.paused);

      expect(lockCount, equals(1));
      expect(service.isRunning, isFalse);

      service.setLockOnBackground(false);
      service.start();
      service.handleLifecycleState(AppLifecycleState.paused);

      expect(lockCount, equals(1));
      expect(service.isRunning, isTrue);
    });

    test('stop cancels pending timer', () async {
      var lockCount = 0;
      final service = AutoLockService(
        onLock: () => lockCount++,
        timeout: const Duration(milliseconds: 40),
      );
      addTearDown(service.dispose);

      service.start();
      service.stop();
      await Future<void>.delayed(const Duration(milliseconds: 80));

      expect(lockCount, equals(0));
    });
  });
}
