import SwiftUI

/// Compact pill with a colored dot + label. Used for status, urgency, owner banner.
struct GSStatusPill: View {
    let text: String
    var role: PaletteRole = .neutral
    var icon: String? = nil
    var compact: Bool = false

    var body: some View {
        HStack(spacing: compact ? 4 : 6) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: compact ? 10 : 11, weight: .bold))
                    .foregroundStyle(foreground)
            } else {
                Circle()
                    .fill(dot)
                    .frame(width: compact ? 6 : 7, height: compact ? 6 : 7)
            }
            Text(text)
                .font(compact ? .wbCaptionSmall : .wbCaption)
                .foregroundStyle(foreground)
                .lineLimit(1)
        }
        .padding(.horizontal, compact ? Spacing.xs : Spacing.s)
        .padding(.vertical, compact ? 2 : 4)
        .background(
            Capsule(style: .continuous).fill(background)
        )
        .overlay(
            Capsule(style: .continuous).strokeBorder(border, lineWidth: 0.5)
        )
    }

    private var dot: Color {
        switch role {
        case .neutral: return .textSecondary
        case .info:    return .statusBlue
        case .success: return .statusGreen
        case .warning: return .statusAmber
        case .danger:  return .statusRed
        case .accent:  return .accentPrimary
        }
    }

    private var background: Color {
        switch role {
        case .neutral: return Color.bgTertiary
        case .info:    return Color.statusBlue.opacity(0.15)
        case .success: return Color.statusGreen.opacity(0.15)
        case .warning: return Color.statusAmber.opacity(0.18)
        case .danger:  return Color.statusRed.opacity(0.18)
        case .accent:  return Color.accentPrimary.opacity(0.18)
        }
    }

    private var border: Color {
        switch role {
        case .neutral: return Color.dividerColor
        case .info:    return Color.statusBlue.opacity(0.35)
        case .success: return Color.statusGreen.opacity(0.35)
        case .warning: return Color.statusAmber.opacity(0.45)
        case .danger:  return Color.statusRed.opacity(0.45)
        case .accent:  return Color.accentPrimary.opacity(0.45)
        }
    }

    private var foreground: Color {
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
