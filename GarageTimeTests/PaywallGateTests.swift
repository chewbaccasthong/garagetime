import Testing
@testable import GarageTime

@Suite("Paywall gating — legacy smoke tests (v1.1 model)")
struct PaywallGateTests {

    @Test("Free tier locked at vehicle limit (2)")
    func freeLocksAtTwo() {
        let free: SubscriptionTier = .free
        #expect(PaywallGate.addVehicle(currentCount: 1).isLocked(for: free) == false)
        #expect(PaywallGate.addVehicle(currentCount: 2).isLocked(for: free) == true)
    }

    @Test("Customer Plus unlocks PDF + OCR")
    func plusUnlocksExportAndOCR() {
        let plus: SubscriptionTier = .customerPlus
        #expect(PaywallGate.exportPDF.isLocked(for: plus) == false)
        #expect(PaywallGate.useOCR.isLocked(for: plus) == false)
    }

    @Test("Customer Plus cannot access customers/quotes — Shop required")
    func customersRequireShop() {
        #expect(PaywallGate.addCustomer.isLocked(for: .customerPlus) == true)
        #expect(PaywallGate.addCustomer.isLocked(for: .shopStandard) == false)
    }

    @Test("Shop has unlimited vehicles")
    func shopUnlimitedVehicles() {
        #expect(PaywallGate.addVehicle(currentCount: 100).isLocked(for: .shopStandard) == false)
    }
}
