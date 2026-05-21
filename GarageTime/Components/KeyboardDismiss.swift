import SwiftUI
import UIKit

/// Hides the active keyboard.
func hideKeyboard() {
    UIApplication.shared.sendAction(
        #selector(UIResponder.resignFirstResponder),
        to: nil, from: nil, for: nil
    )
}

extension View {
    /// Make the entire view tappable to dismiss the keyboard. Use sparingly — interferes
    /// with TabView/List gestures. Best applied to background or to non-interactive areas
    /// of a Form.
    func tapToDismissKeyboard() -> some View {
        modifier(TapToDismissKeyboard())
    }

    /// Standard text-editing affordances for every screen with input:
    /// 1. Scroll-to-dismiss (drag the keyboard down by pulling content)
    /// 2. A "Done" button in the keyboard toolbar (so you can tap once to close).
    /// Apply to your Form / ScrollView.
    func wbDismissibleKeyboard() -> some View {
        self
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { hideKeyboard() }
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.accentPrimary)
                }
            }
    }
}

private struct TapToDismissKeyboard: ViewModifier {
    func body(content: Content) -> some View {
        // `simultaneousGesture` so child buttons/links still receive their taps.
        content.simultaneousGesture(
            TapGesture().onEnded { _ in
                hideKeyboard()
            }
        )
    }
}
