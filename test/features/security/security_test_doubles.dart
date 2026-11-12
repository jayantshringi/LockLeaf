import 'package:lockleaf/features/security/data/biometric_auth_service.dart';
import 'package:lockleaf/features/security/data/screenshot_protection_service.dart';
import 'package:lockleaf/features/security/data/secure_key_storage.dart';
import 'package:lockleaf/features/security/domain/secure_clipboard_service.dart';

/// In-memory [SecureKeyStorage] test double simulating Keystore / Keychain.
class InMemorySecureKeyStorage implements SecureKeyStorage {
  final Map<String, String> _values = <String, String>{};

  /// Unmodifiable snapshot of stored keys/values for security assertions.
  Map<String, String> get entries => Map<String, String>.unmodifiable(_values);

  @override
  Future<void> write({required String key, required String value}) async {
    _values[key] = value;
  }

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> delete(String key) async {
    _values.remove(key);
  }

  @override
  Future<void> deleteAll() async {
    _values.clear();
  }
}

/// Configurable [BiometricAuthService] test double.
class FakeBiometricAuthService implements BiometricAuthService {
  /// Whether hardware biometrics report available.
  bool available;

  /// Whether the next authentication prompt succeeds.
  bool shouldAuthenticate;

  /// Count of authentication prompt invocations.
  int promptCount = 0;

  FakeBiometricAuthService({
    this.available = true,
    this.shouldAuthenticate = true,
  });

  @override
  Future<bool> isBiometricsAvailable() async => available;

  @override
  Future<bool> authenticate({required String reason}) async {
    promptCount++;
    return available && shouldAuthenticate;
  }
}

/// In-memory [ClipboardAdapter] test double.
class InMemoryClipboardAdapter implements ClipboardAdapter {
  /// Current clipboard text value.
  String? currentText;

  /// Number of times [clear] was invoked.
  int clearCount = 0;

  @override
  Future<void> setText(String text) async {
    currentText = text;
  }

  @override
  Future<String?> getText() async => currentText;

  @override
  Future<void> clear() async {
    clearCount++;
    currentText = '';
  }
}

/// Recording [ScreenshotProtectionService] test double.
class FakeScreenshotProtectionService implements ScreenshotProtectionService {
  /// History of calls made to [setEnabled].
  final List<bool> calls = <bool>[];

  /// Latest configured state.
  bool get latestEnabled => calls.isEmpty ? false : calls.last;

  @override
  Future<void> setEnabled(bool enabled) async {
    calls.add(enabled);
  }
}
