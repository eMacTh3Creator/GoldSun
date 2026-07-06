import GoldSunCore
import SwiftUI

struct BrowserWindowView: View {
    @ObservedObject var model: BrowserModel
    @ObservedObject var bookmarkStore: BookmarkStore
    @ObservedObject var updateStore: SoftwareUpdateStore
    @ObservedObject var downloadStore: DownloadStore
    @ObservedObject var historyStore: HistoryStore
    @ObservedObject var passwordStore: PasswordStore
    let openURLInNewWindow: (URL) -> Void
    @AppStorage("showBookmarkBar") private var showBookmarkBar = true

    var body: some View {
        VStack(spacing: 0) {
            // While page content (for example YouTube video) is in HTML
            // fullscreen, the chrome hides so the content fills the screen.
            if !isContentFullscreen {
                BrowserToolbar(
                    model: model,
                    bookmarkStore: bookmarkStore,
                    updateStore: updateStore,
                    downloadStore: downloadStore,
                    passwordStore: passwordStore
                )

                Divider()
                TabBarView(model: model)

                if showBookmarkBar {
                    Divider()
                    BookmarkBarView(model: model, bookmarkStore: bookmarkStore)
                }

                Divider()
            }

            ZStack {
                if model.tabs.isEmpty {
                    EmptyBrowserView()
                }

                ForEach(model.tabs) { tab in
                    BrowserTabView(
                        tab: tab,
                        model: model,
                        bookmarkStore: bookmarkStore,
                        downloadStore: downloadStore,
                        historyStore: historyStore,
                        passwordStore: passwordStore,
                        openURLInNewWindow: openURLInNewWindow
                    )
                    .opacity(model.selectedTabID == tab.id ? 1 : 0)
                    .allowsHitTesting(model.selectedTabID == tab.id)
                    .accessibilityHidden(model.selectedTabID != tab.id)
                    .zIndex(model.selectedTabID == tab.id ? 1 : 0)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .task {
            updateStore.startAutomaticChecks()
        }
        .sheet(isPresented: $updateStore.isUpdateSheetPresented) {
            SoftwareUpdateSheetView(updateStore: updateStore)
        }
        .sheet(item: passwordPromptBinding) { prompt in
            PasswordSavePromptView(
                prompt: prompt,
                isUpdate: passwordStore.isUpdatePrompt(prompt),
                save: {
                    try passwordStore.savePrompt(prompt)
                },
                dismiss: {
                    passwordStore.dismissPrompt(prompt)
                }
            )
        }
    }

    private var isContentFullscreen: Bool {
        model.selectedTab?.isContentFullscreen == true
    }

    private var passwordPromptBinding: Binding<PasswordSavePrompt?> {
        Binding {
            passwordStore.pendingSavePrompt
        } set: { prompt in
            if prompt == nil {
                passwordStore.dismissPrompt(passwordStore.pendingSavePrompt)
            }
        }
    }
}

private struct PasswordSavePromptView: View {
    let prompt: PasswordSavePrompt
    let isUpdate: Bool
    let save: () throws -> Void
    let dismiss: () -> Void

    @Environment(\.dismiss) private var dismissSheet
    @State private var errorMessage = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "key.fill")
                    .font(.title2)
                    .foregroundStyle(.yellow)

                VStack(alignment: .leading, spacing: 4) {
                    Text(isUpdate ? "Update Password?" : "Save Password?")
                        .font(.headline)

                    Text(prompt.host)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 8) {
                GridRow {
                    Text("Username")
                        .foregroundStyle(.secondary)

                    Text(prompt.username.isEmpty ? "No username detected" : prompt.username)
                        .lineLimit(1)
                }

                GridRow {
                    Text("Password")
                        .foregroundStyle(.secondary)

                    Text(String(repeating: "*", count: max(8, min(prompt.password.count, 18))))
                        .lineLimit(1)
                }
            }

            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.callout)
                    .foregroundStyle(.red)
            }

            HStack {
                Spacer()

                Button("Not Now") {
                    dismiss()
                    dismissSheet()
                }

                Button(isUpdate ? "Update Password" : "Save Password") {
                    do {
                        try save()
                        dismissSheet()
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(22)
        .frame(width: 430)
    }
}
