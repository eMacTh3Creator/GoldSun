# Changelog

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
