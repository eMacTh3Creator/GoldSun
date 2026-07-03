import GoldSunCore
import SwiftUI
import WebKit

struct WebKitBrowserView: NSViewRepresentable {
    @ObservedObject var tab: BrowserTabSession
    @ObservedObject var downloadStore: DownloadStore
    @ObservedObject var passwordStore: PasswordStore
    let openURLInNewTab: (URL) -> Void
    let openURLInNewWindow: (URL) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            tab: tab,
            downloadStore: downloadStore,
            passwordStore: passwordStore,
            openURLInNewTab: openURLInNewTab,
            openURLInNewWindow: openURLInNewWindow
        )
    }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configureSecurity(for: configuration)
        configurePasswordManager(for: configuration, coordinator: context.coordinator)

        let webView = GoldSunWebView(frame: .zero, configuration: configuration)
        webView.openURLInNewTab = openURLInNewTab
        webView.openURLInNewWindow = openURLInNewWindow
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
        context.coordinator.passwordStore = passwordStore
        context.coordinator.openURLInNewTab = openURLInNewTab
        context.coordinator.openURLInNewWindow = openURLInNewWindow

        if let goldSunWebView = webView as? GoldSunWebView {
            goldSunWebView.openURLInNewTab = openURLInNewTab
            goldSunWebView.openURLInNewWindow = openURLInNewWindow
        }

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

    private func configurePasswordManager(for configuration: WKWebViewConfiguration, coordinator: Coordinator) {
        configuration.userContentController.add(
            WeakScriptMessageHandler(delegate: coordinator),
            name: Coordinator.passwordMessageHandlerName
        )
        configuration.userContentController.addUserScript(
            WKUserScript(
                source: Coordinator.passwordCaptureScript,
                injectionTime: .atDocumentEnd,
                forMainFrameOnly: true
            )
        )
    }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
        static let passwordMessageHandlerName = "goldsunPasswords"
        static let passwordCaptureScript = """
        (function () {
          if (window.__goldsunPasswordsInstalled) { return; }
          window.__goldsunPasswordsInstalled = true;

          function candidateUsernameInput(form, passwordInput) {
            var inputs = Array.prototype.slice.call(form.querySelectorAll('input'));
            var passwordIndex = inputs.indexOf(passwordInput);
            var preferred = inputs.filter(function (input, index) {
              if (index > passwordIndex) { return false; }
              var type = (input.getAttribute('type') || 'text').toLowerCase();
              var name = ((input.getAttribute('name') || '') + ' ' + (input.getAttribute('id') || '') + ' ' + (input.getAttribute('autocomplete') || '')).toLowerCase();
              return ['email', 'text', 'search', 'tel', 'url'].indexOf(type) !== -1
                && (name.indexOf('user') !== -1 || name.indexOf('email') !== -1 || name.indexOf('login') !== -1 || name.indexOf('account') !== -1);
            });

            if (preferred.length > 0) { return preferred[preferred.length - 1]; }

            var fallback = inputs.filter(function (input, index) {
              if (index > passwordIndex) { return false; }
              var type = (input.getAttribute('type') || 'text').toLowerCase();
              return ['email', 'text'].indexOf(type) !== -1;
            });

            return fallback.length > 0 ? fallback[fallback.length - 1] : null;
          }

          function dispatchInputEvents(input) {
            input.dispatchEvent(new Event('input', { bubbles: true }));
            input.dispatchEvent(new Event('change', { bubbles: true }));
          }

          function passwordFormPayload(form) {
            var passwordInput = form.querySelector('input[type="password"]');
            if (!passwordInput || !passwordInput.value) { return null; }
            var usernameInput = candidateUsernameInput(form, passwordInput);
            return {
              kind: 'submit',
              origin: window.location.origin,
              action: form.action || window.location.href,
              title: document.title || window.location.hostname,
              username: usernameInput ? usernameInput.value : '',
              password: passwordInput.value
            };
          }

          document.addEventListener('submit', function (event) {
            var payload = passwordFormPayload(event.target);
            if (payload && window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.goldsunPasswords) {
              window.webkit.messageHandlers.goldsunPasswords.postMessage(payload);
            }
          }, true);

          document.addEventListener('contextmenu', function (event) {
            var node = event.target;
            var href = null;
            while (node && node !== document) {
              if (node.href) {
                href = node.href;
                break;
              }
              node = node.parentElement;
            }

            if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.goldsunPasswords) {
              window.webkit.messageHandlers.goldsunPasswords.postMessage({
                kind: 'contextMenuLink',
                href: href
              });
            }
          }, true);

          window.__goldsunFillPassword = function (username, password) {
            var forms = Array.prototype.slice.call(document.forms);
            for (var i = 0; i < forms.length; i += 1) {
              var passwordInput = forms[i].querySelector('input[type="password"]');
              if (!passwordInput) { continue; }
              var usernameInput = candidateUsernameInput(forms[i], passwordInput);
              if (usernameInput && !usernameInput.value) {
                usernameInput.value = username;
                dispatchInputEvents(usernameInput);
              }
              if (!passwordInput.value) {
                passwordInput.value = password;
                dispatchInputEvents(passwordInput);
              }
              return true;
            }
            return false;
          };
        }());
        """

        weak var tab: BrowserTabSession?
        weak var downloadStore: DownloadStore?
        weak var passwordStore: PasswordStore?
        private weak var webView: GoldSunWebView?
        var openURLInNewTab: (URL) -> Void
        var openURLInNewWindow: (URL) -> Void
        var lastNavigationRequestID: UUID?

        private var observations: [NSKeyValueObservation] = []
        private var upgradedHTTPFallbacks: [URL: URL] = [:]
        private var isShowingStartPage = false

        init(
            tab: BrowserTabSession,
            downloadStore: DownloadStore,
            passwordStore: PasswordStore,
            openURLInNewTab: @escaping (URL) -> Void,
            openURLInNewWindow: @escaping (URL) -> Void
        ) {
            self.tab = tab
            self.downloadStore = downloadStore
            self.passwordStore = passwordStore
            self.openURLInNewTab = openURLInNewTab
            self.openURLInNewWindow = openURLInNewWindow
        }

        func attach(to webView: WKWebView) {
            self.webView = webView as? GoldSunWebView
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
            autofillPassword(in: webView)
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

            if BrowserDestination.isInternal(url) {
                tab?.load(url)
                tab?.title = Self.internalTitle(for: url)
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

        private static func internalTitle(for url: URL) -> String {
            switch url {
            case BrowserDestination.bookmarkManager:
                "Bookmarks"
            case BrowserDestination.downloadManager:
                "Downloads"
            case BrowserDestination.passwordManager:
                "Passwords"
            case BrowserDestination.goldSunStartPage:
                "GoldSun"
            default:
                "GoldSun"
            }
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == Self.passwordMessageHandlerName,
                  let payload = message.body as? [String: Any] else {
                return
            }

            if payload["kind"] as? String == "contextMenuLink" {
                if let href = payload["href"] as? String {
                    webView?.contextMenuLinkURL = URL(string: href)
                } else {
                    webView?.contextMenuLinkURL = nil
                }
                return
            }

            guard payload["kind"] as? String == "submit",
                  let originString = payload["origin"] as? String,
                  let origin = URL(string: originString),
                  let password = payload["password"] as? String else {
                return
            }

            let username = payload["username"] as? String ?? ""
            let title = payload["title"] as? String ?? origin.host(percentEncoded: false) ?? origin.absoluteString
            passwordStore?.saveCaptured(origin: origin, username: username, password: password, title: title)
        }

        private func autofillPassword(in webView: WKWebView) {
            guard let url = webView.url,
                  !BrowserDestination.isInternal(url),
                  let autofill = passwordStore?.autofillCredential(for: url) else {
                return
            }

            let username = Self.javaScriptLiteral(autofill.credential.username)
            let password = Self.javaScriptLiteral(autofill.password)
            webView.evaluateJavaScript("window.__goldsunFillPassword && window.__goldsunFillPassword(\(username), \(password));")
        }

        private static func javaScriptLiteral(_ value: String) -> String {
            guard let data = try? JSONSerialization.data(withJSONObject: [value]),
                  let array = String(data: data, encoding: .utf8),
                  array.count >= 2 else {
                return "\"\""
            }

            return String(array.dropFirst().dropLast())
        }

    }
}

