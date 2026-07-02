import Combine
import Foundation
import GoldSunCore

@MainActor
final class BrowserModel: ObservableObject {
    @Published private(set) var tabs: [BrowserTabSession]
    @Published var selectedTabID: BrowserTabSession.ID?
    @Published var addressText: String

    private var tabCancellables: [BrowserTabSession.ID: Set<AnyCancellable>]

    init() {
        let firstURL = Self.resolvedHomePage()
        let firstTab = BrowserTabSession(title: Self.title(for: firstURL), url: firstURL)

        tabs = [firstTab]
        selectedTabID = firstTab.id
        addressText = firstURL.absoluteString
        tabCancellables = [:]

        observe(firstTab)
    }

    var selectedTab: BrowserTabSession? {
        tabs.first { $0.id == selectedTabID }
    }

    func selectTab(_ id: BrowserTabSession.ID?) {
        selectedTabID = id

        if let selectedTab {
            addressText = selectedTab.url.absoluteString
        }
    }

    func newTab(address: String? = nil) {
        let address = address ?? Self.resolvedHomePage().absoluteString
        let url = AddressResolver.resolvedURL(from: address)
        open(url, inNewTab: true)
    }

    func open(_ url: URL, inNewTab: Bool = false) {
        if inNewTab || selectedTab == nil {
            createTab(url: url)
        } else {
            selectedTab?.load(url)
            selectedTab?.title = Self.title(for: url)
            addressText = url.absoluteString
        }
    }

    func openAddress(_ address: String, inNewTab: Bool = false) {
        let url = AddressResolver.resolvedURL(from: address, searchEngine: Self.searchEngine())
        open(url, inNewTab: inNewTab)
    }

    func openAddressInNewTab() {
        openAddress(addressText, inNewTab: true)
    }

    func goHome() {
        open(Self.resolvedHomePage())
    }

    private func createTab(url: URL) {
        let tab = BrowserTabSession(title: Self.title(for: url), url: url)

        tabs.append(tab)
        observe(tab)
        selectTab(tab.id)
    }

    func openChromeWebStore() {
        newTab(address: BrowserDestination.chromeWebStore.absoluteString)
    }

    func openBookmarkManager(inNewTab: Bool = false) {
        open(BrowserDestination.bookmarkManager, inNewTab: inNewTab)
    }

    func openDownloadManager(inNewTab: Bool = false) {
        open(BrowserDestination.downloadManager, inNewTab: inNewTab)
    }

    func closeSelectedTab() {
        guard let selectedTab else {
            return
        }

        close(tab: selectedTab)
    }

    func close(tab: BrowserTabSession) {
        guard let index = tabs.firstIndex(where: { $0.id == tab.id }) else {
            return
        }

        tabs.remove(at: index)
        tabCancellables[tab.id] = nil

        if tabs.isEmpty {
            newTab()
            return
        }

        if selectedTabID == tab.id {
            let fallbackIndex = min(index, tabs.count - 1)
            selectTab(tabs[fallbackIndex].id)
        }
    }

    func loadAddress() {
        guard let selectedTab else {
            return
        }

        let url = AddressResolver.resolvedURL(from: addressText, searchEngine: Self.searchEngine())
        selectedTab.load(url)
        addressText = url.absoluteString
    }

    func goBack() {
        selectedTab?.request(.goBack)
    }

    func goForward() {
        selectedTab?.request(.goForward)
    }

    func reload() {
        selectedTab?.request(.reload)
    }

    func stopLoading() {
        selectedTab?.request(.stopLoading)
    }

    private func observe(_ tab: BrowserTabSession) {
        var cancellables = Set<AnyCancellable>()

        tab.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        tab.$url
            .sink { [weak self, weak tab] url in
                guard let self, let tab, selectedTabID == tab.id else {
                    return
                }

                addressText = url.absoluteString
            }
            .store(in: &cancellables)

        tabCancellables[tab.id] = cancellables
    }

    private static func resolvedHomePage() -> URL {
        guard let storedHomePage = UserDefaults.standard.string(forKey: "homePage"),
              !storedHomePage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return BrowserDestination.goldSunStartPage
        }

        return AddressResolver.resolvedURL(from: storedHomePage, searchEngine: searchEngine())
    }

    private static func searchEngine() -> SearchEngine {
        let rawValue = UserDefaults.standard.string(forKey: "searchEngine") ?? SearchEngine.duckDuckGo.rawValue
        return SearchEngine(rawValue: rawValue) ?? .duckDuckGo
    }

    private static func title(for url: URL) -> String {
        switch url {
        case BrowserDestination.goldSunStartPage:
            "GoldSun"
        case BrowserDestination.bookmarkManager:
            "Bookmarks"
        case BrowserDestination.downloadManager:
            "Downloads"
        default:
            "New Tab"
        }
    }
}
