import Foundation
import SwiftData

@Model
final class Quote {
    var id: UUID = UUID()
    var quoteNumber: String = ""           // human-readable, e.g. "Q-2026-0001"

    var statusRaw: String = QuoteStatus.draft.rawValue

    // Dates
    var issueDate: Date = Date()
    var expiryDate: Date = Date().addingTimeInterval(30 * 86400)
    var approvedDate: Date?
    var completedDate: Date?

    // Notes
    var customerNotes: String = ""         // printed on PDF
    var internalNotes: String = ""         // never printed

    // Totals (snapshot at last save — recomputed when line items change)
    var subtotalLabor: Double = 0
    var subtotalParts: Double = 0
    var subtotalFees: Double = 0
    var discountAmount: Double = 0
    var taxRate: Double = 0                // 0.0875 for 8.75%
    var taxAmount: Double = 0
    var total: Double = 0

    // Signature (PencilKit PNG)
    @Attribute(.externalStorage) var signaturePngData: Data?
    var signedByName: String = ""
    var signedAt: Date?

    // Generated PDF, cached for fast share-sheet (optional — regenerable)
    @Attribute(.externalStorage) var pdfData: Data?

    // Relationships
    var customer: Customer?
    var vehicle: Vehicle?

    @Relationship(deleteRule: .cascade, inverse: \QuoteLineItem.quote)
    var lineItems: [QuoteLineItem]? = []

    /// Service records spawned from this quote (one quote can convert into multiple records
    /// over time if the work is staged). Inverse of `ServiceRecord.derivedFromQuote`.
    @Relationship(deleteRule: .nullify, inverse: \ServiceRecord.derivedFromQuote)
    var derivedServiceRecords: [ServiceRecord]? = []

    /// Inverse for `JobRequest.quote` — a quote may originate from one or more requests.
    @Relationship(deleteRule: .nullify, inverse: \JobRequest.quote)
    var sourceJobRequests: [JobRequest]? = []

    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(
        id: UUID = UUID(),
        quoteNumber: String = "",
        status: QuoteStatus = .draft,
        issueDate: Date = Date(),
        expiryDate: Date = Date().addingTimeInterval(30 * 86400),
        approvedDate: Date? = nil,
        completedDate: Date? = nil,
        customerNotes: String = "",
        internalNotes: String = "",
        subtotalLabor: Double = 0,
        subtotalParts: Double = 0,
        subtotalFees: Double = 0,
        discountAmount: Double = 0,
        taxRate: Double = 0,
        taxAmount: Double = 0,
        total: Double = 0,
        customer: Customer? = nil,
        vehicle: Vehicle? = nil
    ) {
        self.id = id
        self.quoteNumber = quoteNumber
        self.statusRaw = status.rawValue
        self.issueDate = issueDate
        self.expiryDate = expiryDate
        self.approvedDate = approvedDate
        self.completedDate = completedDate
        self.customerNotes = customerNotes
        self.internalNotes = internalNotes
        self.subtotalLabor = subtotalLabor
        self.subtotalParts = subtotalParts
        self.subtotalFees = subtotalFees
        self.discountAmount = discountAmount
        self.taxRate = taxRate
        self.taxAmount = taxAmount
        self.total = total
        self.customer = customer
        self.vehicle = vehicle
    }
}

extension Quote {
    var status: QuoteStatus {
        get { QuoteStatus(rawValue: statusRaw) ?? .draft }
        set { statusRaw = newValue.rawValue }
    }

    var isExpired: Bool {
        status == .sent && Date() > expiryDate
    }

    var sortedLineItems: [QuoteLineItem] {
        (lineItems ?? []).sorted { $0.sortOrder < $1.sortOrder }
    }

    /// Recalculate every subtotal + total from the current line items + tax rate.
    /// Mutates self; caller saves.
    func recompute() {
        let items = lineItems ?? []
        // Labor (sum of labor lines)
        subtotalLabor = Money.sum(items.filter { $0.type == .labor }.map { $0.lineTotal })
        // Parts (sum of part lines)
        subtotalParts = Money.sum(items.filter { $0.type == .part }.map { $0.lineTotal })
        // Fees (sum of fee lines)
        subtotalFees = Money.sum(items.filter { $0.type == .fee }.map { $0.lineTotal })
        // Discounts (sum of discount lines — stored as positive numbers, applied as subtract)
        discountAmount = Money.sum(items.filter { $0.type == .discount }.map { $0.lineTotal })

        // Taxable base: only items marked taxable contribute. Discounts apply pro-rata.
        let taxableBase = Money.sum(
            items.filter { $0.taxable && $0.type != .discount }.map { $0.lineTotal }
        )
        taxAmount = Money.tax(on: taxableBase - discountAmount * proportion(of: taxableBase, in: items), rate: taxRate)

        let sub = subtotalLabor + subtotalParts + subtotalFees - discountAmount
        total = Money.round(sub + taxAmount)
    }

    private func proportion(of taxableBase: Double, in items: [QuoteLineItem]) -> Double {
        let totalLines = Money.sum(items.filter { $0.type != .discount }.map { $0.lineTotal })
        guard totalLines > 0 else { return 0 }
        return taxableBase / totalLines
    }
}
