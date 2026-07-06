import GoldSunCore
import XCTest

final class AddressResolverTests: XCTestCase {
    func testPreservesExplicitHTTPSURL() {
        let url = AddressResolver.resolvedURL(from: "https://example.com/docs")

        XCTAssertEqual(url.absoluteString, "https://example.com/docs")
    }

    func testAddsHTTPSForHostnames() {
        let url = AddressResolver.resolvedURL(from: "example.com")

        XCTAssertEqual(url.absoluteString, "https://example.com")
    }

    func testUsesHTTPForLocalhost() {
        let url = AddressResolver.resolvedURL(from: "localhost:3000")

        XCTAssertEqual(url.absoluteString, "http://localhost:3000")
    }

    func testPreservesGoldSunInternalStartPageURL() {
        let url = AddressResolver.resolvedURL(from: BrowserDestination.goldSunStartPage.absoluteString)

        XCTAssertEqual(url, BrowserDestination.goldSunStartPage)
    }

    func testPreservesGoldSunInternalManagerURLs() {
        XCTAssertEqual(
            AddressResolver.resolvedURL(from: BrowserDestination.bookmarkManager.absoluteString),
            BrowserDestination.bookmarkManager
        )
        XCTAssertEqual(
            AddressResolver.resolvedURL(from: BrowserDestination.downloadManager.absoluteString),
            BrowserDestination.downloadManager
        )
        XCTAssertEqual(
            AddressResolver.resolvedURL(from: BrowserDestination.historyManager.absoluteString),
            BrowserDestination.historyManager
        )
        XCTAssertEqual(
            AddressResolver.resolvedURL(from: BrowserDestination.passwordManager.absoluteString),
            BrowserDestination.passwordManager
        )
    }

    func testSearchesPlainLanguageInput() {
        let url = AddressResolver.resolvedURL(from: "swift browser architecture")
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)

        XCTAssertEqual(components?.host, "duckduckgo.com")
        XCTAssertTrue(url.absoluteString.contains("swift%20browser%20architecture"))
    }

    func testAdBlockDefaultsEnableBalancedProtection() {
        let defaults = AdBlockConfiguration.defaults

        XCTAssertTrue(defaults.isEnabled)
        XCTAssertEqual(defaults.protectionLevel, .balanced)
        XCTAssertTrue(defaults.enabledFilterLists.contains(.easyList))
        XCTAssertTrue(defaults.enabledFilterLists.contains(.easyPrivacy))
    }

    func testSecurityDefaultsPreferHTTPSAndWarnings() {
        let defaults = BrowserSecurityConfiguration.defaults

        XCTAssertEqual(defaults.httpsUpgradeMode, .automaticFallback)
        XCTAssertTrue(defaults.fraudulentWebsiteWarnings)
        XCTAssertTrue(defaults.javaScriptEnabled)
        XCTAssertTrue(defaults.blocksAutomaticPopups)
        XCTAssertTrue(defaults.stripsTrackingParameters)
        XCTAssertFalse(defaults.privateBrowsingByDefault)
    }

    func testHistoryDefaultsAreEnabled() {
        XCTAssertTrue(BrowserHistoryConfiguration.defaults.isEnabled)
        XCTAssertEqual(BrowserHistoryPreferenceKey.isEnabled, "history.isEnabled")
    }

    func testChromiumCompatibilityTargetTracksStableMacRelease() {
        XCTAssertEqual(ChromiumRuntimeVersion.latestKnownGoodVersion, "150.0.7871.47")
        XCTAssertEqual(ChromiumRuntimeVersion.latestKnownGoodRevision, "1639810")
        XCTAssertEqual(ChromiumRuntimeVersion.majorVersion, "150")
        XCTAssertEqual(WebBrowserCapability.passkeyEntitlement, "com.apple.developer.web-browser.public-key-credential")
    }

    func testBookmarkStoresBarPreference() {
        let url = URL(string: "https://example.com")!
        let bookmark = BrowserBookmark(title: "Example", url: url, folder: "Favorites", showsInBar: true)

        XCTAssertEqual(bookmark.url, url)
        XCTAssertEqual(bookmark.folder, "Favorites")
        XCTAssertTrue(bookmark.showsInBar)
    }

    func testAppVersionComparesMultiDigitVersions() {
        XCTAssertGreaterThan(AppVersion("v0.1.10")!, AppVersion("0.1.2")!)
        XCTAssertEqual(AppVersion("0.1")!, AppVersion("0.1.0")!)
        XCTAssertLessThan(AppVersion("0.1.1")!, AppVersion("0.2.0")!)
    }
}
