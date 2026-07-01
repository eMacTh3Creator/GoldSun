import Foundation

public enum AdBlockProtectionLevel: String, CaseIterable, Codable, Identifiable, Sendable {
    case off
    case balanced
    case strict
    case custom

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .off:
            "Off"
        case .balanced:
            "Balanced"
        case .strict:
            "Strict"
        case .custom:
            "Custom"
        }
    }
}

public enum AdBlockFilterList: String, CaseIterable, Codable, Identifiable, Sendable {
    case easyList
    case easyPrivacy
    case annoyances
    case malware
    case regional
    case customRules

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .easyList:
            "EasyList"
        case .easyPrivacy:
            "EasyPrivacy"
        case .annoyances:
            "Annoyances"
        case .malware:
            "Malware Protection"
        case .regional:
            "Regional Lists"
        case .customRules:
            "Custom Rules"
        }
    }

    public var isEnabledByDefault: Bool {
        switch self {
        case .easyList, .easyPrivacy, .malware:
            true
        case .annoyances, .regional, .customRules:
            false
        }
    }

    public var preferenceKey: String {
        "adBlock.filterList.\(rawValue)"
    }

    public var sourceURL: URL? {
        switch self {
        case .easyList:
            URL(string: "https://easylist.to/easylist/easylist.txt")
        case .easyPrivacy:
            URL(string: "https://easylist.to/easylist/easyprivacy.txt")
        case .annoyances:
            URL(string: "https://secure.fanboy.co.nz/fanboy-annoyance.txt")
        case .malware:
            URL(string: "https://malware-filter.gitlab.io/malware-filter/urlhaus-filter.txt")
        case .regional, .customRules:
            nil
        }
    }
}

public struct AdBlockConfiguration: Codable, Equatable, Sendable {
    public var isEnabled: Bool
    public var protectionLevel: AdBlockProtectionLevel
    public var blocksTrackers: Bool
    public var hidesPlaceholders: Bool
    public var allowsAcceptableAds: Bool
    public var updatesFilterListsAutomatically: Bool
    public var enabledFilterLists: Set<AdBlockFilterList>

    public init(
        isEnabled: Bool,
        protectionLevel: AdBlockProtectionLevel,
        blocksTrackers: Bool,
        hidesPlaceholders: Bool,
        allowsAcceptableAds: Bool,
        updatesFilterListsAutomatically: Bool,
        enabledFilterLists: Set<AdBlockFilterList>
    ) {
        self.isEnabled = isEnabled
        self.protectionLevel = protectionLevel
        self.blocksTrackers = blocksTrackers
        self.hidesPlaceholders = hidesPlaceholders
        self.allowsAcceptableAds = allowsAcceptableAds
        self.updatesFilterListsAutomatically = updatesFilterListsAutomatically
        self.enabledFilterLists = enabledFilterLists
    }

    public static let defaults = AdBlockConfiguration(
        isEnabled: true,
        protectionLevel: .balanced,
        blocksTrackers: true,
        hidesPlaceholders: true,
        allowsAcceptableAds: false,
        updatesFilterListsAutomatically: true,
        enabledFilterLists: Set(AdBlockFilterList.allCases.filter(\.isEnabledByDefault))
    )
}
