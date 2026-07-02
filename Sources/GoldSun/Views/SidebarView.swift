import GoldSunCore
import SwiftUI

struct SidebarView: View {
    @ObservedObject var model: BrowserModel
    @ObservedObject var bookmarkStore: BookmarkStore

    private var selection: Binding<BrowserTabSession.ID?> {
        Binding {
            model.selectedTabID
        } set: { newValue in
            model.selectTab(newValue)
        }
    }

    var body: some View {
        List(selection: selection) {
            Section("Tabs") {
                ForEach(model.tabs) { tab in
                    SidebarTabRow(tab: tab)
                        .tag(tab.id)
                        .contextMenu {
                            Button("Close Tab") {
                                model.close(tab: tab)
                            }
                        }
                }
            }

            Section("Bookmarks") {
                ForEach(bookmarkStore.bookmarks.prefix(8)) { bookmark in
                    Button {
                        model.open(bookmark.url)
                    } label: {
                        HStack(spacing: 10) {
                            FaviconView(url: bookmark.url, fallbackSystemImage: "bookmark")

                            Text(bookmark.title)
                                .lineLimit(1)
                        }
                    }
                    .buttonStyle(.plain)
                    .help(bookmark.url.absoluteString)
                }

                Button {
                    model.openBookmarkManager()
                } label: {
                    Label("Manage Bookmarks", systemImage: "book")
                }
                .buttonStyle(.plain)
                .help("Open the built-in bookmark manager")
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            Button {
                model.newTab()
            } label: {
                Label("New Tab", systemImage: "plus")
            }
            .buttonStyle(.borderless)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct SidebarTabRow: View {
    @ObservedObject var tab: BrowserTabSession

    var body: some View {
        HStack(spacing: 10) {
            if tab.isLoading {
                Image(systemName: "circle.dotted")
                    .foregroundStyle(.secondary)
                    .frame(width: 16)
            } else {
                FaviconView(url: tab.url)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(tab.title.isEmpty ? "Untitled" : tab.title)
                    .lineLimit(1)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .help(tab.url.absoluteString)
    }

    private var subtitle: String {
        if tab.url == BrowserDestination.goldSunStartPage {
            return "Start Page"
        }

        if tab.url == BrowserDestination.bookmarkManager {
            return "Bookmark Manager"
        }

        if tab.url == BrowserDestination.downloadManager {
            return "Download Manager"
        }

        return tab.url.host(percentEncoded: false) ?? tab.url.absoluteString
    }
}
