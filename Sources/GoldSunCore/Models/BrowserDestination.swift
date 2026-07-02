import Foundation

public enum BrowserDestination {
    public static let goldSunStartPage = URL(string: "goldsun://home")!
    public static let bookmarkManager = URL(string: "goldsun://bookmarks")!
    public static let downloadManager = URL(string: "goldsun://downloads")!
    public static let chromeWebStore = URL(string: "https://chromewebstore.google.com/")!

    public static func isInternal(_ url: URL) -> Bool {
        url.scheme?.caseInsensitiveCompare("goldsun") == .orderedSame
    }
}
