import AppKit
import Foundation
import GoldSunCore

enum SoftwareUpdateState: Equatable {
    case idle
    case checking
    case upToDate
    case available
    case downloading
    case downloaded
    case failed(String)
}

@MainActor
final class SoftwareUpdateStore: ObservableObject {
    @Published private(set) var state: SoftwareUpdateState = .idle
    @Published private(set) var availableUpdate: SoftwareUpdate?
    @Published private(set) var downloadedInstallerURL: URL?
    @Published var isUpdateSheetPresented = false

    private let client: SoftwareUpdateClient
    private var didStartAutomaticChecks = false
    private var automaticTimer: Timer?

    init(client: SoftwareUpdateClient = .live) {
        self.client = client
    }

    var currentVersion: AppVersion {
        if let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
           let appVersion = AppVersion(version) {
            return appVersion
        }

        return .zero
    }

    var currentVersionString: String {
        currentVersion.rawValue
    }

    var isBusy: Bool {
        state == .checking || state == .downloading
    }

    var toolbarIconName: String {
        switch state {
        case .available, .downloaded:
            "arrow.down.circle.fill"
        case .checking, .downloading:
            "arrow.triangle.2.circlepath.circle"
        case .failed:
            "exclamationmark.arrow.triangle.2.circlepath"
        case .idle, .upToDate:
            "arrow.triangle.2.circlepath.circle"
        }
    }

    var statusMessage: String {
        switch state {
        case .idle:
            "Updates ready"
        case .checking:
            "Checking for updates"
        case .upToDate:
            "GoldSun is up to date"
        case .available:
            "GoldSun \(availableUpdate?.version.rawValue ?? "") is available"
        case .downloading:
            "Downloading update"
        case .downloaded:
            "Installer downloaded"
        case let .failed(message):
            message
        }
    }

    func startAutomaticChecks() {
        guard !didStartAutomaticChecks else {
            return
        }

        didStartAutomaticChecks = true

        guard boolPreference(SoftwareUpdatePreferenceKey.automaticallyChecks, defaultValue: true) else {
            return
        }

        Task {
            await checkForUpdates(userInitiated: false)
        }

        automaticTimer = Timer.scheduledTimer(withTimeInterval: 6 * 60 * 60, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.checkForUpdates(userInitiated: false)
            }
        }
    }

    func checkForUpdates(userInitiated: Bool) async {
        guard !isBusy else {
            if userInitiated {
                isUpdateSheetPresented = true
            }

            return
        }

        state = .checking
        downloadedInstallerURL = nil

        do {
            let includePrereleases = boolPreference(SoftwareUpdatePreferenceKey.includesPrereleases, defaultValue: true)
            let update = try await client.fetchLatestUpdate(includePrereleases)

            guard let update, update.version > currentVersion else {
                availableUpdate = nil
                state = .upToDate
                isUpdateSheetPresented = userInitiated
                return
            }

            availableUpdate = update
            state = .available

            if shouldDownloadAutomatically(for: update, userInitiated: userInitiated) {
                let startsInstaller = boolPreference(
                    SoftwareUpdatePreferenceKey.automaticallyStartsInstaller,
                    defaultValue: true
                )
                await downloadInstaller(startsInstaller: startsInstaller)
            } else {
                isUpdateSheetPresented = true
            }
        } catch {
            state = .failed(error.localizedDescription)
            isUpdateSheetPresented = userInitiated
        }
    }

    func downloadAndStartInstaller() async {
        await downloadInstaller(startsInstaller: true)
    }

    private func downloadInstaller(startsInstaller: Bool) async {
        guard let update = availableUpdate else {
            return
        }

        state = .downloading

        do {
            let installerURL = try await client.downloadInstaller(update)
            downloadedInstallerURL = installerURL
            state = .downloaded
            UserDefaults.standard.set(update.version.rawValue, forKey: SoftwareUpdatePreferenceKey.lastAutomaticInstallerVersion)

            if startsInstaller {
                openInstaller()
            } else {
                isUpdateSheetPresented = true
            }
        } catch {
            state = .failed(error.localizedDescription)
            isUpdateSheetPresented = true
        }
    }

    func openInstaller() {
        guard let downloadedInstallerURL else {
            return
        }

        guard NSWorkspace.shared.open(downloadedInstallerURL) else {
            state = .failed("GoldSun could not open the installer package.")
            isUpdateSheetPresented = true
            return
        }

        isUpdateSheetPresented = false
        quitAfterInstallerHandoff()
    }

    func openReleasePage() {
        guard let releasePageURL = availableUpdate?.releasePageURL else {
            return
        }

        NSWorkspace.shared.open(releasePageURL)
    }

    func dismissUpdateSheet() {
        isUpdateSheetPresented = false
    }

    private func shouldDownloadAutomatically(for update: SoftwareUpdate, userInitiated: Bool) -> Bool {
        guard !userInitiated,
              boolPreference(SoftwareUpdatePreferenceKey.automaticallyDownloadsInstaller, defaultValue: true) else {
            return false
        }

        let lastAutomaticInstallerVersion = UserDefaults.standard.string(
            forKey: SoftwareUpdatePreferenceKey.lastAutomaticInstallerVersion
        )
        return lastAutomaticInstallerVersion != update.version.rawValue
    }

    private func boolPreference(_ key: String, defaultValue: Bool) -> Bool {
        guard UserDefaults.standard.object(forKey: key) != nil else {
            return defaultValue
        }

        return UserDefaults.standard.bool(forKey: key)
    }

    private func quitAfterInstallerHandoff() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
            NSApp.terminate(nil)
        }
    }
}

