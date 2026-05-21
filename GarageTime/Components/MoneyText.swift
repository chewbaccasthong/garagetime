import SwiftUI

/// Renders a money amount with optional stealth-mode dimming. Long-press to peek at
/// the real number when stealth is on (visual only — the underlying value never changes).
///
/// Use this for any list/stat/header that a partner might see. For editors, PDFs, and
/// receipts use `Text(Money.realCost(value))` directly so the actual figure is shown.
struct MoneyText: View {
    let value: Double
    var font: Font = .wbMonoBody
    var color: Color = .textPrimary

    @State private var revealing: Bool = false
    @AppStorage("wb.stealth.enabled") private var stealthEnabled: Bool = false

    var body: some View {
        HStack(spacing: 4) {
            Text(revealing ? Money.realCost(value) : Money.displayCost(value))
                .font(font)
                .foregroundStyle(color)
                .contentTransition(.numericText())
                .animation(.easeInOut(duration: 0.18), value: revealing)
            if stealthEnabled {
                Image(systemName: revealing ? "eye.fill" : "eye.slash.fill")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Color.textTertiary)
            }
        }
        .onLongPressGesture(minimumDuration: 0.25, pressing: { isPressed in
            withAnimation(.easeInOut(duration: 0.18)) {
                revealing = isPressed
            }
            if isPressed { HapticsManager.selection() }
        }, perform: {})
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 12) {
        MoneyText(value: 712.50)
        MoneyText(value: 48.99, font: .wbBody, color: .accentPrimary)
        Text("Long-press a value to peek at the real number.")
            .font(.wbCaptionSmall)
            .foregroundStyle(.gray)
    }
    .padding()
    .wbScreenBackground()
}
