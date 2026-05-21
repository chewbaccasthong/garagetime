import Foundation
import SwiftData

@Model
final class QuoteLineItem {
    var id: UUID = UUID()
    var sortOrder: Int = 0

    var typeRaw: String = QuoteLineItemType.part.rawValue

    var itemDescription: String = ""
    var quantity: Double = 1
    var unitPrice: Double = 0
    var lineTotal: Double = 0      // qty × unitPrice (or hours × rate for labor)
    var taxable: Bool = true

    // Labor-only metadata (nil for non-labor lines)
    var hours: Double?
    var laborRate: Double?

    // Part link — when line was added "from inventory"
    var partRef: Part?

    var quote: Quote?

    var createdAt: Date = Date()

    init(
        id: UUID = UUID(),
        sortOrder: Int = 0,
        type: QuoteLineItemType = .part,
        itemDescription: String = "",
        quantity: Double = 1,
        unitPrice: Double = 0,
        lineTotal: Double = 0,
        taxable: Bool = true,
        hours: Double? = nil,
        laborRate: Double? = nil,
        partRef: Part? = nil,
        quote: Quote? = nil
    ) {
        self.id = id
        self.sortOrder = sortOrder
        self.typeRaw = type.rawValue
        self.itemDescription = itemDescription
        self.quantity = quantity
        self.unitPrice = unitPrice
        self.lineTotal = lineTotal
        self.taxable = taxable
        self.hours = hours
        self.laborRate = laborRate
        self.partRef = partRef
        self.quote = quote
    }
}

extension QuoteLineItem {
    var type: QuoteLineItemType {
        get { QuoteLineItemType(rawValue: typeRaw) ?? .part }
        set { typeRaw = newValue.rawValue }
    }

    /// Recompute `lineTotal` from current quantity / unitPrice (or hours × rate for labor).
    /// Discounts are stored as positive numbers (signed application happens at quote level).
    func recomputeLineTotal() {
        switch type {
        case .labor:
            let q = hours ?? quantity
            let p = laborRate ?? unitPrice
            lineTotal = Money.lineTotal(quantity: q, unitPrice: p)
        case .part, .fee, .discount:
            lineTotal = Money.lineTotal(quantity: quantity, unitPrice: unitPrice)
        }
    }
}
