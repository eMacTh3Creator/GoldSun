import SwiftUI

struct EmptyBrowserView: View {
    var body: some View {
        ContentUnavailableView(
            "No Tab Selected",
            systemImage: "safari",
            description: Text("Create a tab to start browsing.")
        )
    }
}
