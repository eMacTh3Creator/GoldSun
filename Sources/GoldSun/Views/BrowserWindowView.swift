import GoldSunCore
import SwiftUI

struct BrowserWindowView: View {
    @ObservedObject var model: BrowserModel
    @ObservedObject var bookmarkStore: BookmarkStore
    @AppStorage("tabDisplayMode") private var tabDisplayMode = TabDisplayMode.both.rawValue
    @AppStorage("showBookmarkBar") private var showBookmarkBar = true

    private var displayMode: TabDisplayMode {
        TabDisplayMode(rawValue: tabDisplayMode) ?? .both
    }

    var body: some View {
        HStack(spacing: 0) {
            if displayMode.showsSidebar {
                SidebarView(model: model, bookmarkStore: bookmarkStore)
                    .frame(minWidth: 190, idealWidth: 220, maxWidth: 280)

                Divider()
            }

            VStack(spacing: 0) {
                BrowserToolbar(model: model, bookmarkStore: bookmarkStore)

                if displayMode.showsTabBar {
                    Divider()
                    TabBarView(model: model)
                }

                if showBookmarkBar {
                    Divider()
                    BookmarkBarView(model: model, bookmarkStore: bookmarkStore)
                }

                Divider()

                if let selectedTab = model.selectedTab {
                    BrowserTabView(tab: selectedTab)
                } else {
                    EmptyBrowserView()
                }
            }
        }
    }
}