private final class GoldSunWebView: WKWebView {
    var contextMenuLinkURL: URL?
    var openURLInNewTab: ((URL) -> Void)?
    var openURLInNewWindow: ((URL) -> Void)?

    override func rightMouseDown(with event: NSEvent) {
        contextMenuLinkURL = nil
        super.rightMouseDown(with: event)
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = super.menu(for: event) ?? NSMenu()

        guard let contextMenuLinkURL else {
            return menu
        }

        removeDefaultOpenLinkItems(from: menu)

        let openInNewTab = NSMenuItem(
            title: "Open Link in New Tab",
            action: #selector(openContextLinkInNewTab(_:)),
            keyEquivalent: ""
        )
        openInNewTab.target = self
        openInNewTab.representedObject = contextMenuLinkURL

        let openInNewWindow = NSMenuItem(
            title: "Open Link in New Window",
            action: #selector(openContextLinkInNewWindow(_:)),
            keyEquivalent: ""
        )
        openInNewWindow.target = self
        openInNewWindow.representedObject = contextMenuLinkURL

        menu.insertItem(openInNewWindow, at: 0)
        menu.insertItem(openInNewTab, at: 0)

        if menu.items.count > 2,
           !menu.items[2].isSeparatorItem {
            menu.insertItem(.separator(), at: 2)
        }

        return menu
    }

    @objc private func openContextLinkInNewTab(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else {
            return
        }

        openURLInNewTab?(url)
    }

    @objc private func openContextLinkInNewWindow(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else {
            return
        }

        openURLInNewWindow?(url)
    }

    private func removeDefaultOpenLinkItems(from menu: NSMenu) {
        for item in menu.items.reversed() where isDefaultOpenLinkTabOrWindowItem(item) {
            menu.removeItem(item)
        }

        while menu.items.first?.isSeparatorItem == true {
            menu.removeItem(at: 0)
        }
    }

    private func isDefaultOpenLinkTabOrWindowItem(_ item: NSMenuItem) -> Bool {
        let title = item.title.lowercased()
        return title.contains("open link")
            && (title.contains("new tab") || title.contains("new window"))
    }
}

private final class WeakScriptMessageHandler: NSObject, WKScriptMessageHandler {
    weak var delegate: (any WKScriptMessageHandler)?

    init(delegate: any WKScriptMessageHandler) {
        self.delegate = delegate
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        delegate?.userContentController(userContentController, didReceive: message)
    }
}
