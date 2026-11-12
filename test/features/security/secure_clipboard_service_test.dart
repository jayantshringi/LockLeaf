import 'package:flutter_test/flutter_test.dart';
import 'package:lockleaf/core/constants/security_constants.dart';
import 'package:lockleaf/core/crypto/secure_random_service.dart';
import 'package:lockleaf/features/security/domain/secure_clipboard_service.dart';

import 'security_test_doubles.dart';

void main() {
  late SecureRandomService randomService;
  late InMemoryClipboardAdapter adapter;
  late SecureClipboardService clipboardService;

  String randomToken({int length = 16}) {
    final codes = List<int>.generate(
      length,
      (_) => 97 + randomService.nextInt(26),
    );
    return String.fromCharCodes(codes);
  }

  setUp(() {
    randomService = SecureRandomService();
    adapter = InMemoryClipboardAdapter();
    clipboardService = SecureClipboardService(adapter: adapter);
  });

  tearDown(() {
    clipboardService.dispose();
  });

  group('SecureClipboardService', () {
    test('defaults auto-clear policy to 30 seconds', () {
      expect(SecurityConstants.clipboardClearDelaySeconds, equals(30));
    });

    test('copies secret and clears clipboard automatically after delay',
        () async {
      final secret = randomToken();

      await clipboardService.copySecret(
        secret,
        clearAfter: const Duration(milliseconds: 40),
      );

      expect(adapter.currentText, equals(secret));
      expect(clipboardService.hasPendingClear, isTrue);

      await Future<void>.delayed(const Duration(milliseconds: 80));

      expect(adapter.currentText, isEmpty);
      expect(adapter.clearCount, equals(1));
      expect(clipboardService.hasPendingClear, isFalse);
    });

    test('does not wipe newer unrelated clipboard text', () async {
      final secret = randomToken();

      await clipboardService.copySecret(
        secret,
        clearAfter: const Duration(milliseconds: 40),
      );
      await adapter.setText('non_secret_user_text');

      await Future<void>.delayed(const Duration(milliseconds: 80));

      expect(adapter.currentText, equals('non_secret_user_text'));
      expect(adapter.clearCount, equals(0));
    });

    test('clearNow immediately wipes copied secret', () async {
      final secret = randomToken();

      await clipboardService.copySecret(
        secret,
        clearAfter: const Duration(seconds: 30),
      );
      expect(adapter.currentText, equals(secret));

      await clipboardService.clearNow();

      expect(adapter.currentText, isEmpty);
      expect(clipboardService.hasPendingClear, isFalse);
    });

    test('clears clipboard when OS denies reading current clipboard text',
        () async {
      final secret = randomToken();

      await clipboardService.copySecret(
        secret,
        clearAfter: const Duration(milliseconds: 40),
      );
      adapter.currentText = null;

      await Future<void>.delayed(const Duration(milliseconds: 80));

      expect(adapter.clearCount, equals(1));
    });
  });
}
