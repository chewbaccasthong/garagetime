import SwiftUI

/// A tappable card with consistent chrome (rounded, bordered, shadow).
/// Use as the visual container for vehicle tiles, line items, etc.
struct GSCard<Content: View>: View {
    var elevated: Bool = false
    var padding: CGFloat = Spacing.m
    var radius: CGFloat = Radius.l
    var onTap: (() -> Void)? = nil
    @ViewBuilder var content: () -> Content

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Group {
            if let onTap {
                Button(action: { tap(onTap) }) { card }
                    .buttonStyle(.plain)
            } else {
                card
            }
        }
    }

    private var card: some View {
        content()
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Color.bgSecondary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(Color.dividerColor, lineWidth: 0.5)
            )
            .shadow(
                color: shadowSpec.color,
                radius: shadowSpec.radius,
                x: 0, y: shadowSpec.y
            )
    }

    private var shadowSpec: (color: Color, radius: CGFloat, y: CGFloat) {
        elevated ? Shadow.pop(scheme) : Shadow.card(scheme)
    }

    private func tap(_ action: () -> Void) {
        let g = UIImpactFeedbackGenerator(style: .light)
        g.impactOccurred()
        action()
    }
}
