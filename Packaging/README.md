# GoldSun Packaging

GoldSun ships as a macOS app bundle plus an installer package that places the app in `/Applications`.

## Local package

```bash
./script/package_release.sh 0.2.17
```

Artifacts are written to `release/0.2.17/`.

## Chromium/CEF runtime layout

When `ThirdParty/CEFCache/current` exists (created by `script/fetch_cef.sh`), `script/bundle_cef.sh` adds the Chromium runtime to the app bundle:

```text
GoldSun.app/Contents/Frameworks/Chromium Embedded Framework.framework
GoldSun.app/Contents/Frameworks/GoldSun Helper.app
GoldSun.app/Contents/Frameworks/GoldSun Helper (Alerts).app
GoldSun.app/Contents/Frameworks/GoldSun Helper (GPU).app
GoldSun.app/Contents/Frameworks/GoldSun Helper (Plugin).app
GoldSun.app/Contents/Frameworks/GoldSun Helper (Renderer).app
```

All five helper bundles wrap the same `GoldSunCEFHelper` binary; Chromium picks the variant per process type. When the CEF cache is absent (for example on CI today), `bundle_cef.sh` is a no-op and the app ships WebKit-only.

### Signing order

Nested code must be signed inside-out, which `bundle_cef.sh` and `package_release.sh` already do in sequence:

1. Dylibs inside `Chromium Embedded Framework.framework/Libraries`
2. `Chromium Embedded Framework.framework`
3. Each `GoldSun Helper*.app` (with `Packaging/GoldSunHelper.entitlements` when using a real identity)
4. `GoldSun.app` itself (`Packaging/GoldSun.entitlements`)

Verify with `codesign --verify --deep --strict GoldSun.app`.

### Entitlements

- The main app entitlements include `com.apple.security.cs.disable-library-validation` and `com.apple.security.cs.allow-unsigned-executable-memory` because the CEF framework is loaded with `dlopen` and is not signed with the app's identity.
- Helpers need `allow-jit`, `allow-unsigned-executable-memory`, and `disable-library-validation` under the hardened runtime (`Packaging/GoldSunHelper.entitlements`).

### Keychain note

The embedded Chromium currently runs with `--use-mock-keychain` (set in `GoldSunCEFBridge`). Without it, Chromium stores its cookie-encryption key in the macOS Keychain, and because prerelease builds are ad-hoc signed, every new build triggers a Keychain password prompt and blocks page loads until answered. Once Developer ID signing is standard, remove the switch so profile data gets real at-rest encryption.

### Notarization plan for CEF builds

Developer ID + notarization for a CEF-bundled app requires:

1. Sign everything in the order above with the hardened runtime enabled.
2. Keep the helper entitlements minimal (the three listed above).
3. Notarize the `.pkg`/`.dmg` as usual; the CEF framework and helpers are scanned as nested code, so no extra steps beyond correct signing order are expected.
4. Budget for artifact size: the CEF framework adds roughly 300 MB uncompressed to the bundle.

## Signing

For local development, the script falls back to ad-hoc signing. For an official Gatekeeper-friendly release, export these values before packaging:

```bash
export GOLDSUN_SIGNING_IDENTITY="Developer ID Application: Your Name (TEAMID)"
export GOLDSUN_INSTALLER_SIGNING_IDENTITY="Developer ID Installer: Your Name (TEAMID)"
```

## Notarization

Create a notarytool keychain profile once:

```bash
xcrun notarytool store-credentials GoldSunNotaryProfile \
  --apple-id "you@example.com" \
  --team-id "TEAMID" \
  --password "app-specific-password"
```

Then package with notarization enabled:

```bash
export GOLDSUN_NOTARIZE=1
export GOLDSUN_NOTARY_PROFILE=GoldSunNotaryProfile
./script/package_release.sh 0.1.0
```

The script submits and staples the `.pkg` and `.dmg` when notarization is enabled.
