import 'package:flutter/material.dart';
import 'package:lockleaf/core/errors/app_exception.dart';
import 'package:lockleaf/core/theme/app_theme.dart';
import 'package:lockleaf/features/auth/domain/password_strength.dart';
import 'package:lockleaf/features/auth/presentation/vault_controller.dart';
import 'package:lockleaf/features/auth/presentation/widgets/password_strength_meter.dart';
import 'package:lockleaf/features/auth/presentation/widgets/secret_text_field.dart';
import 'package:lockleaf/features/backup/domain/recovery_key.dart';
import 'package:lockleaf/features/backup/presentation/screens/recovery_key_display_screen.dart';

/// Screen allowing master password reset using a verified vault Recovery Key.
class RecoveryKeyResetScreen extends StatefulWidget {
  final VaultController vaultController;

  const RecoveryKeyResetScreen({
    super.key,
    required this.vaultController,
  });

  @override
  State<RecoveryKeyResetScreen> createState() => _RecoveryKeyResetScreenState();
}

class _RecoveryKeyResetScreenState extends State<RecoveryKeyResetScreen> {
  final _formKey = GlobalKey<FormState>();
  final _keyController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  PasswordStrength _strength = PasswordStrength.empty;
  String? _keyFormatValidationMessage;
  bool _isKeyChecksumValid = false;

  @override
  void initState() {
    super.initState();
    _keyController.addListener(_onKeyChanged);
    _passwordController.addListener(_onPasswordChanged);
  }

  @override
  void dispose() {
    _keyController.removeListener(_onKeyChanged);
    _passwordController.removeListener(_onPasswordChanged);
    _keyController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _onKeyChanged() {
    final text = _keyController.text.trim();
    if (text.isEmpty) {
      setState(() {
        _keyFormatValidationMessage = null;
        _isKeyChecksumValid = false;
      });
      return;
    }

    try {
      RecoveryKey.fromString(text);
      setState(() {
        _keyFormatValidationMessage = 'Valid recovery key';
        _isKeyChecksumValid = true;
      });
    } on ValidationException catch (e) {
      setState(() {
        _keyFormatValidationMessage = e.message;
        _isKeyChecksumValid = false;
      });
    }
  }

  void _onPasswordChanged() {
    setState(() {
      _strength = PasswordStrength.evaluate(_passwordController.text);
    });
  }

  Future<void> _handleReset() async {
    if (!_formKey.currentState!.validate()) return;

    RecoveryKey parsedKey;
    try {
      parsedKey = RecoveryKey.fromString(_keyController.text.trim());
    } on ValidationException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
      return;
    }

    final success = await widget.vaultController.resetWithRecoveryKey(
      recoveryKey: parsedKey,
      newMasterPassword: _passwordController.text,
    );

    if (mounted && success) {
      final newKey = widget.vaultController.lastGeneratedRecoveryKey;
      if (newKey != null) {
        // Show the newly rotated recovery key
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => RecoveryKeyDisplayScreen(
              recoveryKey: newKey,
              isInitialSetup: true,
              onConfirmed: () {
                widget.vaultController.clearLastGeneratedRecoveryKey();
                Navigator.of(context).pop();
              },
            ),
          ),
        );
      } else {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final controller = widget.vaultController;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reset Master Password'),
      ),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
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
                        color: AppTheme.accentGold.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12.0),
                        border: Border.all(
                          color: AppTheme.accentGold.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.lock_reset_rounded,
                            color: AppTheme.accentGold,
                            size: 28,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Recovery Key Reset',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Enter your 32-character Recovery Key to decrypt your vault '
                                  'and choose a new master password without data loss.',
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
                    TextFormField(
                      key: const Key('recovery_key_input_field'),
                      controller: _keyController,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Recovery Key',
                        hintText: 'LL-XXXX-XXXX-...',
                        prefixIcon: const Icon(Icons.vpn_key_rounded),
                        suffixIcon: _keyController.text.isNotEmpty
                            ? Icon(
                                _isKeyChecksumValid
                                    ? Icons.check_circle_rounded
                                    : Icons.error_outline_rounded,
                                color: _isKeyChecksumValid
                                    ? AppTheme.primaryGreen
                                    : AppTheme.errorRed,
                              )
                            : null,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your recovery key.';
                        }
                        if (!_isKeyChecksumValid) {
                          return _keyFormatValidationMessage ?? 'Invalid recovery key.';
                        }
                        return null;
                      },
                    ),
                    if (_keyFormatValidationMessage != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        _keyFormatValidationMessage!,
                        style: TextStyle(
                          fontSize: 12,
                          color: _isKeyChecksumValid
                              ? AppTheme.primaryGreen
                              : AppTheme.errorRed,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    SecretTextField(
                      key: const Key('reset_new_password_field'),
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      labelText: 'New Master Password',
                      hintText: 'At least 12 characters recommended',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                        onPressed: () =>
                            setState(() => _obscurePassword = !_obscurePassword),
                      ),
                      validator: (value) {
                        if (value == null || value.length < 12) {
                          return 'Password must be at least 12 characters.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    PasswordStrengthMeter(strength: _strength),
                    const SizedBox(height: 16),
                    SecretTextField(
                      key: const Key('reset_confirm_password_field'),
                      controller: _confirmController,
                      obscureText: _obscureConfirm,
                      labelText: 'Confirm New Master Password',
                      hintText: 'Re-enter your new password',
                      prefixIcon: const Icon(Icons.lock_reset),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirm
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                        onPressed: () =>
                            setState(() => _obscureConfirm = !_obscureConfirm),
                      ),
                      validator: (value) {
                        if (value != _passwordController.text) {
                          return 'Passwords do not match.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 28),
                    ElevatedButton(
                      key: const Key('execute_reset_button'),
                      onPressed: controller.isBusy ? null : _handleReset,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: controller.isBusy
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Reset Master Password & Unlock'),
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
