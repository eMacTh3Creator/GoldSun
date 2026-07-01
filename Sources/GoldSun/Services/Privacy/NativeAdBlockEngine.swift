import Foundation
import GoldSunCore

struct NativeAdBlockEnginePlan {
    let configuration: AdBlockConfiguration

    var activeFilterLists: [AdBlockFilterList] {
        AdBlockFilterList.allCases.filter { configuration.enabledFilterLists.contains($0) }
    }

    var shouldCompileRules: Bool {
        configuration.isEnabled && configuration.protectionLevel != .off
    }
}
