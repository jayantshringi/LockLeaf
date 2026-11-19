# LockLeaf Release & Signing Guide

This guide details the end-to-end process for generating production signing keys, configuring GitHub repository secrets, tagging releases, and verifying distributed release APKs.

---

## 1. Keystore Generation (Maintainer Only)

LockLeaf release APKs are signed using a standard RSA/PKCS12 or JKS keystore. Generate the release keystore securely on your local development workstation:

```bash
keytool -genkeypair -v \
  -keystore lockleaf-release-keystore.jks \
  -alias lockleaf \
  -keyalg RSA \
  -keysize 4096 \
  -validity 10000 \
  -storetype JKS
```

> **Warning:** Back up `lockleaf-release-keystore.jks` and its passwords in a secure, encrypted offline location. If you lose this key, existing sideloaded installations cannot be upgraded seamlessly without uninstalling and losing locally stored data.

### Inspect the Certificate Fingerprint
Extract the SHA-256 certificate digest before uploading:

```bash
keytool -list -v -keystore lockleaf-release-keystore.jks -alias lockleaf
```
Note the `SHA256: XX:XX:XX:...` fingerprint for verification and documentation.

---

## 2. Configure GitHub Repository Secrets

The release workflow (`.github/workflows/release.yml`) strictly requires 4 repository secrets. Navigate to **Settings > Secrets and variables > Actions > New repository secret** in your GitHub repository and define:

| Secret Name | Value Description |
| ----------- | ----------------- |
| `ANDROID_KEYSTORE_BASE64` | Base64-encoded string of `lockleaf-release-keystore.jks` (`base64 -w 0 lockleaf-release-keystore.jks` or `[Convert]::ToBase64String([IO.File]::ReadAllBytes('lockleaf-release-keystore.jks'))`) |
| `ANDROID_KEYSTORE_PASSWORD` | Password protecting the keystore file |
| `ANDROID_KEY_ALIAS` | Key alias name (e.g., `lockleaf`) |
| `ANDROID_KEY_PASSWORD` | Password protecting the key alias |

---

## 3. Creating and Tagging a Release

1. Ensure all changes are merged into `main` and the CI workflow is completely green.
2. Update `version` in `pubspec.yaml` (e.g., `1.0.0+1`) and document changes in [CHANGELOG.md](../CHANGELOG.md).
3. Create an annotated git tag and push it:
   ```bash
   git tag -a v1.0.0 -m "Release v1.0.0"
   git push origin v1.0.0
   ```
   *(Note: Any tag containing a hyphen, such as `v1.0.0-rc.1` or `v1.0.0-beta.1`, is automatically published as a GitHub **Pre-release**).*

4. Alternatively, trigger the workflow manually from the GitHub Actions UI:
   - Select the **LockLeaf GitHub Release** workflow.
   - Click **Run workflow**, choose `main`, and enter the release tag (e.g. `v1.0.0`).

---

## 4. Release Verification Checklist

Once the workflow completes, verify the published assets:

1. **Download Release Assets:**
   - `LockLeaf-<TAG>-arm64-v8a.apk`
   - `LockLeaf-<TAG>-armeabi-v7a.apk`
   - `LockLeaf-<TAG>-x86_64.apk`
   - `SHA256SUMS.txt`

2. **Verify Checksums:**
   ```bash
   sha256sum -c SHA256SUMS.txt
   ```

3. **Verify Signing Certificate:**
   ```bash
   apksigner verify --print-certs LockLeaf-<TAG>-arm64-v8a.apk
   ```
   Confirm that:
   - It is signed with your production release key.
   - The output does **NOT** contain `Android Debug`.
   - The SHA-256 digest matches your generated keystore fingerprint.

4. **Verify GitHub SLSA Build Provenance:**
   ```bash
   gh attestation verify LockLeaf-<TAG>-arm64-v8a.apk --owner jayantshringi
   ```

5. **Post-Release Maintainer Task:**
   After the first signed release, paste the permanent release certificate SHA-256 fingerprint into `README.md` replacing `<PASTE FINGERPRINT AFTER FIRST RELEASE>`.
