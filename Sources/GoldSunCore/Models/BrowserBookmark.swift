import Foundation

public struct BrowserBookmark: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var title: String
    public var url: URL
    public var folder: String
    public var showsInBar: Bool
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        title: String,
        url: URL,
        folder: String = "Favorites",
        showsInBar: Bool = true,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.url = url
        self.folder = folder
        self.showsInBar = showsInBar
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
