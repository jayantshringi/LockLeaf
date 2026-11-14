import 'package:flutter/material.dart';
import 'package:lockleaf/core/theme/app_theme.dart';
import 'package:lockleaf/features/auth/presentation/vault_controller.dart';
import 'package:lockleaf/features/auth/presentation/widgets/secret_text_field.dart';
import 'package:lockleaf/features/backup/presentation/backup_controller.dart';

/// Screen allowing the user to inspect and restore from an encrypted LockLeaf backup.
class BackupRestoreScreen extends StatefulWidget {
  final BackupController backupController;
  final VaultController vaultController;
  final bool isNewVaultSetup;

  const BackupRestoreScreen({
    super.key,
    required this.backupController,
    required this.vaultController,
    this.isNewVaultSetup = false,
  });

  @override
  State<BackupRestoreScreen> createState() => _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends State<BackupRestoreScreen> {
  final _formKey = GlobalKey<FormState>();
  final _jsonController = TextEditingController();
  final _backupPasswordController = TextEditingController();
  final _newMasterPasswordController = TextEditingController();

  bool _obscureBackupPassword = true;
  bool _obscureMasterPassword = true;
  bool _overwrite = false;

  @override
  void dispose() {
    _jsonController.dispose();
    _backupPasswordController.dispose();
    _newMasterPasswordController.dispose();
    super.dispose();
  }

  void _inspect() {
    final raw = _jsonController.text.trim();
    if (raw.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please paste backup JSON content first.'),
        ),
      );
      return;
    }
    final ok = widget.backupController.inspectBackupJson(raw);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid backup format or corrupt JSON.')),
      );
    }
  }

  Future<void> _handleRestore() async {
    if (!_formKey.currentState!.validate()) return;

    final jsonStr = _jsonController.text.trim();
    final backupPassword = _backupPasswordController.text;

    bool success;
    if (widget.isNewVaultSetup) {
      success = await widget.backupController.restoreToNewVault(
        backupJson: jsonStr,
        backupPassword: backupPassword,
        newMasterPassword: _newMasterPasswordController.text,
      );
    } else {
      success = await widget.backupController.restoreBackup(
        backupJson: jsonStr,
        backupPassword: backupPassword,
        overwriteExisting: _overwrite,
      );
    }

    if (mounted && success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.backupController.statusMessage ?? 'Restoration completed.',
          ),
        ),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final controller = widget.backupController;

    return Scaffold(
      appBar: AppBar(title: const Text('Restore from Backup')),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            final header = controller.inspectedHeader;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Paste Encrypted Backup JSON',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      key: const Key('backup_json_input'),
                      controller: _jsonController,
                      maxLines: 4,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                      decoration: InputDecoration(
                        hintText: '{"magic":"LOCKLEAF_BACKUP", ...}',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.manage_search_rounded),
                          tooltip: 'Inspect Backup Header',
                          onPressed: _inspect,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      key: const Key('inspect_backup_button'),
                      onPressed: _inspect,
                      icon: const Icon(Icons.info_outline_rounded, size: 18),
                      label: const Text('Inspect Backup Details'),
                    ),
                    const SizedBox(height: 20),
                    if (header != null) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppTheme.primaryGreen.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.verified_outlined,
                                  color: AppTheme.primaryGreen,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Valid LockLeaf Backup',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 16),
                            Text('Entries: ${header.entryCount}'),
                            Text(
                              'Created: ${header.createdAt.toLocal().toString().split('.').first}',
                            ),
                            if (header.notes != null)
                              Text('Notes: ${header.notes}'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    if (controller.errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.errorRed.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.errorRed),
                        ),
                        child: Text(
                          controller.errorMessage!,
                          style: const TextStyle(color: AppTheme.errorRed),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    SecretTextField(
                      key: const Key('restore_backup_password_field'),
                      controller: _backupPasswordController,
                      obscureText: _obscureBackupPassword,
                      labelText: 'Backup Decryption Password',
                      hintText: 'Enter password used when exporting',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureBackupPassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                        onPressed: () => setState(
                          () =>
                              _obscureBackupPassword = !_obscureBackupPassword,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Enter the backup password.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    if (widget.isNewVaultSetup) ...[
                      SecretTextField(
                        key: const Key('new_vault_master_password_field'),
                        controller: _newMasterPasswordController,
                        obscureText: _obscureMasterPassword,
                        labelText: 'New Master Password',
                        hintText: 'Create password for this restored vault',
                        prefixIcon: const Icon(Icons.key_rounded),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureMasterPassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                          onPressed: () => setState(
                            () => _obscureMasterPassword =
                                !_obscureMasterPassword,
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.length < 12) {
                            return 'Master password must be at least 12 characters.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                    ] else ...[
                      RadioListTile<bool>(
                        key: const Key('restore_mode_merge'),
                        value: false,
                        groupValue: _overwrite,
                        onChanged: (val) =>
                            setState(() => _overwrite = val ?? false),
                        title: const Text('Merge with existing entries'),
                        subtitle: const Text(
                          'Keeps current entries and updates matching ones',
                        ),
                      ),
                      RadioListTile<bool>(
                        key: const Key('restore_mode_overwrite'),
                        value: true,
                        groupValue: _overwrite,
                        onChanged: (val) =>
                            setState(() => _overwrite = val ?? true),
                        title: const Text('Overwrite all existing entries'),
                        subtitle: const Text(
                          'Replaces current vault entries with backup',
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    ElevatedButton(
                      key: const Key('execute_restore_button'),
                      onPressed: controller.isBusy ? null : _handleRestore,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: controller.isBusy
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Restore Vault'),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
