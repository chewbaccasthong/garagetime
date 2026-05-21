import Foundation
import SwiftData

/// One row per install. Created on first launch if absent. Customer-facing PDFs read from this.
@Model
final class ShopSettings {
    var id: UUID = UUID()
    var businessName: String = ""
    var ownerName: String = ""
    var addressLine1: String = ""
    var addressLine2: String = ""
    var city: String = ""
    var state: String = ""
    var zip: String = ""
    var phone: String = ""
    var email: String = ""
    var website: String = ""

    @Attribute(.externalStorage) var logoData: Data?

    var defaultLaborRate: Double = 90
    var defaultTaxRate: Double = 0           // 0.0875 for 8.75%
    var currencyCode: String = "USD"
    var mileageUnitRaw: String = MileageUnit.mi.rawValue

    var quoteNumberPrefix: String = "Q"
    var quoteNumberStart: Int = 1            // sequence start
    var quoteNumberLastUsed: Int = 0         // latest assigned
    var quoteValidDays: Int = 30

    var quoteTerms: String = "Quote valid for 30 days from issue date. 50% deposit required to schedule. Final pricing subject to change after diagnostic inspection."
    var paymentInstructions: String = "Payment due upon completion. Cash, Venmo, Zelle, or major credit card accepted."

    var accentColorHex: String = "#FF6B35"

    // MARK: - Role + "me" identity

    /// Which experience the app shows. Picked once at onboarding, switchable in Settings.
    /// nil = onboarding not yet complete.
    var roleRaw: String?

    /// When role == .customer, the `Customer` record that represents the app user.
    /// Linked so requested jobs can be attributed to "me".
    var meCustomer: Customer?

    /// When role == .mechanic, the mechanic's public-facing display name (defaults to ownerName).
    /// Used in customer-mode UI ("My mechanic: Henry G.")
    var mechanicDisplayName: String = ""

    /// True once onboarding has been completed at least once. Lets us re-show onboarding
    /// after fresh installs without nuking user-set fields.
    var hasCompletedOnboarding: Bool = false

    /// True once the walkthrough tour has been completed (or explicitly skipped).
    var hasCompletedWalkthrough: Bool = false

    /// When the local 7-day trial was started. Nil = never started.
    /// Independent of StoreKit so we can demo without intro pricing configured;
    /// on production launch a successful subscription supersedes this.
    var trialStartedAt: Date?

    /// The tier granted while the trial is active (e.g. `customerPlus` or `shopStandard`).
    var trialTierRaw: String?

    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init() {}
}

extension ShopSettings {
    var mileageUnit: MileageUnit {
        get { MileageUnit(rawValue: mileageUnitRaw) ?? .mi }
        set { mileageUnitRaw = newValue.rawValue }
    }

    /// Active role. Nil until onboarding completes; UI treats nil as "show onboarding".
    var role: UserRole? {
        get { roleRaw.flatMap(UserRole.init(rawValue:)) }
        set { roleRaw = newValue?.rawValue }
    }

    /// Convenience: name shown to a customer for their mechanic. Falls back to ownerName/businessName.
    var resolvedMechanicName: String {
        if !mechanicDisplayName.isEmpty { return mechanicDisplayName }
        if !ownerName.isEmpty { return ownerName }
        if !businessName.isEmpty { return businessName }
        return "your mechanic"
    }

    // MARK: - Trial

    /// Local 7-day trial length.
    static let trialDays: Int = 7

    var trialTier: SubscriptionTier? {
        get { trialTierRaw.flatMap(SubscriptionTier.init(rawValue:)) }
        set { trialTierRaw = newValue?.rawValue }
    }

    /// True if the user is currently inside their 7-day trial window.
    var isTrialActive: Bool {
        guard let start = trialStartedAt else { return false }
        return Date().timeIntervalSince(start) < Double(Self.trialDays) * 86_400
    }

    /// Whole days remaining in the trial (rounded up). 0 once expired or never started.
    var trialDaysRemaining: Int {
        guard let start = trialStartedAt else { return 0 }
        let elapsed = Date().timeIntervalSince(start)
        let remaining = Double(Self.trialDays) * 86_400 - elapsed
        if remaining <= 0 { return 0 }
        return max(1, Int(ceil(remaining / 86_400)))
    }

    /// True once the trial has been started AND has now ended.
    var isTrialExpired: Bool {
        trialStartedAt != nil && !isTrialActive
    }

    /// True if a trial has never been started — show the "Start free trial" CTA.
    var isTrialAvailable: Bool {
        trialStartedAt == nil
    }

    /// Single-line "City, State ZIP" used in PDF headers.
    var cityStateZip: String {
        [city, state, zip].filter { !$0.isEmpty }.joined(separator: ", ")
    }

    /// "Smith Auto · Smith St · Anywhere, ST 00000" for compact display.
    var compactAddress: String {
        let lines = [businessName, addressLine1, cityStateZip, phone].filter { !$0.isEmpty }
        return lines.joined(separator: " · ")
    }

    /// Next quote number that QuoteNumberService would assign.
    var nextQuoteNumber: String {
        let year = Calendar.current.component(.year, from: Date())
        let next = max(quoteNumberStart, quoteNumberLastUsed + 1)
        return String(format: "%@-%04d-%04d", quoteNumberPrefix, year, next)
    }
}
