import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lockleaf/core/theme/app_theme.dart';
import 'package:lockleaf/features/auth/presentation/screens/master_password_setup_screen.dart';
import 'package:lockleaf/features/auth/presentation/screens/onboarding_screen.dart';
import 'package:lockleaf/features/auth/presentation/screens/unlock_screen.dart';
import 'package:lockleaf/features/auth/presentation/vault_controller.dart';
import 'package:lockleaf/features/vault/data/sqlite_vault_storage.dart';
import 'package:lockleaf/features/vault/domain/vault_service.dart';
import 'package:lockleaf/features/vault/presentation/screens/vault_list_screen.dart';

/// Root application widget for LockLeaf.
class LockLeafApp extends StatefulWidget {
  /// Optional injected [VaultController] for testing or custom storage wiring.
  final VaultController? controller;

  /// Creates the root [LockLeafApp].
  const LockLeafApp({
    super.key,
    this.controller,
  });

  @override
  State<LockLeafApp> createState() => _LockLeafAppState();
}

class _LockLeafAppState extends State<LockLeafApp> {
  VaultController? _ownedController;
  late final VaultController _controller;

  @override
  void initState() {
    super.initState();
    final provided = widget.controller;
    if (provided != null) {
      _controller = provided;
    } else {
      final created = VaultController(
        vaultService: VaultService(storage: SqliteVaultStorage()),
      );
      _ownedController = created;
      _controller = created;
    }
    if (_controller.stage == AuthFlowStage.loading) {
      unawaited(_controller.initialize());
    }
  }

  @override
  void dispose() {
    _ownedController?.dispose();
    super.dispose();
  }

  Widget _buildHome() {
    switch (_controller.stage) {
      case AuthFlowStage.loading:
        return const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        );
      case AuthFlowStage.onboarding:
        return Builder(
          builder: (BuildContext innerContext) {
            return OnboardingScreen(
              controller: _controller,
              onGetStarted: () {
                unawaited(
                  Navigator.of(innerContext).push<void>(
                    MaterialPageRoute<void>(
                      builder: (BuildContext context) =>
                          MasterPasswordSetupScreen(controller: _controller),
                    ),
                  ),
                );
              },
            );
          },
        );
      case AuthFlowStage.locked:
        return UnlockScreen(controller: _controller);
      case AuthFlowStage.unlocked:
        return VaultListScreen(controller: _controller);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (BuildContext context, Widget? child) {
        return MaterialApp(
          title: 'LockLeaf',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: _controller.themeMode,
          home: _buildHome(),
        );
      },
    );
  }
}
