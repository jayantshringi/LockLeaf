import 'dart:async';

import 'package:flutter/services.dart';
import 'package:lockleaf/core/constants/security_constants.dart';

/// Platform clipboard abstraction enabling deterministic unit testing.
abstract class ClipboardAdapter {
  /// Writes plain [text] to the system clipboard.
  Future<void> setText(String text);

  /// Reads plain text from the system clipboard, or null if unavailable.
  Future<String?> getText();

  /// Overwrites/clears the system clipboard.
  Future<void> clear();
}

/// Default [ClipboardAdapter] delegating to Flutter's [Clipboard].
class FlutterClipboardAdapter implements ClipboardAdapter {
  @override
  Future<void> setText(String text) =>
      Clipboard.setData(ClipboardData(text: text));

  @override
  Future<String?> getText() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    return data?.text;
  }

  @override
  Future<void> clear() => Clipboard.setData(const ClipboardData(text: ''));
}

/// Copies sensitive values to the clipboard and clears them after 30 seconds.
class SecureClipboardService {
  final ClipboardAdapter _adapter;
  Timer? _clearTimer;
  String? _lastCopiedSecret;

  /// Creates a [SecureClipboardService].
  SecureClipboardService({ClipboardAdapter? adapter})
    : _adapter = adapter ?? FlutterClipboardAdapter();

  /// Whether a secret auto-clear timer is currently scheduled.
  bool get hasPendingClear => _clearTimer?.isActive ?? false;

  /// Copies [secret] and schedules automatic clearing after [clearAfter] (30s default).
  Future<void> copySecret(
    String secret, {
    Duration clearAfter = const Duration(
      seconds: SecurityConstants.clipboardClearDelaySeconds,
    ),
  }) async {
    _clearTimer?.cancel();
    await _adapter.setText(secret);
    _lastCopiedSecret = secret;

    _clearTimer = Timer(clearAfter, () {
      unawaited(_clearIfStillSecret(secret));
    });
  }

  /// Immediately clears any copied secret from the clipboard and cancels timers.
  Future<void> clearNow() async {
    _clearTimer?.cancel();
    _clearTimer = null;
    final pending = _lastCopiedSecret;
    _lastCopiedSecret = null;
    if (pending != null) {
      await _clearIfStillSecret(pending);
    }
  }

  Future<void> _clearIfStillSecret(String secret) async {
    _clearTimer = null;
    if (_lastCopiedSecret == secret) {
      _lastCopiedSecret = null;
    }
    try {
      final current = await _adapter.getText();
      // Clear if unchanged or if OS denies background clipboard inspection.
      if (current == null || current == secret) {
        await _adapter.clear();
      }
    } on PlatformException {
      await _adapter.clear();
    }
  }

  /// Cancels any pending clipboard timer.
  void dispose() {
    _clearTimer?.cancel();
    _clearTimer = null;
    _lastCopiedSecret = null;
  }
}
