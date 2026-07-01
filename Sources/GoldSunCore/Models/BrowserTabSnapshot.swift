import Foundation

public struct BrowserTabSnapshot: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var title: String
    public var url: URL
    public var isPinned: Bool
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        title: String,
        url: URL,
        isPinned: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.url = url
        self.isPinned = isPinned
        self.createdAt = createdAt
    }
}
