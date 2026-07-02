import GoldSunCore
import SwiftUI

struct FaviconView: View {
    let url: URL
    var size: CGFloat = 16
    var fallbackSystemImage = "globe"

    private let gold = Color(red: 0.91, green: 0.61, blue: 0.21)

    var body: some View {
        Group {
            if let internalIconName {
                Image(systemName: internalIconName)
                    .foregroundStyle(internalIconName == "sun.max.fill" ? gold : .secondary)
            } else if let faviconURL {
                AsyncImage(url: faviconURL) { phase in
                    switch phase {
                    case let .success(image):
                        image
                            .resizable()
                            .scaledToFit()
                    case .empty:
                        ProgressView()
                            .controlSize(.mini)
                    case .failure:
                        Image(systemName: fallbackSystemImage)
                            .foregroundStyle(.secondary)
                    @unknown default:
                        Image(systemName: fallbackSystemImage)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Image(systemName: fallbackSystemImage)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
        .font(.system(size: max(10, size - 2)))
    }

    private var internalIconName: String? {
        switch url {
        case BrowserDestination.goldSunStartPage:
            "sun.max.fill"
        case BrowserDestination.bookmarkManager:
            "book"
        case BrowserDestination.downloadManager:
            "tray.and.arrow.down"
        default:
            nil
        }
    }

    private var faviconURL: URL? {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let scheme = components.scheme?.lowercased(),
              scheme == "https" || scheme == "http",
              components.host != nil else {
            return nil
        }

        components.path = "/favicon.ico"
        components.query = nil
        components.fragment = nil
        return components.url
    }
}
