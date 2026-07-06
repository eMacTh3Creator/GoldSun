import GoldSunCEFBridge
import GoldSunCore
import SwiftUI

struct EngineHostView: View {
    @ObservedObject var tab: BrowserTabSession
    @ObservedObject var model: BrowserModel
    @ObservedObject var downloadStore: DownloadStore
    @ObservedObject var historyStore: HistoryStore
    @ObservedObject var passwordStore: PasswordStore
    let openURLInNewWindow: (URL) -> Void

    var body: some View {
        if shouldUseChromium {
            ChromiumBrowserView(
                tab: tab,
                historyStore: historyStore,
                openURLInNewTab: { url in
                    model.open(url, inNewTab: true)
                }
            )
        } else {
            WebKitBrowserView(
                tab: tab,
                downloadStore: downloadStore,
                historyStore: historyStore,
                passwordStore: passwordStore,
                openURLInNewTab: { url in
                    model.open(url, inNewTab: true)
                },
                openURLInNewWindow: openURLInNewWindow
            )
        }
    }

    /// The Chromium/CEF engine handles regular web pages when the runtime is
    /// bundled and healthy. Internal pages, the start page, and every other
    /// case stay on the WebKit development shim.
    private var shouldUseChromium: Bool {
        guard tab.engineKind == .chromiumCEF,
              let scheme = tab.url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              !UserDefaults.standard.bool(forKey: BrowserEnginePreferenceKey.forceWebKit) else {
            return false
        }

        return GSCEFRuntime.isAvailable && !GSCEFRuntime.initializationFailed
    }
}

enum BrowserEnginePreferenceKey {
    /// Escape hatch: set to true to keep using the WebKit shim even when the
    /// CEF runtime is bundled (`defaults write com.goldsun.browser engine.forceWebKit -bool YES`).
    static let forceWebKit = "engine.forceWebKit"
}
