# GoldSun

GoldSun is a native macOS browser shell written in Swift. The product direction is a Chromium-backed browser with a Mac-first feel: system windows, menus, keyboard shortcuts, native controls, and a Safari-like calm around the browsing surface.

The version 2 direction is speed and security first: an offline GoldSun start page, HTTPS-first navigation, tracker-parameter cleanup, native content blocking, tighter pop-up defaults, and optional nonpersistent browsing storage.

## Current scaffold

- SwiftPM macOS app target: `GoldSun`
- Core library target: `GoldSunCore`
- Native SwiftUI window, top tab bar, toolbar, settings scene, and menu commands
- Home navigation, bookmark bar, and native bookmark manager page
- Native browsing history page with search, delete, clear, favicon rows, and a privacy setting to disable history saving
- Browser-compatible bookmark import/export for Safari, Chrome, Edge, Firefox, and GoldSun backups
- Downloads manager with link saving, progress, open, reveal, cancel, retry, and clear actions
- Keychain-backed password manager with browser CSV import/export, exact-origin autofill, submitted-login capture, and native save prompts
- macOS browser registration for default-browser selection plus signed-build passkey entitlement wiring
- AppKit bridge for an embedded development web view
- YouTube-compatible element fullscreen support in the WebKit development backend
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

The app is runnable today with a WebKit development shim that advertises the current Chrome stable compatibility target for stricter sites like Gmail. Chrome Web Store installation is not exposed in the current app because the WebKit backend cannot run Chrome extensions; extension support should return only after the Chromium runtime exists.

## Run

Requires Xcode or Command Line Tools with a Swift compiler and macOS SDK from the same Xcode release.

```bash
./script/build_and_run.sh
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

Download the current prerelease installer from [GoldSun v0.2.11](https://github.com/eMacTh3Creator/GoldSun/releases/tag/v0.2.11).

```bash
./script/package_release.sh 0.2.11
```

The `.pkg` artifact installs GoldSun into `/Applications`. Current prerelease artifacts are unsigned; see `docs/Release.md` for Developer ID signing and notarization.

## Chromium path

See `docs/ChromiumBackend.md` for the backend plan. The short version: use Chromium Embedded Framework as the first practical backend, wrap it in a small Objective-C++ boundary, expose only a Swift browser-engine facade to the UI, and handle signing/sandboxing as a first-class macOS packaging concern.
