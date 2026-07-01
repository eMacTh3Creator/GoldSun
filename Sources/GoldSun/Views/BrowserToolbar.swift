import GoldSunCore
import SwiftUI

struct BrowserToolbar: View {
    @ObservedObject var model: BrowserModel
    @ObservedObject var bookmarkStore: BookmarkStore
    @ObservedObject var updateStore: SoftwareUpdateStore
    @AppStorage("adBlockEnabled") private var adBlockEnabled = AdBlockConfiguration.defaults.isEnabled
    @AppStorage("showBookmarkBar") private var showBookmarkBar = true
    @Environment(\.openWindow) private var openWindow
    @FocusState private var isAddressFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Button {
                toggleTabDisplayMode()
            } label: {
                Image(systemName: "sidebar.left")
            }
            .help("Toggle tab sidebar")

            Divider()
                .frame(height: 18)

            Button {
                model.goHome()
            } label: {
                Image(systemName: "house")
            }
            .help("Home")

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
                bookmarkStore.addCurrentPage(from: model.selectedTab)
            } label: {
                Image(systemName: "star")
            }
            .help("Add bookmark")

            Button {
                openWindow(id: "bookmarks")
            } label: {
                Image(systemName: "book")
            }
            .help("Bookmark manager")

            Button {
                showBookmarkBar.toggle()
            } label: {
                Image(systemName: showBookmarkBar ? "bookmark.fill" : "bookmark")
            }
            .help(showBookmarkBar ? "Hide bookmark bar" : "Show bookmark bar")

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

            Button {
                Task {
                    await updateStore.checkForUpdates(userInitiated: true)
                }
            } label: {
                Image(systemName: updateStore.toolbarIconName)
            }
            .disabled(updateStore.isBusy)
            .help(updateStore.statusMessage)
        }
        .buttonStyle(.borderless)
        .controlSize(.regular)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.bar)
    }

    private func toggleTabDisplayMode() {
        let current = TabDisplayMode(rawValue: UserDefaults.standard.string(forKey: "tabDisplayMode") ?? "") ?? .both
        let next: TabDisplayMode = current.showsSidebar ? .topBar : .both
        UserDefaults.standard.set(next.rawValue, forKey: "tabDisplayMode")
    }
}
