import SwiftUI

struct TabBarView: View {
    @ObservedObject var model: BrowserModel
    private let gold = Color(red: 0.91, green: 0.61, blue: 0.21)

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(model.tabs) { tab in
                    TabBarItemView(
                        tab: tab,
                        isSelected: model.selectedTabID == tab.id,
                        select: {
                            model.selectTab(tab.id)
                        },
                        close: {
                            model.close(tab: tab)
                        }
                    )
                }

                Button {
                    model.newTab()
                } label: {
                    Image(systemName: "plus")
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.borderless)
                .help("New tab")
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
        }
        .background {
            Rectangle()
                .fill(.bar)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(gold.opacity(0.16))
                        .frame(height: 1)
                }
        }
    }
}

private struct TabBarItemView: View {
    @ObservedObject var tab: BrowserTabSession
    let isSelected: Bool
    let select: () -> Void
    let close: () -> Void
    private let gold = Color(red: 0.91, green: 0.61, blue: 0.21)

    var body: some View {
        HStack(spacing: 6) {
            Button(action: select) {
                HStack(spacing: 6) {
                    Image(systemName: tabIconName)
                        .font(.caption)
                        .foregroundStyle(isSelected ? gold : .secondary)

                    Text(tab.title.isEmpty ? "Untitled" : tab.title)
                        .lineLimit(1)
                        .frame(maxWidth: 150, alignment: .leading)
                }
                .frame(width: 176, height: 28, alignment: .leading)
                .padding(.leading, 8)
            }
            .buttonStyle(.plain)

            Button(action: close) {
                Image(systemName: "xmark")
                    .font(.caption2)
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(.plain)
            .help("Close tab")
        }
        .padding(.trailing, 5)
        .background {
            RoundedRectangle(cornerRadius: 7)
                .fill(isSelected ? gold.opacity(0.15) : Color.clear)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 7)
                .stroke(isSelected ? gold.opacity(0.45) : Color.clear)
        }
    }

    private var tabIconName: String {
        if tab.isLoading {
            return "circle.dotted"
        }

        if tab.url.scheme?.caseInsensitiveCompare("goldsun") == .orderedSame {
            return "sun.max.fill"
        }

        return "globe"
    }
}
