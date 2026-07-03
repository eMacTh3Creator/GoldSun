import Foundation

public struct BrowserHistoryEntry: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var title: String
    public var url: URL
    public var visitCount: Int
    public var firstVisitedAt: Date
    public var lastVisitedAt: Date

    public init(
        id: UUID = UUID(),
        title: String,
        url: URL,
        visitCount: Int = 1,
        firstVisitedAt: Date = Date(),
        lastVisitedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.url = url
        self.visitCount = visitCount
        self.firstVisitedAt = firstVisitedAt
        self.lastVisitedAt = lastVisitedAt
    }

    public var host: String {
        url.host(percentEncoded: false) ?? url.absoluteString
    }
}

public enum BrowserHistoryPreferenceKey {
    public static let isEnabled = "history.isEnabled"
}

public struct BrowserHistoryConfiguration: Equatable, Sendable {
    public var isEnabled: Bool

    public init(isEnabled: Bool) {
        self.isEnabled = isEnabled
    }

    public static let defaults = BrowserHistoryConfiguration(isEnabled: true)
}
