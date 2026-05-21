import Foundation
import StoreKit

/// Subscription / one-shot product IDs, mirrored 1:1 with App Store Connect catalog.
///
/// Two product families:
///   - Customer products (consumer side): Plus subscription, optional vehicle-pack one-times
///   - Mechanic products (pro side): Standard + Pro subscriptions
///
/// Pricing intent (USD):
///   - customer.plus.monthly         $4.99/mo     unlimited vehicles + full features
///   - customer.plus.yearly          $39.99/yr    "
///   - customer.vehiclePack3         $4.99 once   +3 vehicle slots (non-consumable)
///   - customer.vehiclePack10        $12.99 once  +10 vehicle slots (non-consumable)
///   - shop.standard.monthly         $29.99/mo    unlimited customers, vehicles, quotes, jobs
///   - shop.standard.yearly          $249/yr      "
///   - shop.pro.monthly              $59.99/mo    standard + advanced reports, custom branding,
///                                                  bulk import, priority support
///   - shop.pro.yearly               $499/yr      "
enum Catalog {
    static let customerPlusMonthly  = "com.henrygawelek.garagetime.customer.plus.monthly"
    static let customerPlusYearly   = "com.henrygawelek.garagetime.customer.plus.yearly"
    static let vehiclePack3         = "com.henrygawelek.garagetime.customer.vehiclePack3"
    static let vehiclePack10        = "com.henrygawelek.garagetime.customer.vehiclePack10"
    static let shopStandardMonthly  = "com.henrygawelek.garagetime.shop.standard.monthly"
    static let shopStandardYearly   = "com.henrygawelek.garagetime.shop.standard.yearly"
    static let shopProMonthly       = "com.henrygawelek.garagetime.shop.pro.monthly"
    static let shopProYearly        = "com.henrygawelek.garagetime.shop.pro.yearly"

    static let allProductIDs: [String] = [
        customerPlusMonthly, customerPlusYearly,
        vehiclePack3, vehiclePack10,
        shopStandardMonthly, shopStandardYearly,
        shopProMonthly, shopProYearly,
    ]

    /// Slot bonus per vehicle-pack product. `0` for subscriptions.
    static func vehicleSlots(for productID: String) -> Int {
        switch productID {
        case vehiclePack3: return 3
        case vehiclePack10: return 10
        default: return 0
        }
    }
}

enum SubscriptionTier: String, Codable, Sendable, CaseIterable {
    case free
    case customerPlus
    case shopStandard
    case shopPro

    var displayName: String {
        switch self {
        case .free:         return "Free"
        case .customerPlus: return "Plus"
        case .shopStandard: return "Shop"
        case .shopPro:      return "Shop Pro"
        }
    }

    /// True if this tier represents a paying mechanic (Shop family).
    var isMechanicTier: Bool {
        self == .shopStandard || self == .shopPro
    }

    /// True if this tier represents a paying customer.
    var isPayingCustomer: Bool {
        self == .customerPlus
    }
}

/// Entitlements derived from active StoreKit transactions.
struct Entitlements: Sendable, Equatable {
    var tier: SubscriptionTier
    var activeProductIDs: Set<String>

    /// Vehicle-slot bonus from purchased packs (above the tier's base allowance).
    /// Customers see this added to the free 2-vehicle base.
    var extraVehicleSlots: Int {
        activeProductIDs.reduce(0) { $0 + Catalog.vehicleSlots(for: $1) }
    }

    static let free = Entitlements(tier: .free, activeProductIDs: [])
}

protocol StoreVending: AnyObject {
    @MainActor var entitlements: Entitlements { get }
    @MainActor var products: [String: Product] { get }
    @MainActor func bootstrap() async
    @MainActor func purchase(_ productID: String) async throws -> Bool
    @MainActor func restore() async
}

