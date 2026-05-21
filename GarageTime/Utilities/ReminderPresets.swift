import Foundation

/// Curated maintenance reminder templates per vehicle type. Used by `RemindersListView`
/// to one-tap-add a baseline set.
enum ReminderPresets {

    struct Preset: Sendable, Hashable, Identifiable {
        var id: String { title + "-" + category.rawValue }
        let title: String
        let category: ReminderCategory
        let intervalMiles: Int
        let intervalMonths: Int
    }

    static func presets(for type: VehicleType, powertrain: Powertrain) -> [Preset] {
        switch type {
        case .motorcycle:
            return motorcyclePresets
        case .car, .truck, .other:
            if powertrain == .ev { return evPresets }
            return carPresets
        }
    }

    // MARK: - Catalogs

    static let carPresets: [Preset] = [
        Preset(title: "Oil change",          category: .oilChange,    intervalMiles: 5_000,  intervalMonths: 6),
        Preset(title: "Tire rotation",       category: .tireRotation, intervalMiles: 7_500,  intervalMonths: 6),
        Preset(title: "Brake inspection",    category: .brakes,       intervalMiles: 15_000, intervalMonths: 12),
        Preset(title: "Coolant flush",       category: .coolant,      intervalMiles: 60_000, intervalMonths: 60),
        Preset(title: "Transmission fluid",  category: .transmission, intervalMiles: 60_000, intervalMonths: 60),
        Preset(title: "Cabin filter",        category: .cabinFilter,  intervalMiles: 15_000, intervalMonths: 12),
        Preset(title: "Engine air filter",   category: .airFilter,    intervalMiles: 30_000, intervalMonths: 24),
        Preset(title: "Spark plugs",         category: .sparkPlugs,   intervalMiles: 80_000, intervalMonths: 0),
        Preset(title: "Brake fluid",         category: .brakeFluid,   intervalMiles: 0,      intervalMonths: 24),
        Preset(title: "Battery check",       category: .battery,      intervalMiles: 0,      intervalMonths: 12),
    ]

    static let motorcyclePresets: [Preset] = [
        Preset(title: "Oil change",          category: .oilChange,    intervalMiles: 3_000,  intervalMonths: 6),
        Preset(title: "Chain lube",          category: .chainLube,    intervalMiles: 500,    intervalMonths: 0),
        Preset(title: "Chain adjustment",    category: .chainAdjust,  intervalMiles: 2_000,  intervalMonths: 0),
        Preset(title: "Valve clearance",     category: .valves,       intervalMiles: 16_000, intervalMonths: 0),
        Preset(title: "Fork oil",            category: .forkOil,      intervalMiles: 20_000, intervalMonths: 24),
        Preset(title: "Brake fluid",         category: .brakeFluid,   intervalMiles: 0,      intervalMonths: 24),
        Preset(title: "Coolant flush",       category: .coolant,      intervalMiles: 0,      intervalMonths: 24),
        Preset(title: "Tire change",         category: .tires,        intervalMiles: 8_000,  intervalMonths: 0),
        Preset(title: "Battery check",       category: .battery,      intervalMiles: 0,      intervalMonths: 12),
    ]

    static let evPresets: [Preset] = [
        Preset(title: "Tire rotation",       category: .tireRotation, intervalMiles: 7_500,  intervalMonths: 6),
        Preset(title: "Cabin filter",        category: .cabinFilter,  intervalMiles: 15_000, intervalMonths: 12),
        Preset(title: "Brake fluid",         category: .brakeFluid,   intervalMiles: 0,      intervalMonths: 24),
        Preset(title: "12V battery",         category: .battery,      intervalMiles: 0,      intervalMonths: 12),
        Preset(title: "Coolant (battery)",   category: .coolant,      intervalMiles: 0,      intervalMonths: 48),
    ]
}
