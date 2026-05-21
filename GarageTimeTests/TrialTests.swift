import Testing
import Foundation
@testable import GarageTime

@Suite("Free trial — 7-day window + entitlement resolution")
struct TrialTests {

    @Test("Fresh ShopSettings: trial is available, not active, not expired")
    func freshState() {
        let shop = ShopSettings()
        #expect(shop.isTrialAvailable == true)
        #expect(shop.isTrialActive == false)
        #expect(shop.isTrialExpired == false)
        #expect(shop.trialDaysRemaining == 0)
    }

    @Test("After start: trial active, 7 days remaining, not available again")
    func startTrial() {
        let shop = ShopSettings()
        shop.trialStartedAt = Date()
        shop.trialTier = .customerPlus
        #expect(shop.isTrialActive == true)
        #expect(shop.isTrialAvailable == false)
        #expect(shop.isTrialExpired == false)
        #expect(shop.trialDaysRemaining == 7)
    }

    @Test("Trial expires after 7 days")
    func expiresAfter7Days() {
        let shop = ShopSettings()
        shop.trialStartedAt = Calendar.current.date(byAdding: .day, value: -8, to: Date())
        shop.trialTier = .customerPlus
        #expect(shop.isTrialActive == false)
        #expect(shop.isTrialExpired == true)
        #expect(shop.trialDaysRemaining == 0)
    }

    @Test("Mid-trial: days remaining ticks down")
    func daysRemainingTicks() {
        let shop = ShopSettings()
        shop.trialStartedAt = Calendar.current.date(byAdding: .day, value: -3, to: Date())
        shop.trialTier = .shopStandard
        // Started 3 days ago, 7-day trial → 4 days remaining (rounded up)
        #expect(shop.trialDaysRemaining == 4)
        #expect(shop.isTrialActive == true)
    }

    @MainActor
    @Test("Trial promotes free→trialTier; real subscription wins over trial")
    func resolveLayersCorrectly() {
        let free = InMemoryStoreService()
        free.entitlements = Entitlements(tier: .free, activeProductIDs: [])
        let shop = ShopSettings()
        shop.trialStartedAt = Date()
        shop.trialTier = .customerPlus

        let resolved = TrialEntitlement.resolve(store: free, settings: shop)
        #expect(resolved.tier == .customerPlus)

        // Now a real subscription is active — wins.
        free.entitlements = Entitlements(tier: .shopStandard,
                                         activeProductIDs: [Catalog.shopStandardYearly])
        let resolvedReal = TrialEntitlement.resolve(store: free, settings: shop)
        #expect(resolvedReal.tier == .shopStandard)
    }

    @MainActor
    @Test("No trial + free store → still free")
    func noTrialKeepsFree() {
        let store = InMemoryStoreService()
        let shop = ShopSettings()
        let resolved = TrialEntitlement.resolve(store: store, settings: shop)
        #expect(resolved.tier == .free)
    }
}

@Suite("Walkthrough — completion flag")
struct WalkthroughTests {

    @Test("Fresh settings: walkthrough not completed")
    func freshNotCompleted() {
        let shop = ShopSettings()
        #expect(shop.hasCompletedWalkthrough == false)
    }

    @Test("Completing once persists")
    func completionPersists() {
        let shop = ShopSettings()
        shop.hasCompletedWalkthrough = true
        #expect(shop.hasCompletedWalkthrough == true)
    }

    @Test("Mechanic walkthrough has at least 6 substantial steps")
    func mechanicStepsCount() {
        #expect(WalkthroughView.mechanicSteps.count >= 6)
        for step in WalkthroughView.mechanicSteps {
            #expect(!step.title.isEmpty)
            #expect(!step.body.isEmpty)
            #expect(!step.icon.isEmpty)
        }
    }

    @Test("Customer walkthrough has at least 4 substantial steps")
    func customerStepsCount() {
        #expect(WalkthroughView.customerSteps.count >= 4)
        for step in WalkthroughView.customerSteps {
            #expect(!step.title.isEmpty)
            #expect(!step.body.isEmpty)
        }
    }
}
