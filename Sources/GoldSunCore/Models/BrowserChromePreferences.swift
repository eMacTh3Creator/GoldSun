import Foundation

public enum TabDisplayMode: String, CaseIterable, Codable, Identifiable, Sendable {
    case sidebar
    case topBar
    case both

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .sidebar:
            "Sidebar"
        case .topBar:
            "Tab Bar"
        case .both:
            "Both"
        }
    }

    public var showsSidebar: Bool {
        self == .sidebar || self == .both
    }

    public var showsTabBar: Bool {
        self == .topBar || self == .both
    }
}
