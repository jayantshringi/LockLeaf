import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:lockleaf/core/errors/app_exception.dart';

/// Abstraction over hardware-backed key storage (Android Keystore / iOS Keychain).
abstract class SecureKeyStorage {
  /// Writes a [value] under [key] in hardware-backed secure storage.
  Future<void> write({required String key, required String value});

  /// Reads the value associated with [key], or null if missing.
  Future<String?> read(String key);

  /// Deletes any value stored under [key].
  Future<void> delete(String key);

  /// Deletes all LockLeaf-managed entries from secure storage.
  Future<void> deleteAll();
}

/// Concrete [SecureKeyStorage] backed by `flutter_secure_storage`.
class FlutterKeychainStorage implements SecureKeyStorage {
  static const AndroidOptions _androidOptions = AndroidOptions(
    encryptedSharedPreferences: true,
  );

  static const IOSOptions _iosOptions = IOSOptions(
    accessibility: KeychainAccessibility.unlocked_this_device,
  );

  final FlutterSecureStorage _storage;

  /// Creates a [FlutterKeychainStorage] with hardened platform options.
  FlutterKeychainStorage({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: _androidOptions,
              iOptions: _iosOptions,
            );

  Future<T> _runStorage<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on PlatformException catch (error) {
      throw StorageException(
        'Secure hardware storage operation failed.',
        error.code,
      );
    }
  }

  @override
  Future<void> write({required String key, required String value}) {
    return _runStorage(
      () => _storage.write(
        key: key,
        value: value,
        aOptions: _androidOptions,
        iOptions: _iosOptions,
      ),
    );
  }

  @override
  Future<String?> read(String key) {
    return _runStorage(
      () => _storage.read(
        key: key,
        aOptions: _androidOptions,
        iOptions: _iosOptions,
      ),
    );
  }

  @override
  Future<void> delete(String key) {
    return _runStorage(
      () => _storage.delete(
        key: key,
        aOptions: _androidOptions,
        iOptions: _iosOptions,
      ),
    );
  }

  @override
  Future<void> deleteAll() {
    return _runStorage(
      () => _storage.deleteAll(
        aOptions: _androidOptions,
        iOptions: _iosOptions,
      ),
    );
  }
}
