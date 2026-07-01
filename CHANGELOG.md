# Changelog

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
