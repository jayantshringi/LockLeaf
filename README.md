# LockLeaf 🍃

[![LockLeaf CI](https://github.com/jayantshringi/LockLeaf/actions/workflows/ci.yml/badge.svg)](https://github.com/jayantshringi/LockLeaf/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-3.19+-02569B.svg?logo=flutter)](https://flutter.dev)
[![Platform](https://img.shields.io/badge/Platform-Android%207.0%2B%20(API%2024%2B)-brightgreen.svg)](android)

LockLeaf is a modern, zero-knowledge password manager engineered for privacy, security, and simplicity on Android.

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
|                               |                            (Android Biometrics)   |
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
4. **Hardware-Backed Biometric Vault**: On supported devices, biometrics (Fingerprint, Face Unlock) gate a hardware-backed AES-256 Data Encryption Key (DEK) secured within the Android Keystore.
5. **Anti-Brute-Force Protection**: Built-in exponential backoff rate limiting locks out authentication attempts after 5 consecutive failures (60s to 15m).
6. **In-Memory Zeroization**: Plaintext credentials and intermediate cryptographic keys are scrubbed immediately from RAM upon completion.

---

## ✨ Features

- 🔐 **Zero-Knowledge Vault**: Store logins, payment cards, secure notes, and identities with end-to-end client-side encryption.
- ⚡ **Biometric Fast Unlock**: Hardware-backed biometric authentication with auto-fallback to master password.
- 🕒 **RFC 6238 / RFC 4226 2FA Authenticator**: Integrated two-factor authentication (TOTP) engine supporting HMAC-SHA-1, HMAC-SHA-256, HMAC-SHA-512, rolling 30s codes, and `otpauth://` URI parsing.
- 🛡️ **Rate-Limiting & Lockout**: Exponential cooldown backoff protection against automated brute-force attacks.
- 🔄 **Ciphertext-Only Cloud Sync**: Multi-device synchronization over HTTPS REST with deterministic Last-Write-Wins (LWW) conflict resolution and cryptographic deletion tombstones.
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

- **Target Platform**: Android (API 24+ / Android 7.0 through Android 15)
- **Framework**: Flutter 3.19+ / Dart 3.3+
- **Cryptographic Primitives**: `package:cryptography` (Argon2id, XChaCha20-Poly1305, AES-256-GCM, HKDF, HMAC)
- **Secure Key Storage**: `package:flutter_secure_storage` (Android Keystore)
- **Local Persistence**: `package:sqflite`
- **Biometric Integration**: `package:local_auth` (AndroidX Biometrics)

---

## 📦 Install & Verify

LockLeaf is distributed exclusively through [GitHub Releases](https://github.com/jayantshringi/LockLeaf/releases). It is not distributed via Google Play Store. Because you are sideloading the application, verifying release integrity is strongly recommended.

### 1. Select the Right APK for Your Device
- **`LockLeaf-<TAG>-arm64-v8a.apk`**: Recommended for almost all modern Android phones and tablets (64-bit ARM).
- **`LockLeaf-<TAG>-armeabi-v7a.apk`**: For older 32-bit Android phones.
- **`LockLeaf-<TAG>-x86_64.apk`**: For Android emulators and x86_64 devices.

### 2. Verify SHA-256 Checksums
Download the APK and the matching `SHA256SUMS.txt` from the release page, then run:

```bash
sha256sum -c SHA256SUMS.txt
```

Ensure the output confirms `OK` for your chosen APK.

### 3. Verify Signing Certificate
All official LockLeaf release APKs are signed with the maintainer's production release key. You can inspect the signing certificate using Android's `apksigner` tool:

```bash
apksigner verify --print-certs LockLeaf-<TAG>-arm64-v8a.apk
```

**Expected Certificate SHA-256 Fingerprint:**
```
<PASTE FINGERPRINT AFTER FIRST RELEASE>
```
*(Verify that the printed SHA-256 digest matches the fingerprint published above and in the release notes).*

### 4. Sideloading Notes
- **"Install unknown apps" Prompt:** Android will ask for permission when installing an APK downloaded through your browser or a file manager. Open **Settings > Apps > Special app access > Install unknown apps** and enable permission for the app initiating the install.
- **Google Play Protect Notice:** Because LockLeaf is distributed outside Google Play and signs releases with an independent developer key, Play Protect may present an "Unrecognized app" dialog on initial install. Tap **More details** and select **Install anyway**.

### 5. Automatic Updates via Obtainium
To receive automatic update notifications and install releases seamlessly, you can use [Obtainium](https://github.com/ImranR98/Obtainium):
1. Install Obtainium on your Android device.
2. Select **Add App** and enter the repository URL: `https://github.com/jayantshringi/LockLeaf`.
3. Obtainium will track new GitHub releases, verify release assets, and prompt you whenever a new version is available.

---

## ⚠️ Limitations & Threat Model Assumptions

- **Not Independently Audited:** LockLeaf employs vetted cryptographic standards (Argon2id, XChaCha20-Poly1305, AES-256-GCM) implemented by vetted libraries, but this software has **not been independently audited by a third-party security firm**. Review the code or use at your own discretion.
- **Compromised Host Security:** If your host Android device is rooted, infected with kernel/OS-level malware, or actively compromised by an adversary with root or hardware debugging access, client-side encryption and memory zeroization cannot provide absolute security guarantees.
- **Irrecoverability by Design:** LockLeaf has no backdoors and stores no keys on remote servers. If you lose your master password AND misplace your emergency recovery key, your vault data is permanently and mathematically unrecoverable.

---

## 🛠️ Building From Source

### Prerequisites
- Flutter SDK `^3.19.0`
- Dart SDK `^3.3.0`
- Android Studio / Android SDK (API 34+)
- JDK 17

```bash
# Clone the repository
git clone https://github.com/jayantshringi/LockLeaf.git
cd LockLeaf

# Install dependencies
flutter pub get

# Run test suite
flutter test

# Run static analysis
flutter analyze

# Build release APKs (split per ABI)
flutter build apk --release --split-per-abi
```

For release procedures and signing configurations, refer to [docs/RELEASING.md](docs/RELEASING.md).

---

## 🤝 Contributing

Contributions are welcome! Please read [CONTRIBUTING.md](CONTRIBUTING.md) for details on code style, cryptographic rules, and pull request guidelines.

---

## 📜 License

Distributed under the MIT License. See [LICENSE](LICENSE) for details.
