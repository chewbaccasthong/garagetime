import Testing
import Foundation
import SwiftData
@testable import GarageTime

@MainActor
@Suite("Time + cost breakdown aggregations")
struct TimeTrackingTests {

    private func container() -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try! ModelContainer(for: Schema(GarageTimeSchema.allTypes), configurations: [config])
    }

    @Test("ServiceRecord total = labor + parts + fees + tax")
    func totalIncludesEverything() {
        let r = ServiceRecord(
            laborHours: 2,
            laborRate: 100,            // → $200 labor
            partsCost: 50,
            feesCost: 10,
            taxCost: 5
        )
        r.recomputeTotal()
        #expect(r.effectiveLaborCost == 200)
        #expect(r.totalCost == 265)
    }

    @Test("ServiceRecord with laborCost override beats hours × rate")
    func laborCostOverrideWins() {
        let r = ServiceRecord(
            laborHours: 2,
            laborRate: 100,            // would compute $200
            laborCost: 175,            // user said flat $175
            partsCost: 0
        )
        r.recomputeTotal()
        #expect(r.effectiveLaborCost == 175)
        #expect(r.totalCost == 175)
    }

    @Test("DIY record with hours but no rate has $0 labor cost but still records time")
    func diyHoursTrackedWithoutMoney() {
        let r = ServiceRecord(laborHours: 1.5, laborRate: 0, partsCost: 30)
        r.recomputeTotal()
        #expect(r.effectiveLaborCost == 0)
        #expect(r.laborHours == 1.5)
        #expect(r.totalCost == 30)
    }

    @Test("Vehicle aggregates labor cost, parts cost, hours across records")
    func vehicleAggregations() {
        let c = container()
        let v = Vehicle(name: "Test", currentMileage: 10_000)
        c.mainContext.insert(v)

        let r1 = ServiceRecord(laborHours: 0.5, laborRate: 100, partsCost: 40, vehicle: v)
        r1.recomputeTotal()                       // labor 50, parts 40 → 90
        let r2 = ServiceRecord(laborHours: 2.0, laborRate: 0, partsCost: 75, vehicle: v)
        r2.recomputeTotal()                       // DIY: 0 labor, 75 parts
        c.mainContext.insert(r1)
        c.mainContext.insert(r2)
        v.serviceRecords = [r1, r2]

        #expect(v.totalLaborHours == 2.5)
        #expect(v.totalLaborCost == 50)
        #expect(v.totalPartsCost == 115)
        #expect(v.totalSpent == 165)
    }

    @Test("Customer aggregates labor across all of their vehicles")
    func customerCrossVehicleAggregation() {
        let c = container()
        let cust = Customer(firstName: "Bob", lastName: "Reyes")
        c.mainContext.insert(cust)

        let v1 = Vehicle(name: "Truck", ownerType: .customer, customer: cust)
        let v2 = Vehicle(name: "Bike",  ownerType: .customer, customer: cust)
        c.mainContext.insert(v1); c.mainContext.insert(v2)

        let r1 = ServiceRecord(laborHours: 1.0, laborRate: 100, partsCost: 25, vehicle: v1)
        r1.recomputeTotal()
        let r2 = ServiceRecord(laborHours: 3.0, laborRate: 100, partsCost: 60, vehicle: v2)
        r2.recomputeTotal()
        c.mainContext.insert(r1); c.mainContext.insert(r2)
        v1.serviceRecords = [r1]
        v2.serviceRecords = [r2]
        cust.vehicles = [v1, v2]

        #expect(cust.totalLaborHours == 4.0)
        #expect(cust.totalLaborCost == 400)
        #expect(cust.totalPartsCost == 85)
    }
}
