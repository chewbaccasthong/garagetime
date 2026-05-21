import SwiftUI

/// Themed text field with optional leading icon and label.
struct GSTextField: View {
    let title: String
    @Binding var text: String
    var placeholder: String = ""
    var icon: String? = nil
    var keyboard: UIKeyboardType = .default
    var textContentType: UITextContentType? = nil
    var autocapitalization: TextInputAutocapitalization = .sentences
    var disableAutocorrection: Bool = false
    var isSecure: Bool = false
    var monospaced: Bool = false
    var errorText: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            if !title.isEmpty {
                Text(title)
                    .font(.wbCaption)
                    .foregroundStyle(Color.textSecondary)
            }
            HStack(spacing: Spacing.xs) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.textTertiary)
                        .frame(width: 16)
                }
                Group {
                    if isSecure {
                        SecureField(placeholder, text: $text)
                    } else {
                        TextField(placeholder, text: $text)
                    }
                }
                .font(monospaced ? .wbMonoBody : .wbBody)
                .foregroundStyle(Color.textPrimary)
                .keyboardType(keyboard)
                .textInputAutocapitalization(autocapitalization)
                .autocorrectionDisabled(disableAutocorrection)
                .textContentType(textContentType)
            }
            .padding(.horizontal, Spacing.m)
            .padding(.vertical, Spacing.s)
            .background(
                RoundedRectangle(cornerRadius: Radius.m, style: .continuous)
                    .fill(Color.bgTertiary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.m, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: 0.5)
            )
            if let errorText, !errorText.isEmpty {
                Text(errorText)
                    .font(.wbCaptionSmall)
                    .foregroundStyle(Color.statusRed)
            }
        }
    }

    private var borderColor: Color {
        errorText?.isEmpty == false ? .statusRed : .dividerColor
    }
}

/// Themed multi-line editor (no border on TextEditor by default — we provide one).
struct GSTextEditor: View {
    let title: String
    @Binding var text: String
    var placeholder: String = ""
    var minHeight: CGFloat = 100

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            if !title.isEmpty {
                Text(title)
                    .font(.wbCaption)
                    .foregroundStyle(Color.textSecondary)
            }
            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text(placeholder)
                        .font(.wbBody)
                        .foregroundStyle(Color.textTertiary)
                        .padding(Spacing.s + 2)
                }
                TextEditor(text: $text)
                    .font(.wbBody)
                    .foregroundStyle(Color.textPrimary)
                    .scrollContentBackground(.hidden)
                    .padding(Spacing.xs)
                    .frame(minHeight: minHeight, alignment: .topLeading)
            }
            .background(
                RoundedRectangle(cornerRadius: Radius.m, style: .continuous)
                    .fill(Color.bgTertiary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.m, style: .continuous)
                    .strokeBorder(Color.dividerColor, lineWidth: 0.5)
            )
        }
    }
}

/// Numeric field — Decimal-backed via String binding.
struct GSNumberField: View {
    let title: String
    @Binding var value: Double
    var icon: String? = nil
    var allowsDecimal: Bool = true
    var placeholder: String = "0"

    @State private var displayText: String = ""

    var body: some View {
        GSTextField(
            title: title,
            text: Binding(
                get: { displayText },
                set: { newValue in
                    displayText = newValue
                    if let parsed = parse(newValue) { value = parsed }
                }
            ),
            placeholder: placeholder,
            icon: icon,
            keyboard: allowsDecimal ? .decimalPad : .numberPad
        )
        .onAppear {
            if value != 0 { displayText = format(value) }
        }
        .onChange(of: value) { _, newValue in
            if displayText.isEmpty && newValue == 0 { return }
            if let parsed = parse(displayText), parsed == newValue { return }
            displayText = format(newValue)
        }
    }

    private func parse(_ s: String) -> Double? {
        let cleaned = s.replacingOccurrences(of: ",", with: ".")
        return Double(cleaned)
    }

    private func format(_ d: Double) -> String {
        if allowsDecimal {
            return String(format: "%g", d)
        } else {
            return String(Int(d))
        }
    }
}
