import Foundation

public enum BrowserDestination {
    public static let goldSunStartPage = URL(string: "goldsun://home")!
    public static let bookmarkManager = URL(string: "goldsun://bookmarks")!
    public static let downloadManager = URL(string: "goldsun://downloads")!
    public static let historyManager = URL(string: "goldsun://history")!
    public static let passwordManager = URL(string: "goldsun://passwords")!
    public static let startPageSearch = URL(string: "goldsun://search")!

    public static func isInternal(_ url: URL) -> Bool {
        url.scheme?.caseInsensitiveCompare("goldsun") == .orderedSame
    }

    public static func startPageSearchQuery(from url: URL) -> String? {
        guard isInternal(url),
              url.host(percentEncoded: false)?.caseInsensitiveCompare(startPageSearch.host(percentEncoded: false) ?? "") == .orderedSame,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let encodedValue = components.percentEncodedQueryItems?.first(where: { $0.name == "q" })?.value else {
            return nil
        }

        // Form GET submissions are application/x-www-form-urlencoded, which
        // encodes spaces as "+"; undo that before percent-decoding.
        return encodedValue
            .replacingOccurrences(of: "+", with: " ")
            .removingPercentEncoding
    }

    public static func isNativePage(_ url: URL) -> Bool {
        url == bookmarkManager
            || url == downloadManager
            || url == historyManager
            || url == passwordManager
    }
}
