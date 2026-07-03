import Foundation
import GoldSunCore
import Security

struct PasswordImportSummary: Equatable {
    let found: Int
    let imported: Int
    let updated: Int
}

struct PasswordAutofillCredential: Equatable {
    let credential: PasswordCredential
    let password: String
}

struct PasswordSavePrompt: Equatable, Identifiable {
    let id: UUID
    let title: String
    let origin: URL
    let username: String
    let password: String

    init(
        id: UUID = UUID(),
        title: String,
        origin: URL,
        username: String,
        password: String
    ) {
        self.id = id
        self.title = title
        self.origin = origin
        self.username = username
        self.password = password
    }

    var host: String {
        origin.host(percentEncoded: false) ?? origin.absoluteString
    }
}

enum PasswordStoreError: LocalizedError {
    case unsupportedURL
    case keychain(OSStatus)

    var errorDescription: String? {
        switch self {
        case .unsupportedURL:
            "GoldSun only saves passwords for http and https websites."
        case let .keychain(status):
            SecCopyErrorMessageString(status, nil) as String?
                ?? "Keychain error \(status)."
        }
    }
}

@MainActor
final class PasswordStore: ObservableObject {
    @Published private(set) var credentials: [PasswordCredential]
    @Published private(set) var pendingSavePrompt: PasswordSavePrompt?

    private let fileURL: URL
    private let keychainService = "com.goldsun.browser.passwords"
    private var recentlyPromptedKeys: [String: Date] = [:]

    init(fileManager: FileManager = .default) {
        fileURL = PasswordStore.storageURL(fileManager: fileManager)
        credentials = []
        pendingSavePrompt = nil
        load()
    }

    var sortedCredentials: [PasswordCredential] {
        credentials.sorted { lhs, rhs in
            if lhs.host == rhs.host {
                return lhs.username.localizedCaseInsensitiveCompare(rhs.username) == .orderedAscending
            }

            return lhs.host.localizedCaseInsensitiveCompare(rhs.host) == .orderedAscending
        }
    }

    func password(for credential: PasswordCredential) -> String? {
        try? readPassword(for: credential.id)
    }

    func credential(for id: PasswordCredential.ID?) -> PasswordCredential? {
        guard let id else {
            return nil
        }

        return credentials.first { $0.id == id }
    }

    @discardableResult
    func upsert(title: String, origin: URL, username: String, password: String) throws -> PasswordCredential {
        guard let normalizedOrigin = normalizedOrigin(from: origin) else {
            throw PasswordStoreError.unsupportedURL
        }

        let normalizedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = normalizedTitle(title, fallbackURL: normalizedOrigin)

        if let index = credentials.firstIndex(where: {
            normalizedOriginKey($0.origin) == normalizedOriginKey(normalizedOrigin)
                && $0.username == normalizedUsername
        }) {
            var credential = credentials[index]
            credential.title = title
            credential.username = normalizedUsername
            credential.origin = normalizedOrigin
            credential.updatedAt = Date()
            try savePassword(password, for: credential)
            credentials[index] = credential
            save()
            return credential
        }

        let credential = PasswordCredential(
            title: title,
            origin: normalizedOrigin,
            username: normalizedUsername
        )
        try savePassword(password, for: credential)
        credentials.append(credential)
        save()
        return credential
    }

    @discardableResult
    func saveCaptured(origin: URL, username: String, password: String, title: String) -> PasswordCredential? {
        let defaults = PasswordManagerConfiguration.defaults
        let isEnabled = UserDefaults.standard.object(forKey: PasswordManagerPreferenceKey.isEnabled) as? Bool ?? defaults.isEnabled
        let savesSubmittedPasswords = UserDefaults.standard.object(forKey: PasswordManagerPreferenceKey.savesSubmittedPasswords) as? Bool ?? defaults.savesSubmittedPasswords

        guard isEnabled,
              savesSubmittedPasswords,
              !password.isEmpty,
              let normalizedOrigin = normalizedOrigin(from: origin) else {
            return nil
        }

        let normalizedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)

        if let existing = existingCredential(origin: normalizedOrigin, username: normalizedUsername),
           let existingPassword = try? readPassword(for: existing.id),
           existingPassword == password {
            return existing
        }

