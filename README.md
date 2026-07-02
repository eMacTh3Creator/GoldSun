# GoldSun

GoldSun is a native macOS browser shell written in Swift. The product direction is a Chromium-backed browser with a Mac-first feel: system windows, menus, keyboard shortcuts, native controls, and a Safari-like calm around the browsing surface.

The version 2 direction is speed and security first: an offline GoldSun start page, HTTPS-first navigation, tracker-parameter cleanup, native content blocking, tighter pop-up defaults, and optional nonpersistent browsing storage.

## Current scaffold

- SwiftPM macOS app target: `GoldSun`
- Core library target: `GoldSunCore`
- Native SwiftUI window, sidebar, toolbar, settings scene, and menu commands
- Home navigation, top tab bar mode, bookmark bar, and native bookmark manager
- Downloads manager with link saving, progress, open, reveal, cancel, retry, and clear actions
- AppKit bridge for an embedded development web view
- Chrome Web Store / Manifest V3 compatibility planning and native settings
- Built-in ad blocker preferences with filter-list options
- Bundled macOS app icon for Dock, Finder, and Applications
- Auto updater that checks GitHub releases, downloads the installer, and starts the macOS install flow
- GoldSun offline start page used until a custom home page is set
- HTTPS-first navigation, fraudulent-site warnings, pop-up blocking, tracking parameter stripping, and optional private browsing storage
- Native WebKit content-rule blocking for common ads and trackers in the development backend
- Release packaging for `.app`, `.pkg`, `.dmg`, and zipped app artifacts
- GitHub Pages-ready static site in `docs/`
- URL/search normalization with tests
- Codex Run action wired through `script/build_and_run.sh`

The app is runnable today with a WebKit development shim. Chrome Web Store extensions and the production ad blocker are Chromium-backend features; their user-facing settings and adapter boundaries are scaffolded now so the next implementation step can vendor CEF or another Chromium embedding layer without rewriting the SwiftUI shell.

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

Download the current prerelease installer from [GoldSun v0.2.2](https://github.com/eMacTh3Creator/GoldSun/releases/tag/v0.2.2).

```bash
./script/package_release.sh 0.2.2
```

The `.pkg` artifact installs GoldSun into `/Applications`. Current prerelease artifacts are unsigned; see `docs/Release.md` for Developer ID signing and notarization.

## Chromium path

See `docs/ChromiumBackend.md` for the backend plan. The short version: use Chromium Embedded Framework as the first practical backend, wrap it in a small Objective-C++ boundary, expose only a Swift browser-engine facade to the UI, and handle signing/sandboxing as a first-class macOS packaging concern.
