import SwiftUI

enum GSButtonStyle {
    case primary
    case secondary
    case tertiary
    case destructive
    case ghost            // text-only on background
}

enum GSButtonSize {
    case small
    case regular
    case large
}

struct GSButton: View {
    let title: String
    var icon: String? = nil
    var trailingIcon: String? = nil
    var style: GSButtonStyle = .primary
    var size: GSButtonSize = .regular
    var fullWidth: Bool = true
    var isLoading: Bool = false
    var isEnabled: Bool = true
    var action: () -> Void

    var body: some View {
        Button(action: tap) {
            HStack(spacing: Spacing.xs) {
                if let icon, !isLoading {
                    Image(systemName: icon)
                        .font(.system(size: iconSize, weight: .semibold))
                }
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .tint(foreground)
                } else {
                    Text(title)
                        .font(font)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                if let trailingIcon, !isLoading {
                    Image(systemName: trailingIcon)
                        .font(.system(size: iconSize, weight: .semibold))
                }
            }
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .foregroundStyle(foreground)
            .background(background)
            .overlay(strokeOverlay)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled || isLoading)
        .opacity(isEnabled ? 1 : 0.5)
    }

    private func tap() {
        let g = UIImpactFeedbackGenerator(style: .light)
        g.impactOccurred()
        action()
    }

    // MARK: - style mapping

    private var foreground: Color {
        switch style {
        case .primary:     return .textOnAccent
        case .secondary:   return .textPrimary
        case .tertiary:    return .textPrimary
        case .destructive: return .white
        case .ghost:       return .accentPrimary
        }
    }

    @ViewBuilder
    private var background: some View {
        switch style {
        case .primary:     Color.accentPrimary
        case .secondary:   Color.bgSecondary
        case .tertiary:    Color.bgTertiary
        case .destructive: Color.destructive
        case .ghost:       Color.clear
        }
    }

    @ViewBuilder
    private var strokeOverlay: some View {
        switch style {
        case .secondary, .tertiary:
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(Color.dividerColor, lineWidth: 0.5)
        case .ghost:
            EmptyView()
        default:
            EmptyView()
        }
    }

    private var font: Font {
        switch size {
        case .small:    return .wbCaption
        case .regular:  return .wbButton
        case .large:    return .wbHeadline
        }
    }

    private var iconSize: CGFloat {
        switch size {
        case .small:   return 12
        case .regular: return 14
        case .large:   return 16
        }
    }

    private var horizontalPadding: CGFloat {
        switch size {
        case .small:   return Spacing.s
        case .regular: return Spacing.l
        case .large:   return Spacing.xl
        }
    }

    private var verticalPadding: CGFloat {
        switch size {
        case .small:   return Spacing.xs
        case .regular: return Spacing.s + 2
        case .large:   return Spacing.m
        }
    }

    private var cornerRadius: CGFloat {
        switch size {
        case .small:   return Radius.s
        case .regular: return Radius.m
        case .large:   return Radius.l
        }
    }
}

#Preview {
    VStack(spacing: Spacing.s) {
        GSButton(title: "Save Vehicle", icon: "tray.and.arrow.down.fill", style: .primary) {}
        GSButton(title: "Scan VIN", icon: "viewfinder", style: .secondary) {}
        GSButton(title: "Add line item", style: .tertiary, size: .small, fullWidth: false) {}
        GSButton(title: "Delete record", icon: "trash", style: .destructive) {}
        GSButton(title: "Restore Purchases", style: .ghost) {}
    }
    .padding()
    .wbScreenBackground()
}
