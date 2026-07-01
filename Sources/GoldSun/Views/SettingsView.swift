import GoldSunCore
import SwiftUI

struct SettingsView: View {
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

            PrivacySettingsPane()
                .tabItem {
                    Label("Privacy", systemImage: "shield")
                }
        }
        .frame(width: 520, height: 430)
        .scenePadding()
    }
}

private struct GeneralSettingsPane: View {
    @AppStorage("homePage") private var homePage = "https://www.google.com"
    @AppStorage("searchEngine") private var searchEngine = SearchEngine.duckDuckGo.rawValue
    @AppStorage("preferredEngine") private var preferredEngine = BrowserEngineKind.chromiumCEF.rawValue
    @AppStorage("tabDisplayMode") private var tabDisplayMode = TabDisplayMode.both.rawValue
    @AppStorage("showBookmarkBar") private var showBookmarkBar = true

    var body: some View {
        Form {
            Section("Startup") {
                TextField("Home page", text: $homePage)
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

            Section("Tabs and Bookmarks") {
                Picker("Tabs", selection: $tabDisplayMode) {
                    ForEach(TabDisplayMode.allCases) { mode in
                        Text(mode.displayName)
                            .tag(mode.rawValue)
                    }
                }

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
    @AppStorage("adBlockEnabled") private var adBlockEnabled = AdBlockConfiguration.defaults.isEnabled
    @AppStorage("adBlockProtectionLevel") private var protectionLevel = AdBlockConfiguration.defaults.protectionLevel.rawValue
    @AppStorage("adBlockBlocksTrackers") private var blocksTrackers = AdBlockConfiguration.defaults.blocksTrackers
    @AppStorage("adBlockHidesPlaceholders") private var hidesPlaceholders = AdBlockConfiguration.defaults.hidesPlaceholders
    @AppStorage("adBlockAllowsAcceptableAds") private var allowsAcceptableAds = AdBlockConfiguration.defaults.allowsAcceptableAds
    @AppStorage("adBlockAutoUpdateLists") private var autoUpdateLists = AdBlockConfiguration.defaults.updatesFilterListsAutomatically

    var body: some View {
        Form {
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
