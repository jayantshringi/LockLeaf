import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockleaf/app.dart';
import 'package:lockleaf/core/crypto/kdf_params.dart';
import 'package:lockleaf/core/crypto/secure_random_service.dart';
import 'package:lockleaf/features/auth/presentation/vault_controller.dart';
import 'package:lockleaf/features/vault/domain/vault_service.dart';

import '../vault/in_memory_vault_storage.dart';

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

  testWidgets('unlock screen handles validation, theme toggle, and login', (
    WidgetTester tester,
  ) async {
    final masterPass = randomToken();
    final wrongPass = randomToken();
    final storage = InMemoryVaultStorage();
    final fastParams = KdfParams(memoryKiB: 256, iterations: 1, parallelism: 1);

    final vaultService = VaultService(
      storage: storage,
      randomService: randomService,
    );
    await vaultService.createVault(
      masterPassword: masterPass,
      kdfParams: fastParams,
    );
    vaultService.lockVault();

    final controller = VaultController(
      vaultService: vaultService,
      kdfParams: fastParams,
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(LockLeafApp(controller: controller));
    await tester.pumpAndSettle();

    expect(find.text('Vault Locked'), findsOneWidget);

    // Verify SecretTextField enforces obscured input and disables keyboard learning
    final editableText = tester.widget<EditableText>(find.byType(EditableText));
    expect(editableText.obscureText, isTrue);
    expect(editableText.autocorrect, isFalse);
    expect(editableText.enableSuggestions, isFalse);

    // Toggle dark -> light -> dark mode
    expect(controller.isDarkMode, isTrue);
    await tester.tap(find.byKey(const Key('unlock_theme_toggle')));
    await tester.pumpAndSettle();
    expect(controller.isDarkMode, isFalse);

    await tester.tap(find.byKey(const Key('unlock_theme_toggle')));
    await tester.pumpAndSettle();
    expect(controller.isDarkMode, isTrue);

    // Empty submission shows validator message
    await tester.tap(find.byKey(const Key('unlock_submit_button')));
    await tester.pump();
    expect(find.text('Enter your master password'), findsOneWidget);

    // Wrong password shows error banner
    await tester.enterText(
      find.byKey(const Key('unlock_password_field')),
      wrongPass,
    );
    await tester.tap(find.byKey(const Key('unlock_submit_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('unlock_error_banner')), findsOneWidget);
    expect(controller.stage, equals(AuthFlowStage.locked));

    // Correct password unlocks vault
    await tester.enterText(
      find.byKey(const Key('unlock_password_field')),
      masterPass,
    );
    await tester.tap(find.byKey(const Key('unlock_submit_button')));
    await tester.pumpAndSettle();

    expect(controller.stage, equals(AuthFlowStage.unlocked));
    expect(find.text('LockLeaf Vault'), findsOneWidget);
  });
}
