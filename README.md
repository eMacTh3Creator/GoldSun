# GoldSun

GoldSun is a Mac browser written in Swift. It uses Chromium/CEF for web pages and Mac controls for tabs, menus, bookmarks, downloads, and settings.

Features include a local start page, HTTPS-first browsing, removal of common tracking parameters, content blocking, pop-up settings, and optional private browsing storage.

## Features and components

- SwiftPM macOS app target: `GoldSun`
- Core library target: `GoldSunCore`
- Native SwiftUI window, top tab bar, toolbar, settings scene, and menu commands
- Home navigation, bookmark bar, and native bookmark manager page
- Native browsing history page with search, delete, clear, favicon rows, and a privacy setting to disable history saving
- Browser-compatible bookmark import/export for Safari, Chrome, Edge, Firefox, and GoldSun backups
- Downloads manager with link saving, progress, open, reveal, cancel, retry, and clear actions
- Keychain-backed password manager with browser CSV import/export, exact-origin autofill, submitted-login capture, and native save prompts
- macOS browser registration for default-browser selection plus signed-build passkey entitlement wiring
- AppKit bridge for an embedded development web view that uses the system WebKit user agent
- YouTube-compatible element fullscreen support in the WebKit development backend
- Default-browser handoff for sites that block embedded WebKit sign-in flows
- Built-in ad blocker preferences with filter-list options
- Bundled macOS app icon for Dock, Finder, and Applications
- Auto updater that checks GitHub releases, downloads the installer, starts the macOS install flow, and quits GoldSun before replacement
- GoldSun offline start page used until a custom home page is set
- HTTPS-first navigation, fraudulent-site warnings, pop-up blocking, tracking parameter stripping, and optional private browsing storage
- Native WebKit content-rule blocking for common ads and trackers in the development backend
- Release packaging for `.app`, `.pkg`, `.dmg`, and zipped app artifacts
- GitHub Pages-ready static site in `docs/`
- URL/search normalization with tests
- Codex Run action wired through `script/build_and_run.sh`
- Chromium/CEF engine behind an Objective-C++ bridge (`GoldSunCEFBridge`), with a pinned CEF download script and automatic WebKit fallback

Release packages include Chromium/CEF for web pages. WebKit handles internal pages and the start page, and is used for all browsing when CEF is not bundled. Chrome Web Store installation is unavailable in the current package; see the release notes for extension support.

## Run

Requires Xcode or Command Line Tools with a Swift compiler and macOS SDK from the same Xcode release.

```bash
./script/fetch_cef.sh   # one-time: download the pinned Chromium/CEF runtime (~120 MB)
./script/build_and_run.sh
```

`fetch_cef.sh` verifies a pinned SHA-256 and unpacks into `ThirdParty/CEFCache/` (git-ignored). Skipping it still builds and runs GoldSun with the WebKit shim only. To force the WebKit shim even when CEF is bundled:

```bash
defaults write com.goldsun.browser engine.forceWebKit -bool YES
```

Useful modes:

```bash
./script/build_and_run.sh --verify
./script/build_and_run.sh --logs
./script/build_and_run.sh --telemetry
```

## Test

```bash
swift test
```

## Package

Download the current prerelease installer from [GoldSun v0.2.20](https://github.com/eMacTh3Creator/GoldSun/releases/tag/v0.2.20).

```bash
./script/package_release.sh 0.2.20
```

When the CEF cache is present, packaging bundles the Chromium framework and helper apps into `GoldSun.app` (see `Packaging/README.md`). The GitHub Release workflow now fetches the pinned CEF runtime before packaging, so public release artifacts include Chromium.

The `.pkg` artifact opens as a versioned `Install GoldSun <version>` installer and installs GoldSun into `/Applications`. Current prerelease artifacts are unsigned; see `docs/Release.md` for Developer ID signing and notarization.

## Browser engine

See `docs/ChromiumBackend.md` for the engine architecture. An Objective-C++ bridge connects Chromium Embedded Framework to the Swift interface. Packaging includes the framework and helper apps.
