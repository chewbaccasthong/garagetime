import Foundation
import SwiftData

@Model
final class Vehicle {
    // Identity
    var id: UUID = UUID()
    var name: String = ""               // user-given nickname ("Daily Civic")
    var year: Int = 0                   // 0 = unknown
    var make: String = ""
    var model: String = ""
    var trim: String = ""
    var vin: String = ""
    var licensePlate: String = ""

    // Classification
    var typeRaw: String = VehicleType.car.rawValue
    var powertrainRaw: String = Powertrain.ic.rawValue
    var ownerTypeRaw: String = OwnerType.personal.rawValue

    // Mileage
    var currentMileage: Int = 0
    var mileageUnitRaw: String = MileageUnit.mi.rawValue

    // Media
    @Attribute(.externalStorage) var photoData: Data?

    // Purchase + notes
    var purchaseDate: Date?
    var purchasePrice: Double = 0       // stored in shop currency
    var notes: String = ""

    /// True if the VIN was successfully decoded against NHTSA's vPIC API at least once.
    /// Used to show a "VIN verified" badge — discourages bogus inventory uploads.
    var isVINVerified: Bool = false

    // Customer link (only for ownerType == .customer)
    var customer: Customer?

    // Per-vehicle labor rate override (nil = use ShopSettings.defaultLaborRate)
    var laborRateOverride: Double?

    // Lifecycle
    var isActive: Bool = true
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    // Relationships (.cascade on owned children)
    @Relationship(deleteRule: .cascade, inverse: \ServiceRecord.vehicle)
    var serviceRecords: [ServiceRecord]? = []

    @Relationship(deleteRule: .cascade, inverse: \Part.vehicle)
    var parts: [Part]? = []

    @Relationship(deleteRule: .cascade, inverse: \MaintenanceReminder.vehicle)
    var reminders: [MaintenanceReminder]? = []

    @Relationship(deleteRule: .cascade, inverse: \MileageLog.vehicle)
    var mileageLogs: [MileageLog]? = []

    @Relationship(deleteRule: .cascade, inverse: \Quote.vehicle)
    var quotes: [Quote]? = []

    @Relationship(deleteRule: .cascade, inverse: \JobRequest.vehicle)
    var jobRequests: [JobRequest]? = []

    init(
        id: UUID = UUID(),
        name: String = "",
        year: Int = 0,
        make: String = "",
        model: String = "",
        trim: String = "",
        vin: String = "",
        licensePlate: String = "",
        type: VehicleType = .car,
        powertrain: Powertrain = .ic,
        ownerType: OwnerType = .personal,
        currentMileage: Int = 0,
        mileageUnit: MileageUnit = .mi,
        photoData: Data? = nil,
        purchaseDate: Date? = nil,
        purchasePrice: Double = 0,
        notes: String = "",
        customer: Customer? = nil,
        laborRateOverride: Double? = nil
    ) {
        self.id = id
        self.name = name
        self.year = year
        self.make = make
        self.model = model
        self.trim = trim
        self.vin = vin
        self.licensePlate = licensePlate
        self.typeRaw = type.rawValue
        self.powertrainRaw = powertrain.rawValue
        self.ownerTypeRaw = ownerType.rawValue
        self.currentMileage = currentMileage
        self.mileageUnitRaw = mileageUnit.rawValue
        self.photoData = photoData
        self.purchaseDate = purchaseDate
        self.purchasePrice = purchasePrice
        self.notes = notes
        self.customer = customer
        self.laborRateOverride = laborRateOverride
    }
}

// MARK: - Computed conveniences

extension Vehicle {
    var type: VehicleType {
        get { VehicleType(rawValue: typeRaw) ?? .car }
        set { typeRaw = newValue.rawValue }
    }

    var powertrain: Powertrain {
        get { Powertrain(rawValue: powertrainRaw) ?? .ic }
        set { powertrainRaw = newValue.rawValue }
    }

    var ownerType: OwnerType {
        get { OwnerType(rawValue: ownerTypeRaw) ?? .personal }
        set { ownerTypeRaw = newValue.rawValue }
    }

    var mileageUnit: MileageUnit {
        get { MileageUnit(rawValue: mileageUnitRaw) ?? .mi }
        set { mileageUnitRaw = newValue.rawValue }
    }

    /// "2018 Honda Civic Touring" or "Daily Civic" if year/make is blank.
    var displayTitle: String {
        if !name.isEmpty { return name }
        var parts: [String] = []
        if year > 0 { parts.append(String(year)) }
        if !make.isEmpty { parts.append(make) }
        if !model.isEmpty { parts.append(model) }
        if !trim.isEmpty { parts.append(trim) }
        let joined = parts.joined(separator: " ")
        return joined.isEmpty ? "Untitled Vehicle" : joined
    }

    /// Year/make/model line shown under the name.
    var subtitle: String {
        var parts: [String] = []
        if year > 0 { parts.append(String(year)) }
        if !make.isEmpty { parts.append(make) }
        if !model.isEmpty { parts.append(model) }
        if !trim.isEmpty { parts.append(trim) }
        return parts.joined(separator: " ")
    }

    var totalSpent: Double {
        Money.sum((serviceRecords ?? []).map { $0.totalCost })
    }

    /// Sum of labor cost (hours × rate, or manual override) across all service records.
    /// Zero for DIY records where no rate was set — see `totalLaborHours` for time.
    var totalLaborCost: Double {
        Money.sum((serviceRecords ?? []).map { $0.effectiveLaborCost })
    }

    /// Sum of parts cost across all service records.
    var totalPartsCost: Double {
        Money.sum((serviceRecords ?? []).map { $0.partsCost })
    }

    /// Total hours spent on this vehicle across every service record — DIY *and* shop.
    /// This is the time spent, independent of whether the time was billed.
    var totalLaborHours: Double {
        (serviceRecords ?? []).reduce(0) { $0 + $1.laborHours }
    }

    /// Total fees + tax (the residual after parts and labor).
    var totalFeesAndTax: Double {
        Money.sum((serviceRecords ?? []).map { $0.feesCost + $0.taxCost })
    }

    var lastServiceDate: Date? {
        (serviceRecords ?? []).map(\.date).max()
    }
}
