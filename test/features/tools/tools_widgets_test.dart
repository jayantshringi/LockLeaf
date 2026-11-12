import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockleaf/app.dart';
import 'package:lockleaf/core/crypto/kdf_params.dart';
import 'package:lockleaf/core/crypto/secure_random_service.dart';
import 'package:lockleaf/features/auth/presentation/vault_controller.dart';
import 'package:lockleaf/features/security/domain/biometric_vault_manager.dart';
import 'package:lockleaf/features/security/domain/secure_clipboard_service.dart';
import 'package:lockleaf/features/security/presentation/security_controller.dart';
import 'package:lockleaf/features/tools/domain/password_generator.dart';
import 'package:lockleaf/features/tools/domain/password_generator_options.dart';
import 'package:lockleaf/features/vault/domain/vault_service.dart';

import '../security/security_test_doubles.dart';
import '../vault/in_memory_vault_storage.dart';

void main() {
  late SecureRandomService randomService;
  late PasswordGenerator passwordGenerator;

  String randomChars(int length) {
    final codes = List<int>.generate(
      length,
      (_) => 97 + randomService.nextInt(26),
    );
    return String.fromCharCodes(codes);
  }

  setUp(() {
    randomService = SecureRandomService();
    passwordGenerator = PasswordGenerator(randomService: randomService);
  });

  testWidgets(
      'tools hub supports generator modes, clipboard copy, health check, and entry picker',
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
      kdfParams: KdfParams(
        memoryKiB: 256,
        iterations: 1,
        parallelism: 1,
      ),
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

    await vaultController.createMasterPassword(randomChars(18));

    final weakSecret = randomChars(6);
    final sharedSecret = passwordGenerator.generate(
      PasswordGeneratorOptions(length: 20),
    );
    await vaultController.addEntry(
      title: 'Weak Account',
      username: 'weak_user',
      password: weakSecret,
    );
    await vaultController.addEntry(
      title: 'Duplicate A',
      username: 'dup_a',
      password: sharedSecret,
    );
    await vaultController.addEntry(
      title: 'Duplicate B',
      username: 'dup_b',
      password: sharedSecret,
    );
    await securityController.initialize();

    await tester.pumpWidget(
      LockLeafApp(
        controller: vaultController,
        securityController: securityController,
      ),
    );
    await tester.pumpAndSettle();

    // 1. Open ToolsHubScreen
    await tester.tap(find.byKey(const Key('vault_tools_button')));
    await tester.pumpAndSettle();
    expect(find.text('Security Tools'), findsOneWidget);

    // 2. Open PasswordGeneratorScreen, regenerate, copy, and switch to Passphrase
    await tester.tap(find.byKey(const Key('tools_generator_tile')));
    await tester.pumpAndSettle();

    final initialOutput = tester
        .widget<SelectableText>(find.byKey(const Key('generator_output_text')))
        .data!;
    expect(
      initialOutput.length,
      equals(PasswordGeneratorOptions.defaultLength),
    );

    await tester.tap(find.byKey(const Key('generator_regenerate_button')));
    await tester.pump();
    final regeneratedOutput = tester
        .widget<SelectableText>(find.byKey(const Key('generator_output_text')))
        .data!;
    expect(regeneratedOutput, isNot(equals(initialOutput)));

    await tester.tap(find.byKey(const Key('generator_copy_button')));
    await tester.pump();
    expect(clipboardAdapter.currentText, equals(regeneratedOutput));

    await tester.tap(find.text('Passphrase'));
    await tester.pumpAndSettle();
    final phraseOutput = tester
        .widget<SelectableText>(find.byKey(const Key('generator_output_text')))
        .data!;
    expect(phraseOutput.split('-').length, equals(6));

    // 3. Back to ToolsHubScreen -> open PasswordHealthScreen
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tools_health_tile')));
    await tester.pumpAndSettle();

    expect(find.text('Password Health'), findsOneWidget);
    expect(find.text('Weak Passwords'), findsOneWidget);
    expect(find.text('Reused Passwords'), findsOneWidget);
    expect(find.text('Weak Account'), findsOneWidget);
    expect(find.text('Duplicate A'), findsOneWidget);
    expect(find.text('Duplicate B'), findsOneWidget);
    expect(find.text(weakSecret), findsNothing);
    expect(find.text(sharedSecret), findsNothing);

    // 4. Back to VaultListScreen -> open AddEditEntryScreen -> use generator picker
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('vault_add_entry_fab')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('entry_generate_password_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('generator_use_button')), findsOneWidget);
    final pickedSecret = tester
        .widget<SelectableText>(find.byKey(const Key('generator_output_text')))
        .data!;

    await tester.tap(find.byKey(const Key('generator_use_button')));
    await tester.pumpAndSettle();

    final passwordField = tester.widget<TextFormField>(
      find.descendant(
        of: find.byKey(const Key('entry_password_field')),
        matching: find.byType(TextFormField),
      ),
    );
    expect(passwordField.controller?.text, equals(pickedSecret));
  });
}
