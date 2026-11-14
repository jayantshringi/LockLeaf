import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockleaf/core/crypto/kdf_params.dart';
import 'package:lockleaf/core/theme/app_theme.dart';
import 'package:lockleaf/features/auth/presentation/vault_controller.dart';
import 'package:lockleaf/features/sync/data/cloud_sync_transport.dart';
import 'package:lockleaf/features/sync/data/sync_storage_repository.dart';
import 'package:lockleaf/features/sync/domain/sync_engine.dart';
import 'package:lockleaf/features/sync/presentation/screens/sync_settings_screen.dart';
import 'package:lockleaf/features/sync/presentation/sync_controller.dart';
import 'package:lockleaf/features/tools/presentation/screens/tools_hub_screen.dart';
import 'package:lockleaf/features/vault/domain/vault_service.dart';
import 'package:lockleaf/features/vault/presentation/screens/vault_list_screen.dart';

import '../vault/in_memory_vault_storage.dart';

void main() {
  late InMemoryVaultStorage vaultStorage;
  late InMemorySyncStorageRepository syncStorage;
  late InMemorySyncTransport transport;
  late VaultService vaultService;
  late VaultController vaultController;
  late SyncEngine syncEngine;
  late SyncController syncController;

  const testMasterPassword = 'MasterPassword123!';
  const fastParams = KdfParams.testFast();

  setUp(() async {
    vaultStorage = InMemoryVaultStorage();
    syncStorage = InMemorySyncStorageRepository();
    transport = InMemorySyncTransport();

    vaultService = VaultService(
      storage: vaultStorage,
      syncStorage: syncStorage,
    );

    vaultController = VaultController(
      vaultService: vaultService,
      kdfParams: fastParams,
    );

    syncEngine = SyncEngine(
      vaultStorage: vaultStorage,
      syncStorage: syncStorage,
      transport: transport,
      localDeviceId: 'test-widget-device',
    );

    syncController = SyncController(
      vaultService: vaultService,
      vaultController: vaultController,
      syncStorage: syncStorage,
      syncEngine: syncEngine,
    );

    await vaultController.createMasterPassword(testMasterPassword);
  });

  tearDown(() {
    vaultController.lock();
  });

  Widget wrapWidget(Widget child) {
    return MaterialApp(theme: AppTheme.darkTheme, home: child);
  }

  group('SyncSettingsScreen widget tests', () {
    testWidgets('renders sync status and triggers manual sync', (tester) async {
      await tester.pumpWidget(
        wrapWidget(SyncSettingsScreen(syncController: syncController)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Cloud Synchronization'), findsOneWidget);
      expect(find.text('End-to-End Encrypted'), findsOneWidget);
      expect(find.byKey(const Key('sync_now_button')), findsOneWidget);

      await tester.tap(find.byKey(const Key('sync_now_button')));
      await tester.pumpAndSettle();

      expect(find.text('Synchronized'), findsOneWidget);
    });

    testWidgets('shows warning on empty server URL connection test', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWidget(SyncSettingsScreen(syncController: syncController)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('test_connection_button')));
      await tester.pumpAndSettle();

      expect(find.text('Please enter a server URL first.'), findsOneWidget);
    });
  });

  group('VaultListScreen and ToolsHubScreen sync integration', () {
    testWidgets('renders sync button on VaultListScreen app bar', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWidget(
          VaultListScreen(
            controller: vaultController,
            syncController: syncController,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('vault_sync_button')), findsOneWidget);
      await tester.tap(find.byKey(const Key('vault_sync_button')));
      await tester.pumpAndSettle();

      expect(find.text('Cloud Synchronization'), findsOneWidget);
    });

    testWidgets('renders Cloud Synchronization tile in ToolsHubScreen', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWidget(
          ToolsHubScreen(
            controller: vaultController,
            syncController: syncController,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('tools_cloud_sync_tile')), findsOneWidget);
      await tester.tap(find.byKey(const Key('tools_cloud_sync_tile')));
      await tester.pumpAndSettle();

      expect(find.text('Cloud Synchronization'), findsOneWidget);
    });
  });
}
