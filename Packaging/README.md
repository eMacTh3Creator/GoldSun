# GoldSun Packaging

GoldSun ships as a macOS app bundle plus an installer package that places the app in `/Applications`.

## Local package

```bash
./script/package_release.sh 0.1.0
```

Artifacts are written to `release/0.1.0/`.

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
