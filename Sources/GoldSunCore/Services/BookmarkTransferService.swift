import Foundation

public enum BookmarkExportFormat: String, CaseIterable, Identifiable, Sendable {
    case browserHTML
    case goldSunJSON

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .browserHTML:
            "Browser HTML"
        case .goldSunJSON:
            "GoldSun JSON"
        }
    }

    public var filenameExtension: String {
        switch self {
        case .browserHTML:
            "html"
        case .goldSunJSON:
            "json"
        }
    }
}

public enum BookmarkTransferError: LocalizedError, Sendable {
    case unsupportedFormat
    case invalidTextEncoding
    case invalidJSON
    case invalidPropertyList

    public var errorDescription: String? {
        switch self {
        case .unsupportedFormat:
            "GoldSun could not find browser bookmarks in that file."
        case .invalidTextEncoding:
            "GoldSun could not read the bookmark file text."
        case .invalidJSON:
            "GoldSun could not read the bookmark JSON."
        case .invalidPropertyList:
            "GoldSun could not read the Safari bookmark property list."
        }
    }
}

public enum BookmarkTransferService {
    public static func importedBookmarks(from data: Data, filename: String? = nil) throws -> [BrowserBookmark] {
        let lowercasedName = filename?.lowercased() ?? ""

        if lowercasedName.hasSuffix(".plist") {
            return try safariBookmarks(from: data)
        }

        if lowercasedName.hasSuffix(".json") {
            if let chromeBookmarks = try? chromeBookmarks(from: data), !chromeBookmarks.isEmpty {
                return chromeBookmarks
            }

            return try goldSunBookmarks(from: data)
        }

        if let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1),
           text.localizedCaseInsensitiveContains("<DT><A")
            || text.localizedCaseInsensitiveContains("<A HREF=") {
            return netscapeBookmarks(from: text)
        }

        if let chromeBookmarks = try? chromeBookmarks(from: data), !chromeBookmarks.isEmpty {
            return chromeBookmarks
        }

        if let safariBookmarks = try? safariBookmarks(from: data), !safariBookmarks.isEmpty {
            return safariBookmarks
        }

