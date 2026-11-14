import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockleaf/app.dart';
import 'package:lockleaf/core/crypto/kdf_params.dart';
import 'package:lockleaf/core/crypto/secure_random_service.dart';
import 'package:lockleaf/features/auth/presentation/vault_controller.dart';
import 'package:lockleaf/features/security/domain/biometric_vault_manager.dart';
import 'package:lockleaf/features/security/domain/secure_clipboard_service.dart';
import 'package:lockleaf/features/security/presentation/security_controller.dart';
import 'package:lockleaf/features/vault/domain/vault_service.dart';

import '../vault/in_memory_vault_storage.dart';
import 'security_test_doubles.dart';

void main() {
  late SecureRandomService randomService;

  String randomToken({int length = 18}) {
    final codes = List<int>.generate(
      length,
      (_) => 97 + randomService.nextInt(26),
    );
    return String.fromCharCodes(codes);
  }

  setUp(() {
    randomService = SecureRandomService();
  });

  testWidgets(
    'device security enables biometrics, shields inactive state, auto-locks on pause, and clears clipboard on lock',
    (WidgetTester tester) async {
      final vaultStorage = InMemoryVaultStorage();
      final keyStorage = InMemorySecureKeyStorage();
      final biometricAuth = FakeBiometricAuthService();
      final clipboardAdapter = InMemoryClipboardAdapter();
      final screenshotService = FakeScreenshotProtectionService();

      final vaultService = VaultService(
        storage: vaultStorage,
        randomService: randomService,
      );
      final vaultController = VaultController(
        vaultService: vaultService,
        kdfParams: KdfParams(memoryKiB: 256, iterations: 1, parallelism: 1),
      );
      final securityController = SecurityController(
        vaultController: vaultController,
        biometricManager: BiometricVaultManager(
          vaultService: vaultService,
          secureStorage: keyStorage,
          biometricAuth: biometricAuth,
          randomService: randomService,
        ),
        clipboard: SecureClipboardService(adapter: clipboardAdapter),
        screenshotProtection: screenshotService,
      );

      addTearDown(() {
        securityController.dispose();
        vaultController.dispose();
      });

      await vaultController.createMasterPassword(randomToken());
      final entrySecret = randomToken(length: 16);
      await vaultController.addEntry(
        title: 'Production Server',
        username: 'ops_admin',
        password: entrySecret,
      );
      await securityController.initialize();

      expect(screenshotService.latestEnabled, isTrue);

      await tester.pumpWidget(
        LockLeafApp(
          controller: vaultController,
          securityController: securityController,
        ),
      );
      await tester.pumpAndSettle();

      // 1. Open SecuritySettingsScreen and enroll biometrics
      await tester.tap(find.byKey(const Key('vault_security_settings_button')));
      await tester.pumpAndSettle();

      expect(find.text('Device Security'), findsOneWidget);
      await tester.tap(find.byKey(const Key('settings_biometric_switch')));
      await tester.pumpAndSettle();

      expect(securityController.biometricEnabled, isTrue);

      // Toggle screenshot blocking off and back on
      await tester.tap(
        find.byKey(const Key('settings_screenshot_block_switch')),
      );
      await tester.pumpAndSettle();
      expect(screenshotService.latestEnabled, isFalse);

      await tester.tap(
        find.byKey(const Key('settings_screenshot_block_switch')),
      );
      await tester.pumpAndSettle();
      expect(screenshotService.latestEnabled, isTrue);

      // Pop back to VaultListScreen
      await tester.pageBack();
      await tester.pumpAndSettle();

      // 2. Copy password from EntryDetailScreen via SecureClipboardService
      await tester.tap(find.text('Production Server'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('detail_copy_password_button')));
      await tester.pump();
      expect(clipboardAdapter.currentText, equals(entrySecret));

      // 3. App inactive shows privacy shield overlay
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(find.byKey(const Key('privacy_shield_overlay')), findsOneWidget);

      // 4. App paused triggers background auto-lock & wipes clipboard immediately
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(vaultController.stage, equals(AuthFlowStage.locked));
      expect(clipboardAdapter.currentText, isEmpty);

      // 5. Resuming hides privacy overlay and shows UnlockScreen with biometrics
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('privacy_shield_overlay')), findsNothing);
      expect(find.text('Vault Locked'), findsOneWidget);
      expect(find.byKey(const Key('unlock_biometric_button')), findsOneWidget);

      // 6. Unlocking with biometrics returns to unlocked vault
      await tester.tap(find.byKey(const Key('unlock_biometric_button')));
      await tester.pumpAndSettle();

      expect(vaultController.stage, equals(AuthFlowStage.unlocked));
      expect(find.text('LockLeaf Vault'), findsOneWidget);
    },
  );
}
