import GoldSunCore
import SwiftUI

struct BrowserWindowView: View {
    @ObservedObject var model: BrowserModel
    @ObservedObject var bookmarkStore: BookmarkStore
    @ObservedObject var updateStore: SoftwareUpdateStore
    @ObservedObject var downloadStore: DownloadStore
    @ObservedObject var passwordStore: PasswordStore
    let openURLInNewWindow: (URL) -> Void
    @AppStorage("showBookmarkBar") private var showBookmarkBar = true

    var body: some View {
        VStack(spacing: 0) {
            BrowserToolbar(
                model: model,
                bookmarkStore: bookmarkStore,
                updateStore: updateStore,
                downloadStore: downloadStore,
                passwordStore: passwordStore
            )

            Divider()
            TabBarView(model: model)

            if showBookmarkBar {
                Divider()
                BookmarkBarView(model: model, bookmarkStore: bookmarkStore)
            }

            Divider()

            ZStack {
                if model.tabs.isEmpty {
                    EmptyBrowserView()
                }

                ForEach(model.tabs) { tab in
                    BrowserTabView(
                        tab: tab,
                        model: model,
                        bookmarkStore: bookmarkStore,
                        downloadStore: downloadStore,
                        passwordStore: passwordStore,
                        openURLInNewWindow: openURLInNewWindow
                    )
                    .opacity(model.selectedTabID == tab.id ? 1 : 0)
                    .allowsHitTesting(model.selectedTabID == tab.id)
                    .accessibilityHidden(model.selectedTabID != tab.id)
                    .zIndex(model.selectedTabID == tab.id ? 1 : 0)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .task {
            updateStore.startAutomaticChecks()
        }
        .sheet(isPresented: $updateStore.isUpdateSheetPresented) {
            SoftwareUpdateSheetView(updateStore: updateStore)
        }
    }
}
