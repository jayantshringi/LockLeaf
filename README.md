# LockLeaf 🍃

LockLeaf is a modern, zero-knowledge password manager engineered for uncompromising security, high usability, and cross-platform reliability on Android and iOS.

---

## 🔒 Security Architecture & Zero-Knowledge Model

LockLeaf adheres strictly to the **zero-knowledge principle**:

1. **Master Password Never Leaves the Device**: The master password is never written to disk, never logged, and never transmitted over any network.
2. **Cryptographic Key Derivation**: Master keys are derived on-device using **Argon2id** (memory-hard, resistant to GPU/ASIC cracking).
3. **Authenticated Encryption with Associated Data (AEAD)**: Vault items are encrypted using **XChaCha20-Poly1305** or **AES-256-GCM** via vetted, audited libraries (`cryptography`).
4. **Unique Salts and Nonces**: Every encryption operation generates a cryptographically secure random salt and nonce (`Random.secure()`).
5. **Encrypted Local Storage**: Database records store only authenticated ciphertext payloads.
6. **Zero Cloud Knowledge**: Any optional sync backend stores exclusively encrypted blobs. Without the user's master key derived locally, ciphertext is indistinguishable from random noise.

---

## 📱 Technology Stack

- **Framework**: Flutter (Dart 3)
- **Cryptography**: `cryptography` package (vetted Argon2id, XChaCha20-Poly1305, AES-256-GCM, HKDF)
- **Secure Key Storage**: `flutter_secure_storage` (Android Keystore / iOS Keychain)
- **Local Persistence**: `sqflite` for encrypted relational storage
- **Biometrics**: `local_auth` (FaceID, TouchID, Android Biometrics)

---

## 🛡️ Project Roadmap & Phases

- **Phase 1**: Setup (scaffolding, configuration, linting, CI)
- **Phase 2**: Crypto Core (Argon2id, AEAD ciphers, secure random, unit tests)
- **Phase 3**: Vault Logic (data models, CRUD, encrypted local DB, lock/unlock)
- **Phase 4**: Auth & UI (onboarding, master password strength, vault UI, dark mode)
- **Phase 5**: Device Security (biometrics, secure storage, auto-lock, clipboard clearing, screenshot blocking)
- **Phase 6**: Security Tools (password generator, passphrase generator, health audit)
- **Phase 7**: Backup & Recovery (encrypted portable backup, recovery keys)
- **Phase 8**: Cloud Sync (ciphertext-only synchronization, conflict resolution)
- **Phase 9**: Hardening (2FA/TOTP, rate limiting, dependency auditing, threat modeling)
- **Phase 10**: Release (documentation, store listing, v1.0.0 tag)

---

## 🚀 Getting Started

### Prerequisites

- Flutter SDK (v3.19.0 or later)
- Dart SDK (v3.3.0 or later)
- Android Studio / Xcode for platform toolchains

### Running Tests

```bash
flutter test
```

### Static Analysis

```bash
flutter analyze
```

---

## 📜 License

Distributed under the MIT License. See [LICENSE](LICENSE) for details.
