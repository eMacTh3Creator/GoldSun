import Foundation
import GoldSunCore

@MainActor
final class BookmarkStore: ObservableObject {
    @Published private(set) var bookmarks: [BrowserBookmark]

    private let fileURL: URL

    init(fileManager: FileManager = .default) {
        fileURL = BookmarkStore.storageURL(fileManager: fileManager)
        bookmarks = []
        load()
    }

    var folders: [String] {
        let names = Set(bookmarks.map(\.folder).filter { !$0.isEmpty })
        return names.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    var bookmarkBarItems: [BrowserBookmark] {
        bookmarks
            .filter(\.showsInBar)
            .sorted { lhs, rhs in
                if lhs.folder == rhs.folder {
                    return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
                }

                return lhs.folder.localizedCaseInsensitiveCompare(rhs.folder) == .orderedAscending
            }
    }

    func add(title: String, url: URL, folder: String = "Favorites", showsInBar: Bool = true) {
        let bookmark = BrowserBookmark(
            title: normalizedTitle(title, fallbackURL: url),
            url: url,
            folder: normalizedFolder(folder),
            showsInBar: showsInBar
        )

        bookmarks.append(bookmark)
        save()
    }

    func addCurrentPage(from tab: BrowserTabSession?) {
        guard let tab else {
            return
        }

        add(title: tab.title, url: tab.url)
    }

    func update(_ bookmark: BrowserBookmark) {
        guard let index = bookmarks.firstIndex(where: { $0.id == bookmark.id }) else {
            return
        }

        var updated = bookmark
        updated.title = normalizedTitle(updated.title, fallbackURL: updated.url)
        updated.folder = normalizedFolder(updated.folder)
        updated.updatedAt = Date()
        bookmarks[index] = updated
        save()
    }

    func delete(_ bookmark: BrowserBookmark) {
        bookmarks.removeAll { $0.id == bookmark.id }
        save()
    }

    func delete(id: BrowserBookmark.ID?) {
        guard let id else {
            return
        }

        bookmarks.removeAll { $0.id == id }
        save()
    }

    func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        let movingBookmarks = source.sorted().map { bookmarks[$0] }

        for index in source.sorted(by: >) {
            bookmarks.remove(at: index)
        }

        let removedBeforeDestination = source.filter { $0 < destination }.count
        let adjustedDestination = destination - removedBeforeDestination
        let boundedDestination = max(0, min(adjustedDestination, bookmarks.count))
        bookmarks.insert(contentsOf: movingBookmarks, at: boundedDestination)
        save()
    }

    private func load() {
        do {
            let data = try Data(contentsOf: fileURL)
            bookmarks = try JSONDecoder().decode([BrowserBookmark].self, from: data)
        } catch {
            bookmarks = BookmarkStore.defaultBookmarks
            save()
        }
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(bookmarks)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            assertionFailure("Failed to save bookmarks: \(error)")
        }
    }

    private func normalizedTitle(_ title: String, fallbackURL: URL) -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return trimmed
        }

        return fallbackURL.host(percentEncoded: false) ?? fallbackURL.absoluteString
    }

    private func normalizedFolder(_ folder: String) -> String {
        let trimmed = folder.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Favorites" : trimmed
    }

    private static func storageURL(fileManager: FileManager) -> URL {
        let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")

        return baseURL
            .appendingPathComponent("GoldSun", isDirectory: true)
            .appendingPathComponent("Bookmarks.json")
    }

    private static let defaultBookmarks: [BrowserBookmark] = [
        BrowserBookmark(title: "GoldSun Releases", url: URL(string: "https://github.com/eMacTh3Creator/GoldSun/releases")!),
        BrowserBookmark(title: "Chrome Web Store", url: BrowserDestination.chromeWebStore, folder: "Extensions")
    ]
}
