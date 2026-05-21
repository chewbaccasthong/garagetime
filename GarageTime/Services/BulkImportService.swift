import Foundation

/// A draft parsed from natural-language text or OCR output. User reviews and approves
/// (or edits) before it becomes a `ServiceRecord`.
struct ImportDraft: Sendable, Identifiable, Hashable {
    let id: UUID
    var sourceText: String
    var date: Date?
    var mileage: Int?
    var category: ServiceCategory
    var title: String
    var laborHours: Double
    var partsCost: Double
    var laborCost: Double
    var totalCost: Double
    var vendor: String?
    var confidence: Confidence

    enum Confidence: Sendable, Hashable {
        case high       // both date and total were detected
        case medium     // one of date/total detected
        case low        // only category guessed

        var displayName: String {
            switch self {
            case .high:   return "Looks good"
            case .medium: return "Check it"
            case .low:    return "Needs review"
            }
        }

        var paletteRole: PaletteRole {
            switch self {
            case .high:   return .success
            case .medium: return .warning
            case .low:    return .danger
            }
        }
    }

    init(
        id: UUID = UUID(),
        sourceText: String = "",
        date: Date? = nil,
        mileage: Int? = nil,
        category: ServiceCategory = .other,
        title: String = "",
        laborHours: Double = 0,
        partsCost: Double = 0,
        laborCost: Double = 0,
        totalCost: Double = 0,
        vendor: String? = nil,
        confidence: Confidence = .low
    ) {
        self.id = id
        self.sourceText = sourceText
        self.date = date
        self.mileage = mileage
        self.category = category
        self.title = title
        self.laborHours = laborHours
        self.partsCost = partsCost
        self.laborCost = laborCost
        self.totalCost = totalCost
        self.vendor = vendor
        self.confidence = confidence
    }
}

protocol BulkImportParsing: Sendable {
    /// Parse a chunk of free text into a list of drafts. Each non-blank line becomes
    /// one draft; multi-line entries can be separated by blank lines.
    func parseText(_ text: String) -> [ImportDraft]

    /// Parse the recognized text from a single receipt scan into a single draft.
    /// Mostly delegates to `ReceiptOCRing` but normalizes into an `ImportDraft`.
    func parseReceipt(_ text: String, ocr: ReceiptOCRing) -> ImportDraft

    /// Parse handwritten OCR output, which tends to be noisier — uses the same NL parser
    /// but lower expectations on field detection.
    func parseHandwriting(_ text: String) -> [ImportDraft]
}

struct RealBulkImportService: BulkImportParsing {

    // MARK: - Public API

    func parseText(_ text: String) -> [ImportDraft] {
        // Split on blank lines OR on hard-newline if the line is dense (one record per line).
        let blocks = blocksFrom(text)
        return blocks.compactMap { parseBlock($0) }
    }

    func parseReceipt(_ text: String, ocr: ReceiptOCRing) -> ImportDraft {
        let receipt = ocr.parse(text: text)
        let categoryGuess = guessCategory(in: text) ?? .other
        let mileageGuess = parseMileage(in: text)
        let title = receipt.vendor ?? categoryGuess.displayName
        let confidence: ImportDraft.Confidence =
            (receipt.total != nil && receipt.date != nil) ? .high :
            (receipt.total != nil || receipt.date != nil) ? .medium : .low

        return ImportDraft(
            sourceText: text,
            date: receipt.date,
            mileage: mileageGuess,
            category: categoryGuess,
            title: title,
            laborHours: 0,
            partsCost: receipt.total ?? 0,
            laborCost: 0,
            totalCost: receipt.total ?? 0,
            vendor: receipt.vendor,
            confidence: confidence
        )
    }

    func parseHandwriting(_ text: String) -> [ImportDraft] {
        // Handwriting OCR is noisier; treat the whole blob as a single block first, then
        // fall back to per-line if that fails.
        if let single = parseBlock(text) {
            return [single]
        }
        return parseText(text)
    }

    // MARK: - Block parsing

