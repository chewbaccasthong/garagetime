import SwiftUI
#if canImport(PencilKit)
import PencilKit
#endif

/// SwiftUI wrapper around PencilKit's `PKCanvasView`. Returns the underlying drawing data.
struct SignaturePadView: UIViewRepresentable {
    @Binding var drawingData: Data

    func makeUIView(context: Context) -> UIView {
        #if canImport(PencilKit)
        let canvas = PKCanvasView()
        canvas.drawingPolicy = .anyInput
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.tool = PKInkingTool(.pen, color: .black, width: 4)
        canvas.delegate = context.coordinator
        context.coordinator.canvas = canvas
        if !drawingData.isEmpty, let drawing = try? PKDrawing(data: drawingData) {
            canvas.drawing = drawing
        }
        return canvas
        #else
        return UIView()
        #endif
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        #if canImport(PencilKit)
        guard let canvas = uiView as? PKCanvasView else { return }
        if !drawingData.isEmpty, canvas.drawing.dataRepresentation() != drawingData {
            if let drawing = try? PKDrawing(data: drawingData) {
                canvas.drawing = drawing
            }
        }
        #endif
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    final class Coordinator: NSObject {
        let parent: SignaturePadView
        #if canImport(PencilKit)
        weak var canvas: PKCanvasView?
        #endif

        init(parent: SignaturePadView) {
            self.parent = parent
        }
    }
}

#if canImport(PencilKit)
extension SignaturePadView.Coordinator: PKCanvasViewDelegate {
    func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
        parent.drawingData = canvasView.drawing.dataRepresentation()
    }
}
#endif
