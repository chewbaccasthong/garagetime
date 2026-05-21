import Testing
import Foundation
import SwiftData
@testable import GarageTime

@MainActor
@Suite("Quote — totals recompute")
struct QuoteTotalsTests {

    private func container() -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try! ModelContainer(for: Schema(GarageTimeSchema.allTypes), configurations: [config])
    }

    @Test("Empty quote totals are zero")
    func emptyQuoteIsZero() {
        let c = container()
        let q = Quote()
        c.mainContext.insert(q)
        q.recompute()
        #expect(q.total == 0)
        #expect(q.subtotalLabor == 0)
        #expect(q.subtotalParts == 0)
        #expect(q.taxAmount == 0)
    }

    @Test("Labor line + part line + 8.25% tax computes correctly")
    func laborPlusPartPlusTax() {
        let c = container()
        let q = Quote(taxRate: 0.0825)
        c.mainContext.insert(q)

        let labor = QuoteLineItem(sortOrder: 0, type: .labor,
                                  quantity: 2.0, unitPrice: 100,
                                  hours: 2.0, laborRate: 100,
                                  quote: q)
        labor.recomputeLineTotal()
        let part = QuoteLineItem(sortOrder: 1, type: .part,
                                 quantity: 1, unitPrice: 50,
                                 quote: q)
        part.recomputeLineTotal()
        c.mainContext.insert(labor)
        c.mainContext.insert(part)
        q.lineItems = [labor, part]
        q.recompute()

        #expect(labor.lineTotal == 200)
        #expect(part.lineTotal == 50)
        #expect(q.subtotalLabor == 200)
        #expect(q.subtotalParts == 50)
        // 250 × 8.25% = 20.625 → rounds to 20.63
        #expect(q.taxAmount == 20.63)
        #expect(q.total == 270.63)
    }

    @Test("Non-taxable line is excluded from tax base")
    func nonTaxableExcluded() {
        let c = container()
        let q = Quote(taxRate: 0.10)
        c.mainContext.insert(q)

        let part = QuoteLineItem(sortOrder: 0, type: .part,
                                 quantity: 1, unitPrice: 100, taxable: true,
                                 quote: q)
        let fee = QuoteLineItem(sortOrder: 1, type: .fee,
                                quantity: 1, unitPrice: 50, taxable: false,
                                quote: q)
        for item in [part, fee] {
            item.recomputeLineTotal()
            c.mainContext.insert(item)
        }
        q.lineItems = [part, fee]
        q.recompute()

        // Tax base is only the $100 part → 10% tax = $10
        #expect(q.taxAmount == 10)
        #expect(q.total == 160)
    }

    @Test("Discount reduces total but doesn't go negative on tax")
    func discountSubtracts() {
        let c = container()
        let q = Quote(taxRate: 0)
        c.mainContext.insert(q)

        let part = QuoteLineItem(sortOrder: 0, type: .part, quantity: 1, unitPrice: 100, quote: q)
        let disc = QuoteLineItem(sortOrder: 1, type: .discount, quantity: 1, unitPrice: 15, taxable: false, quote: q)
        for item in [part, disc] {
            item.recomputeLineTotal()
            c.mainContext.insert(item)
        }
        q.lineItems = [part, disc]
        q.recompute()

        #expect(q.subtotalParts == 100)
        #expect(q.discountAmount == 15)
        #expect(q.total == 85)
    }
}
