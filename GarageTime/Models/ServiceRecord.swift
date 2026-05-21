import Foundation
import SwiftData

@Model
final class ServiceRecord {
    var id: UUID = UUID()
    var date: Date = Date()
    var mileageAtService: Int = 0

    var categoryRaw: String = ServiceCategory.other.rawValue
    var title: String = ""
    var details: String = ""

    // Cost breakdown (all stored as Double; math via Money/Decimal)
    var laborHours: Double = 0
    var laborRate: Double = 0
    var laborCost: Double = 0
    var partsCost: Double = 0
    var feesCost: Double = 0
    var taxCost: Double = 0
    var totalCost: Double = 0

    var performedByRaw: String = PerformedBy.diy.rawValue
    var shopName: String = ""

    // Photos
    @Attribute(.externalStorage) var receiptPhotoData: Data?
    @Attribute(.externalStorage) var additionalPhotos: [Data]? = []

    // Quote link — when work was quoted then completed
    var derivedFromQuote: Quote?

    // Parents
    var vehicle: Vehicle?

    @Relationship(deleteRule: .nullify, inverse: \Part.installedOn)
    var installedParts: [Part]? = []

    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        mileageAtService: Int = 0,
        category: ServiceCategory = .other,
        title: String = "",
        details: String = "",
        laborHours: Double = 0,
        laborRate: Double = 0,
        laborCost: Double = 0,
        partsCost: Double = 0,
        feesCost: Double = 0,
        taxCost: Double = 0,
        totalCost: Double = 0,
        performedBy: PerformedBy = .diy,
        shopName: String = "",
        receiptPhotoData: Data? = nil,
        additionalPhotos: [Data] = [],
        derivedFromQuote: Quote? = nil,
        vehicle: Vehicle? = nil
    ) {
        self.id = id
        self.date = date
        self.mileageAtService = mileageAtService
        self.categoryRaw = category.rawValue
        self.title = title
        self.details = details
        self.laborHours = laborHours
        self.laborRate = laborRate
        self.laborCost = laborCost
        self.partsCost = partsCost
        self.feesCost = feesCost
        self.taxCost = taxCost
        self.totalCost = totalCost
        self.performedByRaw = performedBy.rawValue
        self.shopName = shopName
        self.receiptPhotoData = receiptPhotoData
        self.additionalPhotos = additionalPhotos
        self.derivedFromQuote = derivedFromQuote
        self.vehicle = vehicle
    }
}

extension ServiceRecord {
    var category: ServiceCategory {
        get { ServiceCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }

    var performedBy: PerformedBy {
        get { PerformedBy(rawValue: performedByRaw) ?? .diy }
        set { performedByRaw = newValue.rawValue }
    }

    /// Effective labor dollar cost: manual override if set, else hours × rate.
    /// Zero when rate is 0 (DIY where time was logged but no money was spent).
    var effectiveLaborCost: Double {
        if laborCost > 0 { return laborCost }
        return Money.lineTotal(quantity: laborHours, unitPrice: laborRate)
    }

    /// Recompute `totalCost` = labor + parts + fees + tax. Caller is responsible for saving.
    func recomputeTotal() {
        totalCost = Money.sum([effectiveLaborCost, partsCost, feesCost, taxCost])
    }
}
