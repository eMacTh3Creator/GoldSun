import AppKit
import Foundation

enum DownloadState: Equatable {
    case queued
    case downloading
    case completed
    case failed(String)
    case cancelled
}

struct DownloadItem: Identifiable, Equatable {
    let id: UUID
    var sourceURL: URL
    var destinationURL: URL
    var filename: String
    var progress: Double
    var state: DownloadState
    var createdAt: Date
    var completedAt: Date?
}

final class DownloadStore: NSObject, ObservableObject {
    @Published private(set) var downloads: [DownloadItem] = []

    private lazy var session = URLSession(configuration: .default, delegate: self, delegateQueue: .main)
    private var tasksByDownloadID: [DownloadItem.ID: URLSessionDownloadTask] = [:]
    private var downloadIDsByTaskID: [Int: DownloadItem.ID] = [:]

    var hasFinishedDownloads: Bool {
        downloads.contains { item in
            switch item.state {
            case .completed, .failed, .cancelled:
                true
            case .queued, .downloading:
                false
            }
        }
    }

    func download(_ url: URL, suggestedFilename: String? = nil, destinationURL: URL? = nil) {
        let filename = sanitizedFilename(suggestedFilename ?? url.lastPathComponent, fallback: "GoldSun Download")
        let destinationURL = destinationURL ?? uniqueDownloadURL(for: filename)
        let id = UUID()
        let item = DownloadItem(
            id: id,
            sourceURL: url,
            destinationURL: destinationURL,
            filename: destinationURL.lastPathComponent,
            progress: 0,
            state: .queued,
            createdAt: Date()
        )

        downloads.insert(item, at: 0)

        var request = URLRequest(url: url)
        request.setValue("GoldSun", forHTTPHeaderField: "User-Agent")

        let task = session.downloadTask(with: request)
        tasksByDownloadID[id] = task
        downloadIDsByTaskID[task.taskIdentifier] = id
        updateDownload(id) { item in
            item.state = .downloading
        }
        task.resume()
    }

    func saveLinkAs(_ url: URL, suggestedFilename: String? = nil) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = sanitizedFilename(suggestedFilename ?? url.lastPathComponent, fallback: "GoldSun Download")
        panel.canCreateDirectories = true

        panel.begin { [weak self] response in
            guard response == .OK, let destinationURL = panel.url else {
                return
            }

            self?.download(url, suggestedFilename: destinationURL.lastPathComponent, destinationURL: destinationURL)
        }
    }

    func cancel(_ item: DownloadItem) {
        tasksByDownloadID[item.id]?.cancel()
        tasksByDownloadID[item.id] = nil
        updateDownload(item.id) { download in
            download.state = .cancelled
            download.completedAt = Date()
        }
    }

    func retry(_ item: DownloadItem) {
        download(item.sourceURL, suggestedFilename: item.filename, destinationURL: item.destinationURL)
    }

    func clearFinished() {
        downloads.removeAll { item in
            switch item.state {
            case .completed, .failed, .cancelled:
                true
            case .queued, .downloading:
                false
            }
        }
    }

    func open(_ item: DownloadItem) {
        guard case .completed = item.state else {
            return
        }

        NSWorkspace.shared.open(item.destinationURL)
    }

    func reveal(_ item: DownloadItem) {
        NSWorkspace.shared.activateFileViewerSelecting([item.destinationURL])
    }

    func openDownloadsFolder() {
        let downloadsDirectory = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
        NSWorkspace.shared.open(downloadsDirectory)
    }

    private func updateDownload(_ id: DownloadItem.ID, mutate: (inout DownloadItem) -> Void) {
        guard let index = downloads.firstIndex(where: { $0.id == id }) else {
            return
        }

        mutate(&downloads[index])
    }

    private func uniqueDownloadURL(for filename: String) -> URL {
        let downloadsDirectory = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
        var destinationURL = downloadsDirectory.appendingPathComponent(filename)

        guard FileManager.default.fileExists(atPath: destinationURL.path) else {
            return destinationURL
        }

        let baseName = destinationURL.deletingPathExtension().lastPathComponent
        let pathExtension = destinationURL.pathExtension

        for index in 2...999 {
            let candidateName = pathExtension.isEmpty ? "\(baseName) \(index)" : "\(baseName) \(index).\(pathExtension)"
            destinationURL = downloadsDirectory.appendingPathComponent(candidateName)

            if !FileManager.default.fileExists(atPath: destinationURL.path) {
                return destinationURL
            }
        }

        return downloadsDirectory.appendingPathComponent("\(UUID().uuidString)-\(filename)")
    }

    private func sanitizedFilename(_ name: String, fallback: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let baseName = trimmed.isEmpty ? fallback : trimmed
        let invalidCharacters = CharacterSet(charactersIn: "/:")
        let components = baseName.components(separatedBy: invalidCharacters)
        return components.joined(separator: "-")
    }
}

extension DownloadStore: URLSessionDownloadDelegate {
    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard let id = downloadIDsByTaskID[downloadTask.taskIdentifier],
              totalBytesExpectedToWrite > 0 else {
            return
        }

        let progress = min(1, Double(totalBytesWritten) / Double(totalBytesExpectedToWrite))

        DispatchQueue.main.async { [weak self] in
            self?.updateDownload(id) { item in
                item.progress = progress
                item.state = .downloading
            }
        }
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        guard let id = downloadIDsByTaskID[downloadTask.taskIdentifier] else {
            return
        }

        DispatchQueue.main.async { [weak self] in
            guard let self,
                  let item = downloads.first(where: { $0.id == id }) else {
                return
            }

            do {
                try FileManager.default.createDirectory(
                    at: item.destinationURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )

                if FileManager.default.fileExists(atPath: item.destinationURL.path) {
                    try FileManager.default.removeItem(at: item.destinationURL)
                }

                try FileManager.default.moveItem(at: location, to: item.destinationURL)
                updateDownload(id) { download in
                    download.progress = 1
                    download.state = .completed
                    download.completedAt = Date()
                }
            } catch {
                updateDownload(id) { download in
                    download.state = .failed(error.localizedDescription)
                    download.completedAt = Date()
                }
            }
        }
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        guard let id = downloadIDsByTaskID[task.taskIdentifier] else {
            return
        }

        DispatchQueue.main.async { [weak self] in
            guard let self else {
                return
            }

            tasksByDownloadID[id] = nil
            downloadIDsByTaskID[task.taskIdentifier] = nil

            if let error {
                updateDownload(id) { item in
                    if case .cancelled = item.state {
                        return
                    }

                    item.state = .failed(error.localizedDescription)
                    item.completedAt = Date()
                }
            }
        }
    }
}
