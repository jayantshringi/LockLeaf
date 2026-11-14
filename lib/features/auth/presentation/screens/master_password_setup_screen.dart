import 'package:flutter/material.dart';
import 'package:lockleaf/core/constants/security_constants.dart';
import 'package:lockleaf/core/theme/app_theme.dart';
import 'package:lockleaf/features/auth/domain/password_strength.dart';
import 'package:lockleaf/features/auth/presentation/vault_controller.dart';
import 'package:lockleaf/features/auth/presentation/widgets/password_strength_meter.dart';
import 'package:lockleaf/features/auth/presentation/widgets/secret_text_field.dart';
import 'package:lockleaf/features/backup/presentation/screens/recovery_key_display_screen.dart';

/// Master password creation screen with live strength evaluation.
class MasterPasswordSetupScreen extends StatefulWidget {
  /// Controller managing vault initialization.
  final VaultController controller;

  /// Optional callback invoked once the vault is created and unlocked.
  final VoidCallback? onVaultCreated;

  /// Creates a [MasterPasswordSetupScreen].
  const MasterPasswordSetupScreen({
    super.key,
    required this.controller,
    this.onVaultCreated,
  });

  @override
  State<MasterPasswordSetupScreen> createState() =>
      _MasterPasswordSetupScreenState();
}

class _MasterPasswordSetupScreenState extends State<MasterPasswordSetupScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();

  PasswordStrengthResult _strength = PasswordStrengthEvaluator.evaluate('');
  bool _acknowledged = false;

  @override
  void dispose() {
    _passwordController.clear();
    _confirmController.clear();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final formState = _formKey.currentState;
    if (formState == null || !formState.validate()) {
      return;
    }
    if (!_acknowledged) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please acknowledge the zero-knowledge warning.'),
        ),
      );
      return;
    }

    final success = await widget.controller.createMasterPassword(
      _passwordController.text,
    );
    if (!mounted) {
      return;
    }
    if (success) {
      _passwordController.clear();
      _confirmController.clear();
      final recoveryKey = widget.controller.lastGeneratedRecoveryKey;
      if (recoveryKey != null) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => RecoveryKeyDisplayScreen(
              recoveryKey: recoveryKey,
              isInitialSetup: true,
              onConfirmed: () {
                widget.controller.clearLastGeneratedRecoveryKey();
                Navigator.of(context).pop();
              },
            ),
          ),
        );
      }
      if (!mounted) return;
      if (widget.onVaultCreated != null) {
        widget.onVaultCreated!();
      } else if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (BuildContext context, Widget? child) {
        final isBusy = widget.controller.isBusy;
        final errorMessage = widget.controller.errorMessage;

        return Scaffold(
          appBar: AppBar(title: const Text('Create Master Password')),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Choose a strong master password. It encrypts your entire vault locally and is never stored or sent anywhere.',
                    ),
                    const SizedBox(height: 24),
                    SecretTextField(
                      key: const Key('setup_master_password_field'),
                      controller: _passwordController,
                      labelText: 'Master Password',
                      hintText:
                          'At least ${SecurityConstants.minMasterPasswordLength} characters',
                      enabled: !isBusy,
                      textInputAction: TextInputAction.next,
                      onChanged: (String value) {
                        setState(() {
                          _strength = PasswordStrengthEvaluator.evaluate(value);
                        });
                      },
                      validator: (String? value) {
                        if (value == null ||
                            value.length <
                                SecurityConstants.minMasterPasswordLength) {
                          return 'Use at least ${SecurityConstants.minMasterPasswordLength} characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    PasswordStrengthMeter(result: _strength),
                    const SizedBox(height: 20),
                    SecretTextField(
                      key: const Key('setup_confirm_password_field'),
                      controller: _confirmController,
                      labelText: 'Confirm Master Password',
                      enabled: !isBusy,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      validator: (String? value) {
                        if (value != _passwordController.text) {
                          return 'Master passwords do not match';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    CheckboxListTile(
                      key: const Key('setup_acknowledge_checkbox'),
                      value: _acknowledged,
                      enabled: !isBusy,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: const Text(
                        'I understand LockLeaf cannot reset or recover my master password if I lose it.',
                      ),
                      onChanged: (bool? checked) {
                        setState(() {
                          _acknowledged = checked ?? false;
                        });
                      },
                    ),
                    if (errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.danger.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          errorMessage,
                          style: const TextStyle(color: AppTheme.danger),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 52,
                      child: FilledButton(
                        key: const Key('setup_create_vault_button'),
                        onPressed: isBusy ? null : _submit,
                        child: isBusy
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Create Vault'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
