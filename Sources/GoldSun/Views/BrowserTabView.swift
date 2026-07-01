import SwiftUI

struct BrowserTabView: View {
    @ObservedObject var tab: BrowserTabSession

    var body: some View {
        ZStack(alignment: .top) {
            EngineHostView(tab: tab)

            if tab.isLoading {
                ProgressView(value: tab.estimatedProgress)
                    .progressViewStyle(.linear)
                    .frame(height: 2)
            }
        }
    }
}
