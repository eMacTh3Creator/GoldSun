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

    func bookmark(for url: URL?) -> BrowserBookmark? {
        guard let url else {
            return nil
        }

        let key = normalizedURLKey(url)
        return bookmarks.first { normalizedURLKey($0.url) == key }
    }

    func isBookmarked(_ url: URL?) -> Bool {
        bookmark(for: url) != nil
    }

    @discardableResult
    func add(title: String, url: URL, folder: String = "Favorites", showsInBar: Bool = true) -> BrowserBookmark {
        if let existing = bookmark(for: url) {
            return existing
        }

        let bookmark = BrowserBookmark(
            title: normalizedTitle(title, fallbackURL: url),
            url: url,
            folder: normalizedFolder(folder),
            showsInBar: showsInBar
        )

        bookmarks.append(bookmark)
        save()
        return bookmark
    }

    @discardableResult
    func addCurrentPage(from tab: BrowserTabSession?) -> BrowserBookmark? {
        guard let tab,
              !BrowserDestination.isInternal(tab.url) else {
            return nil
        }

        return add(title: tab.title, url: tab.url)
    }

    @discardableResult
    func update(_ bookmark: BrowserBookmark) -> BrowserBookmark? {
        guard let index = bookmarks.firstIndex(where: { $0.id == bookmark.id }) else {
            return nil
        }

        if let duplicateIndex = bookmarks.firstIndex(where: {
            $0.id != bookmark.id && normalizedURLKey($0.url) == normalizedURLKey(bookmark.url)
        }) {
            var duplicate = bookmarks[duplicateIndex]
            duplicate.title = normalizedTitle(bookmark.title, fallbackURL: bookmark.url)
            duplicate.folder = normalizedFolder(bookmark.folder)
            duplicate.showsInBar = bookmark.showsInBar
            duplicate.updatedAt = Date()
            bookmarks[duplicateIndex] = duplicate
            bookmarks.remove(at: index)
            save()
            return duplicate
        }

        var updated = bookmark
        updated.title = normalizedTitle(updated.title, fallbackURL: updated.url)
        updated.folder = normalizedFolder(updated.folder)
        updated.updatedAt = Date()
        bookmarks[index] = updated
        save()
        return updated
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
            let decodedBookmarks = try JSONDecoder().decode([BrowserBookmark].self, from: data)
            bookmarks = deduplicated(decodedBookmarks)

            if bookmarks.count != decodedBookmarks.count {
                save()
            }
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

    private func normalizedURLKey(_ url: URL) -> String {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url.absoluteString
                .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                .lowercased()
        }

        components.scheme = components.scheme?.lowercased()
        components.host = components.host?.lowercased()
        components.fragment = nil

        if components.path != "/" {
            components.path = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            if !components.path.isEmpty {
                components.path = "/" + components.path
            }
        }

        return components.url?.absoluteString.lowercased() ?? url.absoluteString.lowercased()
    }

    private func deduplicated(_ bookmarks: [BrowserBookmark]) -> [BrowserBookmark] {
        var seenURLKeys = Set<String>()
        var uniqueBookmarks: [BrowserBookmark] = []

        for bookmark in bookmarks {
            let key = normalizedURLKey(bookmark.url)
            guard !seenURLKeys.contains(key) else {
                continue
            }

            seenURLKeys.insert(key)
            uniqueBookmarks.append(bookmark)
        }

        return uniqueBookmarks
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
