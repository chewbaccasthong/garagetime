import SwiftUI

/// Single-line item row used in quote builder, parts list, service line breakdowns.
struct GSLineItemRow: View {
    let leadingIcon: String?
    let title: String
    let subtitle: String?
    let trailing: String?
    let trailingSubtitle: String?
    var role: PaletteRole = .neutral
    var onTap: (() -> Void)? = nil

    var body: some View {
        Group {
            if let onTap {
                Button(action: onTap) { row }
                    .buttonStyle(.plain)
            } else { row }
        }
    }

    private var row: some View {
        HStack(alignment: .center, spacing: Spacing.s) {
            if let leadingIcon {
                ZStack {
                    Circle()
                        .fill(iconBackground)
                        .frame(width: 36, height: 36)
                    Image(systemName: leadingIcon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(iconForeground)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.wbBodyMedium)
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)
                if let subtitle {
                    Text(subtitle)
                        .font(.wbCaption)
                        .foregroundStyle(Color.textSecondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: Spacing.xs)
            if trailing != nil || trailingSubtitle != nil {
                VStack(alignment: .trailing, spacing: 2) {
                    if let trailing {
                        Text(trailing)
                            .font(.wbMonoBody)
                            .foregroundStyle(Color.textPrimary)
                    }
                    if let trailingSubtitle {
                        Text(trailingSubtitle)
                            .font(.wbCaptionSmall)
                            .foregroundStyle(Color.textTertiary)
                    }
                }
            }
        }
        .padding(.vertical, Spacing.s)
        .padding(.horizontal, Spacing.m)
        .background(
            RoundedRectangle(cornerRadius: Radius.m, style: .continuous)
                .fill(Color.bgSecondary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.m, style: .continuous)
                .strokeBorder(Color.dividerColor, lineWidth: 0.5)
        )
    }

    private var iconBackground: Color {
        switch role {
        case .neutral: return Color.bgTertiary
        case .info:    return Color.statusBlue.opacity(0.16)
        case .success: return Color.statusGreen.opacity(0.16)
        case .warning: return Color.statusAmber.opacity(0.18)
        case .danger:  return Color.statusRed.opacity(0.18)
        case .accent:  return Color.accentPrimary.opacity(0.18)
        }
    }

    private var iconForeground: Color {
        switch role {
        case .neutral: return .textPrimary
        case .info:    return .statusBlue
        case .success: return .statusGreen
        case .warning: return .statusAmber
        case .danger:  return .statusRed
        case .accent:  return .accentPrimary
        }
    }
}
