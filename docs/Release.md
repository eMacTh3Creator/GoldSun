# Release Process

GoldSun's release pipeline produces four artifacts:

- `GoldSun.app`: the macOS app bundle.
- `GoldSun-<version>.pkg`: an installer package that installs to `/Applications/GoldSun.app`.
- `GoldSun-<version>.dmg`: a disk image containing the app bundle.
- `GoldSun-<version>.app.zip`: a zipped app bundle for GitHub release uploads.

## Local release

```bash
./script/package_release.sh 0.2.10
```

The package installer can be tested locally with:

```bash
sudo installer -pkg release/0.2.10/GoldSun-0.2.10.pkg -target /
```

## Official signing

Set Developer ID identities before packaging:

```bash
export GOLDSUN_SIGNING_IDENTITY="Developer ID Application: Your Name (TEAMID)"
export GOLDSUN_INSTALLER_SIGNING_IDENTITY="Developer ID Installer: Your Name (TEAMID)"
./script/package_release.sh 0.2.10
```

Without those identities, the script creates ad-hoc signed local artifacts only.

Apple's browser passkey entitlement is restricted. Only enable it for a Developer ID build after the app identifier has that entitlement approved:

```bash
export GOLDSUN_ENABLE_PASSKEY_ENTITLEMENT=1
./script/package_release.sh 0.2.10
```

## Notarization

```bash
export GOLDSUN_NOTARIZE=1
export GOLDSUN_NOTARY_PROFILE=GoldSunNotaryProfile
./script/package_release.sh 0.2.10
```

`GoldSunNotaryProfile` must already exist in the keychain via `xcrun notarytool store-credentials`.

## GitHub release

Create and push a version tag:

```bash
git tag v0.2.10
git push origin main v0.2.10
```

The `Release` workflow tests the package, uploads artifacts, and publishes a prerelease GitHub release.
