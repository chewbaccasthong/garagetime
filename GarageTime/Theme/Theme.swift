import SwiftUI

// MARK: - Color tokens

extension Color {
    // Backgrounds
    static let bgPrimary    = Color("Colors/bg/primary", bundle: .main)
    static let bgSecondary  = Color("Colors/bg/secondary", bundle: .main)
    static let bgTertiary   = Color("Colors/bg/tertiary", bundle: .main)
    static let bgElevated   = Color("Colors/bg/elevated", bundle: .main)
    static let bgOverlay    = Color("Colors/bg/overlay", bundle: .main)

    // Text
    static let textPrimary   = Color("Colors/text/primary", bundle: .main)
    static let textSecondary = Color("Colors/text/secondary", bundle: .main)
    static let textTertiary  = Color("Colors/text/tertiary", bundle: .main)
    static let textInverse   = Color("Colors/text/inverse", bundle: .main)
    static let textOnAccent  = Color("Colors/text/onAccent", bundle: .main)

    // Accent
    static let accentPrimary   = Color("Colors/accent/primary", bundle: .main)
    static let accentSecondary = Color("Colors/accent/secondary", bundle: .main)
    static let accentTertiary  = Color("Colors/accent/tertiary", bundle: .main)

    // Status
    static let statusGreen = Color("Colors/status/green", bundle: .main)
    static let statusAmber = Color("Colors/status/amber", bundle: .main)
    static let statusRed   = Color("Colors/status/red", bundle: .main)
    static let statusBlue  = Color("Colors/status/blue", bundle: .main)

    // Misc
    static let dividerColor = Color("Colors/divider", bundle: .main)
    static let shimmer      = Color("Colors/shimmer", bundle: .main)
    static let destructive  = Color("Colors/destructive", bundle: .main)
}

// MARK: - Spacing scale (4-pt rhythm)

enum Spacing {
    static let xxs: CGFloat = 4
    static let xs:  CGFloat = 8
    static let s:   CGFloat = 12
    static let m:   CGFloat = 16
    static let l:   CGFloat = 20
    static let xl:  CGFloat = 24
    static let xxl: CGFloat = 32
    static let xxxl: CGFloat = 48
    static let huge: CGFloat = 64
}

// MARK: - Radius

enum Radius {
    static let xs: CGFloat = 4
    static let s:  CGFloat = 8
    static let m:  CGFloat = 12
    static let l:  CGFloat = 16
    static let xl: CGFloat = 24
    static let pill: CGFloat = 999
}

// MARK: - Typography

extension Font {
    static let wbDisplayHuge   = Font.system(size: 48, weight: .bold, design: .default)
    static let wbDisplayLarge  = Font.system(size: 36, weight: .bold, design: .default)
    static let wbDisplayMedium = Font.system(size: 28, weight: .bold, design: .default)
    static let wbTitleLarge    = Font.system(size: 22, weight: .semibold, design: .default)
    static let wbTitle         = Font.system(size: 20, weight: .semibold, design: .default)
    static let wbHeadline      = Font.system(size: 17, weight: .semibold, design: .default)
    static let wbBody          = Font.system(size: 16, weight: .regular, design: .default)
    static let wbBodyMedium    = Font.system(size: 16, weight: .medium, design: .default)
    static let wbCallout       = Font.system(size: 15, weight: .regular, design: .default)
    static let wbCaption       = Font.system(size: 13, weight: .medium, design: .default)
    static let wbCaptionSmall  = Font.system(size: 11, weight: .medium, design: .default)
    static let wbMonoBody      = Font.system(size: 15, weight: .regular, design: .monospaced)
    static let wbMonoCaption   = Font.system(size: 12, weight: .medium, design: .monospaced)
    static let wbButton        = Font.system(size: 16, weight: .semibold, design: .default)
}

// MARK: - Shadows

enum Shadow {
    static func card(_ scheme: ColorScheme) -> (color: Color, radius: CGFloat, y: CGFloat) {
        switch scheme {
        case .dark:  return (Color.black.opacity(0.40), 14, 6)
        case .light: return (Color.black.opacity(0.10), 14, 6)
        @unknown default: return (Color.black.opacity(0.20), 14, 6)
        }
    }
    static func pop(_ scheme: ColorScheme) -> (color: Color, radius: CGFloat, y: CGFloat) {
        switch scheme {
        case .dark:  return (Color.black.opacity(0.55), 22, 12)
        case .light: return (Color.black.opacity(0.16), 22, 12)
        @unknown default: return (Color.black.opacity(0.30), 22, 12)
        }
    }
}

// MARK: - Motion

enum Motion {
    static let snap: Animation     = .spring(response: 0.28, dampingFraction: 0.86)
    static let smooth: Animation   = .spring(response: 0.40, dampingFraction: 0.82)
    static let lazy: Animation     = .spring(response: 0.55, dampingFraction: 0.78)
    static let easeFast: Animation = .easeInOut(duration: 0.18)
    static let easeStd: Animation  = .easeInOut(duration: 0.28)
}

// MARK: - Convenience modifiers

struct CardStyle: ViewModifier {
    var elevated: Bool = false
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        let shadow = elevated ? Shadow.pop(scheme) : Shadow.card(scheme)
        return content
            .padding(Spacing.m)
            .background(
                RoundedRectangle(cornerRadius: Radius.l, style: .continuous)
                    .fill(Color.bgSecondary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.l, style: .continuous)
                    .strokeBorder(Color.dividerColor, lineWidth: 0.5)
            )
            .shadow(color: shadow.color, radius: shadow.radius, x: 0, y: shadow.y)
    }
}

extension View {
    /// Standard card chrome. Use for any tappable container.
    func wbCard(elevated: Bool = false) -> some View {
        modifier(CardStyle(elevated: elevated))
    }

    /// Standard screen background fill for full-bleed views.
    func wbScreenBackground() -> some View {
        background(Color.bgPrimary.ignoresSafeArea())
    }
}

