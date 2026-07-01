import AppKit
import GoldSunCore
import SwiftUI

@main
struct GoldSunApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var browserModel = BrowserModel()

    var body: some Scene {
        WindowGroup("GoldSun", id: "browser") {
            BrowserWindowView(model: browserModel)
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

            CommandMenu("Navigation") {
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
        }

        Settings {
            SettingsView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)

        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
