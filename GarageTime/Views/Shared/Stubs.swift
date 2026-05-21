import SwiftUI

/// Temporary placeholder used while a feature view is being built out.
/// Remove a stub once its real view file is added.
struct ComingSoonView: View {
    let title: String
    let icon: String

    var body: some View {
        NavigationStack {
            GSEmptyState(
                icon: icon,
                title: "\(title) — coming soon",
                message: "This tab is part of the next build stage."
            )
            .wbScreenBackground()
            .navigationTitle(title)
        }
    }
}
