import Testing
import Foundation
@testable import GarageTime

@Suite("Bulk import — natural language parser")
struct BulkImportTests {

    private let svc = RealBulkImportService()

    // MARK: - Field extraction

    @Test("Parses standard mm/dd/yyyy dates")
    func parsesSlashDates() {
        let date = svc.parseDate(in: "5/14/2024 oil change")
        #expect(date != nil)
        let comps = Calendar.current.dateComponents([.year, .month, .day], from: date!)
        #expect(comps.year == 2024)
        #expect(comps.month == 5)
        #expect(comps.day == 14)
    }

    @Test("Parses ISO-style dates")
    func parsesISODates() {
        let date = svc.parseDate(in: "2024-01-10 chain lube")
        #expect(date != nil)
    }

    @Test("Extracts mileage with comma separator")
    func parsesMileageWithComma() {
        #expect(svc.parseMileage(in: "oil change at 78,421 mi") == 78421)
        #expect(svc.parseMileage(in: "brakes 75200 miles") == 75200)
        #expect(svc.parseMileage(in: "@ 6,100") == 6100)
    }

    @Test("Extracts dollar amounts as Doubles")
    func parsesAmounts() {
        let amounts = svc.parseAmounts(in: "Brake pads $54.99 tax $4.54 total $59.53")
        #expect(amounts.contains(54.99))
        #expect(amounts.contains(59.53))
    }

    @Test("Hours from text: 2 hrs / 30 min / 2.5 hours")
    func parsesHours() {
        #expect(svc.parseHours(in: "2 hrs labor") == 2.0)
        #expect(svc.parseHours(in: "2.5 hours") == 2.5)
        let half = svc.parseHours(in: "30 min")
        #expect(half > 0.49 && half < 0.51)
    }

    @Test("Category guess matches common keywords")
    func categoryGuess() {
        #expect(svc.guessCategory(in: "oil change synthetic 0w-20") == .oilChange)
        #expect(svc.guessCategory(in: "front brake pads + rotors") == .brakes)
        #expect(svc.guessCategory(in: "chain lube") == .chain)
        #expect(svc.guessCategory(in: "transmission fluid") == .transmission)
        #expect(svc.guessCategory(in: "completely unrelated note") == nil)
    }

    // MARK: - End-to-end parseText

    @Test("Three lines → three drafts with date+mileage+cost detected")
    func parsesMultipleLines() {
        let text = """
        5/14/2024 oil change at 78,000 mi — $48
        2024-04-02 brake pads $110 at 75,200 mi
        2024-01-10 chain lube 6100 mi
        """
        let drafts = svc.parseText(text)
        #expect(drafts.count == 3)

        let oil = drafts[0]
        #expect(oil.category == .oilChange)
        #expect(oil.mileage == 78000)
        #expect(oil.totalCost == 48)
        #expect(oil.date != nil)
        #expect(oil.confidence == .high)

        let brakes = drafts[1]
        #expect(brakes.category == .brakes)
        #expect(brakes.mileage == 75200)
        #expect(brakes.totalCost == 110)

        let chain = drafts[2]
        #expect(chain.category == .chain)
        #expect(chain.mileage == 6100)
    }

    @Test("Blank-line separated blocks each become one draft")
    func parsesBlankLineSeparator() {
        let text = """
        5/14/2024
        Oil change
        $48 at 78,000 mi

        2024-04-02
        New tires $850
        """
        let drafts = svc.parseText(text)
        #expect(drafts.count == 2)
    }

    @Test("Receipt scan output → single draft")
    func receiptScan() {
        let text = """
        AutoZone
        Front brake pads $54.99
        Tax $4.54
        Total $59.53
        4/2/2024
        """
        let draft = svc.parseReceipt(text, ocr: RealOCRService())
        #expect(draft.totalCost == 59.53)
        #expect(draft.category == .brakes)
        #expect(draft.date != nil)
        #expect(draft.confidence == .high)
    }

    @Test("Empty input returns no drafts (not a crash)")
    func emptyText() {
        #expect(svc.parseText("").isEmpty)
        #expect(svc.parseText("   \n  \n").isEmpty)
    }
}
