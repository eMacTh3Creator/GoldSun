import GoldSunCore
import SwiftUI

struct HistoryManagerView: View {
    @ObservedObject var model: BrowserModel
    @ObservedObject var historyStore: HistoryStore

    @State private var searchText = ""

    private var filteredEntries: [BrowserHistoryEntry] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return historyStore.entries
        }

        return historyStore.entries.filter { entry in
            entry.title.localizedCaseInsensitiveContains(query)
                || entry.url.absoluteString.localizedCaseInsensitiveContains(query)
                || entry.host.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar

            if historyStore.entries.isEmpty {
                ContentUnavailableView("No History", systemImage: "clock.arrow.circlepath")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredEntries.isEmpty {
                ContentUnavailableView.search(text: searchText)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(filteredEntries) { entry in
                        HistoryRow(
                            entry: entry,
                            open: {
                                model.open(entry.url)
                            },
                            delete: {
                                historyStore.delete(entry)
                            }
                        )
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(.inset)
                .searchable(text: $searchText, placement: .toolbar)
            }
        }
    }

    private var toolbar: some View {
        HStack(spacing: 8) {
            Label("History", systemImage: "clock.arrow.circlepath")
                .font(.headline)

            Spacer()

            Text("\(historyStore.entries.count) visits")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button {
                historyStore.clear()
            } label: {
                Label("Clear History", systemImage: "trash")
            }
            .disabled(historyStore.entries.isEmpty)
            .help("Clear browsing history")
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(.bar)
    }
}

private struct HistoryRow: View {
    let entry: BrowserHistoryEntry
    let open: () -> Void
    let delete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            FaviconView(url: entry.url, fallbackSystemImage: "clock")

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.title)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(entry.url.absoluteString)
                        .lineLimit(1)

                    Text("-")

                    Text(visitSummary)
                        .lineLimit(1)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Text(entry.lastVisitedAt, style: .relative)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Button {
                open()
            } label: {
                Image(systemName: "arrow.up.right.square")
            }
            .help("Open")

            Button {
                delete()
            } label: {
                Image(systemName: "trash")
            }
            .help("Remove from history")
        }
        .buttonStyle(.borderless)
        .contextMenu {
            Button("Open") {
                open()
            }

            Button("Remove from History") {
                delete()
            }
        }
        .help(entry.url.absoluteString)
    }

    private var visitSummary: String {
        entry.visitCount == 1 ? "1 visit" : "\(entry.visitCount) visits"
    }
}
