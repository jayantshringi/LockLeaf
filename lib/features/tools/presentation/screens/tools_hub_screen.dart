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
import 'package:lockleaf/features/vault/presentation/screens/entry_detail_screen.dart';

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
                key: const Key('tools_authenticator_tile'),
                leading: CircleAvatar(
                  backgroundColor: AppTheme.primaryGreen.withOpacity(0.14),
                  child: const Icon(
                    Icons.pin_outlined,
                    color: AppTheme.primaryGreen,
                  ),
                ),
                title: const Text(
                  '2FA Authenticator (TOTP)',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'RFC 6238 time-based one-time password engine with 30s rolling codes',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  final entriesWithTotp =
                      controller.entries.where((e) => e.hasTotp).toList();
                  showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    builder: (BuildContext sheetContext) {
                      return SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.security,
                                    color: AppTheme.primaryGreen,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '2FA Authenticator',
                                    style: Theme.of(sheetContext)
                                        .textTheme
                                        .titleLarge,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              if (entriesWithTotp.isEmpty) ...[
                                const Text(
                                  'No vault entries currently have two-factor authentication enabled.\n\n'
                                  'To enable 2FA for an account, edit the vault entry and paste its Base32 secret key or otpauth:// URI.',
                                ),
                                const SizedBox(height: 16),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: FilledButton(
                                    onPressed: () =>
                                        Navigator.of(sheetContext).pop(),
                                    child: const Text('Got It'),
                                  ),
                                ),
                              ] else ...[
                                Text(
                                  '${entriesWithTotp.length} account(s) configured with 2FA:',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                ConstrainedBox(
                                  constraints:
                                      const BoxConstraints(maxHeight: 280),
                                  child: ListView.builder(
                                    shrinkWrap: true,
                                    itemCount: entriesWithTotp.length,
                                    itemBuilder: (context, index) {
                                      final item = entriesWithTotp[index];
                                      return ListTile(
                                        leading: const Icon(
                                          Icons.key,
                                          color: AppTheme.primaryGreen,
                                        ),
                                        title: Text(item.title),
                                        subtitle: Text(item.username.isNotEmpty
                                            ? item.username
                                            : 'Account'),
                                        trailing:
                                            const Icon(Icons.chevron_right),
                                        onTap: () {
                                          Navigator.of(sheetContext).pop();
                                          Navigator.of(context).push<void>(
                                            MaterialPageRoute<void>(
                                              builder: (_) => EntryDetailScreen(
                                                controller: controller,
                                                entry: item,
                                                securityController:
                                                    securityController,
                                              ),
                                            ),
                                          );
                                        },
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
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
