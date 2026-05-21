import SwiftUI

/// Single numeric/stat cell for dashboards. Big number with a small caption.
struct GSStatBlock: View {
    let label: String
    let value: String
    var detail: String? = nil
    var icon: String? = nil
    var role: PaletteRole = .neutral

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            HStack(spacing: Spacing.xs) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(roleColor)
                }
                Text(label.uppercased())
                    .font(.wbCaptionSmall)
                    .tracking(0.6)
                    .foregroundStyle(Color.textSecondary)
            }
            Text(value)
                .font(.wbDisplayMedium)
                .foregroundStyle(Color.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            if let detail {
                Text(detail)
                    .font(.wbCaption)
                    .foregroundStyle(Color.textTertiary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.m)
        .background(
            RoundedRectangle(cornerRadius: Radius.l, style: .continuous)
                .fill(Color.bgSecondary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.l, style: .continuous)
                .strokeBorder(Color.dividerColor, lineWidth: 0.5)
        )
    }

    private var roleColor: Color {
        switch role {
        case .neutral: return .textSecondary
        case .info:    return .statusBlue
        case .success: return .statusGreen
        case .warning: return .statusAmber
        case .danger:  return .statusRed
        case .accent:  return .accentPrimary
        }
    }
}
