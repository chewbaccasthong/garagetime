import SwiftUI

/// Section header with title + optional trailing action button.
struct GSSectionHeader: View {
    let title: String
    var subtitle: String? = nil
    var actionTitle: String? = nil
    var actionIcon: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.s) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.wbTitle)
                    .foregroundStyle(Color.textPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(.wbCaption)
                        .foregroundStyle(Color.textSecondary)
                }
            }
            Spacer()
            if let actionTitle, let action {
                Button(action: action) {
                    HStack(spacing: 4) {
                        if let actionIcon {
                            Image(systemName: actionIcon)
                                .font(.system(size: 12, weight: .semibold))
                        }
                        Text(actionTitle)
                            .font(.wbCaption)
                    }
                    .foregroundStyle(Color.accentPrimary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, Spacing.xs)
    }
}
