import Foundation

public enum ChromiumRuntimeVersion {
    public static let stableChannel = "Stable"
    public static let latestKnownGoodVersion = "149.0.7827.201"
    public static let latestKnownGoodRevision = "1625079"
    public static let majorVersion = "149"

    /// Pinned CEF binary distribution that provides the Chromium runtime.
    /// Must stay in sync with script/fetch_cef.sh.
    public static let cefDistributionVersion = "149.0.6+g0d0eeb6+chromium-149.0.7827.201"

    public static var displayName: String {
        "Chrome \(latestKnownGoodVersion)"
    }
}

public enum WebBrowserCapability {
    public static let passkeyEntitlement = "com.apple.developer.web-browser.public-key-credential"
}
