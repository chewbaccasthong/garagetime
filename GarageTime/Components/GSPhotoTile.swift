import SwiftUI

/// Thumbnail tile for vehicle / part / receipt photos. Tap to open full-size sheet.
struct GSPhotoTile: View {
    let imageData: Data?
    var size: CGFloat = 88
    var radius: CGFloat = Radius.m
    var placeholderIcon: String = "photo"
    var onTap: (() -> Void)? = nil

    var body: some View {
        Button(action: { onTap?() }) {
            Group {
                if let imageData, let ui = UIImage(data: imageData) {
                    Image(uiImage: ui)
                        .resizable()
                        .scaledToFill()
                } else {
                    ZStack {
                        Color.bgTertiary
                        Image(systemName: placeholderIcon)
                            .font(.system(size: size * 0.34, weight: .light))
                            .foregroundStyle(Color.textTertiary)
                    }
                }
            }
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(Color.dividerColor, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .disabled(onTap == nil)
    }
}
