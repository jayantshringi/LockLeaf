import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lockleaf/core/theme/app_theme.dart';
import 'package:lockleaf/features/auth/presentation/vault_controller.dart';
import 'package:lockleaf/features/auth/presentation/widgets/secret_text_field.dart';
import 'package:lockleaf/features/backup/presentation/screens/recovery_key_reset_screen.dart';
import 'package:lockleaf/features/security/presentation/security_controller.dart';

/// Master password unlock screen shown whenever the vault is locked.
class UnlockScreen extends StatefulWidget {
  /// Controller managing authentication state.
  final VaultController controller;

  /// Optional controller providing biometric quick unlock.
  final SecurityController? securityController;

  /// Creates an [UnlockScreen].
  const UnlockScreen({
    super.key,
    required this.controller,
    this.securityController,
  });

  @override
  State<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends State<UnlockScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _passwordController.clear();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final formState = _formKey.currentState;
    if (formState == null || !formState.validate()) {
      return;
    }

    final success = await widget.controller.unlock(_passwordController.text);
    if (!mounted) {
      return;
    }
    if (success) {
      _passwordController.clear();
    }
  }

  Future<void> _unlockBiometrics() async {
    final security = widget.securityController;
    if (security == null) {
      return;
    }
    final success = await security.unlockWithBiometrics();
    if (!mounted) {
      return;
    }
    if (success) {
      _passwordController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final security = widget.securityController;
    final listenable = security == null
        ? widget.controller
        : Listenable.merge(<Listenable>[widget.controller, security]);

    return ListenableBuilder(
      listenable: listenable,
      builder: (BuildContext context, Widget? child) {
        final isBusy = widget.controller.isBusy;
        final errorMessage = widget.controller.errorMessage;
        final showBiometrics = security?.biometricEnabled ?? false;

        return Scaffold(
          appBar: AppBar(
            title: const Text('LockLeaf'),
            actions: [
              IconButton(
                key: const Key('unlock_theme_toggle'),
                tooltip: 'Toggle theme',
                icon: Icon(
                  widget.controller.isDarkMode
                      ? Icons.light_mode_outlined
                      : Icons.dark_mode_outlined,
                ),
                onPressed: widget.controller.toggleDarkMode,
              ),
            ],
          ),
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(
                        Icons.lock_outline,
                        size: 72,
                        color: AppTheme.primaryGreen,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Vault Locked',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Enter your master password to decrypt your local vault.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium
                            ?.copyWith(color: Colors.grey),
                      ),
                      const SizedBox(height: 32),
                      SecretTextField(
                        key: const Key('unlock_password_field'),
                        controller: _passwordController,
                        labelText: 'Master Password',
                        enabled: !isBusy,
                        onChanged: (_) => widget.controller.clearError(),
                        onFieldSubmitted: (_) => _submit(),
                        validator: (String? value) {
                          if (value == null || value.isEmpty) {
                            return 'Enter your master password';
                          }
                          return null;
                        },
                      ),
                      if (errorMessage != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          key: const Key('unlock_error_banner'),
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
                          key: const Key('unlock_submit_button'),
                          onPressed: isBusy ? null : _submit,
                          child: isBusy
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Unlock Vault'),
                        ),
                      ),
                      if (showBiometrics) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 52,
                          child: OutlinedButton.icon(
                            key: const Key('unlock_biometric_button'),
                            onPressed: isBusy
                                ? null
                                : () => unawaited(_unlockBiometrics()),
                            icon: const Icon(Icons.fingerprint),
                            label: const Text('Unlock with Biometrics'),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      TextButton(
                        key: const Key('unlock_forgot_password_button'),
                        onPressed: isBusy
                            ? null
                            : () {
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (context) =>
                                        RecoveryKeyResetScreen(
                                          vaultController: widget.controller,
                                        ),
                                  ),
                                );
                              },
                        child: const Text(
                          'Forgot Master Password? Use Recovery Key',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
