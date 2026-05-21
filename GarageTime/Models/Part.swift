import Foundation
import SwiftData

@Model
final class Part {
    var id: UUID = UUID()
    var name: String = ""
    var partNumber: String = ""
    var brand: String = ""
    var supplier: String = ""

    var price: Double = 0          // what was paid (sale-side for customer parts)
    var costBasis: Double?          // what we paid (cost-side) — used for profitability reports later
    var quantity: Int = 1

    var installDate: Date?
    var isOnShelf: Bool = false     // true if uninstalled inventory

    var warrantyMonths: Int = 0
    var warrantyMileage: Int = 0    // miles from installDate
    var notes: String = ""

    @Attribute(.externalStorage) var photoData: Data?

    var vehicle: Vehicle?
    var installedOn: ServiceRecord?

    /// Quote line items that reference this part (inventory pull). Inverse of
    /// `QuoteLineItem.partRef`. Required by CloudKit.
    @Relationship(deleteRule: .nullify, inverse: \QuoteLineItem.partRef)
    var quotedIn: [QuoteLineItem]? = []

    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(
        id: UUID = UUID(),
        name: String = "",
        partNumber: String = "",
        brand: String = "",
        supplier: String = "",
        price: Double = 0,
        costBasis: Double? = nil,
        quantity: Int = 1,
        installDate: Date? = nil,
        isOnShelf: Bool = false,
        warrantyMonths: Int = 0,
        warrantyMileage: Int = 0,
        notes: String = "",
        photoData: Data? = nil,
        vehicle: Vehicle? = nil,
        installedOn: ServiceRecord? = nil
    ) {
        self.id = id
        self.name = name
        self.partNumber = partNumber
        self.brand = brand
        self.supplier = supplier
        self.price = price
        self.costBasis = costBasis
        self.quantity = quantity
        self.installDate = installDate
        self.isOnShelf = isOnShelf
        self.warrantyMonths = warrantyMonths
        self.warrantyMileage = warrantyMileage
        self.notes = notes
        self.photoData = photoData
        self.vehicle = vehicle
        self.installedOn = installedOn
    }
}

extension Part {
    /// Combined display: "Bosch DR1234 — Brake Pads"
    var displayTitle: String {
        var pieces: [String] = []
        if !brand.isEmpty { pieces.append(brand) }
        if !partNumber.isEmpty { pieces.append(partNumber) }
        let prefix = pieces.joined(separator: " ")
        if name.isEmpty { return prefix.isEmpty ? "Unnamed part" : prefix }
        return prefix.isEmpty ? name : "\(prefix) — \(name)"
    }

    /// Date warranty expires, or nil if no warranty.
    var warrantyExpiry: Date? {
        guard warrantyMonths > 0, let install = installDate else { return nil }
        return Calendar.current.date(byAdding: .month, value: warrantyMonths, to: install)
    }

    /// True if a date+mileage warranty check still has coverage.
    func isWarrantied(at date: Date, currentMileage: Int) -> Bool {
        if warrantyMonths == 0 && warrantyMileage == 0 { return false }
        guard installDate != nil else { return false }
        let okByDate: Bool
        if let expiry = warrantyExpiry {
            okByDate = date <= expiry
        } else {
            okByDate = true
        }
        let okByMiles: Bool
        if warrantyMileage > 0 {
            let installMileage = installedOn?.mileageAtService ?? 0
            okByMiles = currentMileage - installMileage <= warrantyMileage
        } else {
            okByMiles = true
        }
        return okByDate && okByMiles
    }
}
