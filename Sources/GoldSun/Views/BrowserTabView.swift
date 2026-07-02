import SwiftUI
import GoldSunCore

struct BrowserTabView: View {
    @ObservedObject var tab: BrowserTabSession
    @ObservedObject var model: BrowserModel
    @ObservedObject var bookmarkStore: BookmarkStore
    @ObservedObject var downloadStore: DownloadStore
    @ObservedObject var passwordStore: PasswordStore

    var body: some View {
        ZStack(alignment: .top) {
            content

            if tab.isLoading {
                ProgressView(value: tab.estimatedProgress)
                    .progressViewStyle(.linear)
                    .frame(height: 2)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch tab.url {
        case BrowserDestination.bookmarkManager:
            BookmarkManagerView(model: model, bookmarkStore: bookmarkStore)
        case BrowserDestination.downloadManager:
            DownloadManagerView(downloadStore: downloadStore)
        case BrowserDestination.passwordManager:
            PasswordManagerView(model: model, passwordStore: passwordStore)
        default:
            EngineHostView(tab: tab, model: model, downloadStore: downloadStore, passwordStore: passwordStore)
        }
    }
}
