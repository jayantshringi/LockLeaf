import 'package:flutter/material.dart';
import 'package:lockleaf/core/theme/app_theme.dart';

/// Full-screen opaque shield obscuring vault contents during app switching.
class PrivacyShieldOverlay extends StatelessWidget {
  /// Underlying application UI.
  final Widget child;

  /// Whether the privacy shield is currently active.
  final bool visible;

  /// Creates a [PrivacyShieldOverlay].
  const PrivacyShieldOverlay({
    super.key,
    required this.child,
    required this.visible,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (visible)
          const Positioned.fill(
            child: ColoredBox(
              key: Key('privacy_shield_overlay'),
              color: AppTheme.darkBg,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      size: 72,
                      color: AppTheme.primaryGreen,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'LockLeaf',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