struct SoftwareUpdateClient {
    var fetchLatestUpdate: @Sendable (_ includePrereleases: Bool) async throws -> SoftwareUpdate?
    var downloadInstaller: @Sendable (_ update: SoftwareUpdate) async throws -> URL

    static let live = SoftwareUpdateClient(
        fetchLatestUpdate: { includePrereleases in
            try await GitHubReleaseUpdateService.fetchLatestUpdate(includePrereleases: includePrereleases)
        },
        downloadInstaller: { update in
            try await GitHubReleaseUpdateService.downloadInstaller(for: update)
        }
    )
}

private enum GitHubReleaseUpdateService {
    private static let releasesURL = URL(string: "https://api.github.com/repos/eMacTh3Creator/GoldSun/releases?per_page=10")!
    private static let isoFormatter = ISO8601DateFormatter()

    static func fetchLatestUpdate(includePrereleases: Bool) async throws -> SoftwareUpdate? {
        var request = URLRequest(url: releasesURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("GoldSun-Updater", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response)

        let releases = try JSONDecoder().decode([GitHubRelease].self, from: data)
        let release = releases.first { release in
            !release.draft
                && (includePrereleases || !release.prerelease)
                && AppVersion(release.tagName) != nil
                && release.pkgAsset != nil
        }

        guard let release, let version = AppVersion(release.tagName), let pkgAsset = release.pkgAsset else {
            return nil
        }

        return SoftwareUpdate(
            version: version,
            displayName: release.displayName,
            releaseNotes: release.body ?? "",
            releasePageURL: release.htmlURL,
            installerURL: pkgAsset.browserDownloadURL,
            installerName: pkgAsset.name,
            installerSize: pkgAsset.size,
            isPrerelease: release.prerelease,
            publishedAt: release.publishedAt.flatMap { isoFormatter.date(from: $0) }
        )
    }

    static func downloadInstaller(for update: SoftwareUpdate) async throws -> URL {
        var request = URLRequest(url: update.installerURL)
        request.setValue("GoldSun-Updater", forHTTPHeaderField: "User-Agent")

        let (temporaryURL, response) = try await URLSession.shared.download(for: request)
        try validate(response: response)

        let downloadsDirectory = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let destinationURL = downloadsDirectory.appendingPathComponent(update.installerName)

        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }

        try FileManager.default.moveItem(at: temporaryURL, to: destinationURL)
        return destinationURL
    }

    private static func validate(response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw SoftwareUpdateError.invalidServerResponse
        }
    }
}

private struct GitHubRelease: Decodable {
    var tagName: String
    var name: String?
    var body: String?
    var htmlURL: URL
    var draft: Bool
    var prerelease: Bool
    var publishedAt: String?
    var assets: [GitHubReleaseAsset]

    var pkgAsset: GitHubReleaseAsset? {
        assets.first { $0.name.localizedCaseInsensitiveCompare("GoldSun-\(tagName.dropFirst(tagName.hasPrefix("v") ? 1 : 0)).pkg") == .orderedSame }
            ?? assets.first { $0.name.hasSuffix(".pkg") }
    }

    var displayName: String {
        guard let name, !name.isEmpty else {
            return tagName
        }

        return name
    }

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case body
        case htmlURL = "html_url"
        case draft
        case prerelease
        case publishedAt = "published_at"
        case assets
    }
}

private struct GitHubReleaseAsset: Decodable {
    var name: String
    var browserDownloadURL: URL
    var size: Int

    enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadURL = "browser_download_url"
        case size
    }
}

private enum SoftwareUpdateError: LocalizedError {
    case invalidServerResponse

    var errorDescription: String? {
        switch self {
        case .invalidServerResponse:
            "The update server returned an unexpected response."
        }
    }
}
