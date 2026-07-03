import Foundation

public enum BrowserDestination {
    public static let goldSunStartPage = URL(string: "goldsun://home")!
    public static let bookmarkManager = URL(string: "goldsun://bookmarks")!
    public static let downloadManager = URL(string: "goldsun://downloads")!
    public static let historyManager = URL(string: "goldsun://history")!
    public static let passwordManager = URL(string: "goldsun://passwords")!
    public static let chromeWebStore = URL(string: "https://chromewebstore.google.com/")!

    public static func isInternal(_ url: URL) -> Bool {
        url.scheme?.caseInsensitiveCompare("goldsun") == .orderedSame
    }

    public static func isNativePage(_ url: URL) -> Bool {
        url == bookmarkManager
            || url == downloadManager
            || url == historyManager
            || url == passwordManager
    }
}
