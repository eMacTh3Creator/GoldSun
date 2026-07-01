import Foundation

public enum BrowserEngineKind: String, CaseIterable, Codable, Identifiable, Sendable {
    case chromiumCEF
    case webKitDevelopmentShim

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .chromiumCEF:
            "Chromium / CEF"
        case .webKitDevelopmentShim:
            "WebKit Development Shim"
        }
    }

    public var isProductionTarget: Bool {
        self == .chromiumCEF
    }
}
