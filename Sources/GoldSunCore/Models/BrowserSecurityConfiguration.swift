import Foundation

public enum HTTPSUpgradeMode: String, CaseIterable, Codable, Identifiable, Sendable {
    case automaticFallback
    case strict
    case off

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .automaticFallback:
            "Upgrade with fallback"
        case .strict:
            "Require HTTPS"
        case .off:
            "Off"
        }
    }
}

public enum BrowserSecurityPreferenceKey {
    public static let httpsUpgradeMode = "security.httpsUpgradeMode"
    public static let fraudulentWebsiteWarnings = "security.fraudulentWebsiteWarnings"
    public static let privateBrowsingByDefault = "security.privateBrowsingByDefault"
    public static let javaScriptEnabled = "security.javaScriptEnabled"
    public static let blocksAutomaticPopups = "security.blocksAutomaticPopups"
    public static let stripsTrackingParameters = "security.stripsTrackingParameters"
}

public struct BrowserSecurityConfiguration: Codable, Equatable, Sendable {
    public var httpsUpgradeMode: HTTPSUpgradeMode
    public var fraudulentWebsiteWarnings: Bool
    public var privateBrowsingByDefault: Bool
    public var javaScriptEnabled: Bool
    public var blocksAutomaticPopups: Bool
    public var stripsTrackingParameters: Bool

    public init(
        httpsUpgradeMode: HTTPSUpgradeMode,
        fraudulentWebsiteWarnings: Bool,
        privateBrowsingByDefault: Bool,
        javaScriptEnabled: Bool,
        blocksAutomaticPopups: Bool,
        stripsTrackingParameters: Bool
    ) {
        self.httpsUpgradeMode = httpsUpgradeMode
        self.fraudulentWebsiteWarnings = fraudulentWebsiteWarnings
        self.privateBrowsingByDefault = privateBrowsingByDefault
        self.javaScriptEnabled = javaScriptEnabled
        self.blocksAutomaticPopups = blocksAutomaticPopups
        self.stripsTrackingParameters = stripsTrackingParameters
    }

    public static let defaults = BrowserSecurityConfiguration(
        httpsUpgradeMode: .automaticFallback,
        fraudulentWebsiteWarnings: true,
        privateBrowsingByDefault: false,
        javaScriptEnabled: true,
        blocksAutomaticPopups: true,
        stripsTrackingParameters: true
    )
}
