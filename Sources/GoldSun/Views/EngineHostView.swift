import SwiftUI

struct EngineHostView: View {
    @ObservedObject var tab: BrowserTabSession

    var body: some View {
        WebKitBrowserView(tab: tab)
    }
}
