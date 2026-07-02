import GoldSunCore
import SwiftUI

struct BrowserToolbar: View {
    @ObservedObject var model: BrowserModel
    @ObservedObject var bookmarkStore: BookmarkStore
    @ObservedObject var updateStore: SoftwareUpdateStore
    @ObservedObject var downloadStore: DownloadStore
    @AppStorage("adBlockEnabled") private var adBlockEnabled = AdBlockConfiguration.defaults.isEnabled
    @AppStorage("tabDisplayMode") private var tabDisplayMode = TabDisplayMode.both.rawValue
    @FocusState private var isAddressFocused: Bool
    @State private var isShowingDownloadsPopover = false
    @State private var isSavingDownloadLink = false
    @State private var downloadLinkText = ""

    private let gold = Color(red: 0.91, green: 0.61, blue: 0.21)

    var body: some View {
        HStack(spacing: 8) {
            Button {
                cycleTabDisplayMode()
            } label: {
                Image(systemName: displayMode.showsSidebar ? "sidebar.left" : "rectangle.topthird.inset.filled")
            }
            .help(displayMode.showsSidebar ? "Hide tab sidebar" : "Show tab sidebar")

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

            HStack(spacing: 7) {
                Image(systemName: addressIconName)
                    .font(.caption)
                    .foregroundStyle(addressIconColor)
                    .frame(width: 14)

                TextField("Search or enter website", text: $model.addressText)
                    .textFieldStyle(.plain)
                    .focused($isAddressFocused)
                    .onSubmit {
                        model.loadAddress()
                        isAddressFocused = false
                    }
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background {
                RoundedRectangle(cornerRadius: 9)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.92))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 9)
                    .stroke(isAddressFocused ? gold.opacity(0.82) : Color(nsColor: .separatorColor).opacity(0.42), lineWidth: 1)
            }
            .help("Search or enter website")

            Button {
                model.newTab()
                isAddressFocused = false
            } label: {
                Image(systemName: "plus.square.on.square")
            }
            .help("New tab")

            Button {
                bookmarkStore.addCurrentPage(from: model.selectedTab)
            } label: {
                Image(systemName: isCurrentPageBookmarked ? "star.fill" : "star")
            }
            .disabled(isCurrentPageInternal || model.selectedTab == nil)
            .help(isCurrentPageBookmarked ? "This page is already bookmarked" : "Add bookmark")

            Button {
                if !displayMode.showsSidebar {
                    tabDisplayMode = TabDisplayMode.both.rawValue
                }

                model.openBookmarkManager()
            } label: {
                Image(systemName: "book")
            }
            .help("Open bookmark manager")

            Button {
                isShowingDownloadsPopover.toggle()
            } label: {
                Image(systemName: "tray.and.arrow.down")
            }
            .help("Downloads")
            .popover(isPresented: $isShowingDownloadsPopover, arrowEdge: .bottom) {
                DownloadsPopoverView(
                    downloadStore: downloadStore,
                    showAllDownloads: {
                        isShowingDownloadsPopover = false
                        model.openDownloadManager()
                    },
                    saveLink: {
                        isShowingDownloadsPopover = false
                        isSavingDownloadLink = true
                    }
                )
                .frame(width: 360)
            }

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
        .tint(gold)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background {
            Rectangle()
                .fill(.bar)
                .overlay(alignment: .bottom) {
                    LinearGradient(
                        colors: [gold.opacity(0.34), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(height: 1)
                }
        }
        .sheet(isPresented: $isSavingDownloadLink) {
            SaveLinkSheet(linkText: $downloadLinkText) {
                saveTypedDownloadLink()
            }
        }
    }

    private var displayMode: TabDisplayMode {
        TabDisplayMode(rawValue: tabDisplayMode) ?? .both
    }

    private func cycleTabDisplayMode() {
        let current = displayMode
        let next: TabDisplayMode = current.showsSidebar ? .topBar : .both
        tabDisplayMode = next.rawValue
    }

    private var addressIconName: String {
        guard let url = model.selectedTab?.url else {
            return "magnifyingglass"
        }

        if url == BrowserDestination.goldSunStartPage {
            return "sun.max.fill"
        }

        if url == BrowserDestination.bookmarkManager {
            return "book"
        }

        if url == BrowserDestination.downloadManager {
            return "tray.and.arrow.down"
        }

        if url.scheme?.caseInsensitiveCompare("https") == .orderedSame {
            return "lock.fill"
        }

        if url.scheme?.caseInsensitiveCompare("http") == .orderedSame {
            return "exclamationmark.triangle.fill"
        }

        return "magnifyingglass"
    }

    private var addressIconColor: Color {
        addressIconName == "exclamationmark.triangle.fill" ? .orange : gold
    }

    private var isCurrentPageBookmarked: Bool {
        bookmarkStore.isBookmarked(model.selectedTab?.url)
    }

    private var isCurrentPageInternal: Bool {
        model.selectedTab.map { BrowserDestination.isInternal($0.url) } ?? true
    }

    private func saveTypedDownloadLink() {
        let trimmed = downloadLinkText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return
        }

        let url = AddressResolver.resolvedURL(from: trimmed)
        downloadStore.saveLinkAs(url)
        downloadLinkText = ""
        isSavingDownloadLink = false
    }
}

