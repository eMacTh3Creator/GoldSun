import SwiftUI

struct EngineHostView: View {
    @ObservedObject var tab: BrowserTabSession
    @ObservedObject var model: BrowserModel
    @ObservedObject var downloadStore: DownloadStore

    var body: some View {
        WebKitBrowserView(
            tab: tab,
            downloadStore: downloadStore,
            openURLInNewTab: { url in
                model.open(url, inNewTab: true)
            }
        )
    }
}
