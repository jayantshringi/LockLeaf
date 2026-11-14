import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lockleaf/core/theme/app_theme.dart';
import 'package:lockleaf/features/auth/presentation/vault_controller.dart';
import 'package:lockleaf/features/auth/presentation/widgets/secret_text_field.dart';
import 'package:lockleaf/features/backup/presentation/backup_controller.dart';
import 'package:lockleaf/features/security/presentation/security_controller.dart';

/// Screen allowing the user to export an authenticated zero-knowledge encrypted backup.
class BackupExportScreen extends StatefulWidget {
  final BackupController backupController;
  final VaultController vaultController;
  final SecurityController? securityController;

  const BackupExportScreen({
    super.key,
    required this.backupController,
    required this.vaultController,
    this.securityController,
  });

  @override
  State<BackupExportScreen> createState() => _BackupExportScreenState();
}

class _BackupExportScreenState extends State<BackupExportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _notesController = TextEditingController();

  bool _copied = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _handleExport() async {
    if (!_formKey.currentState!.validate()) return;

    final success = await widget.backupController.exportBackup(
      backupPassword: _passwordController.text,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
    );

    if (mounted && success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Encrypted backup generated successfully.'),
        ),
      );
    }
  }

  void _copyBackup() {
    final json = widget.backupController.exportedBackupJson;
    if (json == null) return;

    Clipboard.setData(ClipboardData(text: json));
    setState(() => _copied = true);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Backup copied to clipboard.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final controller = widget.backupController;

    return Scaffold(
      appBar: AppBar(title: const Text('Export Encrypted Backup')),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            final exportedJson = controller.exportedBackupJson;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12.0),
                        border: Border.all(
                          color: AppTheme.primaryGreen.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.shield_outlined,
                            color: AppTheme.primaryGreen,
                            size: 28,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Zero-Knowledge Backup',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Backups are encrypted using Argon2id and XChaCha20-Poly1305. '
                                  'Entries (${widget.vaultController.entries.length}) are fully protected.',
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
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
                    if (exportedJson == null) ...[
                      SecretTextField(
                        key: const Key('backup_password_field'),
                        controller: _passwordController,
                        labelText: 'Backup Password',
                        hintText: 'Enter password to protect this backup',
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a backup password.';
                          }
                          if (value.length < 8) {
                            return 'Password should be at least 8 characters.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      SecretTextField(
                        key: const Key('backup_confirm_password_field'),
                        controller: _confirmController,
                        labelText: 'Confirm Backup Password',
                        hintText: 'Re-enter backup password',
                        validator: (value) {
                          if (value != _passwordController.text) {
                            return 'Passwords do not match.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _notesController,
                        decoration: const InputDecoration(
                          labelText: 'Notes (Optional)',
                          hintText: 'e.g. Pre-upgrade backup',
                          prefixIcon: Icon(Icons.notes_rounded),
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 28),
                      ElevatedButton(
                        key: const Key('generate_backup_button'),
                        onPressed: controller.isBusy ? null : _handleExport,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: controller.isBusy
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Generate Encrypted Backup'),
                      ),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppTheme.darkSurface
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color:
                                isDark ? Colors.white12 : Colors.grey.shade300,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  color: AppTheme.primaryGreen,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Backup File Ready (.llbak)',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Your encrypted backup has been created. Copy it and save it '
                              'to your preferred secure cloud or external drive.',
                              style: theme.textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 16),
                            OutlinedButton.icon(
                              key: const Key('copy_backup_button'),
                              onPressed: _copyBackup,
                              icon: Icon(_copied ? Icons.check : Icons.copy),
                              label: Text(
                                _copied
                                    ? 'Copied to Clipboard'
                                    : 'Copy Backup JSON',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () {
                          controller.clearState();
                          Navigator.of(context).pop();
                        },
                        child: const Text('Done'),
                      ),
                    ],
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