    private func blocksFrom(_ text: String) -> [String] {
        // If the text contains blank-line separators, split there. Otherwise split per line.
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n")
        if normalized.contains("\n\n") {
            return normalized
                .components(separatedBy: "\n\n")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }
        return normalized
            .split(separator: "\n")
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private func parseBlock(_ block: String) -> ImportDraft? {
        guard !block.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        let date = parseDate(in: block)
        let mileage = parseMileage(in: block)
        let category = guessCategory(in: block) ?? .other
        let amounts = parseAmounts(in: block)
        let total = amounts.max() ?? 0
        let hours = parseHours(in: block)
        let title = inferTitle(from: block, category: category)

        var confidence: ImportDraft.Confidence = .low
        let signals = [date != nil, total > 0, mileage != nil, hours > 0].filter { $0 }.count
        if signals >= 3      { confidence = .high }
        else if signals == 2 { confidence = .high }
        else if signals == 1 { confidence = .medium }

        return ImportDraft(
            sourceText: block,
            date: date,
            mileage: mileage,
            category: category,
            title: title,
            laborHours: hours,
            partsCost: total > 0 ? total : 0,
            laborCost: 0,
            totalCost: total,
            vendor: nil,
            confidence: confidence
        )
    }

    // MARK: - Field extraction

    /// Best date from a block. Picks the most recent past date if multiple.
    func parseDate(in block: String) -> Date? {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
        let range = NSRange(block.startIndex..., in: block)
        let matches = detector?.matches(in: block, range: range) ?? []
        let dates = matches.compactMap { $0.date }
        let now = Date()
        return dates.filter { $0 <= now }.max() ?? dates.first
    }

    /// "76,000 mi" / "76000 miles" / "76k mi" / "at 76,000"
    func parseMileage(in block: String) -> Int? {
        // Pattern: optional "at"/"@" followed by digits (with optional commas) and an optional unit
        let patterns = [
            #"(\d{1,3}(?:,\d{3})+|\d{4,7})\s*(?:mi|miles|km|kilometers)\b"#,
            #"@\s*(\d{1,3}(?:,\d{3})+|\d{4,7})\b"#,
            #"\bat\s+(\d{1,3}(?:,\d{3})+|\d{4,7})\b"#,
        ]
        for pat in patterns {
            if let r = try? NSRegularExpression(pattern: pat, options: [.caseInsensitive]),
               let m = r.firstMatch(in: block, range: NSRange(block.startIndex..., in: block)),
               let g = Range(m.range(at: 1), in: block) {
                let cleaned = block[g].replacingOccurrences(of: ",", with: "")
                if let n = Int(cleaned) { return n }
            }
        }
        return nil
    }

    /// All dollar-style amounts in a block.
    /// Pass 1 captures decimals ($54.99 / 1,234.56). Pass 2 catches bare $-prefixed
    /// integers ($54) only where they didn't already overlap a decimal match — so
    /// "$54.99" doesn't double-count as both 54.99 and 54.
    func parseAmounts(in block: String) -> [Double] {
        var found: [Double] = []
        var consumedRanges: [NSRange] = []

        let decimalPattern = #"\$?\s?((?:\d{1,3}(?:,\d{3})+|\d{1,7})\.\d{2})"#
        if let r = try? NSRegularExpression(pattern: decimalPattern) {
            let full = NSRange(block.startIndex..., in: block)
            r.enumerateMatches(in: block, range: full) { match, _, _ in
                guard let match,
                      let g = Range(match.range(at: 1), in: block) else { return }
                let cleaned = block[g].replacingOccurrences(of: ",", with: "")
                if let n = Double(cleaned) {
                    found.append(n)
                    consumedRanges.append(match.range)
                }
            }
        }

        let intPattern = #"\$\s?(\d{1,7})\b"#
        if let r = try? NSRegularExpression(pattern: intPattern) {
            let full = NSRange(block.startIndex..., in: block)
            r.enumerateMatches(in: block, range: full) { match, _, _ in
                guard let match,
                      let g = Range(match.range(at: 1), in: block) else { return }
                if consumedRanges.contains(where: { NSIntersectionRange($0, match.range).length > 0 }) {
                    return
                }
                if let n = Double(block[g]) {
                    found.append(n)
                }
            }
        }

        return found
    }

    /// "2 hrs" / "2.5 hours" / "30 min" / "1h 15m"
    func parseHours(in block: String) -> Double {
        // "X hrs"
        if let r = try? NSRegularExpression(pattern: #"\b(\d+(?:\.\d+)?)\s*(hrs?|hours?)\b"#, options: [.caseInsensitive]),
           let m = r.firstMatch(in: block, range: NSRange(block.startIndex..., in: block)),
           let g = Range(m.range(at: 1), in: block),
           let v = Double(block[g]) {
            return v
        }
        // "X min"
        if let r = try? NSRegularExpression(pattern: #"\b(\d+)\s*(min|mins|minutes)\b"#, options: [.caseInsensitive]),
           let m = r.firstMatch(in: block, range: NSRange(block.startIndex..., in: block)),
           let g = Range(m.range(at: 1), in: block),
           let v = Double(block[g]) {
            return v / 60.0
        }
        return 0
    }

    /// Crude keyword-based category guess. Returns nil if nothing matched.
    func guessCategory(in block: String) -> ServiceCategory? {
        let lower = block.lowercased()
        let map: [(needles: [String], category: ServiceCategory)] = [
            (["oil change", "oil + filter", "oil and filter", "engine oil", "0w-20", "5w-30", "10w-40"], .oilChange),
            (["tire rotation", "tires rotated", "rotate tires"], .tireRotation),
            (["brake pad", "brake pads", "brake job", "rotors", "brake rotor", "calipers"], .brakes),
            (["new tires", "tire mount", "tire change", "rear tire", "front tire"], .wheelsTires),
            (["spark plug", "plugs", "ignition coil"], .electrical),
            (["coolant", "antifreeze", "radiator flush"], .cooling),
            (["transmission fluid", "atf", "trans fluid"], .transmission),
            (["air filter", "cabin filter", "engine filter"], .filters),
            (["chain lube", "chain clean", "chain oil"], .chain),
            (["chain adjust", "chain tension"], .chain),
            (["valve clearance", "valve adjustment"], .valves),
            (["fork oil", "fork seals"], .forks),
            (["brake fluid"], .brakes),
            (["fuel pump", "fuel filter", "injector"], .fuel),
            (["alternator", "starter", "battery"], .battery),
            (["state inspection", "safety inspection"], .inspection),
            (["detail", "wash and wax", "ceramic coat"], .detail),
            (["suspension", "shocks", "struts"], .suspension),
            (["exhaust", "muffler"], .exhaust),
            (["mod ", "modification", "tune"], .modification),
        ]
        for (needles, category) in map {
            if needles.contains(where: lower.contains) {
                return category
            }
        }
        return nil
    }

    /// Sentence-case the first chunk that looks like a service description.
    func inferTitle(from block: String, category: ServiceCategory) -> String {
        // Strip leading date / mileage / dollar amounts, keep the meaningful body.
        var s = block
        s = s.replacingOccurrences(of: #"\$\d[\d,.]*"#, with: "", options: .regularExpression)
        s = s.replacingOccurrences(of: #"\b\d{1,3}(?:[/-]\d{1,2}){1,2}(?:[/-]\d{2,4})?"#, with: "", options: .regularExpression)
        s = s.replacingOccurrences(of: #"\b\d{1,3}(?:,\d{3})*\s*(mi|miles|km)\b"#, with: "", options: [.regularExpression, .caseInsensitive])
        s = s.replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
        s = s.trimmingCharacters(in: CharacterSet(charactersIn: " -–—,.|;"))
        if s.isEmpty { return category.displayName }
        // Cap at ~64 chars
        let trimmed = String(s.prefix(80))
        return trimmed
    }
}

/// In-memory fake — returns canned drafts.
final class InMemoryBulkImportService: BulkImportParsing, @unchecked Sendable {
    var fixedDrafts: [ImportDraft] = []
    var fixedReceiptDraft: ImportDraft = ImportDraft()

    func parseText(_ text: String) -> [ImportDraft] { fixedDrafts }
    func parseReceipt(_ text: String, ocr: ReceiptOCRing) -> ImportDraft { fixedReceiptDraft }
    func parseHandwriting(_ text: String) -> [ImportDraft] { fixedDrafts }
}
