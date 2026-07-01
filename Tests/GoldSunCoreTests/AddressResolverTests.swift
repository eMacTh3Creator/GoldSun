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

    func testExtensionDefaultsTargetChromeWebStoreManifestV3() {
        let defaults = ExtensionCompatibilityConfiguration.defaults

        XCTAssertTrue(defaults.isChromeWebStoreEnabled)
        XCTAssertEqual(defaults.installSourcePolicy, .chromeWebStore)
        XCTAssertEqual(defaults.manifestSupportMode, .manifestV3)
        XCTAssertTrue(defaults.requiresInstallReview)
    }
}
