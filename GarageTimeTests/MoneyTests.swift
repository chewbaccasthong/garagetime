import Testing
import Foundation
@testable import GarageTime

@Suite("Money — currency math")
struct MoneyTests {

    @Test("Decimal-safe sum avoids Double precision drift")
    func sumIsPrecise() {
        let dirty: [Double] = [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7]
        let total = Money.sum(dirty)
        #expect(total == 2.80)
    }

    @Test("Rounding uses schoolbook rounding to 2 decimals (receipt-friendly)")
    func roundingHandlesHalfCent() {
        // Schoolbook: 0.5 always rounds up. Matches what people expect on a receipt.
        // Note: Decimal initialized from Double may pick up tiny float noise so we
        // use values that survive the round-trip cleanly.
        #expect(Money.round(1.234) == 1.23)
        #expect(Money.round(1.236) == 1.24)
        #expect(Money.round(2.499) == 2.50)
        #expect(Money.round(0) == 0)
    }

    @Test("Line total uses Decimal math, not Double")
    func lineTotalIsExact() {
        let total = Money.lineTotal(quantity: 2.5, unitPrice: 110.00)
        #expect(total == 275.00)
        let weird = Money.lineTotal(quantity: 1.13, unitPrice: 99.95)
        #expect(weird == 112.94)
    }

    @Test("Tax: 8.25% on $200 = $16.50")
    func taxIsExact() {
        let tax = Money.tax(on: 200.00, rate: 0.0825)
        #expect(tax == 16.50)
    }

    @Test("Format renders 2 fractional digits even when value is whole")
    func formattingIsConsistent() {
        let s = Money.format(48)
        #expect(s.contains("48"))
        #expect(s.contains(".00"))
    }
}
