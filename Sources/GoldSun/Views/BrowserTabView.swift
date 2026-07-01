import SwiftUI

struct BrowserTabView: View {
    @ObservedObject var tab: BrowserTabSession
    @ObservedObject var model: BrowserModel
    @ObservedObject var downloadStore: DownloadStore

    var body: some View {
        ZStack(alignment: .top) {
            EngineHostView(tab: tab, model: model, downloadStore: downloadStore)

            if tab.isLoading {
                ProgressView(value: tab.estimatedProgress)
                    .progressViewStyle(.linear)
                    .frame(height: 2)
            }
        }
    }
}
