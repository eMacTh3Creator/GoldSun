import Foundation
import GoldSunCore

struct ChromiumEngineBridge {
    let runtimeDirectory: URL
    let extensionPlan: ChromeExtensionBridgePlan
    let adBlockPlan: NativeAdBlockEnginePlan

    var engineKind: BrowserEngineKind {
        .chromiumCEF
    }
}

enum ChromiumIntegrationMilestone: String, CaseIterable, Identifiable {
    case singleViewHost
    case tabLifecycle
    case popupRouting
    case downloads
    case permissions
    case chromeWebStore
    case extensionRuntime
    case nativeAdBlocking
    case packaging

    var id: String { rawValue }
}
