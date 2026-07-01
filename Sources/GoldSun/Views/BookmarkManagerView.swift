import GoldSunCore
import SwiftUI

struct BookmarkManagerView: View {
    @ObservedObject var model: BrowserModel
    @ObservedObject var bookmarkStore: BookmarkStore

    @State private var selectedBookmarkID: BrowserBookmark.ID?
    @State private var draft = BookmarkDraft()
    @State private var searchText = ""

    private var filteredBookmarks: [BrowserBookmark] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return bookmarkStore.bookmarks
        }

        return bookmarkStore.bookmarks.filter { bookmark in
            bookmark.title.localizedCaseInsensitiveContains(query)
                || bookmark.folder.localizedCaseInsensitiveContains(query)
                || bookmark.url.absoluteString.localizedCaseInsensitiveContains(query)
        }
    }

    private var selectedBookmark: BrowserBookmark? {
        guard let selectedBookmarkID else {
            return nil
        }

        return bookmarkStore.bookmarks.first { $0.id == selectedBookmarkID }
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                managerToolbar

                List(selection: $selectedBookmarkID) {
                    ForEach(filteredBookmarks) { bookmark in
                        BookmarkManagerRow(bookmark: bookmark)
                            .tag(bookmark.id)
                    }
                    .onMove(perform: bookmarkStore.move)
                }
                .searchable(text: $searchText, placement: .toolbar)
            }
            .frame(minWidth: 300, idealWidth: 360)

            Divider()

            BookmarkEditorView(
                draft: $draft,
                canSave: selectedBookmarkID != nil || !draft.urlText.isEmpty,
                save: saveDraft,
                delete: deleteSelected,
                open: openDraft
            )
            .frame(minWidth: 360)
        }
        .onAppear {
            if selectedBookmarkID == nil {
                selectedBookmarkID = bookmarkStore.bookmarks.first?.id
            }

            loadSelectedBookmark()
        }
        .onChange(of: selectedBookmarkID) {
            loadSelectedBookmark()
        }
    }

    private var managerToolbar: some View {
        HStack(spacing: 8) {
            Button {
                createBookmarkFromCurrentPage()
            } label: {
                Image(systemName: "plus")
            }
            .help("Add current page")

            Button {
                openDraft()
            } label: {
                Image(systemName: "arrow.up.right.square")
            }
            .disabled(draft.resolvedURL == nil)
            .help("Open bookmark")

            Spacer()

            Text("\(bookmarkStore.bookmarks.count) bookmarks")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.bar)
    }

    private func createBookmarkFromCurrentPage() {
        bookmarkStore.addCurrentPage(from: model.selectedTab)
        selectedBookmarkID = bookmarkStore.bookmarks.last?.id
        loadSelectedBookmark()
    }

    private func loadSelectedBookmark() {
        guard let selectedBookmark else {
            draft = BookmarkDraft()
            return
        }

        draft = BookmarkDraft(bookmark: selectedBookmark)
    }

    private func saveDraft() {
        guard let url = draft.resolvedURL else {
            return
        }

        if let selectedBookmark {
            bookmarkStore.update(
                BrowserBookmark(
                    id: selectedBookmark.id,
                    title: draft.title,
                    url: url,
                    folder: draft.folder,
                    showsInBar: draft.showsInBar,
                    createdAt: selectedBookmark.createdAt,
                    updatedAt: selectedBookmark.updatedAt
                )
            )
        } else {
            bookmarkStore.add(
                title: draft.title,
                url: url,
                folder: draft.folder,
                showsInBar: draft.showsInBar
            )
            selectedBookmarkID = bookmarkStore.bookmarks.last?.id
        }
    }

    private func deleteSelected() {
        bookmarkStore.delete(id: selectedBookmarkID)
        selectedBookmarkID = bookmarkStore.bookmarks.first?.id
        loadSelectedBookmark()
    }

    private func openDraft() {
        guard let url = draft.resolvedURL else {
            return
        }

        model.open(url)
    }
}

private struct BookmarkManagerRow: View {
    let bookmark: BrowserBookmark

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: bookmark.showsInBar ? "bookmark.fill" : "bookmark")
                .foregroundStyle(.secondary)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(bookmark.title)
                    .lineLimit(1)

                Text(bookmark.folder)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}

private struct BookmarkEditorView: View {
    @Binding var draft: BookmarkDraft
    let canSave: Bool
    let save: () -> Void
    let delete: () -> Void
    let open: () -> Void

    var body: some View {
        Form {
            Section("Bookmark") {
                TextField("Title", text: $draft.title)
                TextField("Address", text: $draft.urlText)
                TextField("Folder", text: $draft.folder)
                Toggle("Show in bookmark bar", isOn: $draft.showsInBar)
            }

            Section {
                HStack {
                    Button("Open", action: open)
                        .disabled(draft.resolvedURL == nil)

                    Spacer()

                    Button("Delete", role: .destructive, action: delete)

                    Button("Save", action: save)
                        .keyboardShortcut(.defaultAction)
                        .disabled(!canSave || draft.resolvedURL == nil)
                }
            }
        }
        .formStyle(.grouped)
        .padding(16)
    }
}

private struct BookmarkDraft {
    var title = ""
    var urlText = ""
    var folder = "Favorites"
    var showsInBar = true

    init() {}

    init(bookmark: BrowserBookmark) {
        title = bookmark.title
        urlText = bookmark.url.absoluteString
        folder = bookmark.folder
        showsInBar = bookmark.showsInBar
    }

    var resolvedURL: URL? {
        let trimmed = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        return AddressResolver.resolvedURL(from: trimmed)
    }
}
