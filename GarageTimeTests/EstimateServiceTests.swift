import Testing
import Foundation
import SwiftData
@testable import GarageTime

@MainActor
@Suite("Estimates — historical pricing")
struct EstimateServiceTests {

    private func container() -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try! ModelContainer(for: Schema(GarageTimeSchema.allTypes), configurations: [config])
    }

    @Test("No history returns nil")
    func noHistoryIsNil() {
        let c = container()
        let svc = RealEstimateService()
        let estimate = svc.estimate(for: .oilChange, vehicleType: nil, in: c.mainContext)
        #expect(estimate == nil)
    }

    @Test("Median cost = middle value of past oil changes")
    func medianFromSamples() {
        let c = container()
        let v = Vehicle(name: "Car", type: .car); c.mainContext.insert(v)
        for cost in [45.0, 60.0, 90.0] {
            let r = ServiceRecord(category: .oilChange, totalCost: cost, vehicle: v)
            r.laborHours = 0.5
            c.mainContext.insert(r)
        }
        let svc = RealEstimateService()
        let est = svc.estimate(for: .oilChange, vehicleType: nil, in: c.mainContext)
        #expect(est?.costMedian == 60)
        #expect(est?.sampleCount == 3)
    }

    @Test("Scopes to same-vehicle-type when 2+ samples exist")
    func scopesByVehicleType() {
        let c = container()
        let car = Vehicle(name: "Car", type: .car)
        let moto = Vehicle(name: "Moto", type: .motorcycle)
        c.mainContext.insert(car); c.mainContext.insert(moto)

        for cost in [40.0, 50.0] {
            let r = ServiceRecord(category: .oilChange, totalCost: cost, vehicle: car)
            c.mainContext.insert(r)
        }
        for cost in [25.0, 30.0] {
            let r = ServiceRecord(category: .oilChange, totalCost: cost, vehicle: moto)
            c.mainContext.insert(r)
        }

        let svc = RealEstimateService()
        let carEst = svc.estimate(for: .oilChange, vehicleType: .car, in: c.mainContext)
        let motoEst = svc.estimate(for: .oilChange, vehicleType: .motorcycle, in: c.mainContext)
        #expect(carEst?.costMedian == 45)
        #expect(motoEst?.costMedian == 27.5)
        #expect(carEst?.scopedVehicleType == .car)
    }

    @Test("Single sample = low confidence")
    func singleSampleIsLowConfidence() {
        let c = container()
        let v = Vehicle(name: "Car", type: .car); c.mainContext.insert(v)
        let r = ServiceRecord(category: .brakes, totalCost: 200, vehicle: v)
        c.mainContext.insert(r)
        let est = RealEstimateService().estimate(for: .brakes, vehicleType: nil, in: c.mainContext)
        #expect(est?.sampleCount == 1)
        #expect(est?.isLowConfidence == true)
        #expect(est?.costMedian == 200)
    }

    @Test("Records with only hours (no money) still count for hour median")
    func hoursOnlyRecordsCountForHours() {
        let c = container()
        let v = Vehicle(name: "Car", type: .car); c.mainContext.insert(v)
        // DIY: 2hrs, $0
        let r = ServiceRecord(category: .brakes,
                              laborHours: 2.0,
                              partsCost: 50,
                              vehicle: v)
        r.recomputeTotal()
        c.mainContext.insert(r)
        let est = RealEstimateService().estimate(for: .brakes, vehicleType: nil, in: c.mainContext)
        #expect(est?.hoursMedian == 2.0)
    }
}
