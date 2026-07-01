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
        let firstURL = AddressResolver.resolvedURL(from: "https://www.apple.com")
        let firstTab = BrowserTabSession(title: "Apple", url: firstURL)

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

    func newTab(address: String = "https://www.google.com") {
        let url = AddressResolver.resolvedURL(from: address)
        open(url, inNewTab: true)
    }

    func open(_ url: URL, inNewTab: Bool = false) {
        if inNewTab || selectedTab == nil {
            createTab(url: url)
        } else {
            selectedTab?.load(url)
            addressText = url.absoluteString
        }
    }

    func openAddress(_ address: String, inNewTab: Bool = false) {
        let url = AddressResolver.resolvedURL(from: address)
        open(url, inNewTab: inNewTab)
    }

    func openAddressInNewTab() {
        openAddress(addressText, inNewTab: true)
    }

    func goHome() {
        let homePage = UserDefaults.standard.string(forKey: "homePage") ?? "https://www.google.com"
        openAddress(homePage)
    }

    private func createTab(url: URL) {
        let tab = BrowserTabSession(url: url)

        tabs.append(tab)
        observe(tab)
        selectTab(tab.id)
    }

    func openChromeWebStore() {
        newTab(address: BrowserDestination.chromeWebStore.absoluteString)
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

        let url = AddressResolver.resolvedURL(from: addressText)
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
}
