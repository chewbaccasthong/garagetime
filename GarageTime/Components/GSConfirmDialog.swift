import SwiftUI

/// Lightweight modal confirmation. Use for delete, complete-quote, etc.
struct GSConfirmDialog: ViewModifier {
    @Binding var isPresented: Bool
    let title: String
    let message: String
    var destructiveTitle: String = "Delete"
    var cancelTitle: String = "Cancel"
    var isDestructive: Bool = true
    var onConfirm: () -> Void

    func body(content: Content) -> some View {
        content
            .confirmationDialog(
                title,
                isPresented: $isPresented,
                titleVisibility: .visible
            ) {
                Button(destructiveTitle, role: isDestructive ? .destructive : nil) {
                    let g = UINotificationFeedbackGenerator()
                    g.notificationOccurred(.warning)
                    onConfirm()
                }
                Button(cancelTitle, role: .cancel) { }
            } message: {
                Text(message)
            }
    }
}

extension View {
    /// Show a destructive confirmation dialog. Usage:
    /// `.confirm(isPresented: $deleting, title: "Delete vehicle?", message: "…") { vm.delete() }`
    func confirm(
        isPresented: Binding<Bool>,
        title: String,
        message: String,
        destructiveTitle: String = "Delete",
        cancelTitle: String = "Cancel",
        isDestructive: Bool = true,
        onConfirm: @escaping () -> Void
    ) -> some View {
        modifier(GSConfirmDialog(
            isPresented: isPresented,
            title: title,
            message: message,
            destructiveTitle: destructiveTitle,
            cancelTitle: cancelTitle,
            isDestructive: isDestructive,
            onConfirm: onConfirm
        ))
    }
}
