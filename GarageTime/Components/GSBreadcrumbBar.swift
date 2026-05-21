import SwiftUI

/// A single segment in the breadcrumb path.
/// Use the icon to give the leading tab/section a glyph.
struct Crumb: Hashable, Identifiable {
    var id: String { label }
    var label: String
    var icon: String?

    init(_ label: String, icon: String? = nil) {
        self.label = label
        self.icon = icon
    }
}

/// "Garage › Honda Civic › Service" path bar shown directly under the nav title.
/// Horizontally scrollable so deep paths don't wrap or truncate ugly.
struct GSBreadcrumbBar: View {
    let crumbs: [Crumb]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(Array(crumbs.enumerated()), id: \.element.id) { index, crumb in
                    HStack(spacing: 4) {
                        if let icon = crumb.icon {
                            Image(systemName: icon)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(color(at: index))
                        }
                        Text(crumb.label)
                            .font(.wbCaptionSmall)
                            .foregroundStyle(color(at: index))
                            .fontWeight(index == crumbs.count - 1 ? .semibold : .regular)
                            .lineLimit(1)
                    }
                    if index < crumbs.count - 1 {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(Color.textTertiary)
                            .padding(.horizontal, 6)
                    }
                }
            }
            .padding(.horizontal, Spacing.m)
            .padding(.vertical, 6)
        }
        .background(Color.bgSecondary)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.dividerColor)
                .frame(height: 0.5)
        }
    }

    private func color(at index: Int) -> Color {
        index == crumbs.count - 1 ? .textPrimary : .textSecondary
    }
}

extension View {
    /// Show a breadcrumb path bar at the top of the screen. Call below the navigation
    /// title (typically the first child inside the view body).
    ///
    /// Usage:
    /// ```
    /// var body: some View {
    ///     NavigationStack {
    ///         someContent
    ///             .wbBreadcrumbs([Crumb("Garage", icon: "car.2.fill"),
    ///                             Crumb(vehicle.displayTitle, icon: vehicle.type.sfSymbol)])
    ///     }
    /// }
    /// ```
    func wbBreadcrumbs(_ crumbs: [Crumb]) -> some View {
        modifier(BreadcrumbsModifier(crumbs: crumbs))
    }
}

private struct BreadcrumbsModifier: ViewModifier {
    let crumbs: [Crumb]

    func body(content: Content) -> some View {
        VStack(spacing: 0) {
            GSBreadcrumbBar(crumbs: crumbs)
            content
        }
    }
}

#Preview {
    NavigationStack {
        VStack { Text("Body") }
            .wbBreadcrumbs([
                Crumb("Garage", icon: "car.2.fill"),
                Crumb("Honda Civic", icon: "car.fill"),
                Crumb("Service records", icon: "wrench.adjustable.fill"),
                Crumb("Oil change · May 14"),
            ])
            .navigationTitle("Edit Service")
    }
}
