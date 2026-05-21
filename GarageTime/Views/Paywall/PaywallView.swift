import SwiftUI
import StoreKit
import SwiftData

struct PaywallView: View {
    @Environment(Backend.self) private var backend
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var shops: [ShopSettings]

    @State private var selection: String = Catalog.customerPlusYearly
    @State private var purchasing: Bool = false
    @State private var error: String?
    @State private var trialConfirm: Bool = false

    private var role: UserRole {
        shops.first?.role ?? .customer
    }

    private var shop: ShopSettings? { shops.first }

    /// Tier the local trial grants for this role.
    private var trialTierForRole: SubscriptionTier {
        role == .customer ? .customerPlus : .shopStandard
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.bgPrimary.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: Spacing.l) {
                        hero
                        trialBanner
                        tierCards
                        ctaBlock
                        Spacer(minLength: Spacing.xl)
                        restoreFooter
                    }
                    .padding(Spacing.m)
                }
            }
            .navigationTitle("Upgrade")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
            .onAppear {
                // Default the selection to the most likely product for the user's role.
                selection = (role == .customer) ? Catalog.customerPlusYearly : Catalog.shopStandardYearly
            }
            .confirmationDialog("Start your 7-day free trial?",
                                isPresented: $trialConfirm,
                                titleVisibility: .visible) {
                Button("Start \(trialTierForRole.displayName) trial") {
                    startTrial()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Full access for 7 days. You won't be charged. Pick a plan before the trial ends to keep going.")
            }
        }
    }

    private func startTrial() {
        guard let shop = shop, shop.isTrialAvailable else { return }
        shop.trialStartedAt = Date()
        shop.trialTier = trialTierForRole
        shop.updatedAt = Date()
        try? context.save()
        HapticsManager.success()
        dismiss()
    }

    @ViewBuilder
    private var trialBanner: some View {
        if let shop {
            if shop.isTrialActive {
                trialCard(
                    title: "Trial active",
                    body: "\(shop.trialDaysRemaining) day\(shop.trialDaysRemaining == 1 ? "" : "s") left of \(shop.trialTier?.displayName ?? "Plus"). Pick a plan below to continue when it ends.",
                    icon: "checkmark.seal.fill",
                    accent: true,
                    cta: nil
                )
            } else if shop.isTrialAvailable {
                trialCard(
                    title: "Try \(trialTierForRole.displayName) free for 7 days",
                    body: "Full access to every feature. No charge today. Cancel any time — the trial ends automatically.",
                    icon: "gift.fill",
                    accent: true,
                    cta: "Start free trial"
                ) { trialConfirm = true }
            } else if shop.isTrialExpired {
                trialCard(
                    title: "Your trial has ended",
                    body: "Pick a plan to keep your unlimited access. Your data is safe either way.",
                    icon: "hourglass.bottomhalf.filled",
                    accent: false,
                    cta: nil
                )
            }
        }
    }

    @ViewBuilder
    private func trialCard(title: String, body: String, icon: String,
                           accent: Bool, cta: String?,
                           action: (() -> Void)? = nil) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            HStack(spacing: Spacing.s) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(accent ? Color.accentPrimary : Color.textSecondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.wbHeadline)
                        .foregroundStyle(Color.textPrimary)
                    Text(body)
                        .font(.wbCaption)
                        .foregroundStyle(Color.textSecondary)
                }
            }
            if let cta, let action {
                GSButton(title: cta, icon: "gift.fill", style: .primary, action: action)
            }
        }
        .padding(Spacing.m)
        .background(
            RoundedRectangle(cornerRadius: Radius.l, style: .continuous)
                .fill(accent ? Color.accentPrimary.opacity(0.12) : Color.bgSecondary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.l, style: .continuous)
                .strokeBorder(accent ? Color.accentPrimary : Color.dividerColor,
                              lineWidth: accent ? 1.5 : 0.5)
        )
    }

    private var hero: some View {
        VStack(spacing: Spacing.s) {
            ZStack {
                Circle().fill(Color.accentPrimary.opacity(0.16)).frame(width: 96, height: 96)
                Image(systemName: "wrench.and.screwdriver.fill")
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundStyle(Color.accentPrimary)
            }
            Text(role == .customer ? "Track everything you drive" : "Run your one-person shop")
                .font(.wbDisplayMedium)
                .foregroundStyle(Color.textPrimary)
                .multilineTextAlignment(.center)
            Text(role == .customer
                 ? "Free plan covers two vehicles. Unlock unlimited vehicles + PDF export + cloud sync to never lose a record again."
                 : "Shop tier handles unlimited customers, vehicles, quotes, and jobs. Shop Pro adds advanced reports, bulk import, and custom branding.")
                .font(.wbBody)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.textSecondary)
                .padding(.horizontal, Spacing.l)
        }
        .padding(.top, Spacing.l)
    }

    @ViewBuilder
    private var tierCards: some View {
        if role == .customer {
            customerCards
        } else {
            mechanicCards
        }
    }

    private var customerCards: some View {
        VStack(spacing: Spacing.s) {
            tierCard(
                id: Catalog.customerPlusYearly,
                title: "Plus · Yearly",
                price: backend.store.products[Catalog.customerPlusYearly]?.displayPrice ?? "$39.99 / yr",
                subtitle: "Unlimited vehicles · PDFs · OCR · iCloud sync · job requests · all features",
                badge: "Best value"
            )
            tierCard(
                id: Catalog.customerPlusMonthly,
                title: "Plus · Monthly",
                price: backend.store.products[Catalog.customerPlusMonthly]?.displayPrice ?? "$4.99 / mo",
                subtitle: "All Plus features, billed monthly",
                badge: nil
            )
            Divider().background(Color.dividerColor).padding(.vertical, Spacing.xs)
            Text("Or just add slots")
                .font(.wbCaption)
                .foregroundStyle(Color.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            tierCard(
                id: Catalog.vehiclePack3,
                title: "+3 Vehicle Slots",
                price: backend.store.products[Catalog.vehiclePack3]?.displayPrice ?? "$4.99 once",
                subtitle: "Stay on Free, add 3 more vehicles to your garage. One-time.",
                badge: nil
            )
            tierCard(
                id: Catalog.vehiclePack10,
                title: "+10 Vehicle Slots",
                price: backend.store.products[Catalog.vehiclePack10]?.displayPrice ?? "$12.99 once",
                subtitle: "Family fleet or hobbyist collection. One-time.",
                badge: nil
            )
        }
    }

    private var mechanicCards: some View {
        VStack(spacing: Spacing.s) {
            tierCard(
                id: Catalog.shopStandardYearly,
                title: "Shop · Yearly",
                price: backend.store.products[Catalog.shopStandardYearly]?.displayPrice ?? "$249 / yr",
                subtitle: "Unlimited customers, vehicles, quotes, jobs, signatures, branded PDFs.",
                badge: "Most popular"
            )
            tierCard(
                id: Catalog.shopStandardMonthly,
                title: "Shop · Monthly",
                price: backend.store.products[Catalog.shopStandardMonthly]?.displayPrice ?? "$29.99 / mo",
                subtitle: "All Shop features, billed monthly",
                badge: nil
            )
            Divider().background(Color.dividerColor).padding(.vertical, Spacing.xs)
            tierCard(
                id: Catalog.shopProYearly,
                title: "Shop Pro · Yearly",
                price: backend.store.products[Catalog.shopProYearly]?.displayPrice ?? "$499 / yr",
                subtitle: "Shop + Bulk import (paste/OCR/handwriting) · advanced reports · custom branding · priority support",
                badge: "For growing shops"
            )
            tierCard(
                id: Catalog.shopProMonthly,
                title: "Shop Pro · Monthly",
                price: backend.store.products[Catalog.shopProMonthly]?.displayPrice ?? "$59.99 / mo",
                subtitle: "All Pro features, billed monthly",
                badge: nil
            )
        }
    }

    private func tierCard(id: String, title: String, price: String, subtitle: String, badge: String?) -> some View {
        let isSelected = selection == id
        return Button {
            HapticsManager.selection()
            withAnimation(Motion.snap) { selection = id }
        } label: {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack {
                    Text(title)
                        .font(.wbHeadline)
                        .foregroundStyle(Color.textPrimary)
                    Spacer()
                    if let badge {
                        GSStatusPill(text: badge, role: .accent, compact: true)
                    }
                }
                Text(price)
                    .font(.wbDisplayMedium)
                    .foregroundStyle(Color.accentPrimary)
                    .padding(.top, 2)
                Text(subtitle)
                    .font(.wbCaption)
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.m)
            .background(
                RoundedRectangle(cornerRadius: Radius.l, style: .continuous)
                    .fill(Color.bgSecondary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.l, style: .continuous)
                    .strokeBorder(isSelected ? Color.accentPrimary : Color.dividerColor,
                                  lineWidth: isSelected ? 2 : 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    private var ctaBlock: some View {
        VStack(spacing: Spacing.xs) {
            GSButton(
                title: ctaTitle,
                icon: "checkmark.seal.fill",
                style: .primary,
                size: .large,
                isLoading: purchasing
            ) {
                Task { await purchase() }
            }
            if let error {
                Text(error)
                    .font(.wbCaption)
                    .foregroundStyle(Color.statusRed)
            }
            Text("Subscriptions auto-renew unless canceled at least 24 hours before period ends. Manage in Settings → Apple ID → Subscriptions.")
                .font(.wbCaptionSmall)
                .foregroundStyle(Color.textTertiary)
                .multilineTextAlignment(.center)
        }
    }

    private var ctaTitle: String {
        if selection == Catalog.vehiclePack3 || selection == Catalog.vehiclePack10 {
            return "Buy slots"
        }
        return "Subscribe"
    }

    private var restoreFooter: some View {
        VStack(spacing: Spacing.xs) {
            Button("Restore Purchases") {
                Task { await backend.store.restore() }
            }
            .font(.wbCaption)
            .foregroundStyle(Color.accentPrimary)

            HStack(spacing: Spacing.s) {
                Link("Terms", destination: URL(string: "https://chewbaccasthong.github.io/garagetime/#terms")!)
                Link("Privacy", destination: URL(string: "https://chewbaccasthong.github.io/garagetime/#privacy")!)
            }
            .font(.wbCaptionSmall)
            .foregroundStyle(Color.textTertiary)
        }
    }

    private func purchase() async {
        purchasing = true
        error = nil
        defer { purchasing = false }
        do {
            let success = try await backend.store.purchase(selection)
            if success {
                HapticsManager.success()
                dismiss()
            }
        } catch {
            self.error = error.localizedDescription
            HapticsManager.error()
        }
    }
}

#Preview {
    PaywallView()
        .environment(Backend.preview())
        .modelContainer(PreviewModelContainer.shared)
}
