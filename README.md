# LockLeaf 🍃

LockLeaf is a modern, production-grade, zero-knowledge password manager engineered for uncompromising security, high usability, and complete privacy across Android, iOS, and desktop platforms.

---

## 🔒 Zero-Knowledge Security Architecture

LockLeaf operates under a strict **Zero-Knowledge Architecture**:

```
+-----------------------------------------------------------------------------------+
|                                  USER DEVICE                                      |
|                                                                                   |
|  [ Master Password ]                                                              |
|          |                                                                        |
|          v                                                                        |
|  [ Argon2id KDF ] ----( Salt + Memory-Hard Derivation )----> [ Master Key (256-bit)]|
|                                                                     |             |
|                               +-------------------------------------+             |
|                               |                                     |             |
|                               v                                     v             |
|                      [ HKDF Subkey Derivation ]             [ AES-256 Key Wrap ]  |
|                               |                                     |             |
|                               v                                     v             |
|                  [ Database & Sync Subkeys ]               [ Hardware Keystore ]  |
|                               |                            (Android / iOS Biometrics)
|                               v                                                   |
|             [ Authenticated Encryption (AEAD) ]                                   |
|                (XChaCha20-Poly1305 / AES-256-GCM)                                 |
|                               |                                                   |
|                               v                                                   |
|                     [ Encrypted SQLite ]                                          |
+-----------------------------------------------------------------------------------+
                                |
                   (Ciphertext Envelopes Only)
                                |
                                v
                +-------------------------------+
                |   Zero-Knowledge Sync Server  |
                |   (Stores only encrypted sync |
                |    records & HMAC tombstones) |
                +-------------------------------+
```

1. **Master Password Never Leaves the Device**: The master password is never stored on disk, never logged, and never transmitted over the network.
2. **Memory-Hard Key Derivation**: Master keys are derived on-device using **Argon2id** (64 MiB memory, 3 iterations, 4 lanes), offering high resistance against GPU, ASIC, and distributed brute-force attacks.
3. **Authenticated Encryption with Associated Data (AEAD)**: Every item payload is protected using authenticated encryption (**XChaCha20-Poly1305** or **AES-256-GCM**) with unique 192-bit / 96-bit cryptographic nonces.
4. **Hardware-Backed Biometric Vault**: On supported devices, biometrics (Face ID, Touch ID, Fingerprint) gate a hardware-backed AES-256 Data Encryption Key (DEK) secured within Android Keystore or iOS Keychain.
5. **Anti-Brute-Force Protection**: Built-in exponential backoff rate limiting locks out authentication attempts after 5 consecutive failures (60s to 15m).
6. **In-Memory Zeroization**: Plaintext credentials and intermediate cryptographic keys are scrubbed immediately from RAM upon completion.

---

## ✨ Features

- 🔐 **Zero-Knowledge Vault**: Store logins, payment cards, secure notes, and identities with end-to-end client-side encryption.
- ⚡ **Biometric Fast Unlock**: Hardware-backed biometric authentication with auto-fallback to master password.
- 🕒 **RFC 6238 / RFC 4226 2FA Authenticator**: Integrated two-factor authentication (TOTP) engine supporting HMAC-SHA-1, HMAC-SHA-256, HMAC-SHA-512, rolling 30s codes, and `otpauth://` URI parsing.
- 🛡️ **Rate-Limiting & Lockout**: Exponential cooldown backoff protection against automated brute-force attacks.
- 🔄 **Ciphertext-Only Cloud Sync**: Multi-device synchronization over REST with deterministic Last-Write-Wins (LWW) conflict resolution and cryptographic deletion tombstones.
- 💾 **Encrypted Portable Backups**: Export and restore password-protected authenticated `.llbak` archives.
- 🔑 **Crockford Base32 Recovery Keys**: Modulo-37 checksummed offline emergency master password reset keys.
- 🎲 **Security Tools**:
  - Offline Diceware passphrase generator (8.0 bits of entropy per word).
  - CSPRNG configurable password generator with unbiased Fisher-Yates shuffling.
  - Local password health audit detecting weak or reused credentials without external lookups.
- 📋 **Secure Clipboard**: Automatic clipboard scrubbing after 30 seconds to prevent credential snooping.
- 🛡️ **App Shielding**: Dynamic screenshot and task-switcher snapshot blocking to prevent visual eavesdropping.

---

## 📱 Technology Stack

- **Framework**: Flutter 3.19+ / Dart 3.3+
- **Cryptographic Primitives**: `package:cryptography` (Argon2id, XChaCha20-Poly1305, AES-256-GCM, HKDF, HMAC)
- **Secure Key Storage**: `package:flutter_secure_storage` (Android Keystore / iOS Keychain)
- **Local Persistence**: `package:sqflite`
- **Biometric Integration**: `package:local_auth` (AndroidX Biometrics / LocalAuthentication)

---

## 🚀 Getting Started

### Prerequisites

- Flutter SDK `^3.19.0`
- Dart SDK `^3.3.0`
- Android Studio / Android SDK (API 34) or Xcode 15+

### Installation & Execution

```bash
# Clone the repository
git clone https://github.com/jayantshringi/LockLeaf.git
cd LockLeaf

# Install dependencies
flutter pub get

# Run the test suite
flutter test

# Run static analysis
flutter analyze

# Launch in debug mode
flutter run
```

### Production Release Builds

```bash
# Android App Bundle (AAB) for Google Play
flutter build appbundle --release

# Android APK for direct distribution
flutter build apk --release

# iOS Release Archive
flutter build ipa --release
```

---

## 🛡️ Security Audit & Verification

LockLeaf features a comprehensive test suite covering cryptographic primitives, state machines, conflict resolution, rate limiters, widget interactions, and memory zeroization.

```bash
flutter test --coverage
```

See [SECURITY.md](SECURITY.md) for our coordinated disclosure policy and vulnerability reporting instructions.

---

## 📜 License

Distributed under the MIT License. See [LICENSE](LICENSE) for details.
