import SwiftUI

struct BrowserWindowView: View {
    @ObservedObject var model: BrowserModel

    var body: some View {
        HStack(spacing: 0) {
            if model.isSidebarVisible {
                SidebarView(model: model)
                    .frame(minWidth: 190, idealWidth: 220, maxWidth: 280)

                Divider()
            }

            VStack(spacing: 0) {
                BrowserToolbar(model: model)

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
