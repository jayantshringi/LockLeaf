import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lockleaf/core/constants/security_constants.dart';
import 'package:lockleaf/core/theme/app_theme.dart';
import 'package:lockleaf/features/security/presentation/security_controller.dart';

/// Device security preferences screen (biometrics, auto-lock, screen shield).
class SecuritySettingsScreen extends StatelessWidget {
  /// Controller managing hardware security policies.
  final SecurityController securityController;

  /// Creates a [SecuritySettingsScreen].
  const SecuritySettingsScreen({
    super.key,
    required this.securityController,
  });

  static const List<Duration> _timeoutOptions = <Duration>[
    Duration(seconds: 30),
    Duration(minutes: 1),
    Duration(minutes: 5),
    Duration(minutes: 15),
  ];

  String _formatDuration(Duration duration) {
    if (duration.inMinutes >= 1) {
      final mins = duration.inMinutes;
      return '$mins ${mins == 1 ? 'minute' : 'minutes'}';
    }
    return '${duration.inSeconds} seconds';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: securityController,
      builder: (BuildContext context, Widget? child) {
        final supported = securityController.biometricSupported;
        final error = securityController.securityError;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Device Security'),
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (error != null) ...[
                  Container(
                    key: const Key('settings_security_error'),
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.danger.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      error,
                      style: const TextStyle(color: AppTheme.danger),
                    ),
                  ),
                ],
                Card(
                  child: Column(
                    children: [
                      SwitchListTile(
                        key: const Key('settings_biometric_switch'),
                        secondary: const Icon(
                          Icons.fingerprint,
                          color: AppTheme.primaryGreen,
                        ),
                        title: const Text('Biometric Unlock'),
                        subtitle: Text(
                          supported
                              ? 'Seals vault key in Keystore / Keychain without storing master password'
                              : 'Biometric hardware or enrollment unavailable',
                        ),
                        value: securityController.biometricEnabled,
                        onChanged: supported
                            ? (bool value) {
                                unawaited(
                                  securityController
                                      .toggleBiometricUnlock(value),
                                );
                              }
                            : null,
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(
                          Icons.timer_outlined,
                          color: AppTheme.primaryGreen,
                        ),
                        title: const Text('Auto-Lock Timeout'),
                        subtitle: const Text('Lock vault after inactivity'),
                        trailing: DropdownButton<Duration>(
                          key: const Key('settings_autolock_dropdown'),
                          value: _timeoutOptions.contains(
                            securityController.autoLockTimeout,
                          )
                              ? securityController.autoLockTimeout
                              : const Duration(minutes: 5),
                          underline: const SizedBox.shrink(),
                          items: _timeoutOptions
                              .map(
                                (Duration option) => DropdownMenuItem<Duration>(
                                  value: option,
                                  child: Text(_formatDuration(option)),
                                ),
                              )
                              .toList(),
                          onChanged: (Duration? selected) {
                            if (selected != null) {
                              securityController.updateAutoLockTimeout(
                                selected,
                              );
                            }
                          },
                        ),
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        key: const Key('settings_background_lock_switch'),
                        secondary: const Icon(
                          Icons.phonelink_lock_outlined,
                          color: AppTheme.primaryGreen,
                        ),
                        title: const Text('Lock on Background'),
                        subtitle: const Text(
                          'Immediately lock when leaving or minimizing app',
                        ),
                        value: securityController.lockOnBackground,
                        onChanged: securityController.setLockOnBackground,
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        key: const Key('settings_screenshot_block_switch'),
                        secondary: const Icon(
                          Icons.screenshot_monitor_outlined,
                          color: AppTheme.primaryGreen,
                        ),
                        title: const Text('Block Screenshots & Previews'),
                        subtitle: const Text(
                          'Enables FLAG_SECURE and masks app switcher preview',
                        ),
                        value: securityController.screenshotBlockingEnabled,
                        onChanged: (bool value) {
                          unawaited(
                            securityController.setScreenshotBlocking(value),
                          );
                        },
                      ),
                      const Divider(height: 1),
                      const ListTile(
                        leading: Icon(
                          Icons.content_paste_off_outlined,
                          color: AppTheme.primaryGreen,
                        ),
                        title: Text('Clipboard Auto-Clear'),
                        subtitle: Text(
                          'Copied secrets are wiped automatically after '
                          '${SecurityConstants.clipboardClearDelaySeconds} seconds',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
