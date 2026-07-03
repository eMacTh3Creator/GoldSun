import GoldSunCore
import SwiftUI

struct SettingsView: View {
    @ObservedObject var updateStore: SoftwareUpdateStore
    @ObservedObject var historyStore: HistoryStore

    var body: some View {
        TabView {
            GeneralSettingsPane()
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }

            ExtensionsSettingsPane()
                .tabItem {
                    Label("Extensions", systemImage: "puzzlepiece")
                }

            PrivacySettingsPane(historyStore: historyStore)
                .tabItem {
                    Label("Privacy", systemImage: "shield")
                }

            PasswordSettingsPane()
                .tabItem {
                    Label("Passwords", systemImage: "key")
                }

            UpdatesSettingsPane(updateStore: updateStore)
                .tabItem {
                    Label("Updates", systemImage: "arrow.triangle.2.circlepath")
                }
        }
        .frame(width: 580, height: 540)
        .scenePadding()
    }
}

private struct GeneralSettingsPane: View {
    @AppStorage("homePage") private var homePage = BrowserDestination.goldSunStartPage.absoluteString
    @AppStorage("searchEngine") private var searchEngine = SearchEngine.duckDuckGo.rawValue
    @AppStorage("preferredEngine") private var preferredEngine = BrowserEngineKind.chromiumCEF.rawValue
    @AppStorage("showBookmarkBar") private var showBookmarkBar = true

    var body: some View {
        Form {
            Section("Startup") {
                TextField("Home page", text: $homePage)

                Button("Use GoldSun Start Page") {
                    homePage = BrowserDestination.goldSunStartPage.absoluteString
                }
            }

            Section("Search") {
                Picker("Search engine", selection: $searchEngine) {
                    ForEach(SearchEngine.allCases) { engine in
                        Text(engine.displayName)
                            .tag(engine.rawValue)
                    }
                }
            }

            Section("Engine") {
                Picker("Browser engine", selection: $preferredEngine) {
                    ForEach(BrowserEngineKind.allCases) { engine in
                        Text(engine.displayName)
                            .tag(engine.rawValue)
                    }
                }
            }

            Section("Bookmarks") {
                Toggle("Show bookmark bar", isOn: $showBookmarkBar)
            }
        }
        .formStyle(.grouped)
    }
}

private struct ExtensionsSettingsPane: View {
    @AppStorage("extensions.chromeWebStoreEnabled") private var chromeWebStoreEnabled = ExtensionCompatibilityConfiguration.defaults.isChromeWebStoreEnabled
    @AppStorage("extensions.installSourcePolicy") private var installSourcePolicy = ExtensionCompatibilityConfiguration.defaults.installSourcePolicy.rawValue
    @AppStorage("extensions.manifestSupportMode") private var manifestSupportMode = ExtensionCompatibilityConfiguration.defaults.manifestSupportMode.rawValue
    @AppStorage("extensions.requiresInstallReview") private var requiresInstallReview = ExtensionCompatibilityConfiguration.defaults.requiresInstallReview
    @AppStorage("extensions.autoUpdate") private var autoUpdate = ExtensionCompatibilityConfiguration.defaults.updatesExtensionsAutomatically
    @AppStorage("extensions.allowIncognito") private var allowIncognito = ExtensionCompatibilityConfiguration.defaults.allowsIncognitoExtensions

    var body: some View {
        Form {
            Section("Store") {
                Toggle("Enable Chrome Web Store", isOn: $chromeWebStoreEnabled)

                Picker("Install sources", selection: $installSourcePolicy) {
                    ForEach(ExtensionInstallSourcePolicy.allCases) { policy in
                        Text(policy.displayName)
                            .tag(policy.rawValue)
                    }
                }
            }

            Section("Runtime") {
                Picker("Manifest support", selection: $manifestSupportMode) {
                    ForEach(ExtensionManifestSupportMode.allCases) { mode in
                        Text(mode.displayName)
                            .tag(mode.rawValue)
                    }
                }

                Toggle("Review permissions before install", isOn: $requiresInstallReview)
                Toggle("Update extensions automatically", isOn: $autoUpdate)
                Toggle("Allow in Private windows", isOn: $allowIncognito)
            }
        }
        .formStyle(.grouped)
    }
}

private struct PrivacySettingsPane: View {
    @ObservedObject var historyStore: HistoryStore
    @AppStorage("adBlockEnabled") private var adBlockEnabled = AdBlockConfiguration.defaults.isEnabled
    @AppStorage("adBlockProtectionLevel") private var protectionLevel = AdBlockConfiguration.defaults.protectionLevel.rawValue
    @AppStorage("adBlockBlocksTrackers") private var blocksTrackers = AdBlockConfiguration.defaults.blocksTrackers
    @AppStorage("adBlockHidesPlaceholders") private var hidesPlaceholders = AdBlockConfiguration.defaults.hidesPlaceholders
    @AppStorage("adBlockAllowsAcceptableAds") private var allowsAcceptableAds = AdBlockConfiguration.defaults.allowsAcceptableAds
    @AppStorage("adBlockAutoUpdateLists") private var autoUpdateLists = AdBlockConfiguration.defaults.updatesFilterListsAutomatically
    @AppStorage(BrowserSecurityPreferenceKey.httpsUpgradeMode) private var httpsUpgradeMode = BrowserSecurityConfiguration.defaults.httpsUpgradeMode.rawValue
    @AppStorage(BrowserSecurityPreferenceKey.fraudulentWebsiteWarnings) private var fraudulentWebsiteWarnings = BrowserSecurityConfiguration.defaults.fraudulentWebsiteWarnings
    @AppStorage(BrowserSecurityPreferenceKey.privateBrowsingByDefault) private var privateBrowsingByDefault = BrowserSecurityConfiguration.defaults.privateBrowsingByDefault
    @AppStorage(BrowserSecurityPreferenceKey.javaScriptEnabled) private var javaScriptEnabled = BrowserSecurityConfiguration.defaults.javaScriptEnabled
    @AppStorage(BrowserSecurityPreferenceKey.blocksAutomaticPopups) private var blocksAutomaticPopups = BrowserSecurityConfiguration.defaults.blocksAutomaticPopups
    @AppStorage(BrowserSecurityPreferenceKey.stripsTrackingParameters) private var stripsTrackingParameters = BrowserSecurityConfiguration.defaults.stripsTrackingParameters
    @AppStorage(BrowserHistoryPreferenceKey.isEnabled) private var savesBrowsingHistory = BrowserHistoryConfiguration.defaults.isEnabled

