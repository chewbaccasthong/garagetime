import Foundation
import SwiftData

@Model
final class MileageLog {
    var id: UUID = UUID()
    var date: Date = Date()
    var mileage: Int = 0
    var gallons: Double?            // nil if not a fuel fillup
    var pricePerGallon: Double?
    var isFillUp: Bool = false
    var notes: String = ""

    var vehicle: Vehicle?

    var createdAt: Date = Date()

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        mileage: Int = 0,
        gallons: Double? = nil,
        pricePerGallon: Double? = nil,
        isFillUp: Bool = false,
        notes: String = "",
        vehicle: Vehicle? = nil
    ) {
        self.id = id
        self.date = date
        self.mileage = mileage
        self.gallons = gallons
        self.pricePerGallon = pricePerGallon
        self.isFillUp = isFillUp
        self.notes = notes
        self.vehicle = vehicle
    }
}

extension MileageLog {
    var fuelCost: Double? {
        guard let g = gallons, let p = pricePerGallon else { return nil }
        return Money.lineTotal(quantity: g, unitPrice: p)
    }
}
