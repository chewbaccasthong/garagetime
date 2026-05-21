import Testing
import Foundation
@testable import GarageTime

@Suite("Vehicle quota — dealer-abuse prevention")
struct VehicleQuotaTests {

    @Test("Free tier blocks at 2 vehicles")
    func freeTierLimit() {
        let svc = InMemoryVehicleQuotaService()
        let ent = Entitlements(tier: .free, activeProductIDs: [])
        #expect(svc.check(currentTotal: 1, entitlements: ent, now: .now).isAllowed)
        let blocked = svc.check(currentTotal: 2, entitlements: ent, now: .now)
        if case .blocked(.tierLimit(let n)) = blocked {
            #expect(n == 2)
        } else {
            Issue.record("Expected tier-limit block, got \(blocked)")
        }
    }

    @Test("Hourly burst limit kicks in after N adds within 60 minutes")
    func hourlyBurst() {
        let svc = InMemoryVehicleQuotaService()
        let ent = Entitlements(tier: .customerPlus, activeProductIDs: [])  // hourly limit = 3
        let now = Date()
        for offset in 0..<3 {
            svc.recordAdd(at: now.addingTimeInterval(Double(-offset * 60)))
        }
        let decision = svc.check(currentTotal: 5, entitlements: ent, now: now)
        if case .blocked(.hourlyBurst(let n)) = decision {
            #expect(n == 3)
        } else {
            Issue.record("Expected hourly-burst block, got \(decision)")
        }
    }

    @Test("Daily limit kicks in after dailyLimit adds within 24 hours")
    func dailyLimit() {
        let svc = InMemoryVehicleQuotaService()
        let ent = Entitlements(tier: .shopStandard, activeProductIDs: [])  // daily=15, hourly=6
        let now = Date()
        // Spread adds across hours so we hit daily but not hourly.
        for hour in 0..<15 {
            svc.recordAdd(at: now.addingTimeInterval(-Double(hour * 3600 + 60)))
        }
        let decision = svc.check(currentTotal: 20, entitlements: ent, now: now)
        if case .blocked(.dailyRateLimit(let n)) = decision {
            #expect(n == 15)
        } else {
            Issue.record("Expected daily-limit block, got \(decision)")
        }
    }

    @Test("Old adds (>24h ago) don't count toward the daily window")
    func oldAddsDontCount() {
        let svc = InMemoryVehicleQuotaService()
        let ent = Entitlements(tier: .free, activeProductIDs: [])
        let now = Date()
        // Record 10 adds 25 hours ago — outside the 24h window
        for _ in 0..<10 {
            svc.recordAdd(at: now.addingTimeInterval(-25 * 3600))
        }
        let decision = svc.check(currentTotal: 1, entitlements: ent, now: now)
        #expect(decision.isAllowed)
    }

    @Test("Shop Pro daily limit is 30")
    func shopProAllowsBigBatches() {
        #expect(RealVehicleQuotaService.dailyLimit[.shopPro] == 30)
    }
}
