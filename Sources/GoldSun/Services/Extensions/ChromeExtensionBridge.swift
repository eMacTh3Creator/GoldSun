import Foundation
import GoldSunCore

struct ChromeExtensionBridgePlan {
    let configuration: ExtensionCompatibilityConfiguration

    var supportsChromeWebStoreInstall: Bool {
        configuration.isChromeWebStoreEnabled
    }

    var requiresManifestV3Runtime: Bool {
        configuration.manifestSupportMode == .manifestV3
    }
}