/// One source of truth for trial-aware entitlements. Layered on top of any `StoreVending`
/// so a real StoreKit purchase always wins; the trial is the fallback that grants the
/// tier without payment for `trialDays`.
@MainActor
enum TrialEntitlement {
    /// The active entitlements taking the trial into account.
    /// If a real subscription is active, returns store entitlements unchanged.
    static func resolve(store: any StoreVending, settings: ShopSettings?) -> Entitlements {
        let base = store.entitlements
        // Real subscription beats trial.
        if base.tier != .free { return base }
        // Trial active? Promote tier.
        guard let settings, settings.isTrialActive, let trialTier = settings.trialTier else {
            return base
        }
        return Entitlements(tier: trialTier, activeProductIDs: base.activeProductIDs)
    }
}

@MainActor
@Observable
final class RealStoreService: StoreVending {
    private(set) var entitlements: Entitlements = .free
    private(set) var products: [String: Product] = [:]
    private var transactionsTask: Task<Void, Never>?

    func bootstrap() async {
        if transactionsTask == nil {
            transactionsTask = Task.detached(priority: .background) { [weak self] in
                for await result in Transaction.updates {
                    if case .verified(let txn) = result {
                        await txn.finish()
                        await self?.refreshEntitlements()
                    }
                }
            }
        }
        await loadProducts()
        await refreshEntitlements()
    }

    #if DEBUG
    /// Force a tier in DEBUG builds. Reads `DebugTierOverride.current`.
    /// On first launch in DEBUG, defaults to `.shop` so the developer / beta tester
    /// gets full access without going through StoreKit Configuration.
    func applyDebugTier(_ tier: SubscriptionTier) {
        DebugTierOverride.current = tier
        let synthetic: Set<String>
        switch tier {
        case .free:         synthetic = []
        case .customerPlus: synthetic = [Catalog.customerPlusYearly]
        case .shopStandard: synthetic = [Catalog.shopStandardYearly]
        case .shopPro:      synthetic = [Catalog.shopProYearly]
        }
        self.entitlements = Entitlements(tier: tier, activeProductIDs: synthetic)
    }
    #endif

    private func loadProducts() async {
        guard let loaded = try? await Product.products(for: Catalog.allProductIDs) else { return }
        var dict: [String: Product] = [:]
        for p in loaded { dict[p.id] = p }
        self.products = dict
    }

    func purchase(_ productID: String) async throws -> Bool {
        guard let product = products[productID] else { return false }
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            if case .verified(let txn) = verification {
                await txn.finish()
                await refreshEntitlements()
                return true
            }
            return false
        case .userCancelled, .pending:
            return false
        @unknown default:
            return false
        }
    }

    func restore() async {
        try? await AppStore.sync()
        await refreshEntitlements()
    }

    private func refreshEntitlements() async {
        #if DEBUG
        // If a debug override is set, honor it and short-circuit real StoreKit lookup.
        if let override = DebugTierOverride.current {
            applyDebugTier(override)
            return
        }
        #endif
        var active: Set<String> = []
        for await result in Transaction.currentEntitlements {
            if case .verified(let txn) = result {
                active.insert(txn.productID)
            }
        }
        let tier = tier(from: active)
        self.entitlements = Entitlements(tier: tier, activeProductIDs: active)
    }

    private func tier(from active: Set<String>) -> SubscriptionTier {
        if active.contains(Catalog.shopProMonthly) || active.contains(Catalog.shopProYearly) {
            return .shopPro
        }
        if active.contains(Catalog.shopStandardMonthly) || active.contains(Catalog.shopStandardYearly) {
            return .shopStandard
        }
        if active.contains(Catalog.customerPlusMonthly) || active.contains(Catalog.customerPlusYearly) {
            return .customerPlus
        }
        return .free
    }
}

/// In-memory store driven by tests or previews. Set `entitlements` directly.
@MainActor
@Observable
final class InMemoryStoreService: StoreVending {
    var entitlements: Entitlements = .free
    var products: [String: Product] = [:]
    var purchaseHandler: (String) -> Bool = { _ in true }

