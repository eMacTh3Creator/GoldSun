import Foundation
import GoldSunCore
import WebKit

enum WebKitContentBlocker {
    static func install(on webView: WKWebView) {
        guard UserDefaults.standard.object(forKey: "adBlockEnabled") as? Bool ?? AdBlockConfiguration.defaults.isEnabled else {
            return
        }

        let protectionLevel = currentProtectionLevel()
        guard protectionLevel != .off else {
            return
        }

        let rules = rules(
            protectionLevel: protectionLevel,
            blocksTrackers: UserDefaults.standard.object(forKey: "adBlockBlocksTrackers") as? Bool ?? AdBlockConfiguration.defaults.blocksTrackers,
            hidesPlaceholders: UserDefaults.standard.object(forKey: "adBlockHidesPlaceholders") as? Bool ?? AdBlockConfiguration.defaults.hidesPlaceholders
        )

        guard let encodedRules = encodedContentRules(rules) else {
            return
        }

        let identifier = "goldsun.native-blocker.\(rules.count).\(protectionLevel.rawValue)"
        WKContentRuleListStore.default().compileContentRuleList(
            forIdentifier: identifier,
            encodedContentRuleList: encodedRules
        ) { [weak webView] contentRuleList, error in
            guard let contentRuleList, error == nil else {
                return
            }

            Task { @MainActor in
                webView?.configuration.userContentController.add(contentRuleList)
            }
        }
    }

    private static func currentProtectionLevel() -> AdBlockProtectionLevel {
        let rawValue = UserDefaults.standard.string(forKey: "adBlockProtectionLevel") ?? AdBlockConfiguration.defaults.protectionLevel.rawValue
        return AdBlockProtectionLevel(rawValue: rawValue) ?? .balanced
    }

    private static func encodedContentRules(_ rules: [[String: Any]]) -> String? {
        guard JSONSerialization.isValidJSONObject(rules),
              let data = try? JSONSerialization.data(withJSONObject: rules),
              let json = String(data: data, encoding: .utf8) else {
            return nil
        }

        return json
    }

    private static func rules(
        protectionLevel: AdBlockProtectionLevel,
        blocksTrackers: Bool,
        hidesPlaceholders: Bool
    ) -> [[String: Any]] {
        var patterns = [
            ".*doubleclick\\.net/.*",
            ".*googlesyndication\\.com/.*",
            ".*googleadservices\\.com/.*",
            ".*googletagservices\\.com/.*",
            ".*amazon-adsystem\\.com/.*",
            ".*adnxs\\.com/.*",
            ".*adsystem\\.com/.*",
            ".*criteo\\.com/.*",
            ".*outbrain\\.com/.*",
            ".*taboola\\.com/.*"
        ]

        if blocksTrackers {
            patterns.append(contentsOf: [
                ".*google-analytics\\.com/.*",
                ".*googletagmanager\\.com/.*",
                ".*scorecardresearch\\.com/.*",
                ".*quantserve\\.com/.*",
                ".*moatads\\.com/.*",
                ".*hotjar\\.com/.*",
                ".*mixpanel\\.com/.*",
                ".*segment\\.io/.*"
            ])
        }

        if protectionLevel == .strict {
            patterns.append(contentsOf: [
                ".*facebook\\.com/tr/.*",
                ".*connect\\.facebook\\.net/.*",
                ".*analytics\\.tiktok\\.com/.*",
                ".*bat\\.bing\\.com/.*",
                ".*coinhive\\.com/.*",
                ".*crypto-loot\\.com/.*",
                ".*fingerprintjs\\.com/.*"
            ])
        }

        var rules = patterns.map { pattern in
            [
                "trigger": [
                    "url-filter": pattern,
                    "load-type": ["third-party"]
                ],
                "action": [
                    "type": "block"
                ]
            ]
        }

        if protectionLevel == .strict || hidesPlaceholders {
            rules.append([
                "trigger": [
                    "url-filter": ".*"
                ],
                "action": [
                    "type": "css-display-none",
                    "selector": "[id^='google_ads'], [id^='div-gpt-ad'], [class*=' ad-slot'], [class*=' sponsored'], [aria-label='Advertisement']"
                ]
            ])
        }

        return rules
    }
}
