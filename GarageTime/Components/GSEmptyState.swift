import SwiftUI

/// Empty / zero-state for any list. Big SF Symbol, title, optional body, optional CTA.
struct GSEmptyState: View {
    let icon: String
    let title: String
    var message: String? = nil
    var ctaTitle: String? = nil
    var ctaIcon: String? = nil
    var ctaAction: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: Spacing.m) {
            ZStack {
                Circle()
                    .fill(Color.accentPrimary.opacity(0.12))
                    .frame(width: 88, height: 88)
                Image(systemName: icon)
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(Color.accentPrimary)
            }
            VStack(spacing: Spacing.xs) {
                Text(title)
                    .font(.wbTitle)
                    .foregroundStyle(Color.textPrimary)
                    .multilineTextAlignment(.center)
                if let message {
                    Text(message)
                        .font(.wbBody)
                        .foregroundStyle(Color.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Spacing.l)
                }
            }
            if let ctaTitle, let ctaAction {
                GSButton(
                    title: ctaTitle,
                    icon: ctaIcon,
                    style: .primary,
                    fullWidth: false,
                    action: ctaAction
                )
                .padding(.top, Spacing.xs)
            }
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
