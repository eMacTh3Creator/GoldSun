import AppKit
import GoldSunCore
import UniformTypeIdentifiers

@MainActor
enum BrowserDataTransferPanel {
    static func importBookmarks(into bookmarkStore: BookmarkStore) throws -> BookmarkImportSummary? {
        let panel = NSOpenPanel()
        panel.title = "Import Bookmarks"
        panel.prompt = "Import"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.html, .json, .propertyList]

        guard panel.runModal() == .OK, let url = panel.url else {
            return nil
        }

        return try bookmarkStore.importBookmarks(from: url)
    }

    static func exportBookmarks(from bookmarkStore: BookmarkStore, format: BookmarkExportFormat) throws -> URL? {
        let panel = NSSavePanel()
        panel.title = "Export Bookmarks"
        panel.prompt = "Export"
        panel.nameFieldStringValue = "GoldSun Bookmarks.\(format.filenameExtension)"
        panel.canCreateDirectories = true
        panel.allowedContentTypes = [contentType(for: format.filenameExtension)]

        guard panel.runModal() == .OK, let url = panel.url else {
            return nil
        }

        try bookmarkStore.exportBookmarks(to: url, format: format)
        return url
    }

    static func importPasswords(into passwordStore: PasswordStore) throws -> PasswordImportSummary? {
        let panel = NSOpenPanel()
        panel.title = "Import Passwords"
        panel.prompt = "Import"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.commaSeparatedText, contentType(for: "csv")]

        guard panel.runModal() == .OK, let url = panel.url else {
            return nil
        }

        return try passwordStore.importPasswords(from: url)
    }

    static func exportPasswords(from passwordStore: PasswordStore) throws -> URL? {
        let panel = NSSavePanel()
        panel.title = "Export Passwords"
        panel.prompt = "Export"
        panel.nameFieldStringValue = "GoldSun Passwords.csv"
        panel.canCreateDirectories = true
        panel.allowedContentTypes = [.commaSeparatedText, contentType(for: "csv")]

        guard panel.runModal() == .OK, let url = panel.url else {
            return nil
        }

        try passwordStore.exportPasswords(to: url)
        return url
    }

    static func present(_ error: Error) {
        let alert = NSAlert(error: error)
        alert.runModal()
    }

    private static func contentType(for filenameExtension: String) -> UTType {
        UTType(filenameExtension: filenameExtension) ?? .data
    }
}
