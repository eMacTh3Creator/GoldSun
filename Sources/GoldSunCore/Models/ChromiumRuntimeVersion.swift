import Foundation

public enum ChromiumRuntimeVersion {
    public static let stableChannel = "Stable"
    public static let latestKnownGoodVersion = "150.0.7871.46"
    public static let latestKnownGoodRevision = "1639810"
    public static let majorVersion = "150"

    public static let macChromeCompatibleUserAgent =
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/\(majorVersion).0.0.0 Safari/537.36"

    public static var displayName: String {
        "Chrome \(latestKnownGoodVersion)"
    }
}

public enum WebBrowserCapability {
    public static let passkeyEntitlement = "com.apple.developer.web-browser.public-key-credential"
}
