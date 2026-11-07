/// Cryptographic and security policy constants for LockLeaf.
///
/// All values follow modern OWASP and NIST recommendations for password hashing
/// and authenticated encryption.
abstract class SecurityConstants {
  // --- Key Derivation (Argon2id) ---
  /// Recommended Argon2id memory size in kibibytes (64 MiB).
  static const int argon2MemoryKiB = 65536;

  /// Recommended Argon2id iteration count (time cost).
  static const int argon2Iterations = 3;

  /// Argon2id lane parallelism factor.
  static const int argon2Parallelism = 4;

  /// Master derived key output length in bytes (256-bit key).
  static const int derivedKeyLengthBytes = 32;

  /// Minimum salt length in bytes for KDF (256-bit salt).
  static const int saltLengthBytes = 32;

  // --- Symmetric Authenticated Encryption (AEAD) ---
  /// Standard XChaCha20-Poly1305 nonce length in bytes (192-bit nonce).
  static const int xchacha20NonceBytes = 24;

  /// Standard AES-256-GCM nonce (IV) length in bytes (96-bit nonce).
  static const int aesGcmNonceBytes = 12;

  /// Authentication tag length in bytes (128-bit MAC).
  static const int macTagLengthBytes = 16;

  // --- Vault & Application Security Policies ---
  /// Minimum allowed master password length.
  static const int minMasterPasswordLength = 12;

  /// Clipboard auto-clear duration in seconds.
  static const int clipboardClearDelaySeconds = 30;

  /// Default auto-lock idle timeout in seconds (5 minutes).
  static const int defaultAutoLockTimeoutSeconds = 300;

  /// Rate limiting: maximum login attempts before cooldown lockout.
  static const int maxFailedLoginAttempts = 5;

  /// Lockout cooldown duration in seconds.
  static const int failedAttemptLockoutSeconds = 60;
}