        throw BookmarkTransferError.unsupportedFormat
    }

    public static func exportedData(for bookmarks: [BrowserBookmark], format: BookmarkExportFormat) throws -> Data {
        switch format {
        case .browserHTML:
            return browserHTML(from: bookmarks).data(using: .utf8) ?? Data()
        case .goldSunJSON:
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            return try encoder.encode(bookmarks)
        }
    }

    public static func netscapeBookmarks(from text: String) -> [BrowserBookmark] {
        var bookmarks: [BrowserBookmark] = []
        var folderStack: [String] = ["Favorites"]
        var pendingFolder: String?

        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)

            if line.range(of: #"<H3\b"#, options: [.regularExpression, .caseInsensitive]) != nil,
               let folderName = innerHTML(in: line, tag: "H3") {
                pendingFolder = decodedHTMLEntities(in: folderName)
                continue
            }

            if line.range(of: #"<DL\b"#, options: [.regularExpression, .caseInsensitive]) != nil {
                if let folderName = pendingFolder {
                    folderStack.append(normalizedFolder(folderName))
                    pendingFolder = nil
                }
                continue
            }

            if line.range(of: #"</DL>"#, options: [.regularExpression, .caseInsensitive]) != nil {
                if folderStack.count > 1 {
                    folderStack.removeLast()
                }
                continue
            }

            guard line.range(of: #"<A\b"#, options: [.regularExpression, .caseInsensitive]) != nil,
                  let href = attribute("HREF", in: line),
                  let url = URL(string: decodedHTMLEntities(in: href)) else {
                continue
            }

            let title = innerHTML(in: line, tag: "A").map(decodedHTMLEntities)
                ?? url.host(percentEncoded: false)
                ?? url.absoluteString
            let addDate = attribute("ADD_DATE", in: line).flatMap(TimeInterval.init)
            let lastModified = attribute("LAST_MODIFIED", in: line).flatMap(TimeInterval.init)
            let folder = folderStack.last ?? "Favorites"

            bookmarks.append(
                BrowserBookmark(
                    title: title,
                    url: url,
                    folder: folder,
                    showsInBar: isBookmarkBarFolder(folder),
                    createdAt: addDate.map(Date.init(timeIntervalSince1970:)) ?? Date(),
                    updatedAt: lastModified.map(Date.init(timeIntervalSince1970:)) ?? Date()
                )
            )
        }

        return bookmarks
    }

    private static func goldSunBookmarks(from data: Data) throws -> [BrowserBookmark] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        if let bookmarks = try? decoder.decode([BrowserBookmark].self, from: data) {
            return bookmarks
        }

        do {
            return try JSONDecoder().decode([BrowserBookmark].self, from: data)
        } catch {
            throw BookmarkTransferError.invalidJSON
        }
    }

    private static func chromeBookmarks(from data: Data) throws -> [BrowserBookmark] {
        let object = try JSONSerialization.jsonObject(with: data)
        guard let root = object as? [String: Any] else {
            throw BookmarkTransferError.invalidJSON
        }

        var bookmarks: [BrowserBookmark] = []

        if let roots = root["roots"] as? [String: Any] {
            for (_, value) in roots {
                appendChromeBookmarks(from: value, folderStack: [], into: &bookmarks)
            }
        } else {
            appendChromeBookmarks(from: root, folderStack: [], into: &bookmarks)
        }

        return bookmarks
    }

    private static func appendChromeBookmarks(from node: Any, folderStack: [String], into bookmarks: inout [BrowserBookmark]) {
        guard let dictionary = node as? [String: Any] else {
            return
        }

        let type = dictionary["type"] as? String

        if type == "url",
           let urlString = dictionary["url"] as? String,
           let url = URL(string: urlString) {
            let folder = normalizedFolder(folderStack.last ?? "Favorites")
            let date = chromeDate(from: dictionary["date_added"] as? String)
            bookmarks.append(
                BrowserBookmark(
                    title: dictionary["name"] as? String ?? url.host(percentEncoded: false) ?? url.absoluteString,
                    url: url,
                    folder: folder,
                    showsInBar: isBookmarkBarFolder(folder),
                    createdAt: date ?? Date(),
                    updatedAt: date ?? Date()
                )
            )
            return
        }

        let folderName = dictionary["name"] as? String
        let nextStack = folderName.map { folderStack + [normalizedFolder($0)] } ?? folderStack

        if let children = dictionary["children"] as? [Any] {
            for child in children {
                appendChromeBookmarks(from: child, folderStack: nextStack, into: &bookmarks)
            }
        }
    }

    private static func safariBookmarks(from data: Data) throws -> [BrowserBookmark] {
        let object = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        guard let root = object as? [String: Any] else {
            throw BookmarkTransferError.invalidPropertyList
        }

        var bookmarks: [BrowserBookmark] = []
        appendSafariBookmarks(from: root, folderStack: [], into: &bookmarks)
        return bookmarks
    }

    private static func appendSafariBookmarks(from node: [String: Any], folderStack: [String], into bookmarks: inout [BrowserBookmark]) {
        if let urlString = node["URLString"] as? String,
           let url = URL(string: urlString) {
            let folder = normalizedFolder(folderStack.last ?? "Favorites")
            let title = (node["URIDictionary"] as? [String: Any])?["title"] as? String
                ?? node["Title"] as? String
                ?? url.host(percentEncoded: false)
                ?? url.absoluteString

            bookmarks.append(
                BrowserBookmark(
                    title: title,
                    url: url,
                    folder: folder,
                    showsInBar: isBookmarkBarFolder(folder)
                )
            )
            return
        }

        let folderName = node["Title"] as? String
        let nextStack = folderName.map { folderStack + [normalizedFolder($0)] } ?? folderStack

        if let children = node["Children"] as? [[String: Any]] {
            for child in children {
                appendSafariBookmarks(from: child, folderStack: nextStack, into: &bookmarks)
            }
        }
    }

    private static func browserHTML(from bookmarks: [BrowserBookmark]) -> String {
        let sortedBookmarks = bookmarks.sorted { lhs, rhs in
            if lhs.folder == rhs.folder {
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }

            if lhs.showsInBar != rhs.showsInBar {
                return lhs.showsInBar
            }

            return lhs.folder.localizedCaseInsensitiveCompare(rhs.folder) == .orderedAscending
        }

        let grouped = Dictionary(grouping: sortedBookmarks, by: \.folder)
        let folderNames = grouped.keys.sorted { lhs, rhs in
            if isBookmarkBarFolder(lhs) != isBookmarkBarFolder(rhs) {
                return isBookmarkBarFolder(lhs)
            }

            return lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
        }

        var lines: [String] = [
            "<!DOCTYPE NETSCAPE-Bookmark-file-1>",
            "<META HTTP-EQUIV=\"Content-Type\" CONTENT=\"text/html; charset=UTF-8\">",
            "<TITLE>Bookmarks</TITLE>",
            "<H1>Bookmarks</H1>",
            "<DL><p>"
        ]

        for folderName in folderNames {
            let escapedFolderName = escapedHTML(folderName)
            let toolbarAttribute = isBookmarkBarFolder(folderName) ? " PERSONAL_TOOLBAR_FOLDER=\"true\"" : ""
            lines.append("    <DT><H3 ADD_DATE=\"\(unixTimestamp(Date()))\" LAST_MODIFIED=\"\(unixTimestamp(Date()))\"\(toolbarAttribute)>\(escapedFolderName)</H3>")
            lines.append("    <DL><p>")

            for bookmark in grouped[folderName] ?? [] {
                lines.append(
                    "        <DT><A HREF=\"\(escapedHTML(bookmark.url.absoluteString))\" ADD_DATE=\"\(unixTimestamp(bookmark.createdAt))\" LAST_MODIFIED=\"\(unixTimestamp(bookmark.updatedAt))\">\(escapedHTML(bookmark.title))</A>"
                )
            }

            lines.append("    </DL><p>")
        }

        lines.append("</DL><p>")
        return lines.joined(separator: "\n") + "\n"
    }

    private static func attribute(_ name: String, in line: String) -> String? {
        let pattern = #"\b\#(name)\s*=\s*(["'])(.*?)\1"#
        guard let range = line.range(of: pattern, options: [.regularExpression, .caseInsensitive]) else {
            return nil
        }

        let match = String(line[range])
        guard let equalsIndex = match.firstIndex(of: "=") else {
            return nil
        }

        let value = match[match.index(after: equalsIndex)...].trimmingCharacters(in: .whitespacesAndNewlines)
        return String(value.dropFirst().dropLast())
    }

    private static func innerHTML(in line: String, tag: String) -> String? {
        let pattern = #"<\#(tag)\b[^>]*>(.*?)</\#(tag)>"#
        guard let range = line.range(of: pattern, options: [.regularExpression, .caseInsensitive]) else {
            return nil
        }

        let matched = String(line[range])
        guard let openEnd = matched.firstIndex(of: ">"),
              let closeStart = matched.range(of: "</\(tag)", options: [.caseInsensitive])?.lowerBound else {
            return nil
        }

        return String(matched[matched.index(after: openEnd)..<closeStart])
    }

    private static func decodedHTMLEntities(in text: String) -> String {
        var decoded = text
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#34;", with: "\"")
            .replacingOccurrences(of: "&apos;", with: "'")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&#60;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&#62;", with: ">")
            .replacingOccurrences(of: "&amp;", with: "&")

        while let range = decoded.range(of: #"&#(\d+);"#, options: .regularExpression) {
            let entity = String(decoded[range])
            let numberText = entity.dropFirst(2).dropLast()
            guard let scalarValue = UInt32(numberText),
                  let scalar = UnicodeScalar(scalarValue) else {
                break
            }

            decoded.replaceSubrange(range, with: String(Character(scalar)))
        }

        return decoded
    }

    private static func escapedHTML(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    private static func normalizedFolder(_ folder: String) -> String {
        let trimmed = folder.trimmingCharacters(in: .whitespacesAndNewlines)

        switch trimmed.lowercased() {
        case "", "bookmarks", "bookmark menu", "menu":
            return "Favorites"
        case "bookmarks bar", "bookmark bar", "bookmarks toolbar", "favorites bar":
            return "Favorites"
        case "other bookmarks", "other favorites":
            return "Other Bookmarks"
        default:
            return trimmed
        }
    }

    private static func isBookmarkBarFolder(_ folder: String) -> Bool {
        let normalized = normalizedFolder(folder).lowercased()
        return normalized == "favorites"
            || normalized == "bookmarks bar"
            || normalized == "bookmark bar"
            || normalized == "bookmarks toolbar"
            || normalized == "favorites bar"
    }

    private static func chromeDate(from value: String?) -> Date? {
        guard let value,
              let microseconds = Double(value) else {
            return nil
        }

        let chromeEpochOffset: TimeInterval = 11_644_473_600
        return Date(timeIntervalSince1970: microseconds / 1_000_000 - chromeEpochOffset)
    }

    private static func unixTimestamp(_ date: Date) -> Int {
        Int(date.timeIntervalSince1970)
    }

}
