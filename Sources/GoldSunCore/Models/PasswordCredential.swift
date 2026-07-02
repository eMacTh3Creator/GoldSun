import Foundation

public struct PasswordCredential: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var title: String
    public var origin: URL
    public var username: String
    public var createdAt: Date
    public var updatedAt: Date
    public var lastUsedAt: Date?

    public init(
        id: UUID = UUID(),
        title: String,
        origin: URL,
        username: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        lastUsedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.origin = origin
        self.username = username
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastUsedAt = lastUsedAt
    }

    public var host: String {
        origin.host(percentEncoded: false) ?? origin.absoluteString
    }
}

public enum PasswordManagerPreferenceKey {
    public static let isEnabled = "passwordManager.isEnabled"
    public static let autofillEnabled = "passwordManager.autofillEnabled"
    public static let savesSubmittedPasswords = "passwordManager.savesSubmittedPasswords"
}

public struct PasswordManagerConfiguration: Equatable, Sendable {
    public var isEnabled: Bool
    public var autofillEnabled: Bool
    public var savesSubmittedPasswords: Bool

    public init(
        isEnabled: Bool,
        autofillEnabled: Bool,
        savesSubmittedPasswords: Bool
    ) {
        self.isEnabled = isEnabled
        self.autofillEnabled = autofillEnabled
        self.savesSubmittedPasswords = savesSubmittedPasswords
    }

    public static let defaults = PasswordManagerConfiguration(
        isEnabled: true,
        autofillEnabled: true,
        savesSubmittedPasswords: true
    )
}

public struct PasswordImportRecord: Equatable, Sendable {
    public var title: String
    public var url: URL
    public var username: String
    public var password: String

    public init(title: String, url: URL, username: String, password: String) {
        self.title = title
        self.url = url
        self.username = username
        self.password = password
    }
}
