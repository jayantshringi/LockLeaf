## Description
<!-- Provide a concise summary of the changes and motivation. -->

## Type of Change
- [ ] `fix`: Bug fix
- [ ] `feat`: New feature
- [ ] `docs`: Documentation update
- [ ] `style`: Formatting or code style adjustment
- [ ] `refactor`: Code change that neither fixes a bug nor adds a feature
- [ ] `perf`: Performance optimization
- [ ] `test`: Adding or updating tests
- [ ] `ci`: CI/CD workflow update
- [ ] `chore`: Maintenance or repository tooling

## Security Checklist (Mandatory for All PRs)
- [ ] **No Custom Crypto:** Uses only standard primitives from `package:cryptography` or platform keystores.
- [ ] **Nonce Uniqueness:** Generates fresh CSPRNG nonces for every encryption operation; zero nonce reuse.
- [ ] **Zero Secret Logging:** Master passwords, plaintext credentials, and keys are never printed, logged, or serialized.
- [ ] **Memory Zeroization:** Sensitive buffers are explicitly wiped from memory when operations complete.
- [ ] **No Plaintext Network Traffic:** Enforces HTTPS for external transport.
- [ ] **No New Unvetted Dependencies:** No unnecessary dependencies added to `pubspec.yaml`.

## Testing & Verification
- [ ] `dart format --output=none --set-exit-if-changed .` passes cleanly.
- [ ] `flutter analyze --fatal-warnings` passes with zero issues.
- [ ] `flutter test` passes all unit and widget tests.
- [ ] Added unit or widget tests covering any new behavior.
