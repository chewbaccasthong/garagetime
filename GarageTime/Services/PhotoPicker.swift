import SwiftUI
import PhotosUI

/// SwiftUI-wrappable photo picker. Returns single `Data` (PNG/JPEG) once picked.
struct PhotoPickerButton<Label: View>: View {
    @Binding var imageData: Data?
    var compressionQuality: CGFloat = 0.8
    var matchSubject: PHPickerFilter? = .images
    @ViewBuilder let label: () -> Label

    @State private var selection: PhotosPickerItem?

    var body: some View {
        PhotosPicker(selection: $selection, matching: matchSubject, photoLibrary: .shared()) {
            label()
        }
        .onChange(of: selection) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let ui = UIImage(data: data),
                   let resized = ui.scaled(maxDimension: 1600)?.jpegData(compressionQuality: compressionQuality) {
                    imageData = resized
                }
            }
        }
    }
}

private extension UIImage {
    /// Scale the image down so its longest side is `maxDimension`. Returns nil if no scaling needed.
    func scaled(maxDimension: CGFloat) -> UIImage? {
        let longest = max(size.width, size.height)
        guard longest > maxDimension else { return self }
        let scale = maxDimension / longest
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
