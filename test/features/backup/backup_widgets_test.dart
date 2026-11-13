import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockleaf/core/crypto/kdf_params.dart';
import 'package:lockleaf/core/theme/app_theme.dart';
import 'package:lockleaf/features/auth/presentation/vault_controller.dart';
import 'package:lockleaf/features/backup/domain/recovery_key.dart';
import 'package:lockleaf/features/backup/presentation/backup_controller.dart';
import 'package:lockleaf/features/backup/presentation/screens/backup_export_screen.dart';
import 'package:lockleaf/features/backup/presentation/screens/backup_restore_screen.dart';
import 'package:lockleaf/features/backup/presentation/screens/recovery_key_display_screen.dart';
import 'package:lockleaf/features/backup/presentation/screens/recovery_key_reset_screen.dart';
import 'package:lockleaf/features/vault/domain/vault_service.dart';

import '../vault/in_memory_vault_storage.dart';

void main() {
  late InMemoryVaultStorage storage;
  late VaultService vaultService;
  late VaultController vaultController;
  late BackupController backupController;

  const testMasterPassword = 'MasterPassword123!';
  const fastParams = KdfParams.testFast();

  setUp(() async {
    storage = InMemoryVaultStorage();
    vaultService = VaultService(storage: storage);
    vaultController = VaultController(
      vaultService: vaultService,
      kdfParams: fastParams,
    );
    backupController = BackupController(
      vaultService: vaultService,
      vaultController: vaultController,
      kdfParams: fastParams,
    );

    await vaultController.createMasterPassword(testMasterPassword);
  });

  tearDown(() {
    vaultController.lock();
  });

  Widget wrapWidget(Widget child) {
    return MaterialApp(
      theme: AppTheme.darkTheme,
      home: child,
    );
  }

  group('RecoveryKeyDisplayScreen', () {
    testWidgets('renders recovery key and enables continue on checkbox click',
        (tester) async {
      final key = RecoveryKey.generate();
      var confirmed = false;

      await tester.pumpWidget(
        wrapWidget(
          RecoveryKeyDisplayScreen(
            recoveryKey: key,
            isInitialSetup: true,
            onConfirmed: () => confirmed = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Vault Recovery Key'), findsOneWidget);
      expect(find.text('LL'), findsOneWidget);
      expect(find.text('Continue to Vault'), findsOneWidget);

      // Continue button should be disabled initially
      final continueButton = tester.widget<ElevatedButton>(
        find.byKey(const Key('recovery_key_continue_button')),
      );
      expect(continueButton.onPressed, isNull);

      // Check the save confirmation box
      await tester.tap(find.byKey(const Key('recovery_key_saved_checkbox')));
      await tester.pumpAndSettle();

      final continueButtonEnabled = tester.widget<ElevatedButton>(
        find.byKey(const Key('recovery_key_continue_button')),
      );
      expect(continueButtonEnabled.onPressed, isNotNull);

      await tester.tap(find.byKey(const Key('recovery_key_continue_button')));
      await tester.pumpAndSettle();
      expect(confirmed, isTrue);
    });
  });

  group('BackupExportScreen', () {
    testWidgets('validates matching passwords and generates encrypted backup',
        (tester) async {
      await tester.pumpWidget(
        wrapWidget(
          BackupExportScreen(
            backupController: backupController,
            vaultController: vaultController,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Export Encrypted Backup'), findsOneWidget);

      // Enter mismatched passwords
      await tester.enterText(
        find.byKey(const Key('backup_password_field')),
        'SecureBackupPass1',
      );
      await tester.enterText(
        find.byKey(const Key('backup_confirm_password_field')),
        'DifferentPass',
      );
      await tester.tap(find.byKey(const Key('generate_backup_button')));
      await tester.pumpAndSettle();

      expect(find.text('Passwords do not match.'), findsOneWidget);

      // Correct matching password
      await tester.enterText(
        find.byKey(const Key('backup_confirm_password_field')),
        'SecureBackupPass1',
      );
      await tester.tap(find.byKey(const Key('generate_backup_button')));
      await tester.pumpAndSettle();

      expect(find.text('Backup File Ready (.llbak)'), findsOneWidget);
      expect(find.byKey(const Key('copy_backup_button')), findsOneWidget);
    });
  });

  group('BackupRestoreScreen', () {
    testWidgets('inspects backup header and parses entry count',
        (tester) async {
      // Export a sample backup first
      await vaultService.createEntry(
        title: 'WidgetTestAccount',
        username: 'user@test.org',
        password: 'Password123!',
      );

      final backupJson = await backupController.exportBackup(
        backupPassword: 'MyRestorePassword99',
        notes: 'Widget Test Notes',
      );
      expect(backupJson, isTrue);
      final jsonOutput = backupController.exportedBackupJson!;
      backupController.clearState();

      await tester.pumpWidget(
        wrapWidget(
          BackupRestoreScreen(
            backupController: backupController,
            vaultController: vaultController,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Enter JSON and click inspect
      await tester.enterText(
        find.byKey(const Key('backup_json_input')),
        jsonOutput,
      );
      await tester.tap(find.byKey(const Key('inspect_backup_button')));
      await tester.pumpAndSettle();

      expect(find.text('Valid LockLeaf Backup'), findsOneWidget);
      expect(find.textContaining('Entries: 1'), findsOneWidget);
      expect(find.textContaining('Notes: Widget Test Notes'), findsOneWidget);
    });
  });

  group('RecoveryKeyResetScreen', () {
    testWidgets('validates recovery key checksum live in UI', (tester) async {
      final key = RecoveryKey.generate();

      await tester.pumpWidget(
        wrapWidget(
          RecoveryKeyResetScreen(vaultController: vaultController),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Reset Master Password'), findsOneWidget);

      // Type an invalid key
      await tester.enterText(
        find.byKey(const Key('recovery_key_input_field')),
        'LL-1234-5678',
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Expected 32 characters'), findsOneWidget);

      // Type the valid key
      await tester.enterText(
        find.byKey(const Key('recovery_key_input_field')),
        key.formatted,
      );
      await tester.pumpAndSettle();
      expect(find.text('Valid recovery key'), findsOneWidget);
    });
  });
}