    var body: some View {
        Form {
            Section("Security") {
                Picker("HTTPS", selection: $httpsUpgradeMode) {
                    ForEach(HTTPSUpgradeMode.allCases) { mode in
                        Text(mode.displayName)
                            .tag(mode.rawValue)
                    }
                }

                Toggle("Warn about fraudulent websites", isOn: $fraudulentWebsiteWarnings)
                Toggle("Use private browsing storage by default", isOn: $privateBrowsingByDefault)
                Toggle("Enable JavaScript", isOn: $javaScriptEnabled)
                Toggle("Block automatic pop-up windows", isOn: $blocksAutomaticPopups)
                Toggle("Strip known tracking parameters", isOn: $stripsTrackingParameters)
            }

            Section("Ad Blocking") {
                Toggle("Enable built-in ad blocker", isOn: $adBlockEnabled)

                Picker("Protection level", selection: $protectionLevel) {
                    ForEach(AdBlockProtectionLevel.allCases) { level in
                        Text(level.displayName)
                            .tag(level.rawValue)
                    }
                }

                Toggle("Block trackers", isOn: $blocksTrackers)
                Toggle("Hide blocked placeholders", isOn: $hidesPlaceholders)
                Toggle("Allow acceptable ads", isOn: $allowsAcceptableAds)
                Toggle("Update filter lists automatically", isOn: $autoUpdateLists)
            }

            Section("History") {
                Toggle("Save browsing history", isOn: $savesBrowsingHistory)

                Button("Clear Browsing History") {
                    historyStore.clear()
                }
                .disabled(historyStore.entries.isEmpty)
            }

            Section("Filter Lists") {
                ForEach(AdBlockFilterList.allCases) { list in
                    Toggle(list.displayName, isOn: filterListBinding(for: list))
                }
            }
        }
        .formStyle(.grouped)
    }

    private func filterListBinding(for list: AdBlockFilterList) -> Binding<Bool> {
        Binding {
            if let value = UserDefaults.standard.object(forKey: list.preferenceKey) as? Bool {
                return value
            }

            return list.isEnabledByDefault
        } set: { newValue in
            UserDefaults.standard.set(newValue, forKey: list.preferenceKey)
        }
    }
}

private struct UpdatesSettingsPane: View {
    @ObservedObject var updateStore: SoftwareUpdateStore
    @AppStorage(SoftwareUpdatePreferenceKey.automaticallyChecks) private var automaticallyChecks = true
    @AppStorage(SoftwareUpdatePreferenceKey.includesPrereleases) private var includesPrereleases = true
    @AppStorage(SoftwareUpdatePreferenceKey.automaticallyDownloadsInstaller) private var automaticallyDownloadsInstaller = true
    @AppStorage(SoftwareUpdatePreferenceKey.automaticallyStartsInstaller) private var automaticallyStartsInstaller = true

    var body: some View {
        Form {
            Section("Software Update") {
                Toggle("Check for updates automatically", isOn: $automaticallyChecks)
                Toggle("Include prerelease updates", isOn: $includesPrereleases)
                Toggle("Download installers automatically", isOn: $automaticallyDownloadsInstaller)
                Toggle("Start installer automatically and quit GoldSun", isOn: $automaticallyStartsInstaller)
                    .disabled(!automaticallyDownloadsInstaller)
            }

            Section("Status") {
                LabeledContent("Current version", value: updateStore.currentVersionString)
                LabeledContent("Status", value: updateStore.statusMessage)

                HStack {
                    Button("Check Now") {
                        Task {
                            await updateStore.checkForUpdates(userInitiated: true)
                        }
                    }
                    .disabled(updateStore.isBusy)

                    if updateStore.availableUpdate != nil {
                        Button("Release Page") {
                            updateStore.openReleasePage()
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}

private struct PasswordSettingsPane: View {
    @AppStorage(PasswordManagerPreferenceKey.isEnabled) private var isEnabled = PasswordManagerConfiguration.defaults.isEnabled
    @AppStorage(PasswordManagerPreferenceKey.autofillEnabled) private var autofillEnabled = PasswordManagerConfiguration.defaults.autofillEnabled
    @AppStorage(PasswordManagerPreferenceKey.savesSubmittedPasswords) private var savesSubmittedPasswords = PasswordManagerConfiguration.defaults.savesSubmittedPasswords

    var body: some View {
        Form {
            Section("Password Manager") {
                Toggle("Enable password manager", isOn: $isEnabled)

                Toggle("Autofill saved passwords", isOn: $autofillEnabled)
                    .disabled(!isEnabled)

                Toggle("Offer to save submitted passwords", isOn: $savesSubmittedPasswords)
                    .disabled(!isEnabled)
            }

            Section("Passkeys") {
                LabeledContent("Native passkeys", value: "Signed builds")
            }

            Section("Storage") {
                Text("Passwords are stored in the macOS Keychain. Passkeys use macOS WebAuthn support in signed builds that include Apple's browser passkey entitlement.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
