# Changelog

## 0.2.19

- Updated the GitHub Release workflow to cache and fetch the pinned Chromium/CEF runtime before packaging, so published release artifacts bundle the CEF framework and helper apps instead of shipping WebKit-only.
- Updated release, packaging, and site documentation to reflect that CI release installers now include the Chromium engine while WebKit remains the fallback for internal pages and builds without CEF.

## 0.2.18

- Fixed a bug where opening a URL into an already-running GoldSun (for example `open -a GoldSun <url>`, or any external "open URL" request) spun up a second app window sharing the same tab state, so a single tab ended up hosted by two independent CEF Chromium browser instances at once, doubling renderer resource use and firing duplicate title/URL/loading callbacks. The main window scene is now a singleton (`Window` instead of `WindowGroup`); additional windows still open correctly through the existing "open in new window" action, which already used its own independent browser model.

## 0.2.17

- Routed Chromium popups and `target="_blank"` links into regular GoldSun tabs: the CEF life-span handler intercepts `on_before_popup`, suppresses the native popup window, and opens the target URL as a new tab.
- Wired HTML fullscreen to native macOS fullscreen for the embedded Chromium engine: entering video fullscreen (for example the YouTube player) takes the window fullscreen and hides the browser chrome, leaving it restores both, and exiting macOS fullscreen directly also tells the page to leave HTML fullscreen so player state stays in sync.
- Replaced the placeholder Chromium loading progress with real `on_loading_progress_change` values so the address-bar progress bar reflects actual page load progress.
- Verified Google now serves its standard account sign-in flow to the embedded Chromium runtime (no "browser may not be secure" block), and that cookies and profile state persist across app relaunches in the Chromium profile directory.

## 0.2.16

- Fixed searches with a literal `+` (for example `c++ tutorial`) being sent to DuckDuckGo/Google with the `+` silently turned into a space, since query strings decode `+` as a space; the search URL builder now percent-encodes a literal `+` as `%2B` so it survives.

## 0.2.15

- Fixed the offline start page search box treating everything as a search: submissions now go through the same address resolution as the address bar, so typing `https://www.youtube.com` or `youtube.com` opens the site directly while plain text still searches.
- Start page searches now use the search engine selected in Settings instead of always using DuckDuckGo.

## 0.2.14

- Stopped repeated macOS "access files in your Documents folder" prompts for development builds by staging the dev app bundle in `~/Library/Developer/GoldSun/dist` instead of the repo `dist/` folder (TCC re-prompts ad-hoc signed apps inside protected folders on every rebuild). A `dist/GoldSun.app` symlink keeps existing workflows working, and `GOLDSUN_DIST_DIR` overrides the location.

## 0.2.13

- Added a Chromium Embedded Framework (CEF) proof-of-life engine: regular web pages now render in a real Chromium runtime hosted inside GoldSun's native window when the pinned CEF distribution is fetched locally.
- Added `script/fetch_cef.sh`, which downloads CEF `149.0.6+g0d0eeb6+chromium-149.0.7827.201` with SHA-256 verification into a git-ignored local cache.
- Added the `GoldSunCEFBridge` Objective-C++ target (dlopen/dlsym C API bridge, external message pump, title/URL/loading callbacks) and the `GoldSunCEFHelper` process executable.
- Added `script/bundle_cef.sh` so local builds bundle the Chromium framework plus the five helper apps with correct nested code signing; builds and CI without the CEF cache stay WebKit-only automatically.
- Kept the WebKit development shim as an automatic fallback and behind the `engine.forceWebKit` defaults override; internal pages and the start page still use it.
- Ran the embedded Chromium with the mock keychain so ad-hoc prerelease builds never trigger macOS Keychain password prompts for "Chromium Safe Storage".
- Corrected the Chromium compatibility target to the actual Chrome Stable for Mac, `149.0.7827.201` (revision `1625079`); the previous `150.0.7871.47` record was a beta-channel build number.
- Added CEF packaging/signing documentation covering helper bundles, entitlements, signing order, and the notarization plan.

## 0.2.12

- Removed the Chrome-style user-agent override from the WebKit development backend so GoldSun no longer presents a mismatched Chrome identity to Google sign-in.
- Added a Navigation menu action to open the current page in the Mac default browser when a site blocks embedded WebKit sign-in.
- Updated the Chromium backend target record to Chrome Stable `150.0.7871.47` for macOS while keeping Chrome identity limited to the future Chromium runtime.

## 0.2.11

- Enabled WebKit's element fullscreen support so video sites such as YouTube can enter fullscreen from the embedded browser view.

## 0.2.10

- Removed the Chrome Web Store toolbar button, Extensions menu, Extensions settings tab, start-page Extensions link, and default Chrome Web Store bookmark because GoldSun's current WebKit development backend cannot install Chrome extensions.
- Kept extension runtime planning internal to the future Chromium backend instead of exposing non-working install controls in the browser UI.

## 0.2.9

- Fixed prerelease launch validation on macOS by keeping Apple's restricted browser passkey entitlement out of ad-hoc signed builds.
- Added a separate passkey entitlement file for future Developer ID signed builds that have Apple's browser passkey entitlement approval.
- Kept default-browser registration, Gmail compatibility targeting, history, and password-save prompt work from 0.2.8.

## 0.2.8

