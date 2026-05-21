import SwiftUI

/// Sticky segmented control for switching between sub-views within a detail screen.
struct GSSegmentedTabs<Tab: Hashable & CaseIterable>: View where Tab.AllCases: RandomAccessCollection {
    @Binding var selection: Tab
    let label: (Tab) -> String

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(Tab.allCases), id: \.self) { tab in
                tabButton(tab)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: Radius.pill, style: .continuous)
                .fill(Color.bgSecondary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.pill, style: .continuous)
                .strokeBorder(Color.dividerColor, lineWidth: 0.5)
        )
    }

    @ViewBuilder
    private func tabButton(_ tab: Tab) -> some View {
        let selected = tab == selection
        Button {
            withAnimation(Motion.snap) { selection = tab }
            let g = UISelectionFeedbackGenerator()
            g.selectionChanged()
        } label: {
            Text(label(tab))
                .font(.wbCaption)
                .fontWeight(selected ? .semibold : .medium)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.xs)
                .foregroundStyle(selected ? Color.textOnAccent : Color.textPrimary)
                .background(
                    Capsule()
                        .fill(selected ? Color.accentPrimary : Color.clear)
                )
        }
        .buttonStyle(.plain)
    }
}
