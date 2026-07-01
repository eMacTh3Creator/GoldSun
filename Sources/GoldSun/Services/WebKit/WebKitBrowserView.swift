import GoldSunCore
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
        configureSecurity(for: configuration)

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        WebKitContentBlocker.install(on: webView)

        context.coordinator.attach(to: webView)
        context.coordinator.lastNavigationRequestID = tab.navigationRequest.id
        context.coordinator.load(tab.url, in: webView)

        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.tab = tab
        context.coordinator.downloadStore = downloadStore
        context.coordinator.openURLInNewTab = openURLInNewTab

        if context.coordinator.lastNavigationRequestID != tab.navigationRequest.id {
            context.coordinator.lastNavigationRequestID = tab.navigationRequest.id
            context.coordinator.load(tab.navigationRequest.url, in: webView)
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

    private func configureSecurity(for configuration: WKWebViewConfiguration) {
        let defaults = UserDefaults.standard
        let securityDefaults = BrowserSecurityConfiguration.defaults
        let javaScriptEnabled = defaults.object(forKey: BrowserSecurityPreferenceKey.javaScriptEnabled) as? Bool ?? securityDefaults.javaScriptEnabled
        let blocksAutomaticPopups = defaults.object(forKey: BrowserSecurityPreferenceKey.blocksAutomaticPopups) as? Bool ?? securityDefaults.blocksAutomaticPopups
        let fraudulentWebsiteWarnings = defaults.object(forKey: BrowserSecurityPreferenceKey.fraudulentWebsiteWarnings) as? Bool ?? securityDefaults.fraudulentWebsiteWarnings
        let privateBrowsingByDefault = defaults.object(forKey: BrowserSecurityPreferenceKey.privateBrowsingByDefault) as? Bool ?? securityDefaults.privateBrowsingByDefault

        configuration.defaultWebpagePreferences.allowsContentJavaScript = javaScriptEnabled
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = !blocksAutomaticPopups
        configuration.preferences.isFraudulentWebsiteWarningEnabled = fraudulentWebsiteWarnings

        if privateBrowsingByDefault {
            configuration.websiteDataStore = .nonPersistent()
        }
    }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        weak var tab: BrowserTabSession?
        weak var downloadStore: DownloadStore?
        var openURLInNewTab: (URL) -> Void
        var lastNavigationRequestID: UUID?

        private var observations: [NSKeyValueObservation] = []
        private var upgradedHTTPFallbacks: [URL: URL] = [:]
        private var isShowingStartPage = false

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

        func load(_ url: URL, in webView: WKWebView) {
            if GoldSunStartPage.isStartPage(url) {
                isShowingStartPage = true
                tab?.title = "GoldSun"
                tab?.url = GoldSunStartPage.url
                webView.loadHTMLString(GoldSunStartPage.html(), baseURL: GoldSunStartPage.url)
            } else {
                isShowingStartPage = false
                webView.load(URLRequest(url: url))
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
            if tryHTTPFallback(after: error, in: webView) {
                return
            }

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
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }

            if GoldSunStartPage.isStartPage(url) {
                guard !isShowingStartPage else {
                    decisionHandler(.allow)
                    return
                }

                load(url, in: webView)
                decisionHandler(.cancel)
                return
            }

            isShowingStartPage = false

            if let strippedURL = trackingParameterStrippedURL(for: url) {
                load(strippedURL, in: webView)
                decisionHandler(.cancel)
                return
            }

            if let upgradedURL = upgradedHTTPSURL(for: url) {
                if currentHTTPSUpgradeMode() == .automaticFallback {
                    upgradedHTTPFallbacks[upgradedURL] = url
                }

                load(upgradedURL, in: webView)
                decisionHandler(.cancel)
                return
            }

            decisionHandler(.allow)
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

            if isShowingStartPage {
                tab?.title = "GoldSun"
                tab?.url = GoldSunStartPage.url
            } else if let url = webView.url {
                tab?.url = url
            }

            tab?.isLoading = webView.isLoading
            tab?.estimatedProgress = webView.estimatedProgress
            tab?.canGoBack = webView.canGoBack
            tab?.canGoForward = webView.canGoForward
        }

        private func upgradedHTTPSURL(for url: URL) -> URL? {
            guard currentHTTPSUpgradeMode() != .off,
                  url.scheme?.caseInsensitiveCompare("http") == .orderedSame,
                  let host = url.host(percentEncoded: false),
                  !isLocalHost(host),
                  var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
                return nil
            }

            components.scheme = "https"
            return components.url
        }

        private func trackingParameterStrippedURL(for url: URL) -> URL? {
            let defaultValue = BrowserSecurityConfiguration.defaults.stripsTrackingParameters
            let isEnabled = UserDefaults.standard.object(forKey: BrowserSecurityPreferenceKey.stripsTrackingParameters) as? Bool ?? defaultValue
            guard isEnabled,
                  url.scheme?.caseInsensitiveCompare("http") == .orderedSame
                    || url.scheme?.caseInsensitiveCompare("https") == .orderedSame,
                  var components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                  let queryItems = components.queryItems,
                  !queryItems.isEmpty else {
                return nil
            }

            let strippedNames: Set<String> = [
                "fbclid",
                "gclid",
                "dclid",
                "gbraid",
                "wbraid",
                "msclkid",
                "twclid",
                "igshid",
                "mc_cid",
                "mc_eid",
                "yclid",
                "_hsenc",
                "_hsmi",
                "vero_id"
            ]

            let filteredItems = queryItems.filter { item in
                let lowercasedName = item.name.lowercased()
                return !strippedNames.contains(lowercasedName)
                    && !lowercasedName.hasPrefix("utm_")
            }

            guard filteredItems.count != queryItems.count else {
                return nil
            }

            components.queryItems = filteredItems.isEmpty ? nil : filteredItems
            return components.url
        }

        private func tryHTTPFallback(after error: Error, in webView: WKWebView) -> Bool {
            guard currentHTTPSUpgradeMode() == .automaticFallback else {
                return false
            }

            let nsError = error as NSError
            let failingURL = nsError.userInfo[NSURLErrorFailingURLErrorKey] as? URL
                ?? nsError.userInfo[NSURLErrorFailingURLStringErrorKey].flatMap { URL(string: "\($0)") }

            guard let failingURL,
                  let fallbackURL = upgradedHTTPFallbacks.removeValue(forKey: failingURL) else {
                return false
            }

            webView.load(URLRequest(url: fallbackURL))
            return true
        }

        private func currentHTTPSUpgradeMode() -> HTTPSUpgradeMode {
            let defaultMode = BrowserSecurityConfiguration.defaults.httpsUpgradeMode
            let rawValue = UserDefaults.standard.string(forKey: BrowserSecurityPreferenceKey.httpsUpgradeMode) ?? defaultMode.rawValue
            return HTTPSUpgradeMode(rawValue: rawValue) ?? defaultMode
        }

        private func isLocalHost(_ host: String) -> Bool {
            let lowercasedHost = host.lowercased()
            return lowercasedHost == "localhost"
                || lowercasedHost == "127.0.0.1"
                || lowercasedHost == "::1"
                || lowercasedHost.hasSuffix(".local")
        }
    }
}