- Added browsing history with a native `goldsun://history` manager page, toolbar/start-page/menu entry points, favicon rows, search, delete, and clear actions.
- Added a Privacy setting to turn history saving on or off, with history recording disabled immediately when the setting is off.
- Updated the address bar so focusing it selects the full URL/search text for faster copying, pasting, and replacement typing.
- Improved Back from built-in manager pages so History, Bookmarks, Downloads, and Passwords can return to the page that opened them.
- Added macOS browser registration metadata for `http`, `https`, and local file URLs so GoldSun can appear as a selectable default browser.
- Added the macOS browser passkey entitlement for native WebAuthn/passkey support in signed builds.
- Updated the WebKit development shim to use the current Chrome 150 stable compatibility target for sites such as Gmail while the Chromium backend is integrated.
- Added a native save-password prompt and broader login capture for JavaScript-heavy sites such as Gmail.

## 0.2.7

- Added distinct right-click link actions for opening links in a new tab or a real separate browser window.
- Kept inactive tab web views mounted so tabs preserve page state, scroll position, and WebKit back/forward history when switching.
- Improved back/forward reliability by preserving each tab's native WebKit session instead of rebuilding it on selection changes.

## 0.2.6

- Removed the descriptive tagline from the built-in `goldsun://home` start page while leaving the browser and public site marketing copy intact.

## 0.2.5

- Added browser-compatible bookmark import from Netscape HTML, Chrome-family JSON, Safari property lists, and GoldSun JSON backups.
- Added bookmark export to browser HTML for moving bookmarks to Safari, Chrome, Edge, Firefox, and other browsers, plus GoldSun JSON backup export.
- Added a built-in password manager at `goldsun://passwords` with Keychain-backed storage, exact-origin autofill, submitted-login capture, manual editing, and browser CSV import/export.
- Added Passwords toolbar, start-page, Settings, and menu bar entry points.

## 0.2.4

- Removed the browser sidebar and the sidebar/tab display preference path entirely; GoldSun now uses the top tab bar as its only tab chrome.
- Kept bookmark and download management in built-in browser pages instead of sidebar-dependent surfaces.
- Fixed the GoldSun start page Bookmarks and Downloads buttons so they open `goldsun://bookmarks` and `goldsun://downloads` in the current browser tab.

## 0.2.3

- Updated software update installs to open the macOS installer and then quit GoldSun so the app can be replaced cleanly.
- Clarified updater controls around automatic installer launch and quit behavior.

## 0.2.2

- Restored the GoldSun mountain sunrise treatment on the built-in start page using self-contained CSS art.
- Added the two-tone GoldSun wordmark styling to the browser start page.
- Refreshed the GitHub Pages hero image from the real GoldSun app window with the updated start page.
- Removed the unused Chrome-like bundled start-page mock image from packaged app resources.

## 0.2.1

- Made the toolbar's left new-tab button the single New Tab control and removed the duplicate plus button.
- Removed the bookmark-bar toggle from the toolbar; bookmark-bar visibility is now in Settings and the menu bar.
- Prevented duplicate bookmarks, merged duplicate bookmark edits, and deduplicated previously saved bookmarks on load.
- Added favicon rendering for tabs, sidebar tabs, bookmark rows, bookmark bar items, and the bookmark manager.
- Moved bookmark and download management into built-in browser pages at `goldsun://bookmarks` and `goldsun://downloads`.
- Added a Downloads popover on the toolbar icon with recent downloads, Save Link, folder, clear, and Show All actions.
- Expanded menu bar coverage for bookmarks, downloads, tab display, bookmark bar visibility, and ad blocker toggling.

## 0.2.0

- Added an offline GoldSun start page that is used at launch, for new tabs, and for Home until a custom home page is set.
- Polished the native toolbar, address field, tab bar, sidebar tab rows, and bookmark bar with cleaner GoldSun-accented chrome.
- Added security preferences for HTTPS-first navigation, strict HTTPS mode, fraudulent-website warnings, private browsing storage, JavaScript, pop-up blocking, and tracking parameter stripping.
- Added app-owned HTTPS upgrades with localhost exemptions and automatic HTTP fallback in the default mode.
- Added navigation cleanup for common tracking query parameters such as `utm_*`, `fbclid`, `gclid`, and `msclkid`.
- Added a native WebKit content-rule blocker for common ad, tracker, malware, fingerprinting, and crypto-mining patterns in the development backend.
- Bundled the GoldSun hero art into packaged apps for the internal start page.
- Polished the GitHub Pages site around the speed-and-security product direction.

## 0.1.3

- Added a native Downloads manager window with progress, open, reveal, cancel, retry, clear, and Downloads folder actions.
- Added Save Link support from the Downloads manager.
- Added a toolbar button to open the current address in a new tab.
- Opened target-blank WebKit links in new tabs instead of replacing the current tab.
- Fixed tab-bar-only mode by removing the stale sidebar state path and binding the toolbar directly to tab display preferences.

## 0.1.2

- Added a native auto updater backed by GitHub Releases.
- Added automatic launch checks, a manual Check for Updates command, and toolbar update status.
- Added updater settings for prerelease updates, automatic installer downloads, and automatic installer launch.
- Added an update sheet for release notes, installer download, installer launch, and release page access.

## 0.1.1

- Added Home navigation in the toolbar and Navigation menu.
- Added a native bookmark manager with search, edit, delete, open, folder, bookmark-bar, and reorder support.
- Added an optional bookmark bar and bookmark shortcuts in the sidebar.
- Added top tab bar mode with settings for Sidebar, Tab Bar, or Both.
- Added a bundled GoldSun app icon for packaged apps, Finder, Applications, and the Dock.

## 0.1.0

- Initial native macOS Swift browser shell.
- WebKit development browsing adapter.
- Chromium/CEF backend integration boundary.
- Chrome Web Store and Manifest V3 compatibility plan.
- Built-in ad blocker preference model and native settings.
- Release packaging scripts for `.app`, `.pkg`, `.dmg`, and `.zip` artifacts.
