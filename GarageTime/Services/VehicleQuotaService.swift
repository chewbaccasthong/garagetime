import Foundation

/// Reason a vehicle add was blocked.
enum QuotaBlockReason: Sendable, Equatable {
    case tierLimit(allowed: Int)        // hit the hard cap for the tier
    case dailyRateLimit(allowed: Int)   // adding too fast (per 24h)
    case hourlyBurst(allowed: Int)      // adding too fast (per hour)

    var title: String {
        switch self {
        case .tierLimit:        return "Vehicle limit reached"
        case .dailyRateLimit:   return "Slow down — daily limit hit"
        case .hourlyBurst:      return "Too many in a short window"
        }
    }

    var message: String {
        switch self {
        case .tierLimit(let n):
            return "Your plan allows up to \(n) vehicles. Upgrade or buy a vehicle pack to add more."
        case .dailyRateLimit(let n):
            return "Garage Time is built for personal garages and one-person shops — not dealer inventories. You can add up to \(n) vehicles in a 24-hour window."
        case .hourlyBurst(let n):
            return "Looks like a lot of vehicles fast — Garage Time isn't for dealer inventories. You can add \(n) per hour."
        }
    }
}

/// Decision returned by the quota service.
enum QuotaDecision: Sendable, Equatable {
    case allowed
    case blocked(QuotaBlockReason)

    var isAllowed: Bool {
        if case .allowed = self { return true }
        return false
    }
}

protocol VehicleQuotaChecking: Sendable {
    /// Determines whether the user may add another vehicle now, given:
    ///   - currentTotal: existing vehicle count in their store
    ///   - entitlements: the subscription state
    ///   - now: injected for tests
    func check(currentTotal: Int, entitlements: Entitlements, now: Date) -> QuotaDecision

    /// Records that a vehicle was added at `at`. Used for rate-limit windowing.
    func recordAdd(at: Date)

    /// All add timestamps in memory/UserDefaults — useful for tests.
    func recentAdds() -> [Date]
}

/// UserDefaults-backed rate limiter + tier-limit checker.
final class RealVehicleQuotaService: VehicleQuotaChecking, @unchecked Sendable {
    static let shared = RealVehicleQuotaService()

    // Rate limits per tier (per 24h and per 60min).
    // These are intentionally permissive for real users and restrictive for dealer batch-add patterns.
    static let dailyLimit: [SubscriptionTier: Int] = [
        .free:          3,    // 2 base + a small buffer for re-tries
        .customerPlus:  6,    // a customer adding their 5-car family in a day is fine
        .shopStandard:  15,   // active shop onboarding day
        .shopPro:       30,
    ]
    static let hourlyLimit: [SubscriptionTier: Int] = [
        .free:          2,
        .customerPlus:  3,
        .shopStandard:  6,
        .shopPro:       12,
    ]

    private let lock = NSLock()
    private let storageKey = "wb.vehicleQuota.addTimestamps"
    private let maxStoredTimestamps = 200

    func check(currentTotal: Int, entitlements: Entitlements, now: Date = Date()) -> QuotaDecision {
        // 1. Hard tier limit
        let tierCap = PaywallGate.vehicleLimit(for: entitlements)
        if currentTotal >= tierCap {
            return .blocked(.tierLimit(allowed: tierCap))
        }

        // 2. Hourly burst
        let hourlyCap = Self.hourlyLimit[entitlements.tier] ?? 2
        if countAdds(within: 3600, of: now) >= hourlyCap {
            return .blocked(.hourlyBurst(allowed: hourlyCap))
        }

        // 3. Daily window
        let dailyCap = Self.dailyLimit[entitlements.tier] ?? 3
        if countAdds(within: 86_400, of: now) >= dailyCap {
            return .blocked(.dailyRateLimit(allowed: dailyCap))
        }

        return .allowed
    }

    func recordAdd(at: Date = Date()) {
        lock.lock(); defer { lock.unlock() }
        var stamps = loadStampsLocked()
        stamps.append(at)
        // Trim to recent + cap
        let cutoff = at.addingTimeInterval(-7 * 86_400)
        stamps = Array(stamps.filter { $0 >= cutoff }.suffix(maxStoredTimestamps))
        saveStampsLocked(stamps)
    }

    func recentAdds() -> [Date] {
        lock.lock(); defer { lock.unlock() }
        return loadStampsLocked()
    }

    // MARK: - Storage

    private func loadStampsLocked() -> [Date] {
        let raw = UserDefaults.standard.array(forKey: storageKey) as? [Double] ?? []
        return raw.map { Date(timeIntervalSince1970: $0) }
    }

    private func saveStampsLocked(_ stamps: [Date]) {
        let raw = stamps.map { $0.timeIntervalSince1970 }
        UserDefaults.standard.set(raw, forKey: storageKey)
    }

    private func countAdds(within seconds: TimeInterval, of now: Date) -> Int {
        let cutoff = now.addingTimeInterval(-seconds)
        return recentAdds().filter { $0 >= cutoff }.count
    }
}

/// In-memory fake for tests. Holds its own clock for full control.
final class InMemoryVehicleQuotaService: VehicleQuotaChecking, @unchecked Sendable {
    private let lock = NSLock()
    private var stamps: [Date] = []

    func check(currentTotal: Int, entitlements: Entitlements, now: Date) -> QuotaDecision {
        let tierCap = PaywallGate.vehicleLimit(for: entitlements)
        if currentTotal >= tierCap {
            return .blocked(.tierLimit(allowed: tierCap))
        }
        let hourly = RealVehicleQuotaService.hourlyLimit[entitlements.tier] ?? 2
        if countAdds(within: 3600, of: now) >= hourly {
            return .blocked(.hourlyBurst(allowed: hourly))
        }
        let daily = RealVehicleQuotaService.dailyLimit[entitlements.tier] ?? 3
        if countAdds(within: 86_400, of: now) >= daily {
            return .blocked(.dailyRateLimit(allowed: daily))
        }
        return .allowed
    }

    func recordAdd(at: Date) {
        lock.lock(); defer { lock.unlock() }
        stamps.append(at)
    }

    func recentAdds() -> [Date] {
        lock.lock(); defer { lock.unlock() }
        return stamps
    }

    private func countAdds(within seconds: TimeInterval, of now: Date) -> Int {
        let cutoff = now.addingTimeInterval(-seconds)
        return recentAdds().filter { $0 >= cutoff }.count
    }
}
