import AppKit
import GoldSunCEFBridge
import GoldSunCore
import SwiftUI

/// Hosts a CEF-backed Chromium browser behind the same tab-session contract
/// as `WebKitBrowserView`. Downloads and password capture are not wired up
/// yet; see docs/ChromiumBackend.md for the phased plan.
struct ChromiumBrowserView: NSViewRepresentable {
    @ObservedObject var tab: BrowserTabSession
    @ObservedObject var historyStore: HistoryStore
    let openURLInNewTab: (URL) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(tab: tab, historyStore: historyStore, openURLInNewTab: openURLInNewTab)
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
        context.coordinator.openURLInNewTab = openURLInNewTab

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
        coordinator.contentFullscreenEnded()
        view.tearDown()
    }

    @MainActor
    final class Coordinator: NSObject, GSCEFBrowserHostViewDelegate {
        weak var tab: BrowserTabSession?
        weak var historyStore: HistoryStore?
        var openURLInNewTab: (URL) -> Void
        var lastNavigationRequestID: UUID?

        /// True when this coordinator started the native fullscreen
        /// transition (as opposed to the video going fullscreen while the
        /// window was already fullscreen).
        private var enteredNativeFullscreen = false
        private weak var fullscreenWindow: NSWindow?
        private var fullscreenExitObserver: NSObjectProtocol?

        init(
            tab: BrowserTabSession,
            historyStore: HistoryStore,
            openURLInNewTab: @escaping (URL) -> Void
        ) {
            self.tab = tab
            self.historyStore = historyStore
            self.openURLInNewTab = openURLInNewTab
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
                if isLoading {
                    // Reset the finished bar; on_loading_progress_change
                    // reports real progress from here on.
                    if tab.estimatedProgress >= 1 {
                        tab.estimatedProgress = 0
                    }
                } else {
                    tab.estimatedProgress = 1
                }
                tab.canGoBack = canGoBack
                tab.canGoForward = canGoForward

                if !isLoading {
                    self.historyStore?.record(title: tab.title, url: tab.url)
                }
            }
        }

        nonisolated func cefBrowserHostView(
            _ view: GSCEFBrowserHostView,
            didUpdateLoadingProgress progress: Double
        ) {
            Task { @MainActor in
                self.tab?.estimatedProgress = min(max(progress, 0), 1)
            }
        }

        nonisolated func cefBrowserHostView(
            _ view: GSCEFBrowserHostView,
            didRequestPopupWith url: URL
        ) {
            Task { @MainActor in
                self.openURLInNewTab(url)
            }
        }

        nonisolated func cefBrowserHostView(
            _ view: GSCEFBrowserHostView,
            didChangeContentFullscreen fullscreen: Bool
        ) {
            Task { @MainActor in
                if fullscreen {
                    self.contentFullscreenStarted(in: view)
                } else {
                    self.contentFullscreenEnded()
                }
            }
        }

        // CEF's Alloy runtime only resizes the web content on HTML fullscreen;
        // the host drives the native window transition. The chrome (toolbar,
        // tab bar) hides via `BrowserTabSession.isContentFullscreen`.
        private func contentFullscreenStarted(in view: GSCEFBrowserHostView) {
            tab?.isContentFullscreen = true

            guard let window = view.window else {
                return
            }

            fullscreenWindow = window
            if !window.styleMask.contains(.fullScreen) {
                enteredNativeFullscreen = true
                window.toggleFullScreen(nil)
            }

            // If the user exits native fullscreen directly (green button,
            // Mission Control), ask the page to leave HTML fullscreen too so
            // the video player state stays in sync.
            fullscreenExitObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.willExitFullScreenNotification,
                object: window,
                queue: .main
            ) { [weak self, weak view] _ in
                MainActor.assumeIsolated {
                    guard let self, self.tab?.isContentFullscreen == true else {
                        return
                    }

                    self.enteredNativeFullscreen = false
                    view?.exitContentFullscreen()
                }
            }
        }

        func contentFullscreenEnded() {
            tab?.isContentFullscreen = false

            if let fullscreenExitObserver {
                NotificationCenter.default.removeObserver(fullscreenExitObserver)
                self.fullscreenExitObserver = nil
            }

            if enteredNativeFullscreen {
                enteredNativeFullscreen = false

                if let window = fullscreenWindow, window.styleMask.contains(.fullScreen) {
                    window.toggleFullScreen(nil)
                }
            }
            fullscreenWindow = nil
        }
    }
}
