import AppKit
import GoldSunCore
import SwiftUI

@main
struct GoldSunApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var browserModel = BrowserModel()
    @StateObject private var bookmarkStore = BookmarkStore()
    @StateObject private var updateStore = SoftwareUpdateStore()
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        WindowGroup("GoldSun", id: "browser") {
            BrowserWindowView(model: browserModel, bookmarkStore: bookmarkStore, updateStore: updateStore)
                .frame(minWidth: 960, minHeight: 620)
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

            CommandMenu("Bookmarks") {
                Button("Add Bookmark") {
                    bookmarkStore.addCurrentPage(from: browserModel.selectedTab)
                }
                .keyboardShortcut("d", modifiers: .command)

                Button("Show Bookmarks") {
                    openWindow(id: "bookmarks")
                }
                .keyboardShortcut("b", modifiers: [.command, .option])
            }
        }

        Window("Bookmarks", id: "bookmarks") {
            BookmarkManagerView(model: browserModel, bookmarkStore: bookmarkStore)
                .frame(minWidth: 760, minHeight: 460)
        }

        Settings {
            SettingsView(updateStore: updateStore)
        }
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
