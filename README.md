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
- Chromium/CEF proof-of-life engine behind an Objective-C++ bridge (`GoldSunCEFBridge`), with a pinned CEF download script and automatic WebKit fallback

GoldSun now hosts a real Chromium browsing surface through CEF when the pinned runtime is fetched locally (see below). Regular `http(s)` pages render in Chromium; internal pages and the start page stay on the WebKit development shim, and the app falls back to WebKit entirely when the CEF runtime is not bundled. Chrome Web Store installation is still not exposed; extension support returns only after the Chromium runtime is production-ready.

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

Download the current prerelease installer from [GoldSun v0.2.17](https://github.com/eMacTh3Creator/GoldSun/releases/tag/v0.2.17).

```bash
./script/package_release.sh 0.2.17
```

When the CEF cache is present, packaging bundles the Chromium framework and helper apps into `GoldSun.app` (see `Packaging/README.md`); without it the package is WebKit-only, which is how CI release artifacts are currently built.

The `.pkg` artifact installs GoldSun into `/Applications`. Current prerelease artifacts are unsigned; see `docs/Release.md` for Developer ID signing and notarization.

## Chromium path

See `docs/ChromiumBackend.md` for the backend plan. The short version: use Chromium Embedded Framework as the first practical backend, wrap it in a small Objective-C++ boundary, expose only a Swift browser-engine facade to the UI, and handle signing/sandboxing as a first-class macOS packaging concern.
