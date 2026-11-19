# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-11-19

### Added
- **Zero-Knowledge Core:**
  - Client-side master key derivation using Argon2id (64 MiB memory, 3 iterations, 4 lanes, 256-bit derived key).
  - Authenticated symmetric encryption (AEAD) with XChaCha20-Poly1305 and AES-256-GCM using unique CSPRNG nonces per record.
  - Subkey derivation via HKDF-SHA256 for segregated database and sync keys.
  - Sensitive byte zeroization in memory upon completion of cryptographic routines.
- **Vault Management:**
  - Full CRUD operations for logins, credit cards, secure notes, and identities.
  - Encrypted local SQLite persistence storing exclusively authenticated ciphertext envelopes.
  - Full-text search and category filtering over decrypted in-memory records.
- **Device Security & Biometrics:**
  - Hardware-backed biometric quick-unlock (Android Keystore / AndroidX Biometrics).
  - Configurable idle auto-lock timer with lifecycle listening.
  - Anti-brute-force rate limiter with exponential lockout backoff (5 attempts, 60s to 15m).
  - Window security flags blocking screenshots and task-switcher previews.
  - Auto-clearing secure clipboard service (30-second countdown).
- **Authentication & Security Tools:**
  - Integrated RFC 6238 / RFC 4226 2FA TOTP authenticator with `otpauth://` URI support.
  - Offline Diceware passphrase generator and configurable CSPRNG password generator.
  - Local password health audit detecting weak, duplicate, or compromised passwords without network queries.
  - Password-protected encrypted backup export and import (`.llbak` archives).
  - Crockford Base32 emergency recovery key generation with Modulo-37 error-detection check character.
- **Cloud Sync:**
  - End-to-end encrypted REST sync client with strict HTTPS enforcement.
  - Deterministic Last-Write-Wins (LWW) conflict resolution and cryptographic deletion tombstones.
- **Release & Distribution Hardening:**
  - Automated GitHub Releases workflow building split-per-ABI APKs (`arm64-v8a`, `armeabi-v7a`, `x86_64`).
  - Cryptographic SLSA build provenance attestations via GitHub Actions.
  - Automatic `SHA256SUMS.txt` generation and verification.
  - Production keystore signature verification step with `apksigner`.

### Changed
- Explicitly elevated Android `minSdkVersion` to 24 (Android 7.0+) for consistency with modern dependencies.
- Updated sync transport to strictly reject plain HTTP connections (with exception only for local loopback in debug mode).
- Removed deprecated `android.permission.USE_FINGERPRINT` in favor of `USE_BIOMETRIC`.
- Replaced monolithic debug-signed release APK with per-ABI release builds.
