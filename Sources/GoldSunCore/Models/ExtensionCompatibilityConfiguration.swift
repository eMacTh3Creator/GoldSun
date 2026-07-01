import Foundation

public enum ExtensionManifestSupportMode: String, CaseIterable, Codable, Identifiable, Sendable {
    case manifestV3
    case manifestV3WithDeveloperLegacy

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .manifestV3:
            "Manifest V3"
        case .manifestV3WithDeveloperLegacy:
            "MV3 + Developer Legacy"
        }
    }
}

public enum ExtensionInstallSourcePolicy: String, CaseIterable, Codable, Identifiable, Sendable {
    case chromeWebStore
    case chromeWebStoreAndUnpacked
    case chromeWebStoreUnpackedAndCRX

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .chromeWebStore:
            "Chrome Web Store"
        case .chromeWebStoreAndUnpacked:
            "Store + Unpacked"
        case .chromeWebStoreUnpackedAndCRX:
            "Store + Unpacked + CRX"
        }
    }
}

public struct ExtensionCompatibilityConfiguration: Codable, Equatable, Sendable {
    public var isChromeWebStoreEnabled: Bool
    public var installSourcePolicy: ExtensionInstallSourcePolicy
    public var manifestSupportMode: ExtensionManifestSupportMode
    public var requiresInstallReview: Bool
    public var updatesExtensionsAutomatically: Bool
    public var allowsIncognitoExtensions: Bool

    public init(
        isChromeWebStoreEnabled: Bool,
        installSourcePolicy: ExtensionInstallSourcePolicy,
        manifestSupportMode: ExtensionManifestSupportMode,
        requiresInstallReview: Bool,
        updatesExtensionsAutomatically: Bool,
        allowsIncognitoExtensions: Bool
    ) {
        self.isChromeWebStoreEnabled = isChromeWebStoreEnabled
        self.installSourcePolicy = installSourcePolicy
        self.manifestSupportMode = manifestSupportMode
        self.requiresInstallReview = requiresInstallReview
        self.updatesExtensionsAutomatically = updatesExtensionsAutomatically
        self.allowsIncognitoExtensions = allowsIncognitoExtensions
    }

    public static let defaults = ExtensionCompatibilityConfiguration(
        isChromeWebStoreEnabled: true,
        installSourcePolicy: .chromeWebStore,
        manifestSupportMode: .manifestV3,
        requiresInstallReview: true,
        updatesExtensionsAutomatically: true,
        allowsIncognitoExtensions: false
    )
}
