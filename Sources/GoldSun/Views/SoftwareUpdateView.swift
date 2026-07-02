import GoldSunCore
import SwiftUI

struct SoftwareUpdateSheetView: View {
    @ObservedObject var updateStore: SoftwareUpdateStore

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header

            switch updateStore.state {
            case .checking:
                ProgressView("Checking for updates...")
                    .frame(maxWidth: .infinity, alignment: .leading)
            case .downloading:
                ProgressView("Downloading installer...")
                    .frame(maxWidth: .infinity, alignment: .leading)
            case .upToDate:
                Text("GoldSun \(updateStore.currentVersionString) is the newest available version.")
                    .foregroundStyle(.secondary)
            case .available, .downloaded:
                if let update = updateStore.availableUpdate {
                    UpdateDetailsView(update: update)
                }
            case let .failed(message):
                Text(message)
                    .foregroundStyle(.secondary)
            case .idle:
                Text("GoldSun can check GitHub releases for installer packages.")
                    .foregroundStyle(.secondary)
            }

            HStack {
                Button("Release Page") {
                    updateStore.openReleasePage()
                }
                .disabled(updateStore.availableUpdate == nil)

                Spacer()

                Button("Later") {
                    updateStore.dismissUpdateSheet()
                }

                primaryButton
            }
        }
        .padding(24)
        .frame(width: 460)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: updateStore.toolbarIconName)
                .font(.system(size: 30))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 3) {
                Text(headerTitle)
                    .font(.title3.weight(.semibold))

                Text(updateStore.statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var headerTitle: String {
        switch updateStore.state {
        case .upToDate:
            "GoldSun is up to date"
        case .available, .downloaded, .downloading:
            "Update available"
        case .failed:
            "Update check failed"
        case .checking:
            "Checking for updates"
        case .idle:
            "Software Update"
        }
    }

    @ViewBuilder
    private var primaryButton: some View {
        switch updateStore.state {
        case .available:
            Button("Download and Install") {
                Task {
                    await updateStore.downloadAndStartInstaller()
                }
            }
            .help("Downloads the installer, opens it, then quits GoldSun so the update can install.")
            .keyboardShortcut(.defaultAction)
        case .downloaded:
            Button("Open Installer and Quit") {
                updateStore.openInstaller()
            }
            .help("Opens the installer package and quits GoldSun so the update can install.")
            .keyboardShortcut(.defaultAction)
        case .failed, .upToDate, .idle:
            Button("Check Again") {
                Task {
                    await updateStore.checkForUpdates(userInitiated: true)
                }
            }
            .keyboardShortcut(.defaultAction)
        case .checking, .downloading:
            Button("Working") {}
                .disabled(true)
        }
    }
}

private struct UpdateDetailsView: View {
    let update: SoftwareUpdate

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("GoldSun \(update.version.rawValue)", systemImage: "shippingbox")
                    .font(.headline)

                Spacer()

                if update.isPrerelease {
                    Text("Prerelease")
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.quaternary, in: Capsule())
                }
            }

            Text(update.installerName)
                .font(.caption)
                .foregroundStyle(.secondary)

            if !update.releaseNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                ScrollView {
                    Text(update.releaseNotes)
                        .font(.callout)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 140)
            }
        }
    }
}
