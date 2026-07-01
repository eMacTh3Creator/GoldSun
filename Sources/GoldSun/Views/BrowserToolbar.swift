import GoldSunCore
import SwiftUI

struct BrowserToolbar: View {
    @ObservedObject var model: BrowserModel
    @AppStorage("adBlockEnabled") private var adBlockEnabled = AdBlockConfiguration.defaults.isEnabled
    @FocusState private var isAddressFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Button {
                model.isSidebarVisible.toggle()
            } label: {
                Image(systemName: "sidebar.left")
            }
            .help("Show or hide sidebar")

            Divider()
                .frame(height: 18)

            Button {
                model.goBack()
            } label: {
                Image(systemName: "chevron.left")
            }
            .disabled(model.selectedTab?.canGoBack != true)
            .help("Back")

            Button {
                model.goForward()
            } label: {
                Image(systemName: "chevron.right")
            }
            .disabled(model.selectedTab?.canGoForward != true)
            .help("Forward")

            Button {
                if model.selectedTab?.isLoading == true {
                    model.stopLoading()
                } else {
                    model.reload()
                }
            } label: {
                Image(systemName: model.selectedTab?.isLoading == true ? "xmark" : "arrow.clockwise")
            }
            .help(model.selectedTab?.isLoading == true ? "Stop" : "Reload")

            TextField("Search or enter website", text: $model.addressText)
                .textFieldStyle(.plain)
                .focused($isAddressFocused)
                .onSubmit {
                    model.loadAddress()
                    isAddressFocused = false
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(nsColor: .controlBackgroundColor))
                }

            Button {
                model.newTab()
            } label: {
                Image(systemName: "plus")
            }
            .help("New tab")

            Button {
                model.openChromeWebStore()
            } label: {
                Image(systemName: "puzzlepiece")
            }
            .help("Chrome Web Store")

            Button {
                adBlockEnabled.toggle()
            } label: {
                Image(systemName: adBlockEnabled ? "checkmark.shield" : "shield.slash")
            }
            .help(adBlockEnabled ? "Ad blocker on" : "Ad blocker off")
        }
        .buttonStyle(.borderless)
        .controlSize(.regular)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.bar)
    }
}