    func bootstrap() async {}

    func purchase(_ productID: String) async throws -> Bool {
        if purchaseHandler(productID) {
            entitlements = Entitlements(
                tier: tier(from: productID),
                activeProductIDs: entitlements.activeProductIDs.union([productID])
            )
            return true
        }
        return false
    }

    func restore() async {}

    private func tier(from productID: String) -> SubscriptionTier {
        if productID.contains(".shop.pro.")      { return .shopPro }
        if productID.contains(".shop.standard.") { return .shopStandard }
        if productID.contains(".customer.plus.") { return .customerPlus }
        return .free
    }
}

#if DEBUG
/// DEBUG-only persistent override. Stripped from Release builds.
/// On first launch we default the override to `.shopPro` so the dev / beta tester
/// has full access without configuring a StoreKit Configuration file.
enum DebugTierOverride {
    private static let key = "wb.debug.tierOverride"

    static var current: SubscriptionTier? {
        get {
            let defaults = UserDefaults.standard
            if defaults.object(forKey: key) == nil {
                defaults.set(SubscriptionTier.shopPro.rawValue, forKey: key)
                return .shopPro
            }
            guard let raw = defaults.string(forKey: key) else { return nil }
            if raw == "real" { return nil }   // user opted back to real StoreKit
            // Migrate legacy values from earlier builds
            if raw == "pro" { return .customerPlus }
            if raw == "shop" { return .shopPro }
            return SubscriptionTier(rawValue: raw)
        }
        set {
            UserDefaults.standard.set(newValue?.rawValue ?? "real", forKey: key)
        }
    }
}
#endif

// MARK: - Paywall gating

/// Pure logic for the question: "can the user do X on their current entitlement?"
/// Updated for v1.1 pricing:
///   - Free customer gets 2 vehicles; +N via packs; unlimited if subscribed to Plus.
///   - Mechanic actions (add customer, create quote, jobs) require Shop tier.
///   - Bulk import + custom branding + advanced reports require Shop Pro.
enum PaywallGate {
    case addVehicle(currentCount: Int)
    case exportPDF
    case useOCR
    case addCustomer
    case createQuote
    case bulkImport
    case customBranding
    case advancedReports

    /// Returns true if locked for this entitlement set.
    func isLocked(for entitlements: Entitlements) -> Bool {
        switch self {
        case .addVehicle(let count):
            return count >= vehicleLimit(for: entitlements)

        case .exportPDF, .useOCR:
            // Pro-customer or any Shop tier unlocks these.
            return entitlements.tier == .free

        case .addCustomer, .createQuote:
            // Mechanic-only features.
            return !entitlements.tier.isMechanicTier

        case .bulkImport, .customBranding, .advancedReports:
            // Shop Pro features.
            return entitlements.tier != .shopPro
        }
    }

    /// Convenience: ignore pack slots and ask just-by-tier (used by simple call sites).
    func isLocked(for tier: SubscriptionTier) -> Bool {
        isLocked(for: Entitlements(tier: tier, activeProductIDs: []))
    }

    /// The minimum tier required to unlock this gate.
    var requiredTier: SubscriptionTier {
        switch self {
        case .addVehicle, .exportPDF, .useOCR:                  return .customerPlus
        case .addCustomer, .createQuote:                        return .shopStandard
        case .bulkImport, .customBranding, .advancedReports:    return .shopPro
        }
    }

    /// Total vehicle slots allowed for the given entitlement (base + packs + subscription).
    static func vehicleLimit(for entitlements: Entitlements) -> Int {
        if entitlements.tier == .customerPlus || entitlements.tier.isMechanicTier {
            return .max
        }
        return 2 + entitlements.extraVehicleSlots
    }

    /// Convenience wrapper for the case statement.
    func vehicleLimit(for entitlements: Entitlements) -> Int {
        Self.vehicleLimit(for: entitlements)
    }
}
