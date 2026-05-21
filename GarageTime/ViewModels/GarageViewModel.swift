import Foundation
import SwiftData

enum GarageFilter: String, CaseIterable, Hashable, Identifiable {
    case all
    case personal
    case customer

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .all:      return "All"
        case .personal: return "Personal"
        case .customer: return "Customers"
        }
    }
}

@MainActor
@Observable
final class GarageViewModel {
    var filter: GarageFilter = .all
    var searchQuery: String = ""
    var addingVehicle: Bool = false

    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    /// Filter + search predicate applied to vehicles. Returns a sorted snapshot.
    func vehicles(from all: [Vehicle]) -> [Vehicle] {
        all
            .filter { matchesFilter($0) && matchesSearch($0) }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    func summary(for vehicle: Vehicle, currentMileage: Int) -> ReminderUrgency {
        let reminders = vehicle.reminders ?? []
        let urgencies = reminders.map { $0.urgency(now: Date(), currentMileage: currentMileage) }
        if urgencies.contains(.overdue) { return .overdue }
        if urgencies.contains(.dueSoon) { return .dueSoon }
        return .ok
    }

    // MARK: - Private helpers

    private func matchesFilter(_ vehicle: Vehicle) -> Bool {
        switch filter {
        case .all:      return true
        case .personal: return vehicle.ownerType == .personal
        case .customer: return vehicle.ownerType == .customer
        }
    }

    private func matchesSearch(_ vehicle: Vehicle) -> Bool {
        let q = searchQuery.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return true }
        let haystack = "\(vehicle.displayTitle) \(vehicle.subtitle) \(vehicle.vin) \(vehicle.licensePlate) \(vehicle.customer?.displayName ?? "")".lowercased()
        return haystack.contains(q)
    }

    // MARK: - Mutations

    func deleteVehicle(_ vehicle: Vehicle) {
        context.delete(vehicle)
        try? context.save()
    }
}
