import GoldSunCore
import SwiftUI

struct BookmarkBarView: View {
    @ObservedObject var model: BrowserModel
    @ObservedObject var bookmarkStore: BookmarkStore

    private var looseBookmarks: [BrowserBookmark] {
        bookmarkStore.bookmarkBarItems.filter { $0.folder == "Favorites" }
    }

    private var folderNames: [String] {
        bookmarkStore.folders.filter { $0 != "Favorites" }
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(looseBookmarks) { bookmark in
                    Button {
                        model.open(bookmark.url)
                    } label: {
                        Label(bookmark.title, systemImage: "bookmark")
                            .lineLimit(1)
                    }
                    .buttonStyle(.borderless)
                    .help(bookmark.url.absoluteString)
                }

                ForEach(folderNames, id: \.self) { folder in
                    Menu {
                        ForEach(bookmarkStore.bookmarkBarItems.filter { $0.folder == folder }) { bookmark in
                            Button(bookmark.title) {
                                model.open(bookmark.url)
                            }
                        }
                    } label: {
                        Label(folder, systemImage: "folder")
                    }
                    .menuStyle(.button)
                    .fixedSize()
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
        }
        .background(.bar)
    }
}
