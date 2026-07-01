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
    private let gold = Color(red: 0.91, green: 0.61, blue: 0.21)

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: tabIconName)
                .foregroundStyle(tab.url.scheme?.caseInsensitiveCompare("goldsun") == .orderedSame ? gold : .secondary)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(tab.title.isEmpty ? "Untitled" : tab.title)
                    .lineLimit(1)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private var tabIconName: String {
        if tab.isLoading {
            return "circle.dotted"
        }

        if tab.url.scheme?.caseInsensitiveCompare("goldsun") == .orderedSame {
            return "sun.max.fill"
        }

        return "globe"
    }

    private var subtitle: String {
        if tab.url.scheme?.caseInsensitiveCompare("goldsun") == .orderedSame {
            return "Start Page"
        }

        return tab.url.host(percentEncoded: false) ?? tab.url.absoluteString
    }
}
