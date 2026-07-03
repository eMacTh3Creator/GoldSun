import AppKit
import GoldSunCore
import SwiftUI

@main
struct GoldSunApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var browserModel = BrowserModel()
    @StateObject private var bookmarkStore = BookmarkStore()
    @StateObject private var updateStore = SoftwareUpdateStore()
    @StateObject private var downloadStore = DownloadStore()
    @StateObject private var historyStore = HistoryStore()
    @StateObject private var passwordStore = PasswordStore()
    @StateObject private var browserWindowOpener = BrowserWindowOpener()
    @AppStorage("showBookmarkBar") private var showBookmarkBar = true
    @AppStorage("adBlockEnabled") private var adBlockEnabled = AdBlockConfiguration.defaults.isEnabled

    var body: some Scene {
        WindowGroup("GoldSun", id: "browser") {
            BrowserWindowView(
                model: browserModel,
                bookmarkStore: bookmarkStore,
                updateStore: updateStore,
                downloadStore: downloadStore,
                historyStore: historyStore,
                passwordStore: passwordStore,
                openURLInNewWindow: { url in
                    browserWindowOpener.openWindow(
                        initialURL: url,
                        bookmarkStore: bookmarkStore,
                        updateStore: updateStore,
                        downloadStore: downloadStore,
                        historyStore: historyStore,
                        passwordStore: passwordStore
                    )
                }
            )
                .frame(minWidth: 960, minHeight: 620)
                .onOpenURL { url in
                    browserModel.open(url)
                }
        }
        .windowToolbarStyle(.unifiedCompact)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Tab") {
                    browserModel.newTab()
                }
                .keyboardShortcut("t", modifiers: .command)
            }

            CommandGroup(after: .appInfo) {
                Button("Check for Updates...") {
                    Task {
                        await updateStore.checkForUpdates(userInitiated: true)
                    }
                }
                .keyboardShortcut("u", modifiers: [.command, .shift])
                .disabled(updateStore.isBusy)
            }

            CommandMenu("Navigation") {
                Button("Home") {
                    browserModel.goHome()
                }
                .keyboardShortcut("h", modifiers: [.command, .shift])

                Divider()

                Button("Back") {
                    browserModel.goBack()
                }
                .keyboardShortcut("[", modifiers: .command)
                .disabled(browserModel.selectedTab?.canGoBack != true)

                Button("Forward") {
                    browserModel.goForward()
                }
                .keyboardShortcut("]", modifiers: .command)
                .disabled(browserModel.selectedTab?.canGoForward != true)

                Button("Reload") {
                    browserModel.reload()
                }
                .keyboardShortcut("r", modifiers: .command)

                Divider()

                Button("Close Tab") {
                    browserModel.closeSelectedTab()
                }
                .keyboardShortcut("w", modifiers: .command)
                .disabled(browserModel.selectedTab == nil)
            }

            CommandMenu("Extensions") {
                Button("Chrome Web Store") {
                    browserModel.openChromeWebStore()
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])
            }

            CommandMenu("Privacy") {
                Toggle("Enable Ad Blocker", isOn: $adBlockEnabled)
            }

            CommandMenu("History") {
                Button("Show History") {
                    browserModel.openHistoryManager()
                }
                .keyboardShortcut("y", modifiers: .command)

                Button("Clear History") {
                    historyStore.clear()
                }
                .disabled(historyStore.entries.isEmpty)
            }

            CommandMenu("Bookmarks") {
                Button("Add Bookmark") {
                    bookmarkStore.addCurrentPage(from: browserModel.selectedTab)
                }
                .keyboardShortcut("d", modifiers: .command)
                .disabled(!canBookmarkCurrentPage)

                Button("Show Bookmarks") {
                    browserModel.openBookmarkManager()
                }
                .keyboardShortcut("b", modifiers: [.command, .option])

                Divider()

                Button("Import Bookmarks...") {
                    do {
                        _ = try BrowserDataTransferPanel.importBookmarks(into: bookmarkStore)
                    } catch {
                        BrowserDataTransferPanel.present(error)
                    }
                }

                Button("Export Bookmarks...") {
                    do {
                        _ = try BrowserDataTransferPanel.exportBookmarks(from: bookmarkStore, format: .browserHTML)
                    } catch {
                        BrowserDataTransferPanel.present(error)
                    }
                }

                Toggle("Show Bookmark Bar", isOn: $showBookmarkBar)
            }

            CommandMenu("Passwords") {
                Button("Show Passwords") {
                    browserModel.openPasswordManager()
                }
                .keyboardShortcut("p", modifiers: [.command, .option])

                Divider()

                Button("Import Passwords...") {
                    do {
                        _ = try BrowserDataTransferPanel.importPasswords(into: passwordStore)
                    } catch {
                        BrowserDataTransferPanel.present(error)
                    }
                }

                Button("Export Passwords...") {
                    do {
                        _ = try BrowserDataTransferPanel.exportPasswords(from: passwordStore)
                    } catch {
                        BrowserDataTransferPanel.present(error)
                    }
                }
                .disabled(passwordStore.credentials.isEmpty)
            }

            CommandMenu("Downloads") {
                Button("Show Downloads") {
                    browserModel.openDownloadManager()
                }
                .keyboardShortcut("j", modifiers: [.command, .option])

                Button("Open Downloads Folder") {
                    downloadStore.openDownloadsFolder()
                }

                Button("Clear Finished Downloads") {
                    downloadStore.clearFinished()
                }
                .disabled(!downloadStore.hasFinishedDownloads)
            }

            CommandMenu("Browser View") {
                Toggle("Show Bookmark Bar", isOn: $showBookmarkBar)
            }
        }

        Settings {
            SettingsView(updateStore: updateStore, historyStore: historyStore)
        }
    }

    private var canBookmarkCurrentPage: Bool {
        guard let url = browserModel.selectedTab?.url,
              !BrowserDestination.isInternal(url) else {
            return false
        }

        return !bookmarkStore.isBookmarked(url)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)

        if let iconURL = Bundle.main.url(forResource: "GoldSun", withExtension: "icns"),
           let image = NSImage(contentsOf: iconURL) {
            NSApp.applicationIconImage = image
        }

        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
