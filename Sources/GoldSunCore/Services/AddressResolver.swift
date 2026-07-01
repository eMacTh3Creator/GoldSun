import Foundation

public enum SearchEngine: String, CaseIterable, Codable, Identifiable, Sendable {
    case duckDuckGo
    case google

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .duckDuckGo:
            "DuckDuckGo"
        case .google:
            "Google"
        }
    }

    func searchURL(for query: String) -> URL {
        var components: URLComponents

        switch self {
        case .duckDuckGo:
            components = URLComponents(string: "https://duckduckgo.com/")!
        case .google:
            components = URLComponents(string: "https://www.google.com/search")!
        }

        components.queryItems = [
            URLQueryItem(name: "q", value: query)
        ]

        return components.url!
    }
}

public enum AddressResolver {
    public static func resolvedURL(
        from rawAddress: String,
        searchEngine: SearchEngine = .duckDuckGo
    ) -> URL {
        let address = rawAddress.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !address.isEmpty else {
            return URL(string: "about:blank")!
        }

        if shouldPreserveScheme(in: address), let url = URL(string: address) {
            return url
        }

        if looksLikeHostOrPath(address) {
            let scheme = hasCaseInsensitivePrefix(address, "localhost") ? "http" : "https"
            return URL(string: "\(scheme)://\(address)")!
        }

        return searchEngine.searchURL(for: address)
    }

    private static func shouldPreserveScheme(in address: String) -> Bool {
        guard let scheme = URLComponents(string: address)?.scheme else {
            return false
        }

        if address.contains("://") {
            return true
        }

        return ["about", "file", "mailto"].contains(scheme.lowercased())
    }

    private static func looksLikeHostOrPath(_ address: String) -> Bool {
        guard !address.contains(where: { $0.isWhitespace }) else {
            return false
        }

        if hasCaseInsensitivePrefix(address, "localhost") {
            return true
        }

        let hostCandidate = address
            .split(separator: "/", maxSplits: 1, omittingEmptySubsequences: true)
            .first?
            .split(separator: ":", maxSplits: 1, omittingEmptySubsequences: true)
            .first

        guard let hostCandidate else {
            return false
        }

        return hostCandidate.contains(".")
    }

    private static func hasCaseInsensitivePrefix(_ address: String, _ prefix: String) -> Bool {
        address.range(of: prefix, options: [.anchored, .caseInsensitive]) != nil
    }
}
