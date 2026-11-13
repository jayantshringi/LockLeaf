import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lockleaf/core/theme/app_theme.dart';
import 'package:lockleaf/features/backup/domain/recovery_key.dart';
import 'package:lockleaf/features/security/presentation/security_controller.dart';

/// Screen displaying the user's high-entropy vault Recovery Key.
class RecoveryKeyDisplayScreen extends StatefulWidget {
  final RecoveryKey recoveryKey;
  final bool isInitialSetup;
  final VoidCallback? onConfirmed;
  final SecurityController? securityController;

  const RecoveryKeyDisplayScreen({
    super.key,
    required this.recoveryKey,
    this.isInitialSetup = false,
    this.onConfirmed,
    this.securityController,
  });

  @override
  State<RecoveryKeyDisplayScreen> createState() =>
      _RecoveryKeyDisplayScreenState();
}

class _RecoveryKeyDisplayScreenState extends State<RecoveryKeyDisplayScreen> {
  bool _hasSavedKey = false;
  bool _copied = false;

  void _copyToClipboard() {
    final text = widget.recoveryKey.formatted;
    if (widget.securityController != null) {
      widget.securityController!.copySecret(
        text,
        label: 'Recovery Key',
      );
    } else {
      Clipboard.setData(ClipboardData(text: text));
    }
    setState(() => _copied = true);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Recovery Key copied to clipboard.'),
        duration: Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final parts = widget.recoveryKey.formatted.split('-');
    // parts[0] is 'LL', followed by 8 groups of 4 characters

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vault Recovery Key'),
        automaticallyImplyLeading: !widget.isInitialSetup,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: AppTheme.accentGold.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12.0),
                  border: Border.all(
                    color: AppTheme.accentGold.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: AppTheme.accentGold,
                      size: 28,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Save This Key Securely',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : AppTheme.darkBackground,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'If you ever lose your master password, this Recovery Key is '
                            'the ONLY way to recover your vault. LockLeaf has zero knowledge '
                            'of your data and cannot recover it for you.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'Your Recovery Key',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 20,
                ),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkSurface : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? Colors.white12 : Colors.grey.shade300,
                  ),
                ),
                child: Column(
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: parts.map((part) {
                        final isPrefix = part == 'LL';
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: isPrefix
                                ? AppTheme.primaryGreen.withValues(alpha: 0.15)
                                : (isDark ? Colors.white10 : Colors.white),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isPrefix
                                  ? AppTheme.primaryGreen
                                  : (isDark ? Colors.white12 : Colors.grey.shade300),
                            ),
                          ),
                          child: Text(
                            part,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                              color: isPrefix ? AppTheme.primaryGreen : null,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _copyToClipboard,
                      icon: Icon(
                        _copied ? Icons.check : Icons.copy_rounded,
                        size: 18,
                      ),
                      label: Text(_copied ? 'Copied' : 'Copy Key'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              if (widget.isInitialSetup) ...[
                CheckboxListTile(
                  key: const Key('recovery_key_saved_checkbox'),
                  value: _hasSavedKey,
                  onChanged: (val) => setState(() => _hasSavedKey = val ?? false),
                  title: const Text(
                    'I have written down or saved this recovery key in a safe place.',
                    style: TextStyle(fontSize: 14),
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  key: const Key('recovery_key_continue_button'),
                  onPressed: _hasSavedKey ? widget.onConfirmed : null,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Continue to Vault'),
                ),
              ] else ...[
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Done'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
