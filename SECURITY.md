# Security Policy

## 🔒 Zero-Knowledge Guarantee

LockLeaf is designed from the ground up under a strict **Zero-Knowledge Architecture**:
- All cryptographic key derivation and data encryption/decryption happen exclusively on the user's client device.
- The master password is never transmitted, stored in plaintext, or saved into memory dumps.
- Server backends and synchronization endpoints receive exclusively authenticated ciphertext blobs.

---

## 🛡️ Supported Versions

Only the latest active release and current development branch receive security updates:

| Version | Supported          |
| ------- | ------------------ |
| 1.0.x   | :white_check_mark: |
| < 1.0   | :x:                |

---

## 🚨 Reporting a Vulnerability

We take the security of LockLeaf very seriously. If you believe you have discovered a security vulnerability or cryptographic weakness:

1. **Do NOT open a public GitHub issue.**
2. Send a detailed report via encrypted email to `localeaf.support@gmail.com` (or file a private GitHub Advisory on the repository).
3. Include the following details:
   - Type of issue (e.g., KDF implementation flaw, AEAD nonce reuse, memory leak, side-channel vulnerability).
   - Detailed proof of concept or reproduction steps.
   - Any proposed mitigations or code patches.

### Response Timelines
- **Initial acknowledgment**: Within 24 hours.
- **Triage and severity assessment**: Within 72 hours.
- **Remediation release**: We strive to ship security patches within 7 business days depending on complexity.
- **Coordinated Disclosure**: We request a 90-day embargo period prior to public disclosure to allow users time to update their applications.
