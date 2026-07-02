# Changelog

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
