import GoldSunCore
import SwiftUI

struct DownloadManagerView: View {
    @ObservedObject var downloadStore: DownloadStore
    @State private var linkText = ""
    @State private var isAddingLink = false

    var body: some View {
        VStack(spacing: 0) {
            toolbar

            if downloadStore.downloads.isEmpty {
                ContentUnavailableView("No Downloads", systemImage: "tray")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(downloadStore.downloads) { item in
                        DownloadRow(item: item, downloadStore: downloadStore)
                            .padding(.vertical, 4)
                    }
                }
                .listStyle(.inset)
            }
        }
        .sheet(isPresented: $isAddingLink) {
            SaveLinkSheet(linkText: $linkText, save: saveTypedLink)
        }
    }

    private var toolbar: some View {
        HStack(spacing: 8) {
            Button {
                isAddingLink = true
            } label: {
                Label("Save Link", systemImage: "link.badge.plus")
            }
            .help("Save a link as a file")

            Button {
                downloadStore.openDownloadsFolder()
            } label: {
                Label("Downloads Folder", systemImage: "folder")
            }
            .help("Open Downloads folder")

            Spacer()

            Text("\(downloadStore.downloads.count) downloads")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button {
                downloadStore.clearFinished()
            } label: {
                Label("Clear Finished", systemImage: "xmark.circle")
            }
            .disabled(!downloadStore.hasFinishedDownloads)
            .help("Clear finished downloads")
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(.bar)
    }

    private func saveTypedLink() {
        let trimmed = linkText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return
        }

        let url = AddressResolver.resolvedURL(from: trimmed)
        downloadStore.saveLinkAs(url)
        linkText = ""
        isAddingLink = false
    }
}

private struct DownloadRow: View {
    let item: DownloadItem
    @ObservedObject var downloadStore: DownloadStore

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .foregroundStyle(iconColor)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 5) {
                Text(item.filename)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    if isActive {
                        ProgressView(value: item.progress)
                            .frame(width: 150)
                    }

                    Text(statusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Button {
                downloadStore.open(item)
            } label: {
                Image(systemName: "arrow.up.right.square")
            }
            .disabled(!isCompleted)
            .help("Open")

            Button {
                downloadStore.reveal(item)
            } label: {
                Image(systemName: "magnifyingglass")
            }
            .disabled(!isCompleted)
            .help("Reveal in Finder")

            if isActive {
                Button {
                    downloadStore.cancel(item)
                } label: {
                    Image(systemName: "xmark.circle")
                }
                .help("Cancel")
            } else if isFailed {
                Button {
                    downloadStore.retry(item)
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Retry")
            }
        }
        .buttonStyle(.borderless)
        .contextMenu {
            Button("Open") {
                downloadStore.open(item)
            }
            .disabled(!isCompleted)

            Button("Reveal in Finder") {
                downloadStore.reveal(item)
            }
            .disabled(!isCompleted)

            Button("Retry") {
                downloadStore.retry(item)
            }
            .disabled(!isFailed)
        }
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
            "\(Int(item.progress * 100))% - \(item.sourceURL.host(percentEncoded: false) ?? item.sourceURL.absoluteString)"
        case .completed:
            "Saved to \(item.destinationURL.deletingLastPathComponent().path)"
        case let .failed(message):
            message
        case .cancelled:
            "Cancelled"
        }
    }
}

struct SaveLinkSheet: View {
    @Binding var linkText: String
    let save: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Save Link")
                .font(.title3.weight(.semibold))

            TextField("URL", text: $linkText)
                .textFieldStyle(.roundedBorder)
                .frame(width: 420)

            HStack {
                Spacer()

                Button("Cancel") {
                    dismiss()
                }

                Button("Save As", action: save)
                    .keyboardShortcut(.defaultAction)
                    .disabled(linkText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
    }
}
