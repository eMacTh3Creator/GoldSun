import Foundation
import GoldSunCore

@MainActor
final class HistoryStore: ObservableObject {
    @Published private(set) var entries: [BrowserHistoryEntry]

    private let fileURL: URL
    private let maxEntries = 2_000

    init(fileManager: FileManager = .default) {
        fileURL = HistoryStore.storageURL(fileManager: fileManager)
        entries = []
        load()
    }

    var isEnabled: Bool {
        UserDefaults.standard.object(forKey: BrowserHistoryPreferenceKey.isEnabled) as? Bool
            ?? BrowserHistoryConfiguration.defaults.isEnabled
    }

    func record(title: String?, url: URL?) {
        guard isEnabled,
              let url,
              Self.canRecord(url) else {
            return
        }

        let key = normalizedURLKey(url)
        let now = Date()
        let cleanedTitle = normalizedTitle(title, fallbackURL: url)

        if let index = entries.firstIndex(where: { normalizedURLKey($0.url) == key }) {
            var updated = entries[index]
            updated.title = cleanedTitle
            updated.url = url
            updated.visitCount += 1
            updated.lastVisitedAt = now
            entries[index] = updated
        } else {
            entries.append(
                BrowserHistoryEntry(
                    title: cleanedTitle,
                    url: url,
                    firstVisitedAt: now,
                    lastVisitedAt: now
                )
            )
        }

        entries = entries
            .sorted { $0.lastVisitedAt > $1.lastVisitedAt }
            .prefix(maxEntries)
            .map { $0 }
        save()
    }

    func delete(_ entry: BrowserHistoryEntry) {
        entries.removeAll { $0.id == entry.id }
        save()
    }

    func clear() {
        entries.removeAll()
        save()
    }

    private func load() {
        do {
            let data = try Data(contentsOf: fileURL)
            let decodedEntries = try JSONDecoder().decode([BrowserHistoryEntry].self, from: data)
            entries = deduplicated(decodedEntries)

            if entries.count != decodedEntries.count {
                save()
            }
        } catch {
            entries = []
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
            let data = try encoder.encode(entries)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            assertionFailure("Failed to save history: \(error)")
        }
    }

    private func deduplicated(_ entries: [BrowserHistoryEntry]) -> [BrowserHistoryEntry] {
        var seenURLKeys = Set<String>()
        var uniqueEntries: [BrowserHistoryEntry] = []

        for entry in entries.sorted(by: { $0.lastVisitedAt > $1.lastVisitedAt }) {
            let key = normalizedURLKey(entry.url)
            guard !seenURLKeys.contains(key),
                  Self.canRecord(entry.url) else {
                continue
            }

            seenURLKeys.insert(key)
            uniqueEntries.append(entry)
        }

        return Array(uniqueEntries.prefix(maxEntries))
    }

    private func normalizedTitle(_ title: String?, fallbackURL: URL) -> String {
        let trimmed = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmed.isEmpty,
           trimmed != fallbackURL.absoluteString {
            return trimmed
        }

        return fallbackURL.host(percentEncoded: false) ?? fallbackURL.absoluteString
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

    private static func canRecord(_ url: URL) -> Bool {
        guard !BrowserDestination.isInternal(url) else {
            return false
        }

        return url.scheme?.caseInsensitiveCompare("http") == .orderedSame
            || url.scheme?.caseInsensitiveCompare("https") == .orderedSame
    }

    private static func storageURL(fileManager: FileManager) -> URL {
        let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")

        return baseURL
            .appendingPathComponent("GoldSun", isDirectory: true)
            .appendingPathComponent("History.json")
    }
}
