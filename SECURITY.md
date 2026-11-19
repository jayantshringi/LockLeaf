# Security Policy

## 🔒 Zero-Knowledge Guarantee

LockLeaf is designed under a strict **Zero-Knowledge Architecture**:
- All cryptographic key derivation and data encryption/decryption happen exclusively on the user's client device.
- The master password is never transmitted across the network, never stored in plaintext, and never logged.
- Server backends and synchronization endpoints receive and store only authenticated ciphertext envelopes and encrypted sync records.

---

## 🛡️ Supported Versions

Only the latest active release receives security updates:

| Version | Supported          |
| ------- | ------------------ |
| 1.0.x   | :white_check_mark: |
| < 1.0   | :x:                |

---

## 🚨 Reporting a Vulnerability

We take the security and integrity of LockLeaf very seriously. If you believe you have discovered a security vulnerability, cryptographic weakness, or unintended exposure:

1. **Do NOT open a public GitHub issue.** Public issues disclose potential vulnerabilities before a fix is available to users.
2. **Submit a Private Report via GitHub:**
   Please use [GitHub Private Vulnerability Reporting](https://github.com/jayantshringi/LockLeaf/security/advisories/new) to submit your advisory directly and confidentially to the maintainer.
3. Include the following information in your report:
   - Type of issue (e.g., KDF configuration flaw, AEAD nonce reuse, memory zeroization failure, side-channel leak, authentication bypass).
   - Detailed proof of concept, reproduction steps, or affected code references.
   - Any proposed mitigations or patch suggestions if available.

### Responsible Disclosure & Response Targets
- **Initial Acknowledgment:** Within **3 business days**.
- **Triage & Severity Assessment:** Within **10 business days**.
- **Coordinated Disclosure:** We request a coordinated disclosure embargo of up to **90 days** from initial report to allow adequate time to validate the fix, issue an update on GitHub Releases, and give sideloading users time to update their installations.
