import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockleaf/core/crypto/kdf_params.dart';
import 'package:lockleaf/core/crypto/secure_random_service.dart';
import 'package:lockleaf/features/auth/presentation/vault_controller.dart';
import 'package:lockleaf/features/security/domain/biometric_vault_manager.dart';
import 'package:lockleaf/features/security/domain/secure_clipboard_service.dart';
import 'package:lockleaf/features/security/presentation/security_controller.dart';
import 'package:lockleaf/features/vault/domain/vault_entry.dart';
import 'package:lockleaf/features/vault/domain/vault_service.dart';
import 'package:lockleaf/features/vault/presentation/screens/entry_detail_screen.dart';
import 'package:lockleaf/features/vault/presentation/widgets/vault_entry_tile.dart';

import '../security/security_test_doubles.dart';
import 'in_memory_vault_storage.dart';

void main() {
  testWidgets(
    'EntryDetailScreen renders TOTP card and countdown when entry has totpSecret',
    (WidgetTester tester) async {
      final fastParams = KdfParams(
        memoryKiB: 256,
        iterations: 1,
        parallelism: 1,
      );
      final randomService = SecureRandomService();
      final vaultService = VaultService(
        storage: InMemoryVaultStorage(),
        randomService: randomService,
      );
      final controller = VaultController(
        vaultService: vaultService,
        kdfParams: fastParams,
      );
      final clipboardAdapter = InMemoryClipboardAdapter();
      final securityController = SecurityController(
        vaultController: controller,
        biometricManager: BiometricVaultManager(
          vaultService: vaultService,
          secureStorage: FakeSecureKeyStorage(),
          biometricAuth: FakeBiometricAuthService(),
          randomService: randomService,
        ),
        clipboard: SecureClipboardService(adapter: clipboardAdapter),
        screenshotProtection: FakeScreenshotProtectionService(),
      );

      addTearDown(() {
        securityController.dispose();
        controller.dispose();
      });

      final now = DateTime.utc(2026, 11, 16, 12, 0, 0);
      final entry = VaultEntry(
        id: 'entry-totp-1',
        title: 'GitHub',
        username: 'alice',
        password: 'password123',
        totpSecret: 'JBSWY3DPEHPK3PXP',
        createdAt: now,
        updatedAt: now,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: EntryDetailScreen(
            controller: controller,
            entry: entry,
            securityController: securityController,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify TOTP card and elements are displayed
      expect(
        find.byKey(const Key('detail_totp_card_entry-totp-1')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('detail_totp_code')), findsOneWidget);
      expect(find.byKey(const Key('detail_totp_countdown')), findsOneWidget);
      expect(find.byKey(const Key('detail_copy_totp_button')), findsOneWidget);

      // Tap copy 2FA button and verify clipboard was set with 6-digit code
      await tester.tap(find.byKey(const Key('detail_copy_totp_button')));
      await tester.pump();
      expect(clipboardAdapter.currentText, isNotNull);
      expect(clipboardAdapter.currentText!.length, equals(6));
    },
  );

  testWidgets(
    'VaultEntryTile renders 2FA badge if entry.hasTotp is true',
    (WidgetTester tester) async {
      final now = DateTime.utc(2026, 11, 16, 12, 0, 0);
      final entryWithTotp = VaultEntry(
        id: 'entry-badge-1',
        title: 'GitLab',
        username: 'bob',
        password: 'password123',
        totpSecret: 'JBSWY3DPEHPK3PXP',
        createdAt: now,
        updatedAt: now,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VaultEntryTile(
              entry: entryWithTotp,
              onTap: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('vault_entry_2fa_badge_entry-badge-1')),
        findsOneWidget,
      );
      expect(find.text('2FA'), findsOneWidget);
    },
  );
}
