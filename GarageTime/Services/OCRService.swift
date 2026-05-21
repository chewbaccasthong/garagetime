import Foundation

/// User-confirmable receipt draft. Never silently applied to a record.
struct ReceiptDraft: Sendable, Equatable {
    var date: Date?
    var vendor: String?
    var total: Double?
    var rawText: String
    static let empty = ReceiptDraft(date: nil, vendor: nil, total: nil, rawText: "")
}

protocol ReceiptOCRing: Sendable {
    /// Parse extracted text (from VisionKit / DataScannerViewController) into a draft.
    func parse(text: String) -> ReceiptDraft
}

struct RealOCRService: ReceiptOCRing {

    func parse(text: String) -> ReceiptDraft {
        let lines = text.split(separator: "\n").map(String.init)
        let total = bestTotal(in: lines)
        let date = bestDate(in: text)
        let vendor = bestVendor(in: lines)
        return ReceiptDraft(date: date, vendor: vendor, total: total, rawText: text)
    }

    // MARK: - Totals

    private static let totalKeywords = ["total", "grand total", "amount due", "balance", "amount paid", "amount"]
    private static let totalNegatives = ["subtotal", "sub total", "tax", "change", "tip"]

    /// Prefer the largest "Total:"-tagged amount. Fall back to the largest dollar value on the receipt.
    private func bestTotal(in lines: [String]) -> Double? {
        var taggedAmounts: [Double] = []
        var allAmounts: [Double] = []

        for line in lines {
            let lower = line.lowercased()
            let amounts = parseAmounts(in: line)
            allAmounts.append(contentsOf: amounts)
            if Self.totalNegatives.contains(where: lower.contains) { continue }
            if Self.totalKeywords.contains(where: lower.contains) {
                taggedAmounts.append(contentsOf: amounts)
            }
        }

        return taggedAmounts.max() ?? allAmounts.max()
    }

    private func parseAmounts(in line: String) -> [Double] {
        // Match $123.45 / 123.45 / 1,234.56 (not 4-digit years)
        let pattern = #"\$?\s?-?(?<num>(?:\d{1,3}(?:,\d{3})+|\d{1,7})\.\d{2})\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(line.startIndex..., in: line)
        return regex.matches(in: line, range: range).compactMap { match in
            guard let r = Range(match.range(withName: "num"), in: line) else { return nil }
            let cleaned = line[r].replacingOccurrences(of: ",", with: "")
            return Double(cleaned)
        }
    }

    // MARK: - Dates

    private func bestDate(in text: String) -> Date? {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
        let range = NSRange(text.startIndex..., in: text)
        let matches = detector?.matches(in: text, range: range) ?? []
        let dates = matches.compactMap { $0.date }
        // Prefer the most recent past date
        let now = Date()
        return dates.filter { $0 <= now }.max() ?? dates.first
    }

    // MARK: - Vendor

    /// Heuristic: the first non-empty line that isn't an address, phone, or price.
    private func bestVendor(in lines: [String]) -> String? {
        for raw in lines.prefix(6) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }
            if isLikelyAddress(line) { continue }
            if isLikelyPhone(line) { continue }
            if line.range(of: #"\d+\.\d{2}"#, options: .regularExpression) != nil { continue }
            if line.allSatisfy({ $0.isNumber || $0.isWhitespace }) { continue }
            return line
        }
        return nil
    }

    private func isLikelyAddress(_ line: String) -> Bool {
        line.range(of: #"\b(\d+\s+(N|S|E|W|North|South|East|West)?\s?[A-Z][a-zA-Z]+)\b"#, options: .regularExpression) != nil
    }

    private func isLikelyPhone(_ line: String) -> Bool {
        line.range(of: #"\(?\d{3}\)?[\s.-]?\d{3}[\s.-]?\d{4}"#, options: .regularExpression) != nil
    }
}

final class InMemoryOCRService: ReceiptOCRing, @unchecked Sendable {
    private let lock = NSLock()
    private var _nextDraft: ReceiptDraft
    init(_ draft: ReceiptDraft = .empty) { self._nextDraft = draft }
    func setNextDraft(_ draft: ReceiptDraft) {
        lock.lock(); defer { lock.unlock() }
        _nextDraft = draft
    }
    func parse(text: String) -> ReceiptDraft {
        lock.lock(); defer { lock.unlock() }
        return _nextDraft
    }
}
