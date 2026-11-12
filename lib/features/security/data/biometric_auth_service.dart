import 'package:flutter/services.dart';
import 'package:local_auth/error_codes.dart' as auth_error;
import 'package:local_auth/local_auth.dart';
import 'package:lockleaf/core/errors/app_exception.dart';

/// Abstraction for device biometric authentication (Face ID / Touch ID / Fingerprint).
abstract class BiometricAuthService {
  /// Returns true if the device has biometric hardware with enrolled credentials.
  Future<bool> isBiometricsAvailable();

  /// Prompts the user for biometric verification with [reason].
  Future<bool> authenticate({required String reason});
}

/// Concrete [BiometricAuthService] backed by `local_auth`.
class LocalAuthBiometricService implements BiometricAuthService {
  final LocalAuthentication _localAuth;

  /// Creates a [LocalAuthBiometricService].
  LocalAuthBiometricService({LocalAuthentication? localAuth})
      : _localAuth = localAuth ?? LocalAuthentication();

  @override
  Future<bool> isBiometricsAvailable() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final deviceSupported = await _localAuth.isDeviceSupported();
      if (!canCheck || !deviceSupported) {
        return false;
      }
      final enrolled = await _localAuth.getAvailableBiometrics();
      return enrolled.isNotEmpty;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<bool> authenticate({required String reason}) async {
    try {
      final available = await isBiometricsAvailable();
      if (!available) {
        throw const AuthenticationException(
          'Biometric authentication is unavailable on this device.',
        );
      }

      return await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
    } on AuthenticationException {
      rethrow;
    } on PlatformException catch (error) {
      if (error.code == auth_error.lockedOut ||
          error.code == auth_error.permanentlyLockedOut) {
        throw const AuthenticationException(
          'Biometrics locked due to too many attempts. Use your master password.',
        );
      }
      throw AuthenticationException(
        'Biometric authentication failed.',
        error.code,
      );
    }
  }
}
