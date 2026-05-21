import SwiftUI

/// A horizontal scrollable chip bar — used for "All / Personal / Customer" type filters.
struct GSChipBar<Item: Hashable>: View {
    let items: [Item]
    @Binding var selection: Item
    let label: (Item) -> String
    var icon: ((Item) -> String?)? = nil

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.xs) {
                ForEach(items, id: \.self) { item in
                    chip(item)
                }
            }
            .padding(.horizontal, Spacing.m)
            .padding(.vertical, Spacing.xs)
        }
    }

    @ViewBuilder
    private func chip(_ item: Item) -> some View {
        let selected = item == selection
        Button {
            withAnimation(Motion.snap) { selection = item }
            let g = UISelectionFeedbackGenerator()
            g.selectionChanged()
        } label: {
            HStack(spacing: 6) {
                if let ic = icon?(item) {
                    Image(systemName: ic)
                        .font(.system(size: 12, weight: .semibold))
                }
                Text(label(item))
                    .font(.wbCaption)
                    .fontWeight(selected ? .semibold : .medium)
            }
            .padding(.horizontal, Spacing.s)
            .padding(.vertical, 6)
            .foregroundStyle(selected ? Color.textOnAccent : Color.textPrimary)
            .background(
                Capsule().fill(selected ? Color.accentPrimary : Color.bgSecondary)
            )
            .overlay(
                Capsule().strokeBorder(
                    selected ? Color.clear : Color.dividerColor,
                    lineWidth: 0.5
                )
            )
        }
        .buttonStyle(.plain)
    }
}
