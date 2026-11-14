import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lockleaf/core/theme/app_theme.dart';
import 'package:lockleaf/features/auth/presentation/vault_controller.dart';
import 'package:lockleaf/features/backup/presentation/backup_controller.dart';
import 'package:lockleaf/features/backup/presentation/screens/backup_export_screen.dart';
import 'package:lockleaf/features/backup/presentation/screens/backup_restore_screen.dart';
import 'package:lockleaf/features/security/presentation/security_controller.dart';
import 'package:lockleaf/features/sync/presentation/screens/sync_settings_screen.dart';
import 'package:lockleaf/features/sync/presentation/sync_controller.dart';
import 'package:lockleaf/features/tools/presentation/screens/password_generator_screen.dart';
import 'package:lockleaf/features/tools/presentation/screens/password_health_screen.dart';

/// Hub screen providing access to LockLeaf's offline security tools.
class ToolsHubScreen extends StatelessWidget {
  /// Controller providing unlocked vault entries.
  final VaultController controller;

  /// Optional device security controller for clipboard auto-clear.
  final SecurityController? securityController;

  /// Optional cloud synchronization controller.
  final SyncController? syncController;

  /// Creates a [ToolsHubScreen].
  const ToolsHubScreen({
    super.key,
    required this.controller,
    this.securityController,
    this.syncController,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Security Tools')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: ListTile(
                key: const Key('tools_generator_tile'),
                leading: CircleAvatar(
                  backgroundColor: AppTheme.primaryGreen.withOpacity(0.14),
                  child: const Icon(
                    Icons.password,
                    color: AppTheme.primaryGreen,
                  ),
                ),
                title: const Text(
                  'Password & Passphrase Generator',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Create high-entropy random passwords and Diceware passphrases offline',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  unawaited(
                    Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (BuildContext context) =>
                            PasswordGeneratorScreen(
                              securityController: securityController,
                            ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                key: const Key('tools_health_tile'),
                leading: CircleAvatar(
                  backgroundColor: AppTheme.primaryGreen.withOpacity(0.14),
                  child: const Icon(
                    Icons.health_and_safety_outlined,
                    color: AppTheme.primaryGreen,
                  ),
                ),
                title: const Text(
                  'Password Health Check',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Identify weak or reused passwords across your local vault',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  unawaited(
                    Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (BuildContext context) => PasswordHealthScreen(
                          controller: controller,
                          securityController: securityController,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                key: const Key('tools_export_backup_tile'),
                leading: CircleAvatar(
                  backgroundColor: AppTheme.primaryGreen.withOpacity(0.14),
                  child: const Icon(
                    Icons.upload_file_rounded,
                    color: AppTheme.primaryGreen,
                  ),
                ),
                title: const Text(
                  'Export Encrypted Backup',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Generate an authenticated zero-knowledge .llbak file',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  final backupCtrl = BackupController(
                    vaultService: controller.vaultService,
                    vaultController: controller,
                  );
                  unawaited(
                    Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (BuildContext context) => BackupExportScreen(
                          backupController: backupCtrl,
                          vaultController: controller,
                          securityController: securityController,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                key: const Key('tools_restore_backup_tile'),
                leading: CircleAvatar(
                  backgroundColor: AppTheme.primaryGreen.withOpacity(0.14),
                  child: const Icon(
                    Icons.settings_backup_restore_rounded,
                    color: AppTheme.primaryGreen,
                  ),
                ),
                title: const Text(
                  'Restore from Backup',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Inspect and restore vault entries from a backup',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  final backupCtrl = BackupController(
                    vaultService: controller.vaultService,
                    vaultController: controller,
                  );
                  unawaited(
                    Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (BuildContext context) => BackupRestoreScreen(
                          backupController: backupCtrl,
                          vaultController: controller,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            if (syncController != null) ...[
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  key: const Key('tools_cloud_sync_tile'),
                  leading: CircleAvatar(
                    backgroundColor: AppTheme.primaryGreen.withOpacity(0.14),
                    child: const Icon(
                      Icons.cloud_sync_outlined,
                      color: AppTheme.primaryGreen,
                    ),
                  ),
                  title: const Text(
                    'Cloud Synchronization',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'End-to-end encrypted multi-device synchronization',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    unawaited(
                      Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          builder: (BuildContext context) => SyncSettingsScreen(
                            syncController: syncController!,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
