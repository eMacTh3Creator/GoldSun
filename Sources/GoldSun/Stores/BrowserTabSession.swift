import Foundation
import GoldSunCore

@MainActor
final class BrowserTabSession: ObservableObject, Identifiable {
    let id: UUID
    let engineKind: BrowserEngineKind

    @Published var title: String
    @Published var url: URL
    @Published var isLoading: Bool
    @Published var estimatedProgress: Double
    @Published var canGoBack: Bool
    @Published var canGoForward: Bool
    @Published var navigationRequest: BrowserNavigationRequest
    @Published var pendingAction: BrowserAction?

    init(
        id: UUID = UUID(),
        title: String = "New Tab",
        url: URL,
        engineKind: BrowserEngineKind = .chromiumCEF
    ) {
        self.id = id
        self.title = title
        self.url = url
        self.engineKind = engineKind
        isLoading = false
        estimatedProgress = 0
        canGoBack = false
        canGoForward = false
        navigationRequest = BrowserNavigationRequest(url: url)
    }

    func load(_ url: URL) {
        self.url = url

        if url == BrowserDestination.bookmarkManager || url == BrowserDestination.downloadManager {
            isLoading = false
            estimatedProgress = 1
            canGoBack = false
            canGoForward = false
            return
        }

        navigationRequest = BrowserNavigationRequest(url: url)

        if BrowserDestination.isInternal(url) {
            isLoading = false
            estimatedProgress = 1
            canGoBack = false
            canGoForward = false
        }
    }

    func request(_ action: BrowserAction) {
        pendingAction = action
    }
}

struct BrowserNavigationRequest: Equatable {
    let id: UUID
    let url: URL

    init(id: UUID = UUID(), url: URL) {
        self.id = id
        self.url = url
    }
}

enum BrowserAction: Equatable {
    case goBack
    case goForward
    case reload
    case stopLoading
}
