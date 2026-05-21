import Testing
import Foundation
import SwiftData
@testable import GarageTime

@MainActor
@Suite("JobRequest lifecycle")
struct JobRequestLifecycleTests {

    private func container() -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try! ModelContainer(for: Schema(GarageTimeSchema.allTypes), configurations: [config])
    }

    @Test("New job request starts in .pending")
    func defaultsToPending() {
        let r = JobRequest()
        #expect(r.status == .pending)
    }

    @Test("Status transitions hold via raw-string column")
    func statusRoundTrips() {
        let r = JobRequest()
        r.status = .accepted
        #expect(r.statusRaw == "accepted")
        r.status = .scheduled
        #expect(r.statusRaw == "scheduled")
        r.status = .completed
        #expect(r.statusRaw == "completed")
    }

    @Test("displayTitle falls back to category name")
    func titleFallback() {
        let r = JobRequest(category: .brakes, title: "")
        #expect(r.displayTitle == "Brakes")
        r.title = "Front pads + rotors"
        #expect(r.displayTitle == "Front pads + rotors")
    }

    @Test("Linked customer + vehicle survive a save round-trip")
    func relationshipsPersist() {
        let c = container()
        let cust = Customer(firstName: "A", lastName: "B")
        let v = Vehicle(name: "Car", ownerType: .customer, customer: cust)
        c.mainContext.insert(cust); c.mainContext.insert(v)
        let r = JobRequest(category: .oilChange, customer: cust, vehicle: v)
        c.mainContext.insert(r)
        try? c.mainContext.save()
        #expect(r.customer?.id == cust.id)
        #expect(r.vehicle?.id == v.id)
    }
}

@Suite("UserRole + ShopSettings.role")
struct UserRoleTests {

    @Test("Role round-trips through rawValue")
    func roleRoundTrip() {
        let shop = ShopSettings()
        #expect(shop.role == nil)
        shop.role = .customer
        #expect(shop.roleRaw == "customer")
        #expect(shop.role == .customer)
        shop.role = .mechanic
        #expect(shop.role == .mechanic)
    }

    @Test("resolvedMechanicName falls through display → owner → business")
    func mechanicNameFallback() {
        let shop = ShopSettings()
        #expect(shop.resolvedMechanicName == "your mechanic")
        shop.businessName = "Smith Auto"
        #expect(shop.resolvedMechanicName == "Smith Auto")
        shop.ownerName = "Henry G."
        #expect(shop.resolvedMechanicName == "Henry G.")
        shop.mechanicDisplayName = "Henry"
        #expect(shop.resolvedMechanicName == "Henry")
    }
}
