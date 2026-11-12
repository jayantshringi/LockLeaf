import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lockleaf/core/theme/app_theme.dart';
import 'package:lockleaf/features/auth/presentation/screens/master_password_setup_screen.dart';
import 'package:lockleaf/features/auth/presentation/screens/onboarding_screen.dart';
import 'package:lockleaf/features/auth/presentation/screens/unlock_screen.dart';
import 'package:lockleaf/features/auth/presentation/vault_controller.dart';
import 'package:lockleaf/features/security/data/biometric_auth_service.dart';
import 'package:lockleaf/features/security/data/secure_key_storage.dart';
import 'package:lockleaf/features/security/domain/biometric_vault_manager.dart';
import 'package:lockleaf/features/security/presentation/security_controller.dart';
import 'package:lockleaf/features/security/presentation/widgets/privacy_shield_overlay.dart';
import 'package:lockleaf/features/vault/data/sqlite_vault_storage.dart';
import 'package:lockleaf/features/vault/domain/vault_service.dart';
import 'package:lockleaf/features/vault/presentation/screens/vault_list_screen.dart';

/// Root application widget for LockLeaf.
class LockLeafApp extends StatefulWidget {
  /// Optional injected [VaultController] for testing or custom wiring.
  final VaultController? controller;

  /// Optional injected [SecurityController] for device security policies.
  final SecurityController? securityController;

  /// Creates the root [LockLeafApp].
  const LockLeafApp({
    super.key,
    this.controller,
    this.securityController,
  });

  @override
  State<LockLeafApp> createState() => _LockLeafAppState();
}

class _LockLeafAppState extends State<LockLeafApp> with WidgetsBindingObserver {
  VaultController? _ownedController;
  SecurityController? _ownedSecurityController;
  late final VaultController _controller;
  SecurityController? _securityController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    final providedController = widget.controller;
    if (providedController != null) {
      _controller = providedController;
      _securityController = widget.securityController;
    } else {
      final vaultService = VaultService(storage: SqliteVaultStorage());
      final createdController = VaultController(vaultService: vaultService);
      _ownedController = createdController;
      _controller = createdController;

      final providedSecurity = widget.securityController;
      if (providedSecurity != null) {
        _securityController = providedSecurity;
      } else {
        final createdSecurity = SecurityController(
          vaultController: createdController,
          biometricManager: BiometricVaultManager(
            vaultService: vaultService,
            secureStorage: FlutterKeychainStorage(),
            biometricAuth: LocalAuthBiometricService(),
          ),
        );
        _ownedSecurityController = createdSecurity;
        _securityController = createdSecurity;
        unawaited(createdSecurity.initialize());
      }
    }

    if (_controller.stage == AuthFlowStage.loading) {
      unawaited(_controller.initialize());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _securityController?.handleLifecycleState(state);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ownedSecurityController?.dispose();
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
        return UnlockScreen(
          controller: _controller,
          securityController: _securityController,
        );
      case AuthFlowStage.unlocked:
        return VaultListScreen(
          controller: _controller,
          securityController: _securityController,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final security = _securityController;
    final listenable = security == null
        ? _controller
        : Listenable.merge(<Listenable>[_controller, security]);

    return ListenableBuilder(
      listenable: listenable,
      builder: (BuildContext context, Widget? child) {
        return MaterialApp(
          title: 'LockLeaf',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: _controller.themeMode,
          builder: (BuildContext context, Widget? appChild) {
            return Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (_) => security?.recordUserActivity(),
              child: PrivacyShieldOverlay(
                visible: security?.isPrivacyOverlayVisible ?? false,
                child: appChild ?? const SizedBox.shrink(),
              ),
            );
          },
          home: _buildHome(),
        );
      },
    );
  }
}
