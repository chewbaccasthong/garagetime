import SwiftUI

/// Customer or vehicle initials avatar bubble. Pre-rendered Data → UIImage if available.
struct GSAvatar: View {
    let initials: String
    var imageData: Data? = nil
    var size: CGFloat = 44
    var role: PaletteRole = .accent

    var body: some View {
        Group {
            if let imageData, let ui = UIImage(data: imageData) {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Circle().fill(background)
                    Text(initials.uppercased())
                        .font(.system(size: size * 0.4, weight: .bold, design: .default))
                        .foregroundStyle(foreground)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(
            Circle().strokeBorder(Color.dividerColor, lineWidth: 0.5)
        )
    }

    private var background: Color {
        switch role {
        case .neutral: return Color.bgTertiary
        case .info:    return Color.statusBlue.opacity(0.22)
        case .success: return Color.statusGreen.opacity(0.22)
        case .warning: return Color.statusAmber.opacity(0.22)
        case .danger:  return Color.statusRed.opacity(0.22)
        case .accent:  return Color.accentPrimary.opacity(0.22)
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
