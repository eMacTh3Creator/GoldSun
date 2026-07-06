import Foundation

public enum ChromiumRuntimeVersion {
    public static let stableChannel = "Stable"
    public static let latestKnownGoodVersion = "150.0.7871.47"
    public static let latestKnownGoodRevision = "1639810"
    public static let majorVersion = "150"

    public static var displayName: String {
        "Chrome \(latestKnownGoodVersion)"
    }
}

public enum WebBrowserCapability {
    public static let passkeyEntitlement = "com.apple.developer.web-browser.public-key-credential"
}
