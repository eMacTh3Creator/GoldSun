import AppKit
import GoldSunCore
import SwiftUI

struct PasswordManagerView: View {
    @ObservedObject var model: BrowserModel
    @ObservedObject var passwordStore: PasswordStore

    @State private var selectedCredentialID: PasswordCredential.ID?
    @State private var draft = PasswordDraft()
    @State private var searchText = ""
    @State private var statusMessage = ""

    private var filteredCredentials: [PasswordCredential] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let credentials = passwordStore.sortedCredentials

        guard !query.isEmpty else {
            return credentials
        }

        return credentials.filter { credential in
            credential.title.localizedCaseInsensitiveContains(query)
                || credential.host.localizedCaseInsensitiveContains(query)
                || credential.username.localizedCaseInsensitiveContains(query)
                || credential.origin.absoluteString.localizedCaseInsensitiveContains(query)
        }
    }

    private var selectedCredential: PasswordCredential? {
        passwordStore.credential(for: selectedCredentialID)
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                managerToolbar

                List(selection: $selectedCredentialID) {
                    ForEach(filteredCredentials) { credential in
                        PasswordManagerRow(credential: credential)
                            .tag(credential.id)
                    }
                }
                .searchable(text: $searchText, placement: .toolbar)
            }
            .frame(minWidth: 310, idealWidth: 380)

            Divider()

            PasswordEditorView(
                draft: $draft,
                canSave: !draft.urlText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    && !draft.password.isEmpty,
                save: saveDraft,
                delete: deleteSelected,
                open: openDraft,
                copyUsername: copyUsername,
                copyPassword: copyPassword
            )
            .frame(minWidth: 420)
        }
        .onAppear {
            if selectedCredentialID == nil {
                selectedCredentialID = passwordStore.sortedCredentials.first?.id
            }

            loadSelectedCredential()
        }
        .onChange(of: selectedCredentialID) {
            loadSelectedCredential()
        }
    }

    private var managerToolbar: some View {
        HStack(spacing: 8) {
            Button {
                createCredentialFromCurrentSite()
            } label: {
                Image(systemName: "plus")
            }
            .help("Add password")

            Button {
                openDraft()
            } label: {
                Image(systemName: "arrow.up.right.square")
            }
            .disabled(draft.resolvedURL == nil)
            .help("Open website")

            Button {
                importPasswords()
            } label: {
                Image(systemName: "square.and.arrow.down")
            }
            .help("Import browser password CSV")

            Button {
                exportPasswords()
            } label: {
                Image(systemName: "square.and.arrow.up")
            }
            .disabled(passwordStore.credentials.isEmpty)
            .help("Export browser password CSV")

            Spacer()

            if !statusMessage.isEmpty {
                Text(statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Text("\(passwordStore.credentials.count) passwords")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.bar)
    }

    private func createCredentialFromCurrentSite() {
        selectedCredentialID = nil

        if let url = model.selectedTab?.url,
           !BrowserDestination.isInternal(url) {
            draft = PasswordDraft(
                title: model.selectedTab?.title ?? url.host(percentEncoded: false) ?? "",
                urlText: url.absoluteString,
                username: "",
                password: ""
            )
        } else {
            draft = PasswordDraft()
        }
    }

    private func loadSelectedCredential() {
        guard let selectedCredential else {
            if selectedCredentialID != nil {
                draft = PasswordDraft()
            }
            return
        }

        draft = PasswordDraft(
            credential: selectedCredential,
            password: passwordStore.password(for: selectedCredential) ?? ""
        )
    }

    private func saveDraft() {
        guard let url = draft.resolvedURL else {
            return
        }

        do {
            let previousID = selectedCredentialID
            let credential = try passwordStore.upsert(
                title: draft.title,
                origin: url,
                username: draft.username,
                password: draft.password
            )

            if let previousID, previousID != credential.id {
                passwordStore.delete(id: previousID)
            }

            selectedCredentialID = credential.id
            statusMessage = "Saved \(credential.host)"
        } catch {
            statusMessage = error.localizedDescription
            BrowserDataTransferPanel.present(error)
        }
    }

    private func deleteSelected() {
        passwordStore.delete(id: selectedCredentialID)
        selectedCredentialID = passwordStore.sortedCredentials.first?.id
        loadSelectedCredential()
        statusMessage = "Deleted password"
    }

    private func openDraft() {
        guard let url = draft.resolvedURL else {
            return
        }

        model.open(url)
    }

    private func copyUsername() {
        copyToPasteboard(draft.username)
        statusMessage = "Copied username"
    }

    private func copyPassword() {
        copyToPasteboard(draft.password)
        statusMessage = "Copied password"
    }

    private func importPasswords() {
        do {
            guard let summary = try BrowserDataTransferPanel.importPasswords(into: passwordStore) else {
                return
            }

            statusMessage = "Imported \(summary.imported), updated \(summary.updated)"
            selectedCredentialID = passwordStore.sortedCredentials.first?.id
            loadSelectedCredential()
        } catch {
            statusMessage = error.localizedDescription
            BrowserDataTransferPanel.present(error)
        }
    }

    private func exportPasswords() {
        do {
            if let url = try BrowserDataTransferPanel.exportPasswords(from: passwordStore) {
                statusMessage = "Exported \(url.lastPathComponent)"
            }
        } catch {
            statusMessage = error.localizedDescription
            BrowserDataTransferPanel.present(error)
        }
    }

    private func copyToPasteboard(_ value: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
    }
}

private struct PasswordManagerRow: View {
    let credential: PasswordCredential

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "key.fill")
                .foregroundStyle(.yellow)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(credential.title)
                    .lineLimit(1)

                Text("\(credential.username) • \(credential.host)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .help(credential.origin.absoluteString)
    }
}

