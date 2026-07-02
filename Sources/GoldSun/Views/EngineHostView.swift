import SwiftUI

struct EngineHostView: View {
    @ObservedObject var tab: BrowserTabSession
    @ObservedObject var model: BrowserModel
    @ObservedObject var downloadStore: DownloadStore
    @ObservedObject var passwordStore: PasswordStore

    var body: some View {
        WebKitBrowserView(
            tab: tab,
            downloadStore: downloadStore,
            passwordStore: passwordStore,
            openURLInNewTab: { url in
                model.open(url, inNewTab: true)
            }
        )
    }
}
