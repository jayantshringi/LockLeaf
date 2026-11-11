/// Base sealed exception class for all LockLeaf operations.
///
/// Designed intentionally never to print or interpolate raw user secrets.
abstract class AppException implements Exception {
  final String message;
  final String? technicalDetails;

  const AppException(this.message, [this.technicalDetails]);

  @override
  String toString() =>
      technicalDetails == null ? message : '$message ($technicalDetails)';
}

/// Thrown when cryptographic derivation, encryption, or authentication MAC fails.
class CryptoException extends AppException {
  const CryptoException(super.message, [super.technicalDetails]);
}

/// Thrown when attempting to access vault resources while the vault is locked.
class VaultLockedException extends AppException {
  const VaultLockedException(
      [super.message = 'Vault is locked. Master key required.']);
}

/// Thrown on invalid master password or failed biometric authentication.
class AuthenticationException extends AppException {
  const AuthenticationException(super.message, [super.technicalDetails]);
}

/// Thrown on SQLite storage or hardware keystore access errors.
class StorageException extends AppException {
  const StorageException(super.message, [super.technicalDetails]);
}

/// Thrown when input fails security policy validations (e.g., password complexity).
class ValidationException extends AppException {
  const ValidationException(super.message);
}
