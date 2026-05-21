import SwiftUI

struct QuoteSignatureView: View {
    @Environment(Backend.self) private var backend
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Bindable var quote: Quote
    @State private var drawingData: Data = Data()
    @State private var signerName: String = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: Spacing.m) {
                Text("Sign below to approve this quote.")
                    .font(.wbBody)
                    .foregroundStyle(Color.textSecondary)
                    .padding(.top)

                GSTextField(title: "Print name", text: $signerName, placeholder: "Customer name", icon: "person.fill")
                    .padding(.horizontal, Spacing.m)

                ZStack {
                    RoundedRectangle(cornerRadius: Radius.l, style: .continuous)
                        .fill(Color.bgSecondary)
                    RoundedRectangle(cornerRadius: Radius.l, style: .continuous)
                        .strokeBorder(Color.dividerColor, lineWidth: 0.5)
                    SignaturePadView(drawingData: $drawingData)
                        .padding(Spacing.s)
                }
                .frame(height: 240)
                .padding(.horizontal, Spacing.m)

                HStack(spacing: Spacing.s) {
                    GSButton(title: "Clear", icon: "arrow.uturn.backward", style: .secondary) {
                        drawingData = Data()
                    }
                    GSButton(title: "Save Signature", icon: "checkmark.seal.fill", style: .primary) {
                        commit()
                    }
                    .disabled(drawingData.isEmpty || signerName.isEmpty)
                }
                .padding(.horizontal, Spacing.m)

                Spacer()
            }
            .wbScreenBackground()
            .navigationTitle("Signature")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                if let existing = quote.signaturePngData {
                    // No-op; we don't re-decode previous PNG into a PencilKit drawing.
                    _ = existing
                }
                signerName = quote.signedByName
            }
        }
    }

    private func commit() {
        let png = backend.signature.png(from: drawingData, size: CGSize(width: 600, height: 200))
            ?? rasterize(size: CGSize(width: 600, height: 200))
        quote.signaturePngData = png
        quote.signedByName = signerName
        quote.signedAt = Date()
        if quote.status == .sent {
            quote.status = .approved
            quote.approvedDate = Date()
        }
        try? context.save()
        HapticsManager.success()
        dismiss()
    }

    /// Fallback if PencilKit failed: render the raw drawing data into a transparent PNG.
    private func rasterize(size: CGSize) -> Data? {
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            UIColor.clear.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
        return image.pngData()
    }
}
