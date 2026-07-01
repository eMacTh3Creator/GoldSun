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

            if !bookmarkStore.bookmarks.isEmpty {
                Section("Bookmarks") {
                    ForEach(bookmarkStore.bookmarks.prefix(8)) { bookmark in
                        Button {
                            model.open(bookmark.url)
                        } label: {
                            Label(bookmark.title, systemImage: "bookmark")
                                .lineLimit(1)
                        }
                        .buttonStyle(.plain)
                    }
                }
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
            Image(systemName: tab.isLoading ? "circle.dotted" : "globe")
                .foregroundStyle(.secondary)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(tab.title.isEmpty ? "Untitled" : tab.title)
                    .lineLimit(1)

                Text(tab.url.host(percentEncoded: false) ?? tab.url.absoluteString)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}