        let prompt = PasswordSavePrompt(
            title: normalizedTitle(title, fallbackURL: normalizedOrigin),
            origin: normalizedOrigin,
            username: normalizedUsername,
            password: password
        )

        guard shouldShowPrompt(prompt) else {
            return nil
        }

        pendingSavePrompt = prompt
        recentlyPromptedKeys[promptKey(for: prompt)] = Date()
        return nil
    }

    func isUpdatePrompt(_ prompt: PasswordSavePrompt) -> Bool {
        existingCredential(origin: prompt.origin, username: prompt.username) != nil
    }

    @discardableResult
    func savePrompt(_ prompt: PasswordSavePrompt) throws -> PasswordCredential {
        let credential = try upsert(
            title: prompt.title,
            origin: prompt.origin,
            username: prompt.username,
            password: prompt.password
        )

        if pendingSavePrompt?.id == prompt.id {
            pendingSavePrompt = nil
        }

        return credential
    }

    func dismissPrompt(_ prompt: PasswordSavePrompt?) {
        guard prompt == nil || pendingSavePrompt?.id == prompt?.id else {
            return
        }

        pendingSavePrompt = nil
    }

    func autofillCredential(for pageURL: URL) -> PasswordAutofillCredential? {
        let defaults = PasswordManagerConfiguration.defaults
        let isEnabled = UserDefaults.standard.object(forKey: PasswordManagerPreferenceKey.isEnabled) as? Bool ?? defaults.isEnabled
        let autofillEnabled = UserDefaults.standard.object(forKey: PasswordManagerPreferenceKey.autofillEnabled) as? Bool ?? defaults.autofillEnabled

        guard isEnabled,
              autofillEnabled,
              let origin = normalizedOrigin(from: pageURL) else {
            return nil
        }

        let key = normalizedOriginKey(origin)
        let candidates = credentials
            .filter { normalizedOriginKey($0.origin) == key }
            .sorted { lhs, rhs in
                let lhsDate = lhs.lastUsedAt ?? lhs.updatedAt
                let rhsDate = rhs.lastUsedAt ?? rhs.updatedAt
                return lhsDate > rhsDate
            }

        guard let credential = candidates.first,
              let password = try? readPassword(for: credential.id) else {
            return nil
        }

        markUsed(credential)
        return PasswordAutofillCredential(credential: credential, password: password)
    }

    func markUsed(_ credential: PasswordCredential) {
        guard let index = credentials.firstIndex(where: { $0.id == credential.id }) else {
            return
        }

        credentials[index].lastUsedAt = Date()
        save()
    }

    func delete(_ credential: PasswordCredential) {
        credentials.removeAll { $0.id == credential.id }
        deletePassword(for: credential.id)
        save()
    }

    func delete(id: PasswordCredential.ID?) {
        guard let credential = credential(for: id) else {
            return
        }

        delete(credential)
    }

    @discardableResult
    func importPasswords(from url: URL) throws -> PasswordImportSummary {
        let data = try Data(contentsOf: url)
        let records = try PasswordTransferService.importedPasswords(fromCSV: data)
        var imported = 0
        var updated = 0

        for record in records {
            let origin = normalizedOrigin(from: record.url)
            let existing = origin.flatMap { origin in
                credentials.first {
                    normalizedOriginKey($0.origin) == normalizedOriginKey(origin)
                        && $0.username == record.username.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }

            do {
                _ = try upsert(
                    title: record.title,
                    origin: record.url,
                    username: record.username,
                    password: record.password
                )
            } catch PasswordStoreError.unsupportedURL {
                continue
            } catch {
                throw error
            }

            if existing == nil {
                imported += 1
            } else {
                updated += 1
            }
        }

        return PasswordImportSummary(found: records.count, imported: imported, updated: updated)
    }

    func exportPasswords(to url: URL) throws {
        let records = credentials.compactMap { credential -> PasswordImportRecord? in
            guard let password = password(for: credential) else {
                return nil
            }

            return PasswordImportRecord(
                title: credential.title,
                url: credential.origin,
                username: credential.username,
                password: password
            )
        }

        try PasswordTransferService.exportedCSV(from: records).write(to: url, options: [.atomic])
    }

    private func load() {
        do {
            let data = try Data(contentsOf: fileURL)
            let decodedCredentials = try JSONDecoder().decode([PasswordCredential].self, from: data)
            credentials = deduplicated(decodedCredentials)

            if credentials.count != decodedCredentials.count {
                save()
            }
        } catch {
            credentials = []
            save()
        }
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(credentials)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            assertionFailure("Failed to save password metadata: \(error)")
        }
    }

    private func savePassword(_ password: String, for credential: PasswordCredential) throws {
        let data = Data(password.utf8)
        let baseQuery = keychainQuery(for: credential.id)
        let status = SecItemCopyMatching(baseQuery as CFDictionary, nil)

        if status == errSecSuccess {
            let update: [String: Any] = [
                kSecValueData as String: data,
                kSecAttrLabel as String: "GoldSun password for \(credential.host)"
            ]
            let updateStatus = SecItemUpdate(baseQuery as CFDictionary, update as CFDictionary)
            guard updateStatus == errSecSuccess else {
                throw PasswordStoreError.keychain(updateStatus)
            }
        } else if status == errSecItemNotFound {
            var query = baseQuery
            query[kSecValueData as String] = data
            query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            query[kSecAttrLabel as String] = "GoldSun password for \(credential.host)"

            let addStatus = SecItemAdd(query as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw PasswordStoreError.keychain(addStatus)
            }
        } else {
            throw PasswordStoreError.keychain(status)
        }
    }

    private func readPassword(for id: PasswordCredential.ID) throws -> String {
        var query = keychainQuery(for: id)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else {
            throw PasswordStoreError.keychain(status)
        }

        guard let data = result as? Data,
              let password = String(data: data, encoding: .utf8) else {
            throw PasswordStoreError.keychain(errSecDecode)
        }

        return password
    }

    private func deletePassword(for id: PasswordCredential.ID) {
        SecItemDelete(keychainQuery(for: id) as CFDictionary)
    }

    private func keychainQuery(for id: PasswordCredential.ID) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: id.uuidString
        ]
    }

    private func normalizedOrigin(from url: URL) -> URL? {
        guard let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let host = url.host(percentEncoded: false)?.lowercased(),
              var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }

        components.scheme = scheme
        components.host = host
        components.path = ""
        components.query = nil
        components.fragment = nil
        return components.url
    }

    private func normalizedOriginKey(_ url: URL) -> String {
        normalizedOrigin(from: url)?.absoluteString.lowercased() ?? url.absoluteString.lowercased()
    }

    private func existingCredential(origin: URL, username: String) -> PasswordCredential? {
        let key = normalizedOriginKey(origin)
        return credentials.first {
            normalizedOriginKey($0.origin) == key
                && $0.username == username
        }
    }

    private func shouldShowPrompt(_ prompt: PasswordSavePrompt) -> Bool {
        if pendingSavePrompt.map({ promptKey(for: $0) }) == promptKey(for: prompt) {
            return false
        }

        let now = Date()
        recentlyPromptedKeys = recentlyPromptedKeys.filter { now.timeIntervalSince($0.value) < 60 }

        if let promptedAt = recentlyPromptedKeys[promptKey(for: prompt)],
           now.timeIntervalSince(promptedAt) < 30 {
            return false
        }

        return true
    }

    private func promptKey(for prompt: PasswordSavePrompt) -> String {
        "\(normalizedOriginKey(prompt.origin))|\(prompt.username)|\(prompt.password)"
    }

    private func normalizedTitle(_ title: String, fallbackURL: URL) -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return trimmed
        }

        return fallbackURL.host(percentEncoded: false) ?? fallbackURL.absoluteString
    }

    private func deduplicated(_ credentials: [PasswordCredential]) -> [PasswordCredential] {
        var seenKeys = Set<String>()
        var uniqueCredentials: [PasswordCredential] = []

        for credential in credentials {
            let key = "\(normalizedOriginKey(credential.origin))|\(credential.username)"
            guard !seenKeys.contains(key) else {
                deletePassword(for: credential.id)
                continue
            }

            seenKeys.insert(key)
            uniqueCredentials.append(credential)
        }

        return uniqueCredentials
    }

    private static func storageURL(fileManager: FileManager) -> URL {
        let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")

        return baseURL
            .appendingPathComponent("GoldSun", isDirectory: true)
            .appendingPathComponent("Passwords.json")
    }
}
