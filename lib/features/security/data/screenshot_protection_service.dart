import 'package:flutter/services.dart';

/// Abstraction for enabling/disabling OS-level screenshot and screen recording blocking.
abstract class ScreenshotProtectionService {
  /// Toggles screenshot and recent-apps preview protection on the host window.
  Future<void> setEnabled(bool enabled);
}

/// Platform channel implementation calling native window security APIs.
class PlatformScreenshotProtectionService
    implements ScreenshotProtectionService {
  /// MethodChannel shared with Android `MainActivity` and iOS `AppDelegate`.
  static const MethodChannel channel =
      MethodChannel('com.lockleaf.lockleaf/security');

  @override
  Future<void> setEnabled(bool enabled) async {
    try {
      await channel.invokeMethod<void>(
        'setScreenshotBlocked',
        <String, bool>{'blocked': enabled},
      );
    } on MissingPluginException {
      // Safe no-op in widget tests or unsupported desktop targets.
    } on PlatformException {
      // Ignore if host window is unavailable during background transition.
    }
  }
}
