import Testing
@testable import GarageTime

@Suite("Pricing v1.1 — tier helpers + paywall gates")
struct PricingTests {

    @Test("Customer Plus + Shop tiers correctly classified")
    func tierClassification() {
        #expect(SubscriptionTier.customerPlus.isPayingCustomer == true)
        #expect(SubscriptionTier.shopStandard.isMechanicTier == true)
        #expect(SubscriptionTier.shopPro.isMechanicTier == true)
        #expect(SubscriptionTier.free.isMechanicTier == false)
    }

    @Test("Vehicle limit: free=2, +pack adds slots, Plus = unlimited")
    func vehicleLimits() {
        let free = Entitlements(tier: .free, activeProductIDs: [])
        #expect(PaywallGate.vehicleLimit(for: free) == 2)

        let freeWithPack = Entitlements(tier: .free,
                                        activeProductIDs: [Catalog.vehiclePack3])
        #expect(PaywallGate.vehicleLimit(for: freeWithPack) == 5)

        let freeWithBigPack = Entitlements(tier: .free,
                                           activeProductIDs: [Catalog.vehiclePack10])
        #expect(PaywallGate.vehicleLimit(for: freeWithBigPack) == 12)

        let plus = Entitlements(tier: .customerPlus, activeProductIDs: [])
        #expect(PaywallGate.vehicleLimit(for: plus) == .max)

        let shop = Entitlements(tier: .shopStandard, activeProductIDs: [])
        #expect(PaywallGate.vehicleLimit(for: shop) == .max)
    }

    @Test("addVehicle gate respects vehicle limit, including slot packs")
    func addVehicleGate() {
        let free = Entitlements(tier: .free, activeProductIDs: [])
        #expect(PaywallGate.addVehicle(currentCount: 1).isLocked(for: free) == false)
        #expect(PaywallGate.addVehicle(currentCount: 2).isLocked(for: free) == true)

        let freePack = Entitlements(tier: .free,
                                    activeProductIDs: [Catalog.vehiclePack3])
        #expect(PaywallGate.addVehicle(currentCount: 4).isLocked(for: freePack) == false)
        #expect(PaywallGate.addVehicle(currentCount: 5).isLocked(for: freePack) == true)
    }

    @Test("Customer cannot access mechanic-only features")
    func customerBlockedFromMechanicFeatures() {
        let plus = Entitlements(tier: .customerPlus, activeProductIDs: [])
        #expect(PaywallGate.addCustomer.isLocked(for: plus) == true)
        #expect(PaywallGate.createQuote.isLocked(for: plus) == true)
    }

    @Test("Shop unlocks customer + quote management")
    func shopUnlocks() {
        let shop = Entitlements(tier: .shopStandard, activeProductIDs: [])
        #expect(PaywallGate.addCustomer.isLocked(for: shop) == false)
        #expect(PaywallGate.createQuote.isLocked(for: shop) == false)
    }

    @Test("Bulk import + custom branding + advanced reports gated to Shop Pro only")
    func shopProOnly() {
        let standard = Entitlements(tier: .shopStandard, activeProductIDs: [])
        let pro      = Entitlements(tier: .shopPro,      activeProductIDs: [])
        #expect(PaywallGate.bulkImport.isLocked(for: standard) == true)
        #expect(PaywallGate.bulkImport.isLocked(for: pro) == false)
        #expect(PaywallGate.customBranding.isLocked(for: pro) == false)
        #expect(PaywallGate.advancedReports.isLocked(for: standard) == true)
    }

    @Test("Vehicle pack counts roll up correctly on Entitlements")
    func packSlotsAddUp() {
        let both = Entitlements(tier: .free,
                                activeProductIDs: [Catalog.vehiclePack3, Catalog.vehiclePack10])
        #expect(both.extraVehicleSlots == 13)
    }
}
