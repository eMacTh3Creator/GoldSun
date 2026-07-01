import SwiftUI
import WebKit

struct WebKitBrowserView: NSViewRepresentable {
    @ObservedObject var tab: BrowserTabSession
    @ObservedObject var downloadStore: DownloadStore
    let openURLInNewTab: (URL) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(tab: tab, downloadStore: downloadStore, openURLInNewTab: openURLInNewTab)
    }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true

        context.coordinator.attach(to: webView)
        context.coordinator.lastNavigationRequestID = tab.navigationRequest.id
        webView.load(URLRequest(url: tab.url))

        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.tab = tab
        context.coordinator.downloadStore = downloadStore
        context.coordinator.openURLInNewTab = openURLInNewTab

        if context.coordinator.lastNavigationRequestID != tab.navigationRequest.id {
            context.coordinator.lastNavigationRequestID = tab.navigationRequest.id
            webView.load(URLRequest(url: tab.navigationRequest.url))
        }

        if let pendingAction = tab.pendingAction {
            context.coordinator.perform(pendingAction, in: webView)

            DispatchQueue.main.async {
                if tab.pendingAction == pendingAction {
                    tab.pendingAction = nil
                }
            }
        }
    }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        weak var tab: BrowserTabSession?
        weak var downloadStore: DownloadStore?
        var openURLInNewTab: (URL) -> Void
        var lastNavigationRequestID: UUID?

        private var observations: [NSKeyValueObservation] = []

        init(tab: BrowserTabSession, downloadStore: DownloadStore, openURLInNewTab: @escaping (URL) -> Void) {
            self.tab = tab
            self.downloadStore = downloadStore
            self.openURLInNewTab = openURLInNewTab
        }

        func attach(to webView: WKWebView) {
            observations = [
                webView.observe(\.title, options: [.initial, .new]) { [weak self] webView, _ in
                    Task { @MainActor in
                        self?.tab?.title = webView.title ?? "Untitled"
                    }
                },
                webView.observe(\.url, options: [.new]) { [weak self] webView, _ in
                    Task { @MainActor in
                        guard let url = webView.url else {
                            return
                        }

                        self?.tab?.url = url
                    }
                },
                webView.observe(\.isLoading, options: [.initial, .new]) { [weak self] webView, _ in
                    Task { @MainActor in
                        self?.tab?.isLoading = webView.isLoading
                    }
                },
                webView.observe(\.estimatedProgress, options: [.initial, .new]) { [weak self] webView, _ in
                    Task { @MainActor in
                        self?.tab?.estimatedProgress = webView.estimatedProgress
                    }
                },
                webView.observe(\.canGoBack, options: [.initial, .new]) { [weak self] webView, _ in
                    Task { @MainActor in
                        self?.tab?.canGoBack = webView.canGoBack
                    }
                },
                webView.observe(\.canGoForward, options: [.initial, .new]) { [weak self] webView, _ in
                    Task { @MainActor in
                        self?.tab?.canGoForward = webView.canGoForward
                    }
                }
            ]
        }

        func perform(_ action: BrowserAction, in webView: WKWebView) {
            switch action {
            case .goBack:
                if webView.canGoBack {
                    webView.goBack()
                }
            case .goForward:
                if webView.canGoForward {
                    webView.goForward()
                }
            case .reload:
                webView.reload()
            case .stopLoading:
                webView.stopLoading()
            }
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            syncNavigationState(from: webView)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            syncNavigationState(from: webView)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            syncNavigationState(from: webView)
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            syncNavigationState(from: webView)
        }

        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            if navigationAction.targetFrame == nil, let url = navigationAction.request.url {
                openURLInNewTab(url)
            }

            return nil
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationResponse: WKNavigationResponse,
            decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void
        ) {
            guard !navigationResponse.canShowMIMEType,
                  let url = navigationResponse.response.url else {
                decisionHandler(.allow)
                return
            }

            downloadStore?.download(url, suggestedFilename: navigationResponse.response.suggestedFilename)
            decisionHandler(.cancel)
        }

        private func syncNavigationState(from webView: WKWebView) {
            tab?.title = webView.title ?? tab?.title ?? "Untitled"

            if let url = webView.url {
                tab?.url = url
            }

            tab?.isLoading = webView.isLoading
            tab?.estimatedProgress = webView.estimatedProgress
            tab?.canGoBack = webView.canGoBack
            tab?.canGoForward = webView.canGoForward
        }
    }
}
