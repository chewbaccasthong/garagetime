import Testing
import Foundation
@testable import GarageTime

@Suite("OCR — receipt parsing")
struct OCRTests {

    @Test("Picks the largest 'Total:' line over subtotal")
    func picksTotalOverSubtotal() {
        let text = """
        AutoZone
        Brake pads   $54.99
        Subtotal     $54.99
        Tax          $4.54
        Total        $59.53
        """
        let draft = RealOCRService().parse(text: text)
        #expect(draft.total == 59.53)
    }

    @Test("Falls back to the largest dollar value if no Total tag")
    func fallsBackToMaxAmount() {
        let text = """
        O'Reilly
        $12.49
        $87.20
        $3.50
        """
        let draft = RealOCRService().parse(text: text)
        #expect(draft.total == 87.20)
    }

    @Test("Vendor is the first non-numeric line")
    func vendorIsTopLine() {
        let text = """
        Jiffy Lube
        100 Main St
        (555) 123-4567
        Total: $79.95
        """
        let draft = RealOCRService().parse(text: text)
        #expect(draft.vendor == "Jiffy Lube")
    }

    @Test("Empty text returns empty draft")
    func emptyIsEmpty() {
        let draft = RealOCRService().parse(text: "")
        #expect(draft.total == nil)
        #expect(draft.vendor == nil)
    }
}