private struct PasswordEditorView: View {
    @Binding var draft: PasswordDraft
    let canSave: Bool
    let save: () -> Void
    let delete: () -> Void
    let open: () -> Void
    let copyUsername: () -> Void
    let copyPassword: () -> Void

    @State private var revealsPassword = false

    var body: some View {
        Form {
            Section("Password") {
                TextField("Name", text: $draft.title)
                TextField("Website", text: $draft.urlText)
                TextField("Username", text: $draft.username)

                HStack {
                    if revealsPassword {
                        TextField("Password", text: $draft.password)
                    } else {
                        SecureField("Password", text: $draft.password)
                    }

                    Button {
                        revealsPassword.toggle()
                    } label: {
                        Image(systemName: revealsPassword ? "eye.slash" : "eye")
                    }
                    .buttonStyle(.borderless)
                    .help(revealsPassword ? "Hide password" : "Show password")
                }
            }

            Section {
                HStack {
                    Button("Open", action: open)
                        .disabled(draft.resolvedURL == nil)
                        .help("Open website")

                    Button("Copy Username", action: copyUsername)
                        .disabled(draft.username.isEmpty)
                        .help("Copy username")

                    Button("Copy Password", action: copyPassword)
                        .disabled(draft.password.isEmpty)
                        .help("Copy password")

                    Spacer()

                    Button("Delete", role: .destructive, action: delete)
                        .help("Delete password")

                    Button("Save", action: save)
                        .keyboardShortcut(.defaultAction)
                        .disabled(!canSave || draft.resolvedURL == nil)
                        .help("Save password")
                }
            }
        }
        .formStyle(.grouped)
        .padding(16)
    }
}

private struct PasswordDraft {
    var title = ""
    var urlText = ""
    var username = ""
    var password = ""

    init() {}

    init(title: String, urlText: String, username: String, password: String) {
        self.title = title
        self.urlText = urlText
        self.username = username
        self.password = password
    }

    init(credential: PasswordCredential, password: String) {
        title = credential.title
        urlText = credential.origin.absoluteString
        username = credential.username
        self.password = password
    }

    var resolvedURL: URL? {
        let trimmed = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        return AddressResolver.resolvedURL(from: trimmed)
    }
}
