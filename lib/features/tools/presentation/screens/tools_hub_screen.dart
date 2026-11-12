import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lockleaf/core/theme/app_theme.dart';
import 'package:lockleaf/features/auth/presentation/vault_controller.dart';
import 'package:lockleaf/features/security/presentation/security_controller.dart';
import 'package:lockleaf/features/tools/presentation/screens/password_generator_screen.dart';
import 'package:lockleaf/features/tools/presentation/screens/password_health_screen.dart';

/// Hub screen providing access to LockLeaf's offline security tools.
class ToolsHubScreen extends StatelessWidget {
  /// Controller providing unlocked vault entries.
  final VaultController controller;

  /// Optional device security controller for clipboard auto-clear.
  final SecurityController? securityController;

  /// Creates a [ToolsHubScreen].
  const ToolsHubScreen({
    super.key,
    required this.controller,
    this.securityController,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Security Tools'),
      ),
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
          ],
        ),
      ),
    );
  }
}
