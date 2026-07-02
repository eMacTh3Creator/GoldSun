import GoldSunCore
import SwiftUI

struct BrowserWindowView: View {
    @ObservedObject var model: BrowserModel
    @ObservedObject var bookmarkStore: BookmarkStore
    @ObservedObject var updateStore: SoftwareUpdateStore
    @ObservedObject var downloadStore: DownloadStore
    @AppStorage("showBookmarkBar") private var showBookmarkBar = true

    var body: some View {
        VStack(spacing: 0) {
            BrowserToolbar(
                model: model,
                bookmarkStore: bookmarkStore,
                updateStore: updateStore,
                downloadStore: downloadStore
            )

            Divider()
            TabBarView(model: model)

            if showBookmarkBar {
                Divider()
                BookmarkBarView(model: model, bookmarkStore: bookmarkStore)
            }

            Divider()

            if let selectedTab = model.selectedTab {
                BrowserTabView(
                    tab: selectedTab,
                    model: model,
                    bookmarkStore: bookmarkStore,
                    downloadStore: downloadStore
                )
            } else {
                EmptyBrowserView()
            }
        }
        .task {
            updateStore.startAutomaticChecks()
        }
        .sheet(isPresented: $updateStore.isUpdateSheetPresented) {
            SoftwareUpdateSheetView(updateStore: updateStore)
        }
    }
}
