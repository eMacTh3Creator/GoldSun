import Foundation

public struct SoftwareUpdate: Equatable, Identifiable, Sendable {
    public var id: String { version.rawValue }

    public var version: AppVersion
    public var displayName: String
    public var releaseNotes: String
    public var releasePageURL: URL
    public var installerURL: URL
    public var installerName: String
    public var installerSize: Int
    public var isPrerelease: Bool
    public var publishedAt: Date?

    public init(
        version: AppVersion,
        displayName: String,
        releaseNotes: String,
        releasePageURL: URL,
        installerURL: URL,
        installerName: String,
        installerSize: Int,
        isPrerelease: Bool,
        publishedAt: Date? = nil
    ) {
        self.version = version
        self.displayName = displayName
        self.releaseNotes = releaseNotes
        self.releasePageURL = releasePageURL
        self.installerURL = installerURL
        self.installerName = installerName
        self.installerSize = installerSize
        self.isPrerelease = isPrerelease
        self.publishedAt = publishedAt
    }
}

public enum SoftwareUpdatePreferenceKey {
    public static let automaticallyChecks = "updates.automaticallyChecks"
    public static let includesPrereleases = "updates.includesPrereleases"
    public static let automaticallyDownloadsInstaller = "updates.automaticallyDownloadsInstaller"
    public static let automaticallyStartsInstaller = "updates.automaticallyStartsInstaller"
    public static let lastAutomaticInstallerVersion = "updates.lastAutomaticInstallerVersion"
}
