import GoldSunCore
import XCTest

final class TransferServiceTests: XCTestCase {
    func testImportsNetscapeBookmarkHTML() throws {
        let html = """
        <!DOCTYPE NETSCAPE-Bookmark-file-1>
        <DL><p>
            <DT><H3 ADD_DATE="1782940000">Bookmarks Bar</H3>
            <DL><p>
                <DT><A HREF="https://example.com/path" ADD_DATE="1782940001">Example &amp; Docs</A>
            </DL><p>
        </DL><p>
        """

        let bookmarks = BookmarkTransferService.netscapeBookmarks(from: html)

        XCTAssertEqual(bookmarks.count, 1)
        XCTAssertEqual(bookmarks[0].title, "Example & Docs")
        XCTAssertEqual(bookmarks[0].url.absoluteString, "https://example.com/path")
        XCTAssertEqual(bookmarks[0].folder, "Favorites")
        XCTAssertTrue(bookmarks[0].showsInBar)
    }

    func testImportsChromeBookmarkJSON() throws {
        let json = """
        {
          "roots": {
            "bookmark_bar": {
              "type": "folder",
              "name": "Bookmarks Bar",
              "children": [
                { "type": "url", "name": "GoldSun", "url": "https://github.com/eMacTh3Creator/GoldSun" }
              ]
            }
          }
        }
        """

        let bookmarks = try BookmarkTransferService.importedBookmarks(from: Data(json.utf8), filename: "Bookmarks.json")

        XCTAssertEqual(bookmarks.count, 1)
        XCTAssertEqual(bookmarks[0].title, "GoldSun")
        XCTAssertEqual(bookmarks[0].folder, "Favorites")
    }

    func testExportsBrowserBookmarkHTML() throws {
        let bookmark = BrowserBookmark(
            title: "GoldSun",
            url: URL(string: "https://github.com/eMacTh3Creator/GoldSun")!,
            folder: "Favorites",
            showsInBar: true
        )

        let data = try BookmarkTransferService.exportedData(for: [bookmark], format: .browserHTML)
        let html = String(data: data, encoding: .utf8)

        XCTAssertTrue(html?.contains("<!DOCTYPE NETSCAPE-Bookmark-file-1>") == true)
        XCTAssertTrue(html?.contains("PERSONAL_TOOLBAR_FOLDER=\"true\"") == true)
        XCTAssertTrue(html?.contains("https://github.com/eMacTh3Creator/GoldSun") == true)
    }

    func testImportsBrowserPasswordCSV() throws {
        let csv = """
        name,url,username,password
        Example,https://example.com,person@example.com,"sec,ret"
        """

        let records = try PasswordTransferService.importedPasswords(fromCSV: Data(csv.utf8))

        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records[0].title, "Example")
        XCTAssertEqual(records[0].url.absoluteString, "https://example.com")
        XCTAssertEqual(records[0].username, "person@example.com")
        XCTAssertEqual(records[0].password, "sec,ret")
    }

    func testExportsBrowserPasswordCSV() {
        let data = PasswordTransferService.exportedCSV(
            from: [
                PasswordImportRecord(
                    title: "Example",
                    url: URL(string: "https://example.com")!,
                    username: "person@example.com",
                    password: "sec,ret"
                )
            ]
        )
        let csv = String(data: data, encoding: .utf8)

        XCTAssertEqual(csv, "name,url,username,password\nExample,https://example.com,person@example.com,\"sec,ret\"\n")
    }
}
