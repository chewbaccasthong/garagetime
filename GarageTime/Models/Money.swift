import Foundation

/// Currency formatting + safe Decimal math. Storage is `Double` (CloudKit-friendly).
/// All arithmetic goes through `Decimal` to avoid Float precision drift on totals.
enum Money {

    // MARK: - Formatting

    /// "$1,234.56" (or local currency). Uses the device's locale.
    static func format(_ value: Double, currencyCode: String? = nil) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        if let code = currencyCode { f.currencyCode = code }
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        return f.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    /// "1,234.56" — no currency symbol, fixed 2-decimal. For totals row alignment.
    static func formatBare(_ value: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        return f.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    // MARK: - Stealth mode (partner-friendly amounts)

    /// True if the user has flipped on the "partner-friendly amounts" toggle. When on,
    /// all customer-facing amounts are multiplied by `stealthFactor`. PDF exports,
    /// service-record editor, and quote builder always show real values — stealth is a
    /// *display* concept for casual browsing, not a falsification of records.
    static var stealthEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "wb.stealth.enabled") }
        set { UserDefaults.standard.set(newValue, forKey: "wb.stealth.enabled") }
    }

    /// 0.0 … 1.0 — the fraction of the real amount displayed when stealth is on.
    /// Default `0.2` (show 20% of actual: $700 → "$140").
    static var stealthFactor: Double {
        get {
            let raw = UserDefaults.standard.double(forKey: "wb.stealth.factor")
            return raw <= 0 ? 0.2 : min(raw, 1.0)
        }
        set { UserDefaults.standard.set(max(0.01, min(newValue, 1.0)), forKey: "wb.stealth.factor") }
    }

    /// "$140.00" (stealth on) or "$700.00" (off). Use this anywhere you display a cost
    /// in a place a partner might see — totals on lists, stat blocks, headers.
    static func displayCost(_ value: Double) -> String {
        let v = stealthEnabled ? value * stealthFactor : value
        return format(v)
    }

    /// The actual stored value, ignoring stealth. Use in editors, PDFs, exports — anywhere
    /// the real number must be correct.
    static func realCost(_ value: Double) -> String {
        format(value)
    }

    // MARK: - Math (Decimal in, Double out, banker-rounded to 2 dp)

    static func round(_ value: Double) -> Double {
        scrub(round(decimal: Decimal(value)).asDouble())
    }

    static func round(decimal value: Decimal) -> Decimal {
        var rounded = Decimal()
        var input = value
        // Schoolbook (.plain) rounding matches what people expect on a receipt:
        // 0.5 always rounds up. Banker's rounding makes "20.625" → 20.62 which surprises users.
        NSDecimalRound(&rounded, &input, 2, .plain)
        return rounded
    }

    /// Sum a list of `Double` line-totals with Decimal precision.
    static func sum(_ values: [Double]) -> Double {
        let total = values.reduce(Decimal(0)) { $0 + Decimal($1) }
        return scrub(round(decimal: total).asDouble())
    }

    /// Multiply quantity × unitPrice as Decimal, return Double rounded to cents.
    /// Final Double is re-rounded in IEEE-754 space to scrub any tiny conversion noise.
    static func lineTotal(quantity: Double, unitPrice: Double) -> Double {
        let q = Decimal(quantity)
        let u = Decimal(unitPrice)
        return scrub(round(decimal: q * u).asDouble())
    }

    /// Round to 2 dp in Double-space to clean up artifacts like 112.94000000000001.
    private static func scrub(_ value: Double) -> Double {
        (value * 100).rounded() / 100
    }

    /// Apply a percentage tax (e.g. 0.0875 for 8.75%) to a base amount.
    static func tax(on base: Double, rate: Double) -> Double {
        scrub(round(decimal: Decimal(base) * Decimal(rate)).asDouble())
    }
}

extension Decimal {
    func asDouble() -> Double {
        NSDecimalNumber(decimal: self).doubleValue
    }
}