private struct DownloadsPopoverView: View {
    @ObservedObject var downloadStore: DownloadStore
    let showAllDownloads: () -> Void
    let saveLink: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Downloads")
                    .font(.headline)

                Spacer()

                Button {
                    showAllDownloads()
                } label: {
                    Image(systemName: "arrow.up.right.square")
                }
                .buttonStyle(.borderless)
                .help("Show all downloads")
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Divider()

            if downloadStore.downloads.isEmpty {
                ContentUnavailableView("No Downloads", systemImage: "tray")
                    .frame(height: 120)
            } else {
                VStack(spacing: 0) {
                    ForEach(downloadStore.downloads.prefix(5)) { item in
                        DownloadPopoverRow(item: item, downloadStore: downloadStore)

                        if item.id != downloadStore.downloads.prefix(5).last?.id {
                            Divider()
                                .padding(.leading, 44)
                        }
                    }
                }
            }

            Divider()

            HStack(spacing: 8) {
                Button("Save Link...", action: saveLink)
                    .help("Save a link as a file")

                Button("Folder") {
                    downloadStore.openDownloadsFolder()
                }
                .help("Open Downloads folder")

                Spacer()

                Button("Clear") {
                    downloadStore.clearFinished()
                }
                .disabled(!downloadStore.hasFinishedDownloads)
                .help("Clear finished downloads")
            }
            .padding(12)
        }
    }
}

private struct DownloadPopoverRow: View {
    let item: DownloadItem
    @ObservedObject var downloadStore: DownloadStore

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: iconName)
                .foregroundStyle(iconColor)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.filename)
                    .lineLimit(1)

                if isActive {
                    ProgressView(value: item.progress)
                } else {
                    Text(statusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if isCompleted {
                Button {
                    downloadStore.open(item)
                } label: {
                    Image(systemName: "arrow.up.right.square")
                }
                .buttonStyle(.borderless)
                .help("Open download")
            } else if isActive {
                Button {
                    downloadStore.cancel(item)
                } label: {
                    Image(systemName: "xmark.circle")
                }
                .buttonStyle(.borderless)
                .help("Cancel download")
            } else if isFailed {
                Button {
                    downloadStore.retry(item)
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help("Retry download")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .help(item.sourceURL.absoluteString)
    }

    private var isActive: Bool {
        item.state == .queued || item.state == .downloading
    }

    private var isCompleted: Bool {
        item.state == .completed
    }

    private var isFailed: Bool {
        if case .failed = item.state {
            return true
        }

        return false
    }

    private var iconName: String {
        switch item.state {
        case .completed:
            "checkmark.circle.fill"
        case .failed:
            "exclamationmark.circle.fill"
        case .cancelled:
            "xmark.circle"
        case .queued, .downloading:
            "arrow.down.circle"
        }
    }

    private var iconColor: Color {
        switch item.state {
        case .completed:
            .green
        case .failed:
            .red
        case .cancelled:
            .secondary
        case .queued, .downloading:
            .accentColor
        }
    }

    private var statusText: String {
        switch item.state {
        case .queued:
            "Queued"
        case .downloading:
            "\(Int(item.progress * 100))%"
        case .completed:
            "Completed"
        case let .failed(message):
            message
        case .cancelled:
            "Cancelled"
        }
    }
}
