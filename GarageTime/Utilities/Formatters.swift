import Foundation

enum WBFormat {
    static let shortDate: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    static let shortDateTime: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    static let monthYear: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM yyyy"
        return f
    }()

    /// "5 days ago", "in 3 weeks". Uses the system Relative formatter.
    static func relative(_ date: Date, base: Date = Date()) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: base)
    }

    /// "12,345 mi" — locale-aware grouping.
    static func mileage(_ value: Int, unit: MileageUnit = .mi) -> String {
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        let number = nf.string(from: NSNumber(value: value)) ?? "\(value)"
        return "\(number) \(unit.rawValue)"
    }

    /// "8.75%"
    static func percent(_ rate: Double) -> String {
        let nf = NumberFormatter()
        nf.numberStyle = .percent
        nf.minimumFractionDigits = 0
        nf.maximumFractionDigits = 2
        return nf.string(from: NSNumber(value: rate)) ?? "\(rate * 100)%"
    }

    /// "2.5 hrs", "30 min", "1 hr 15 min". Compact, human-readable.
    static func hours(_ value: Double) -> String {
        if value <= 0 { return "0 hrs" }
        if value < 1 {
            let mins = Int((value * 60).rounded())
            return "\(mins) min"
        }
        // Whole hours: "2 hrs"; fractional: "1.5 hrs"
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            let n = Int(value)
            return "\(n) \(n == 1 ? "hr" : "hrs")"
        }
        return String(format: "%.1f hrs", value)
    }
}
