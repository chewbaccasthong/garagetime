import Foundation
import SwiftData

protocol QuoteNumberMinting: Sendable {
    /// Atomically returns the next quote number string and bumps the counter.
    /// Uses the prefix + year + 4-digit sequence on `ShopSettings`.
    @MainActor func nextNumber(in context: ModelContext) -> String
}

struct RealQuoteNumberService: QuoteNumberMinting {
    @MainActor func nextNumber(in context: ModelContext) -> String {
        // Find or create the singleton ShopSettings row
        let descriptor = FetchDescriptor<ShopSettings>()
        let settings: ShopSettings
        if let existing = (try? context.fetch(descriptor))?.first {
            settings = existing
        } else {
            let new = ShopSettings()
            context.insert(new)
            settings = new
        }

        let year = Calendar.current.component(.year, from: Date())
        let next = max(settings.quoteNumberStart, settings.quoteNumberLastUsed + 1)
        settings.quoteNumberLastUsed = next
        settings.updatedAt = Date()

        try? context.save()

        return String(format: "%@-%04d-%04d", settings.quoteNumberPrefix, year, next)
    }
}

final class InMemoryQuoteNumberService: QuoteNumberMinting, @unchecked Sendable {
    private var seq: Int = 0
    @MainActor func nextNumber(in context: ModelContext) -> String {
        seq += 1
        return String(format: "TEST-%04d", seq)
    }
}
