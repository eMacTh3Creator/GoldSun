import GoldSunCEFBridge
import GoldSunCore
import SwiftUI

/// Hosts a CEF-backed Chromium browser behind the same tab-session contract
/// as `WebKitBrowserView`. Downloads, popup routing, and password capture are
/// not wired up yet; see docs/ChromiumBackend.md for the phased plan.
struct ChromiumBrowserView: NSViewRepresentable {
    @ObservedObject var tab: BrowserTabSession
    @ObservedObject var historyStore: HistoryStore

    func makeCoordinator() -> Coordinator {
        Coordinator(tab: tab, historyStore: historyStore)
    }

    func makeNSView(context: Context) -> GSCEFBrowserHostView {
        let view = GSCEFBrowserHostView(frame: .zero)
        view.delegate = context.coordinator
        context.coordinator.lastNavigationRequestID = tab.navigationRequest.id
        view.load(tab.url)
        return view
    }

    func updateNSView(_ view: GSCEFBrowserHostView, context: Context) {
        context.coordinator.tab = tab
        context.coordinator.historyStore = historyStore

        if context.coordinator.lastNavigationRequestID != tab.navigationRequest.id {
            context.coordinator.lastNavigationRequestID = tab.navigationRequest.id
            view.load(tab.navigationRequest.url)
        }

        if let pendingAction = tab.pendingAction {
            switch pendingAction {
            case .goBack:
                view.goBack()
            case .goForward:
                view.goForward()
            case .reload:
                view.reload()
            case .stopLoading:
                view.stopLoading()
            }

            DispatchQueue.main.async {
                if tab.pendingAction == pendingAction {
                    tab.pendingAction = nil
                }
            }
        }
    }

    static func dismantleNSView(_ view: GSCEFBrowserHostView, coordinator: Coordinator) {
        view.tearDown()
    }

    @MainActor
    final class Coordinator: NSObject, GSCEFBrowserHostViewDelegate {
        weak var tab: BrowserTabSession?
        weak var historyStore: HistoryStore?
        var lastNavigationRequestID: UUID?

        init(tab: BrowserTabSession, historyStore: HistoryStore) {
            self.tab = tab
            self.historyStore = historyStore
        }

        nonisolated func cefBrowserHostView(_ view: GSCEFBrowserHostView, didUpdateTitle title: String) {
            Task { @MainActor in
                self.tab?.title = title.isEmpty ? "Untitled" : title
            }
        }

        nonisolated func cefBrowserHostView(_ view: GSCEFBrowserHostView, didUpdatePageURL url: URL) {
            Task { @MainActor in
                self.tab?.url = url
            }
        }

        nonisolated func cefBrowserHostView(
            _ view: GSCEFBrowserHostView,
            didUpdateLoadingState isLoading: Bool,
            canGoBack: Bool,
            canGoForward: Bool
        ) {
            Task { @MainActor in
                guard let tab = self.tab else {
                    return
                }

                tab.isLoading = isLoading
                tab.estimatedProgress = isLoading ? 0.5 : 1
                tab.canGoBack = canGoBack
                tab.canGoForward = canGoForward

                if !isLoading {
                    self.historyStore?.record(title: tab.title, url: tab.url)
                }
            }
        }
    }
}
