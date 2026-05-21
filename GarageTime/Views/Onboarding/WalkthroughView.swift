import SwiftUI
import SwiftData

/// A swipeable, role-aware tour of Garage Time's main features. Shown automatically the
/// first time the user lands after onboarding; the user can skip or replay it from
/// More → About.
struct WalkthroughView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var shopSettings: [ShopSettings]

    @State private var index: Int = 0

    var body: some View {
        let steps = currentSteps()
        ZStack {
            Color.bgPrimary.ignoresSafeArea()
            VStack(spacing: Spacing.l) {
                topBar
                TabView(selection: $index) {
                    ForEach(Array(steps.enumerated()), id: \.offset) { i, step in
                        WalkthroughStepView(step: step)
                            .tag(i)
                            .padding(.horizontal, Spacing.l)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: index)

                pageDots(count: steps.count)
                bottomBar(stepCount: steps.count)
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Sub-views

    private var topBar: some View {
        HStack {
            ZStack {
                Circle().fill(Color.accentPrimary.opacity(0.18))
                    .frame(width: 40, height: 40)
                Image(systemName: "wrench.and.screwdriver.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.accentPrimary)
            }
            Text("Garage Time tour")
                .font(.wbHeadline)
                .foregroundStyle(Color.textPrimary)
            Spacer()
            Button("Skip") { finish() }
                .font(.wbCaption)
                .foregroundStyle(Color.textSecondary)
        }
        .padding(.horizontal, Spacing.m)
        .padding(.top, Spacing.m)
    }

    private func pageDots(count: Int) -> some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { i in
                Circle()
                    .fill(i == index ? Color.accentPrimary : Color.dividerColor)
                    .frame(width: 7, height: 7)
            }
        }
    }

    private func bottomBar(stepCount: Int) -> some View {
        HStack(spacing: Spacing.s) {
            if index > 0 {
                GSButton(title: "Back", icon: "chevron.left", style: .secondary) {
                    withAnimation { index -= 1 }
                }
            }
            if index < stepCount - 1 {
                GSButton(title: "Next", trailingIcon: "chevron.right", style: .primary) {
                    HapticsManager.selection()
                    withAnimation { index += 1 }
                }
            } else {
                GSButton(title: "Get started", icon: "checkmark.seal.fill",
                         style: .primary, size: .large) {
                    finish()
                }
            }
        }
        .padding(.horizontal, Spacing.m)
        .padding(.bottom, Spacing.l)
    }

    // MARK: - Step content

    private func currentSteps() -> [WalkthroughStep] {
        let role = shopSettings.first?.role ?? .mechanic
        return role == .mechanic ? Self.mechanicSteps : Self.customerSteps
    }

    static let mechanicSteps: [WalkthroughStep] = [
        WalkthroughStep(
            icon: "car.2.fill",
            title: "Your garage",
            body: "Add every vehicle you work on — personal cars and customer vehicles in one place. Scan a VIN, snap a photo, and you're tracking.",
            cta: "Open Garage"
        ),
        WalkthroughStep(
            icon: "person.2.fill",
            title: "Customers",
            body: "Build a roster of customers with contact info and an at-a-glance view of every vehicle, quote, and dollar billed.",
            cta: "Open Customers"
        ),
        WalkthroughStep(
            icon: "doc.text.fill",
            title: "Quotes & signatures",
            body: "Build line-item quotes — labor, parts, fees, discounts — collect a real signature, and export a branded PDF. The signature shows on the PDF.",
            cta: "Open Quotes"
        ),
        WalkthroughStep(
            icon: "tray.full.fill",
            title: "Job requests",
            body: "When a customer asks for work, it lands in your Jobs tab. Accept, decline, schedule, or convert directly to a quote.",
            cta: "Open Jobs"
        ),
        WalkthroughStep(
            icon: "calendar",
            title: "Your availability",
            body: "Set the days and hours you're open. Customers see this when they ask for an estimate so they don't ping you at 2 a.m.",
            cta: "Set availability"
        ),
        WalkthroughStep(
            icon: "wrench.adjustable.fill",
            title: "Time + cost tracking",
            body: "Every service record captures parts, labor, and time spent — even DIY work. Reports break it all down by category and vehicle.",
            cta: "Try a record"
        ),
        WalkthroughStep(
            icon: "square.and.arrow.down.on.square.fill",
            title: "Bring your history with you",
            body: "Bulk Import (Shop Pro) reads pasted text, scanned receipts, or handwritten log pages and turns them into service records — fast.",
            cta: "Try Bulk Import"
        ),
        WalkthroughStep(
            icon: "checkmark.seal.fill",
            title: "Ready to wrench",
            body: "Tap Get started to dive into your garage. You can replay this tour anytime from More → About.",
            cta: nil
        ),
    ]

    static let customerSteps: [WalkthroughStep] = [
        WalkthroughStep(
            icon: "car.fill",
            title: "Your vehicles",
            body: "Track every car, truck, or motorcycle you drive. Log oil changes, mileage, photos — the whole history in one tap.",
            cta: "Open My Garage"
        ),
        WalkthroughStep(
            icon: "wand.and.stars",
            title: "Get an estimate",
            body: "Wondering what an oil change will cost? Garage Time shows you what your mechanic has historically charged for that job, based on real past work.",
            cta: "Try Estimates"
        ),
        WalkthroughStep(
            icon: "paperplane.fill",
            title: "Request work",
            body: "Send a job request straight to your mechanic with a preferred date and notes. Track its status until it's done.",
            cta: "View Requests"
        ),
        WalkthroughStep(
            icon: "bell.fill",
            title: "Maintenance reminders",
            body: "Pick from preset reminders (oil change, brake fluid, chain lube, more) — Garage Time nudges you before they're due.",
            cta: "Set reminders"
        ),
        WalkthroughStep(
            icon: "eye.slash.fill",
            title: "Partner-friendly amounts",
            body: "Settings → Stealth mode lets you display totals as a fraction of the real number. Long-press any amount to peek at the truth.",
            cta: nil
        ),
        WalkthroughStep(
            icon: "checkmark.seal.fill",
            title: "Ready to wrench",
            body: "Tap Get started. Free covers two vehicles — start a free trial of Plus to unlock unlimited + cloud sync + PDF export.",
            cta: nil
        ),
    ]

    // MARK: - Actions

    private func finish() {
        if let shop = shopSettings.first {
            shop.hasCompletedWalkthrough = true
            shop.updatedAt = Date()
            try? context.save()
        }
        HapticsManager.success()
        dismiss()
    }
}

struct WalkthroughStep: Hashable {
    let icon: String
    let title: String
    let body: String
    let cta: String?
}

private struct WalkthroughStepView: View {
    let step: WalkthroughStep

    var body: some View {
        VStack(spacing: Spacing.l) {
            Spacer(minLength: Spacing.xl)
            ZStack {
                Circle().fill(Color.accentPrimary.opacity(0.16))
                    .frame(width: 156, height: 156)
                Image(systemName: step.icon)
                    .font(.system(size: 70, weight: .regular))
                    .foregroundStyle(Color.accentPrimary)
            }
            VStack(spacing: Spacing.s) {
                Text(step.title)
                    .font(.wbDisplayMedium)
                    .foregroundStyle(Color.textPrimary)
                    .multilineTextAlignment(.center)
                Text(step.body)
                    .font(.wbBody)
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.s)
            }
            Spacer()
        }
    }
}

#Preview {
    WalkthroughView()
        .environment(Backend.preview())
        .modelContainer(PreviewModelContainer.shared)
}
