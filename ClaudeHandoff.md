# GoldSun Chromium Handoff

Use this when handing GoldSun work to another coding agent.

## Repo Location

Local project:

```bash
cd "/Users/everettjenkins/Documents/Claude/Projects/App Creation/GoldSun"
```

GitHub repository:

```text
https://github.com/eMacTh3Creator/GoldSun
```

Current known release:

```text
v0.2.15
```

GoldSun is a SwiftPM macOS app. There is no Xcode project in the repo. Use SwiftPM and the existing scripts.

## Current State

GoldSun currently has a native SwiftUI/AppKit browser shell with:

- top tab bar
- toolbar and address bar
- bookmarks, bookmark import/export, bookmark bar
- history with opt-out setting
- downloads page and popover
- Keychain-backed password manager
- auto updater
- app icon, installer packaging, GitHub Pages site
- temporary `WKWebView` backend

Important: the temporary WebKit backend is not the final browser engine. It cannot reliably pass Google account sign-in because Google may block embedded `WKWebView` sign-in flows. Do not try to fix this by spoofing Chrome user-agent strings. That was removed in `v0.2.12` because it creates a mismatched browser identity and can make Google trust checks worse.

The real fix is to integrate a real Chromium runtime, most practically Chromium Embedded Framework / CEF.

## Key Files

Start here:

```text
README.md
docs/Architecture.md
docs/ChromiumBackend.md
Sources/GoldSun/Services/WebKit/WebKitBrowserView.swift
Sources/GoldSun/Services/Chromium/ChromiumEngineBridge.swift
Sources/GoldSun/Stores/BrowserTabSession.swift
Sources/GoldSun/Stores/BrowserModel.swift
Sources/GoldSun/Views/BrowserTabView.swift
Package.swift
script/package_release.sh
.github/workflows/release.yml
```

Current Chromium target metadata:

```text
Sources/GoldSunCore/Models/ChromiumRuntimeVersion.swift
```

As of `v0.2.15`:

```text
Chrome Stable 149.0.7827.201
Chromium revision 1625079
CEF 149.0.6+g0d0eeb6+chromium-149.0.7827.201 (pinned in script/fetch_cef.sh)
```

Before choosing a CEF build, verify the current target from official Chromium/Chrome sources and update the constants/tests/docs together.

## Main Goal

Replace the temporary `WKWebView` browsing surface with a CEF-backed Chromium surface while keeping GoldSun's native Swift UI.

The SwiftUI layer should not know about CEF types directly. Put CEF behind a small adapter boundary and keep browser state flowing through `BrowserTabSession` and `BrowserModel`.

## Recommended Work Plan

### Phase 1: CEF Proof Of Life

