import Foundation
#if canImport(UIKit) && canImport(PencilKit)
import UIKit
import PencilKit
#endif

/// Renders a `PKDrawing` (or fallback) to a transparent PNG. Used by `QuoteSignatureView`.
protocol SignatureRendering: Sendable {
    /// Returns PNG `Data` representing a signature, sized to the given bounds.
    func png(from drawingData: Data, size: CGSize) -> Data?
}

struct RealSignatureService: SignatureRendering {
    func png(from drawingData: Data, size: CGSize) -> Data? {
        #if canImport(UIKit) && canImport(PencilKit)
        guard let drawing = try? PKDrawing(data: drawingData) else { return nil }
        let bounds = CGRect(origin: .zero, size: size)
        // Render at 2x — high enough for a quote PDF, no need to bounce to main actor for UIScreen.
        let image = drawing.image(from: bounds, scale: 2.0)
        return image.pngData()
        #else
        return nil
        #endif
    }
}

final class InMemorySignatureService: SignatureRendering, @unchecked Sendable {
    var fixedPNG: Data?
    init(_ fixedPNG: Data? = nil) { self.fixedPNG = fixedPNG }
    func png(from drawingData: Data, size: CGSize) -> Data? { fixedPNG }
}
