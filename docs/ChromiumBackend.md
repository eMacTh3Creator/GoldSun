# Chromium Backend Plan

GoldSun's intended backend is Chromium. On macOS, the practical embedding route for a Swift-native app is Chromium Embedded Framework (CEF), because raw Chromium is not designed as a small embeddable framework.

Current compatibility target: Chrome Stable `149.0.7827.201` / Chromium revision `1625079`, delivered by pinned CEF `149.0.6+g0d0eeb6+chromium-149.0.7827.201`. (The previously documented `150.0.7871.47` was a beta-channel build number; CEF stable and Chrome Stable for Mac are both on 149 as of 2026-07-06.)

## Implementation status (proof of life shipped in 0.2.13)

Working today:

- `script/fetch_cef.sh` downloads the pinned CEF distribution (SHA-256 verified) into the git-ignored `ThirdParty/CEFCache/`.
- `GoldSunCEFBridge` (Objective-C++ SwiftPM target) owns the CEF lifecycle. It compiles the real integration only when the CEF cache is present (`__has_include`); otherwise it builds a stub and the app is WebKit-only, which keeps CI green without the 120 MB download.
- The framework is loaded with `dlopen` and the C API is resolved with `dlsym` (no libcef link-time dependency, no `libcef_dll_wrapper` build). The API hash is verified against the compiled headers at startup.
- `GSCEFBrowserHostView` hosts one windowed CEF browser per tab as a child `NSView`; `parent_view` forces Alloy runtime style, so no Chrome UI is transplanted.
- `ChromiumBrowserView` (SwiftUI `NSViewRepresentable`) mirrors `WebKitBrowserView` against the same `BrowserTabSession` contract: navigation requests, back/forward/reload/stop, and title/URL/loading-state callbacks.
- `EngineHostView` routes regular `http(s)` pages to Chromium when the runtime is bundled and healthy; internal pages, the start page, and the `engine.forceWebKit` defaults override stay on WebKit.
- Message pump: CEF's external message pump (`on_schedule_message_pump_work`) drives `cef_do_message_loop_work` on the main run loop, with a 30 Hz safety-net timer in common run-loop modes.
- `script/bundle_cef.sh` copies the framework and creates the five helper app bundles, signing nested-first (see `Packaging/README.md`).
- Browsing profile persists at `~/Library/Application Support/GoldSun/CEFProfile`.

Hard-won integration notes:

- SwiftUI ignores `NSPrincipalClass`, so the `CefAppProtocol` methods (`isHandlingSendEvent` etc.) are grafted onto SwiftUI's `NSApplication` subclass at runtime with the Objective-C runtime, and `sendEvent:` is wrapped. Without this, CEF raises an unrecognized-selector exception during app termination.
- The embedded Chromium runs with `--use-mock-keychain`. Ad-hoc signed builds otherwise trigger a macOS Keychain password prompt for "Chromium Safe Storage" on every rebuild, and the first navigation blocks until it is answered. Remove the switch once Developer ID signing is standard.
- Browser creation waits for the host view to be in a window with non-empty bounds.
- On termination, browsers are force-closed and the loop is pumped briefly before `cef_shutdown()` so the profile flushes cleanly.

Not wired yet (next phases): downloads, popup routing into tabs, permission prompts, fullscreen handoff, renderer-crash recovery UI, password-manager integration, ad blocking on the Chromium path, and CEF in CI/release packaging.

## Recommended integration

1. Vendor a pinned CEF binary distribution under a reproducible dependency step.
2. Add a small Objective-C++ wrapper target that owns CEF lifecycle and translates events into Swift-friendly objects.
3. Expose a Swift facade with operations such as `load`, `reload`, `goBack`, `goForward`, `stop`, and state callbacks for title, URL, load progress, and navigation availability.
4. Keep SwiftUI views bound to GoldSun tab/session state, not to CEF objects directly.
5. Add signing, hardened runtime, helper process, and sandbox checks early, because Chromium helpers are packaging-sensitive on macOS.

## Adapter contract

The Swift UI should only need:

- current URL
- page title
- loading state
- estimated progress
- back/forward availability
- navigation commands
- lifecycle hooks for tab creation and teardown
- extension runtime status and toolbar actions
- native ad-blocking state and blocked-request counts

That contract is already mirrored by `BrowserTabSession` and the WebKit development shim.

## Chrome Web Store extensions

GoldSun should target Chrome's Manifest V3 extension platform first. Chrome describes MV3 as the current extensions platform, with service workers replacing long-running background pages, remotely hosted code removed, and network-request modification moving toward `declarativeNetRequest`.

Implementation requirements:

1. Add CRX download, signature verification, unpacking, and update checks for Chrome Web Store items.
2. Parse `manifest.json` and reject unsupported permissions before install.
3. Host Manifest V3 extension service workers inside the Chromium runtime.
4. Inject content scripts into matching frames through the Chromium adapter.
5. Implement the `chrome.*` API surface required for common extensions, starting with tabs, storage, runtime, scripting, action, alarms, cookies, permissions, and `declarativeNetRequest`.
6. Show native permission review before install and expose per-site access controls.
7. Keep Manifest V2 limited to explicitly enabled developer legacy support, not the default Web Store path.

Relevant Chrome documentation:

- https://developer.chrome.com/docs/extensions/develop/migrate/what-is-mv3
- https://developer.chrome.com/docs/webstore
- https://support.google.com/chrome_webstore/answer/2664769

## Built-in ad blocker

GoldSun's built-in blocker should not depend on a third-party extension. It should run as a native Chromium network/content-filtering service with user options for protection level, filter lists, tracker blocking, placeholder hiding, acceptable ads, and automatic list updates.

Implementation requirements:

1. Compile EasyList-style filter lists into efficient URL and cosmetic rules.
2. Apply native rules in Chromium's request path before page resources are fetched.
3. Use `declarativeNetRequest`-compatible semantics where possible so native blocking and extension blocking do not fight each other.
4. Support per-site allowlisting and temporary shield toggles from the toolbar.
5. Keep filter-list updates signed or checksum-verified before activation.
6. Expose blocked request counts to the Swift tab/session state.

Chrome's `declarativeNetRequest` documentation is the right compatibility baseline for extension-driven request rules:

- https://developer.chrome.com/docs/extensions/reference/api/declarativeNetRequest

## Milestones

1. Create a CEF sample host that opens one page inside a native `NSView`.
2. Replace `WebKitBrowserView` with `ChromiumBrowserView` behind the same tab-session contract.
3. Add popup/new-window routing into GoldSun tabs.
4. Add Chrome Web Store install/update plumbing and native permission sheets.
5. Add the Manifest V3 service-worker, content-script, and `chrome.*` API runtime.
6. Add native ad-block rule compilation and per-site controls.
7. Add download handling and permission prompts with native sheets.
8. Add process crash reporting and recovery UI.
9. Move packaging from the SwiftPM development bundle to a signed app bundle workflow.
