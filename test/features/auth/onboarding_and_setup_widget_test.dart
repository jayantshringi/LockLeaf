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

  String randomChars(String alphabet, int count) {
    final buffer = StringBuffer();
    for (var i = 0; i < count; i++) {
      buffer.write(alphabet[randomService.nextInt(alphabet.length)]);
    }
    return buffer.toString();
  }

  VaultController createTestController() {
    return VaultController(
      vaultService: VaultService(
        storage: InMemoryVaultStorage(),
        randomService: randomService,
      ),
      kdfParams: KdfParams(memoryKiB: 256, iterations: 1, parallelism: 1),
    );
  }

  setUp(() {
    randomService = SecureRandomService();
  });

  testWidgets(
    'onboarding navigates through slides to master password setup and creates vault',
    (WidgetTester tester) async {
      final controller = createTestController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(LockLeafApp(controller: controller));
      await tester.pumpAndSettle();

      expect(find.text('Zero-Knowledge Vault'), findsOneWidget);

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Audited Cryptography'), findsOneWidget);

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Encrypted Local Storage'), findsOneWidget);

      await tester.tap(find.text('Create Master Password'));
      await tester.pumpAndSettle();
      expect(find.text('Create Master Password'), findsOneWidget);

      // Weak input updates strength meter
      final weakInput = randomChars('abcdef', 6);
      await tester.enterText(
        find.byKey(const Key('setup_master_password_field')),
        weakInput,
      );
      await tester.pump();
      expect(find.text('Strength: Weak'), findsOneWidget);

      // Strong random input updates strength meter to Strong
      final strongInput =
          '${randomChars('abcdefghijklmnopqrstuvwxyz', 6)}'
          '${randomChars('ABCDEFGHIJKLMNOPQRSTUVWXYZ', 5)}'
          '${randomChars('0123456789', 4)}'
          '${randomChars('!@#%^&*', 3)}';
      await tester.enterText(
        find.byKey(const Key('setup_master_password_field')),
        strongInput,
      );
      await tester.pump();
      expect(find.text('Strength: Strong'), findsOneWidget);

      // Mismatched confirm password fails validation
      await tester.enterText(
        find.byKey(const Key('setup_confirm_password_field')),
        '${strongInput}x',
      );
      await tester.tap(find.byKey(const Key('setup_create_vault_button')));
      await tester.pump();
      expect(find.text('Master passwords do not match'), findsOneWidget);

      // Fix confirm password, check acknowledgment, and create vault
      await tester.enterText(
        find.byKey(const Key('setup_confirm_password_field')),
        strongInput,
      );
      await tester.tap(find.byKey(const Key('setup_acknowledge_checkbox')));
      await tester.pump();

      await tester.tap(find.byKey(const Key('setup_create_vault_button')));
      await tester.pumpAndSettle();

      // If initial recovery key screen appears, acknowledge and continue to vault
      if (find
          .byKey(const Key('recovery_key_saved_checkbox'))
          .evaluate()
          .isNotEmpty) {
        await tester.tap(find.byKey(const Key('recovery_key_saved_checkbox')));
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.byKey(const Key('recovery_key_continue_button')),
        );
        await tester.tap(find.byKey(const Key('recovery_key_continue_button')));
        await tester.pumpAndSettle();
      }

      expect(find.text('LockLeaf Vault'), findsOneWidget);
      expect(find.text('Your vault is empty'), findsOneWidget);
      expect(controller.stage, equals(AuthFlowStage.unlocked));
    },
  );
}
