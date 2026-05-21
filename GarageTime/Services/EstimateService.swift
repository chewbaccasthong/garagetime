import Foundation
import SwiftData

/// A cost + time estimate for a service category, derived from the mechanic's history.
/// Returned by `EstimateService.estimate(for:)`.
struct Estimate: Sendable, Equatable {
    let category: ServiceCategory
    let sampleCount: Int

    let costMedian: Double
    let costLow: Double               // 25th percentile of samples
    let costHigh: Double              // 75th percentile of samples

    let hoursMedian: Double
    let hoursLow: Double
    let hoursHigh: Double

    /// Optional: most recent comparable record's date — helps customer judge freshness.
    let lastSeen: Date?

    /// Vehicle type the estimate was scoped to (nil = all types).
    let scopedVehicleType: VehicleType?

    var isLowConfidence: Bool { sampleCount < 3 }

    /// Pretty range, e.g. "$45–$72" or "$60" if low/high are tight.
    var costRangeDisplay: String {
        if abs(costHigh - costLow) < 1 {
            return Money.format(costMedian)
        }
        return "\(Money.format(costLow))–\(Money.format(costHigh))"
    }

    var hoursRangeDisplay: String {
        if abs(hoursHigh - hoursLow) < 0.1 {
            return WBFormat.hours(hoursMedian)
        }
        return "\(WBFormat.hours(hoursLow))–\(WBFormat.hours(hoursHigh))"
    }
}

protocol EstimateProviding: Sendable {
    /// Compute an estimate for a category. If `vehicleType` is given, restrict to records
    /// for that vehicle type when there are enough samples; otherwise widen to all vehicles.
    @MainActor func estimate(
        for category: ServiceCategory,
        vehicleType: VehicleType?,
        in context: ModelContext
    ) -> Estimate?
}

/// Real impl reading from local `ServiceRecord` history.
struct RealEstimateService: EstimateProviding {

    private let minSamplesForTypeFilter = 2

    @MainActor func estimate(
        for category: ServiceCategory,
        vehicleType: VehicleType?,
        in context: ModelContext
    ) -> Estimate? {
        // SwiftData #Predicate can't filter on rawValue easily because category is
        // stored as String; pull all records and filter in-memory. Fast at app scale.
        let descriptor = FetchDescriptor<ServiceRecord>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        let all = (try? context.fetch(descriptor)) ?? []
        let byCategory = all.filter { $0.category == category }
        if byCategory.isEmpty { return nil }

        // Prefer same-vehicle-type subset if enough samples; else widen.
        var scoped: [ServiceRecord]
        var scopedTo: VehicleType? = nil
        if let vehicleType {
            let narrow = byCategory.filter { $0.vehicle?.type == vehicleType }
            if narrow.count >= minSamplesForTypeFilter {
                scoped = narrow
                scopedTo = vehicleType
            } else {
                scoped = byCategory
            }
        } else {
            scoped = byCategory
        }

        // Filter to records with positive total cost OR positive hours (i.e. something logged)
        scoped = scoped.filter { $0.totalCost > 0 || $0.laborHours > 0 }
        guard !scoped.isEmpty else { return nil }

        let costs = scoped.map(\.totalCost).filter { $0 > 0 }
        let hours = scoped.map(\.laborHours).filter { $0 > 0 }

        return Estimate(
            category: category,
            sampleCount: scoped.count,
            costMedian: median(costs),
            costLow: percentile(costs, 0.25),
            costHigh: percentile(costs, 0.75),
            hoursMedian: median(hours),
            hoursLow: percentile(hours, 0.25),
            hoursHigh: percentile(hours, 0.75),
            lastSeen: scoped.map(\.date).max(),
            scopedVehicleType: scopedTo
        )
    }

    // MARK: - Math

    private func median(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        if sorted.count.isMultiple(of: 2) {
            let a = sorted[sorted.count / 2 - 1]
            let b = sorted[sorted.count / 2]
            return Money.round((a + b) / 2)
        }
        return Money.round(sorted[sorted.count / 2])
    }

    private func percentile(_ values: [Double], _ p: Double) -> Double {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        if sorted.count == 1 { return Money.round(sorted[0]) }
        let rank = p * Double(sorted.count - 1)
        let lower = Int(rank.rounded(.down))
        let upper = Int(rank.rounded(.up))
        if lower == upper { return Money.round(sorted[lower]) }
        let fraction = rank - Double(lower)
        return Money.round(sorted[lower] + (sorted[upper] - sorted[lower]) * fraction)
    }
}

/// In-memory fake — returns whatever you set on `fixedEstimate`.
final class InMemoryEstimateService: EstimateProviding, @unchecked Sendable {
    var fixedEstimate: Estimate?

    @MainActor func estimate(for category: ServiceCategory, vehicleType: VehicleType?, in context: ModelContext) -> Estimate? {
        fixedEstimate
    }
}
