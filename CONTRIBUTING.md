# Contributing to LockLeaf

Thank you for your interest in contributing to LockLeaf! As a zero-knowledge password manager handling sensitive credentials, we maintain strict engineering and security standards.

---

## 🔒 Cryptographic & Security Rules (Non-Negotiable)

When contributing code to LockLeaf, the following rules must be strictly adhered to without exception:

1. **No Custom Cryptography:**
   Never implement proprietary or unvetted cryptographic algorithms. All cryptographic primitives must originate from vetted, reviewed libraries (specifically `package:cryptography` and platform-backed keystores).
2. **Strict Nonce Uniqueness:**
   Never reuse a cryptographic nonce or IV. Every AEAD encryption operation must generate a fresh, cryptographically secure random nonce via `SecureRandomService` (24 bytes for XChaCha20-Poly1305, 12 bytes for AES-256-GCM).
3. **Zero Secret Logging or Retention:**
   Never log, print, persist in plaintext, or serialize master passwords, derived keys, or plaintext entries. `AppException` subclasses and debug logs must never interpolate user secrets.
4. **Immediate In-Memory Zeroization:**
   Sensitive byte arrays, intermediate keys, and secret buffers must be wiped (`fillRange(0, length, 0)`) immediately after their cryptographic operation concludes.
5. **No Unjustified Dependencies:**
   Do not introduce new third-party dependencies unless strictly necessary and thoroughly vetted. Every dependency adds supply chain attack surface.
6. **HTTPS Strict Transport:**
   Network communication (such as REST sync) must strictly enforce TLS/HTTPS. Cleartext HTTP is forbidden except for local loopback in debug mode.

---

## 🛠️ Development Workflow

1. **Fork and Clone:**
   ```bash
   git clone https://github.com/jayantshringi/LockLeaf.git
   cd LockLeaf
   ```

2. **Branching:**
   Create a dedicated feature or bugfix branch from `main`:
   ```bash
   git checkout -b fix/issue-description
   ```

3. **Code Formatting & Linting:**
   Ensure your code conforms to standard Dart style:
   ```bash
   dart format --output=none --set-exit-if-changed .
   flutter analyze --fatal-warnings
   ```

4. **Testing:**
   All new features and fixes must include corresponding tests:
   ```bash
   flutter test --coverage
   ```

5. **Commit Conventions:**
   Use conventional commit messages (`feat:`, `fix:`, `docs:`, `ci:`, `chore:`, `test:`, `style:`). Keep commits small, logical, and focused on one task.

6. **Pull Requests:**
   Submit a PR against `main`. Fill out the [Pull Request Template](.github/PULL_REQUEST_TEMPLATE.md) completely, including security considerations and verification steps.

---

## 🚨 Security Vulnerabilities

Please **do not** use GitHub Issues to report security vulnerabilities. Refer to [SECURITY.md](SECURITY.md) to submit reports via GitHub Private Vulnerability Reporting.
