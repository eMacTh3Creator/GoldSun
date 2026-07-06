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

    func testStartPageSearchQueryExtractsSubmittedText() {
        let submission = URL(string: "goldsun://search?q=https%3A%2F%2Fwww.youtube.com")!

        XCTAssertEqual(BrowserDestination.startPageSearchQuery(from: submission), "https://www.youtube.com")
    }

    func testStartPageSearchQueryDecodesFormEncodedSpacesAndPluses() {
        let spaces = URL(string: "goldsun://search?q=swift+browser+architecture")!
        let literalPlus = URL(string: "goldsun://search?q=c%2B%2B+tutorial")!

        XCTAssertEqual(BrowserDestination.startPageSearchQuery(from: spaces), "swift browser architecture")
        XCTAssertEqual(BrowserDestination.startPageSearchQuery(from: literalPlus), "c++ tutorial")
    }

    func testStartPageSearchQueryIgnoresOtherURLs() {
        XCTAssertNil(BrowserDestination.startPageSearchQuery(from: BrowserDestination.goldSunStartPage))
        XCTAssertNil(BrowserDestination.startPageSearchQuery(from: BrowserDestination.bookmarkManager))
        XCTAssertNil(BrowserDestination.startPageSearchQuery(from: URL(string: "goldsun://search")!))
        XCTAssertNil(BrowserDestination.startPageSearchQuery(from: URL(string: "https://duckduckgo.com/?q=example")!))
    }

    func testStartPageSubmissionOfFullURLNavigatesDirectly() {
        let submission = URL(string: "goldsun://search?q=https%3A%2F%2Fwww.youtube.com")!
        let query = BrowserDestination.startPageSearchQuery(from: submission)!

        XCTAssertEqual(AddressResolver.resolvedURL(from: query).absoluteString, "https://www.youtube.com")
    }

    func testStartPageSubmissionOfHostnameNavigatesDirectly() {
        let submission = URL(string: "goldsun://search?q=youtube.com")!
        let query = BrowserDestination.startPageSearchQuery(from: submission)!

        XCTAssertEqual(AddressResolver.resolvedURL(from: query).absoluteString, "https://youtube.com")
    }

    func testStartPageSubmissionOfPlainTextSearchesConfiguredEngine() {
        let submission = URL(string: "goldsun://search?q=swift%20browser%20architecture")!
        let query = BrowserDestination.startPageSearchQuery(from: submission)!
        let url = AddressResolver.resolvedURL(from: query, searchEngine: .google)
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)

        XCTAssertEqual(components?.host, "www.google.com")
        XCTAssertEqual(components?.queryItems?.first { $0.name == "q" }?.value, "swift browser architecture")
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
        XCTAssertEqual(ChromiumRuntimeVersion.latestKnownGoodVersion, "149.0.7827.201")
        XCTAssertEqual(ChromiumRuntimeVersion.latestKnownGoodRevision, "1625079")
        XCTAssertEqual(ChromiumRuntimeVersion.majorVersion, "149")
        XCTAssertTrue(ChromiumRuntimeVersion.cefDistributionVersion.hasSuffix("chromium-\(ChromiumRuntimeVersion.latestKnownGoodVersion)"))
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
