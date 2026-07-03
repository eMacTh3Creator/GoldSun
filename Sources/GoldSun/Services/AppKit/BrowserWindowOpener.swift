import AppKit
import SwiftUI

@MainActor
final class BrowserWindowOpener: NSObject, ObservableObject, NSWindowDelegate {
    private var windowControllers: [NSWindowController] = []

    func openWindow(
        initialURL: URL,
        bookmarkStore: BookmarkStore,
        updateStore: SoftwareUpdateStore,
        downloadStore: DownloadStore,
        passwordStore: PasswordStore
    ) {
        let model = BrowserModel(initialURL: initialURL)
        let rootView = BrowserWindowView(
            model: model,
            bookmarkStore: bookmarkStore,
            updateStore: updateStore,
            downloadStore: downloadStore,
            passwordStore: passwordStore,
            openURLInNewWindow: { [weak self, weak bookmarkStore, weak updateStore, weak downloadStore, weak passwordStore] url in
                guard let self,
                      let bookmarkStore,
                      let updateStore,
                      let downloadStore,
                      let passwordStore else {
                    return
                }

                openWindow(
                    initialURL: url,
                    bookmarkStore: bookmarkStore,
                    updateStore: updateStore,
                    downloadStore: downloadStore,
                    passwordStore: passwordStore
                )
            }
        )
        .frame(minWidth: 960, minHeight: 620)

        let hostingController = NSHostingController(rootView: rootView)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "GoldSun"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.minSize = NSSize(width: 960, height: 620)
        window.setContentSize(NSSize(width: 1120, height: 760))
        window.toolbarStyle = .unifiedCompact
        window.delegate = self
        window.center()

        let controller = NSWindowController(window: window)
        windowControllers.append(controller)
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        guard let closingWindow = notification.object as? NSWindow else {
            return
        }

        windowControllers.removeAll { controller in
            controller.window === closingWindow
        }
    }
}
