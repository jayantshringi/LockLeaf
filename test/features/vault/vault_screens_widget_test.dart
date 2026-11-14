import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockleaf/app.dart';
import 'package:lockleaf/core/crypto/kdf_params.dart';
import 'package:lockleaf/core/crypto/secure_random_service.dart';
import 'package:lockleaf/features/auth/presentation/vault_controller.dart';
import 'package:lockleaf/features/vault/domain/vault_service.dart';

import 'in_memory_vault_storage.dart';

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
    'vault list supports create, search, detail reveal, edit, delete, and lock',
    (WidgetTester tester) async {
      final fastParams = KdfParams(
        memoryKiB: 256,
        iterations: 1,
        parallelism: 1,
      );
      final vaultService = VaultService(
        storage: InMemoryVaultStorage(),
        randomService: randomService,
      );
      final controller = VaultController(
        vaultService: vaultService,
        kdfParams: fastParams,
      );
      addTearDown(controller.dispose);

      await controller.createMasterPassword(randomToken());

      await tester.pumpWidget(LockLeafApp(controller: controller));
      await tester.pumpAndSettle();

      expect(find.text('Your vault is empty'), findsOneWidget);

      // 1. Add entry via AddEditEntryScreen
      final entrySecret = 'secret_${randomToken(length: 12)}';
      await tester.tap(find.byKey(const Key('vault_add_entry_fab')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('entry_title_field')),
        'Hosting Provider',
      );
      await tester.enterText(
        find.byKey(const Key('entry_username_field')),
        'admin_user',
      );
      await tester.enterText(
        find.byKey(const Key('entry_password_field')),
        entrySecret,
      );
      await tester.tap(find.byKey(const Key('entry_save_button')));
      await tester.pumpAndSettle();

      expect(find.text('Hosting Provider'), findsOneWidget);
      expect(find.text('admin_user'), findsOneWidget);
      expect(find.text(entrySecret), findsNothing);

      // 2. Add second entry and test search filtering
      await controller.addEntry(
        title: 'Backup Note',
        username: 'local_note',
        password: randomToken(),
      );
      await tester.pumpAndSettle();

      expect(find.text('Backup Note'), findsOneWidget);
      expect(find.text('Hosting Provider'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('vault_search_field')),
        'Backup',
      );
      await tester.pumpAndSettle();

      expect(find.text('Backup Note'), findsOneWidget);
      expect(find.text('Hosting Provider'), findsNothing);

      await tester.tap(find.byKey(const Key('vault_search_clear')));
      await tester.pumpAndSettle();

      expect(find.text('Hosting Provider'), findsOneWidget);

      // 3. Open EntryDetailScreen, toggle password reveal, edit, and delete
      await tester.tap(find.text('Hosting Provider'));
      await tester.pumpAndSettle();

      expect(find.text(entrySecret), findsNothing);
      await tester.tap(find.byKey(const Key('detail_reveal_password_button')));
      await tester.pump();
      expect(find.text(entrySecret), findsOneWidget);

      await tester.tap(find.byKey(const Key('detail_edit_button')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('entry_title_field')),
        'Hosting Console',
      );
      await tester.tap(find.byKey(const Key('entry_save_button')));
      await tester.pumpAndSettle();

      expect(find.text('Hosting Console'), findsOneWidget);

      await tester.tap(find.byKey(const Key('detail_delete_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm_delete_button')));
      await tester.pumpAndSettle();

      expect(find.text('Hosting Console'), findsNothing);
      expect(find.text('Backup Note'), findsOneWidget);

      // 4. Lock vault returns to UnlockScreen
      await tester.tap(find.byKey(const Key('vault_lock_button')));
      await tester.pumpAndSettle();

      expect(find.text('Vault Locked'), findsOneWidget);
      expect(controller.stage, equals(AuthFlowStage.locked));
    },
  );
}