Status: DONE in `v0.2.13` (with the start of Phase 2's adapter contract). See "Implementation status" in `docs/ChromiumBackend.md` for what exists and the integration gotchas (SwiftUI `NSPrincipalClass`, mock keychain, message pump).

Create a minimal CEF host that can load one page inside a native macOS `NSView`.

Requirements:

- Add a reproducible CEF dependency script, for example `script/fetch_cef.sh`.
- Pin the CEF version and checksum. Do not silently float to latest.
- Prefer downloading CEF into a local ignored cache such as `.build/cef` or `ThirdParty/CEFCache`.
- Do not commit large CEF binaries unless the repo is explicitly moved to Git LFS.
- Add clear setup docs for the CEF download path.

SwiftPM note:

- SwiftPM targets cannot freely mix Swift and Objective-C++ in one target.
- Add a separate C/Objective-C++ bridge target, for example `GoldSunCEFBridge`.
- Expose a small Objective-C-compatible API to Swift via public headers/module map.
- Keep CEF includes and CEF framework linking inside that bridge target.

The first successful milestone is simply:

```text
GoldSun opens a native window and CEF loads https://www.youtube.com in a hosted view.
```

### Phase 2: Adapter Contract

Build a Swift-facing Chromium adapter with the same operations GoldSun already uses:

```text
load(url)
reload()
goBack()
goForward()
stopLoading()
title callback
url callback
loading callback
progress callback
canGoBack/canGoForward callback
```

Then create:

```text
Sources/GoldSun/Services/Chromium/ChromiumBrowserView.swift
```

It should mirror `WebKitBrowserView` as much as possible, but host the CEF `NSView`.

Do not delete `WebKitBrowserView` immediately. Keep it as a fallback until CEF can handle regular browsing.

### Phase 3: Make Google And YouTube Work

CEF must handle:

- Google account sign-in at `accounts.google.com`
- YouTube sign-in
- YouTube fullscreen
- cookies and persistent profile storage
- regular back/forward navigation
- popup/new-window routing into GoldSun tabs

Do not inject password-capture JavaScript into Google sign-in pages. Once CEF is working, revisit the password manager with a safer credential-save strategy.

### Phase 4: Downloads, Permissions, And Native UI

Wire CEF callbacks into GoldSun's native stores/UI:

- downloads into `DownloadStore`
- popups into new tabs/windows
- fullscreen into native macOS fullscreen/video presentation
- camera/microphone permission prompts
- geolocation permission prompts
- notification permission prompts
- certificate/auth error handling
- renderer crash recovery UI

### Phase 5: Packaging, Signing, Notarization

CEF needs helper apps/processes in the final `.app` bundle. The current package script is simple and will need to be expanded.

Update:

```text
script/package_release.sh
Packaging/GoldSun.entitlements
Packaging/README.md
.github/workflows/release.yml
```

Requirements:

- Include CEF framework/resources/helpers in `GoldSun.app`.
- Sign all nested frameworks, helpers, and the main app in the correct order.
- Keep hardened runtime enabled.
- Verify `codesign --verify --deep --strict`.
- Support Developer ID signing and notarization.
- Keep ad-hoc local builds working for development when possible.

The installer must still install to:

```text
/Applications/GoldSun.app
```

### Phase 6: Chrome Web Store Extensions

Do this only after CEF is stable for ordinary browsing.

Extension support requires more than loading Chromium:

- CRX download and signature verification
- unpack/install/update flow
- Manifest V3 parsing
- native permission review
- extension service workers
- content script injection
- enough `chrome.*` APIs for common extensions
- `declarativeNetRequest`
- per-site extension access controls

Do not re-add Chrome Web Store install buttons until extension installation truly works.

### Phase 7: Native Ad Blocking On Chromium

Move the current WebKit content-rule blocking into Chromium's request path:

- compile EasyList-style rules
- block network requests before fetch
- add cosmetic hiding later
- expose blocked counts to Swift UI
- support per-site allowlisting
- avoid fighting extension `declarativeNetRequest` rules

## Versioning Rules

Use semantic prerelease-style versions already established in the repo:

```text
0.2.12 -> 0.2.13 -> 0.2.14
```

For normal fixes, bump patch by one.

For the first CEF proof-of-life release, use the next patch version unless the owner asks for a larger version bump. Example:

```text
0.2.13
```

When bumping a version, update every active reference:

```bash
rg -n "0\\.2\\.12|v0\\.2\\.12|GoldSun-0\\.2\\.12" .
```

Usually update:

```text
CHANGELOG.md
README.md
docs/index.html
docs/Release.md
script/build_and_run.sh
script/package_release.sh
.github/workflows/release.yml
```

If Chromium target metadata changes, also update:

```text
Sources/GoldSunCore/Models/ChromiumRuntimeVersion.swift
Tests/GoldSunCoreTests/AddressResolverTests.swift
docs/ChromiumBackend.md
```

## Local Build And Test

Use the Xcode beta toolchain that has been used for releases:

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer swift build
```

Local tests currently often fail before running due to a local `.xctest` metadata signing issue:

```text
resource fork, Finder information, or similar detritus not allowed
```

Still try:

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer swift test
```

If it fails with that exact metadata/codesign issue, mention it in the handoff/final note and rely on the clean GitHub Actions runner after pushing a release tag.

Package locally:

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer ./script/package_release.sh <version>
```

Expected local unsigned prerelease behavior:

- `pkgutil --check-signature` may say no signature.
- `spctl` may reject the app.
- That is expected until Developer ID signing/notarization is configured.

## Git Workflow

Check state first:

```bash
git status --short --branch
```

Do not revert unrelated user changes.

Commit focused changes:

```bash
git add <changed files>
git commit -m "Short clear message"
```

Push main:

```bash
git push origin main
```

Create and push release tag:

```bash
git tag v<version>
git push origin v<version>
```

Watch the release workflow:

```bash
gh run list --repo eMacTh3Creator/GoldSun --workflow Release --limit 5
gh run watch <run-id> --repo eMacTh3Creator/GoldSun --exit-status
```

Verify release assets:

```bash
gh release view v<version> --repo eMacTh3Creator/GoldSun --json url,assets,isPrerelease,tagName
```

## GitHub Pages Site Update

After a release, update `gh-pages` from `docs/`.

Use a temp worktree:

```bash
tmpdir="$(mktemp -d)"
git worktree add "$tmpdir" gh-pages
rsync -a --delete --exclude .git docs/ "$tmpdir"/
git -C "$tmpdir" status --short --branch
git -C "$tmpdir" add .
git -C "$tmpdir" commit -m "Update site for GoldSun <version>"
git -C "$tmpdir" push origin gh-pages
git worktree remove "$tmpdir"
```

Watch Pages deployment:

```bash
gh run list --repo eMacTh3Creator/GoldSun --limit 8
gh run watch <pages-run-id> --repo eMacTh3Creator/GoldSun --exit-status
```

Verify live site with a cache buster:

```bash
curl -fsSL --max-time 20 "https://emacth3creator.github.io/GoldSun/?v=<version>-<commit>" \
  | rg "<version>|GoldSun-<version>"
```

## Important Warnings

- Do not reintroduce fake Chrome UA spoofing in `WKWebView`.
- Do not re-add Chrome Web Store UI until actual extension install works.
- Do not enable Apple's restricted passkey entitlement in ad-hoc builds.
- Do not commit CEF binaries unless the repo owner explicitly accepts Git LFS or another binary strategy.
- Keep the SwiftUI browser shell native and Mac-like. Chromium should be an engine, not a full Chrome UI transplant.

## Suggested First Claude Task

Start with this exact objective:

```text
Create a CEF proof-of-life integration for GoldSun that can host one Chromium browser view inside the existing native macOS app, behind a small Objective-C++ bridge, without removing the existing WebKit fallback. Include a reproducible CEF download/pinning script and build documentation. Do not implement Chrome extensions yet.
```

Success criteria:

```text
1. GoldSun builds locally.
2. A CEF-backed view can load https://www.youtube.com.
3. The CEF work is behind a clean adapter boundary.
4. WebKit fallback still exists.
5. No fake Chrome UA spoofing is added to WebKit.
6. The release/package plan for CEF helpers is documented.
```
