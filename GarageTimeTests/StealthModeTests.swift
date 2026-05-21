import Testing
import Foundation
@testable import GarageTime

@Suite("Stealth mode — partner-friendly amounts")
struct StealthModeTests {

    @Test("displayCost equals format when stealth is off")
    func offShowsReal() {
        Money.stealthEnabled = false
        let real = Money.format(700)
        let display = Money.displayCost(700)
        #expect(real == display)
    }

    @Test("displayCost scales by stealth factor when on")
    func onScalesAmount() {
        Money.stealthEnabled = true
        Money.stealthFactor = 0.2
        // $700 × 0.2 = $140
        let display = Money.displayCost(700)
        #expect(display.contains("140"))
        Money.stealthEnabled = false  // cleanup
    }

    @Test("realCost ignores stealth setting")
    func realIgnoresStealth() {
        Money.stealthEnabled = true
        Money.stealthFactor = 0.1
        let real = Money.realCost(500)
        #expect(real.contains("500"))
        Money.stealthEnabled = false
    }

    @Test("factor is clamped to [0.01, 1.0]")
    func factorClamps() {
        Money.stealthFactor = 2.5
        #expect(Money.stealthFactor <= 1.0)
        Money.stealthFactor = -0.5
        #expect(Money.stealthFactor >= 0.01)
        Money.stealthFactor = 0.2  // restore
    }
}
