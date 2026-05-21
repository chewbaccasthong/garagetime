import SwiftUI

/// Horizontal progress bar used for reminders. Colors change based on progress value.
struct GSProgressBar: View {
    let progress: Double      // 0…1 (can exceed 1.0 to show overshoot)
    var role: PaletteRole = .neutral
    var height: CGFloat = 8

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.bgTertiary)
                Capsule()
                    .fill(fillColor)
                    .frame(width: max(2, min(geo.size.width, geo.size.width * progress)))
            }
        }
        .frame(height: height)
    }

    private var fillColor: Color {
        if progress >= 1.0 { return .statusRed }
        if progress >= 0.85 { return .statusAmber }
        switch role {
        case .success: return .statusGreen
        case .warning: return .statusAmber
        case .danger:  return .statusRed
        case .info:    return .statusBlue
        case .accent:  return .accentPrimary
        case .neutral: return .statusGreen
        }
    }
}
