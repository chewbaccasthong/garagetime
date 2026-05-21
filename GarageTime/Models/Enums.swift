import Foundation

// MARK: - Vehicle classification

enum VehicleType: String, Codable, CaseIterable, Identifiable, Sendable {
    case car
    case truck
    case motorcycle
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .car:        return "Car"
        case .truck:      return "Truck"
        case .motorcycle: return "Motorcycle"
        case .other:      return "Other"
        }
    }

    var sfSymbol: String {
        switch self {
        case .car:        return "car.fill"
        case .truck:      return "truck.box.fill"
        case .motorcycle: return "scooter"   // SF Symbol "motorcycle" exists from iOS 17
        case .other:      return "wrench.and.screwdriver.fill"
        }
    }
}

enum Powertrain: String, Codable, CaseIterable, Identifiable, Sendable {
    case ic
    case hybrid
    case ev

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .ic:     return "Internal Combustion"
        case .hybrid: return "Hybrid"
        case .ev:     return "Electric"
        }
    }
}

enum OwnerType: String, Codable, CaseIterable, Identifiable, Sendable {
    case personal
    case customer

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .personal: return "Personal"
        case .customer: return "Customer"
        }
    }
}

enum MileageUnit: String, Codable, CaseIterable, Identifiable, Sendable {
    case mi
    case km

    var id: String { rawValue }
    var displayName: String { rawValue }

    var longName: String {
        switch self {
        case .mi: return "Miles"
        case .km: return "Kilometers"
        }
    }
}

enum VolumeUnit: String, Codable, CaseIterable, Identifiable, Sendable {
    case gallons
    case liters

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .gallons: return "Gallons"
        case .liters:  return "Liters"
        }
    }

    var shortName: String {
        switch self {
        case .gallons: return "gal"
        case .liters:  return "L"
        }
    }
}

// MARK: - Service records

enum ServiceCategory: String, Codable, CaseIterable, Identifiable, Sendable {
    case oilChange
    case tireRotation
    case brakes
    case suspension
    case engine
    case transmission
    case cooling
    case fuel
    case electrical
    case bodywork
    case exhaust
    case wheelsTires
    case detail
    case inspection
    case modification
    case fluids
    case filters
    case chain         // motorcycle
    case valves        // motorcycle
    case forks         // motorcycle
    case battery
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .oilChange:    return "Oil change"
        case .tireRotation: return "Tire rotation"
        case .brakes:       return "Brakes"
        case .suspension:   return "Suspension"
        case .engine:       return "Engine"
        case .transmission: return "Transmission"
        case .cooling:      return "Cooling"
        case .fuel:         return "Fuel system"
        case .electrical:   return "Electrical"
        case .bodywork:     return "Bodywork"
        case .exhaust:      return "Exhaust"
        case .wheelsTires:  return "Wheels & tires"
        case .detail:       return "Detail"
        case .inspection:   return "Inspection"
        case .modification: return "Modification"
        case .fluids:       return "Fluids"
        case .filters:      return "Filters"
        case .chain:        return "Chain"
        case .valves:       return "Valves"
        case .forks:        return "Forks"
        case .battery:      return "Battery"
        case .other:        return "Other"
        }
    }

    var sfSymbol: String {
        switch self {
        case .oilChange:    return "drop.fill"
        case .tireRotation: return "arrow.triangle.2.circlepath"
        case .brakes:       return "octagon.fill"
        case .suspension:   return "spring"
        case .engine:       return "engine.combustion.fill"
        case .transmission: return "gearshape.2.fill"
        case .cooling:      return "thermometer.snowflake"
        case .fuel:         return "fuelpump.fill"
        case .electrical:   return "bolt.fill"
        case .bodywork:     return "paintpalette.fill"
        case .exhaust:      return "wind"
        case .wheelsTires:  return "circle.dotted"
        case .detail:       return "sparkles"
        case .inspection:   return "checkmark.shield.fill"
        case .modification: return "wand.and.stars"
        case .fluids:       return "drop.triangle"
        case .filters:      return "line.3.horizontal.decrease.circle.fill"
        case .chain:        return "link"
        case .valves:       return "valve.fill"
        case .forks:        return "rectangle.split.2x1"
        case .battery:      return "battery.100"
        case .other:        return "wrench.adjustable.fill"
        }
    }
}

enum PerformedBy: String, Codable, CaseIterable, Identifiable, Sendable {
    case diy
    case shop

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .diy:  return "DIY"
        case .shop: return "Shop"
        }
    }
}

// MARK: - Quotes

enum QuoteStatus: String, Codable, CaseIterable, Identifiable, Sendable {
    case draft
    case sent
    case approved
    case declined
    case expired
    case completed

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .draft:     return "Draft"
        case .sent:      return "Sent"
        case .approved:  return "Approved"
        case .declined:  return "Declined"
        case .expired:   return "Expired"
        case .completed: return "Completed"
        }
    }

    /// Colors used in status pills.
    var paletteRole: PaletteRole {
        switch self {
        case .draft:     return .neutral
        case .sent:      return .info
        case .approved:  return .success
        case .declined:  return .danger
        case .expired:   return .warning
        case .completed: return .success
        }
    }
}

enum QuoteLineItemType: String, Codable, CaseIterable, Identifiable, Sendable {
    case labor
    case part
    case fee
    case discount

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .labor:    return "Labor"
        case .part:     return "Part"
        case .fee:      return "Fee"
        case .discount: return "Discount"
        }
    }

    var sfSymbol: String {
        switch self {
        case .labor:    return "wrench.and.screwdriver.fill"
        case .part:     return "shippingbox.fill"
        case .fee:      return "dollarsign.circle.fill"
        case .discount: return "tag.fill"
        }
    }
}

// MARK: - Reminders

enum ReminderCategory: String, Codable, CaseIterable, Identifiable, Sendable {
    case oilChange
    case tireRotation
    case brakes
    case coolant
    case transmission
    case cabinFilter
    case airFilter
    case sparkPlugs
    case chainLube
    case chainAdjust
    case valves
    case forkOil
    case brakeFluid
    case tires
    case battery
    case inspection
    case registration
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .oilChange:    return "Oil change"
        case .tireRotation: return "Tire rotation"
        case .brakes:       return "Brakes"
        case .coolant:      return "Coolant flush"
        case .transmission: return "Transmission service"
        case .cabinFilter:  return "Cabin air filter"
        case .airFilter:    return "Engine air filter"
        case .sparkPlugs:   return "Spark plugs"
        case .chainLube:    return "Chain lube"
        case .chainAdjust:  return "Chain adjust"
        case .valves:       return "Valve clearance"
        case .forkOil:      return "Fork oil"
        case .brakeFluid:   return "Brake fluid"
        case .tires:        return "Tires"
        case .battery:      return "12V battery"
        case .inspection:   return "State inspection"
        case .registration: return "Registration"
        case .other:        return "Custom"
        }
    }

    var sfSymbol: String {
        switch self {
        case .oilChange:    return "drop.fill"
        case .tireRotation: return "arrow.triangle.2.circlepath"
        case .brakes:       return "octagon.fill"
        case .coolant:      return "thermometer.snowflake"
        case .transmission: return "gearshape.2.fill"
        case .cabinFilter:  return "air.purifier.fill"
        case .airFilter:    return "wind"
        case .sparkPlugs:   return "bolt.fill"
        case .chainLube:    return "link"
        case .chainAdjust:  return "link.badge.plus"
        case .valves:       return "valve.fill"
        case .forkOil:      return "drop.triangle"
        case .brakeFluid:   return "drop.halffull"
        case .tires:        return "circle.dotted"
        case .battery:      return "battery.100"
        case .inspection:   return "checkmark.shield.fill"
        case .registration: return "doc.plaintext.fill"
        case .other:        return "bell.fill"
        }
    }
}

enum ReminderUrgency: String, Codable, Sendable {
    case ok          // > 30 days OR > 500 miles away
    case dueSoon     // within window
    case overdue     // past

    var paletteRole: PaletteRole {
        switch self {
        case .ok:       return .success
        case .dueSoon:  return .warning
        case .overdue:  return .danger
        }
    }

    var displayName: String {
        switch self {
        case .ok:       return "On track"
        case .dueSoon:  return "Due soon"
        case .overdue:  return "Overdue"
        }
    }
}

// MARK: - Palette role (shared across status pills, badges, urgency)

enum PaletteRole: Sendable {
    case neutral
    case info
    case success
    case warning
    case danger
    case accent
}

// MARK: - User role (mechanic vs customer)

enum UserRole: String, Codable, CaseIterable, Identifiable, Sendable {
    case mechanic
    case customer

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .mechanic: return "Mechanic"
        case .customer: return "Customer"
        }
    }

    var blurb: String {
        switch self {
        case .mechanic: return "Manage customers, vehicles, parts, quotes, and incoming job requests."
        case .customer: return "Track your vehicles, look up cost estimates, and request work from your mechanic."
        }
    }

    var sfSymbol: String {
        switch self {
        case .mechanic: return "wrench.and.screwdriver.fill"
        case .customer: return "person.fill"
        }
    }
}

// MARK: - Job request lifecycle

enum JobStatus: String, Codable, CaseIterable, Identifiable, Sendable {
    case pending        // customer just submitted
    case accepted       // mechanic accepted, scheduling next
    case scheduled      // accepted + has a scheduledDate
    case declined       // mechanic said no
    case quoted         // mechanic generated a quote from this request
    case completed      // work done
    case cancelled      // customer pulled it

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .pending:   return "Pending"
        case .accepted:  return "Accepted"
        case .scheduled: return "Scheduled"
        case .declined:  return "Declined"
        case .quoted:    return "Quoted"
        case .completed: return "Completed"
        case .cancelled: return "Cancelled"
        }
    }

    var paletteRole: PaletteRole {
        switch self {
        case .pending:   return .warning
        case .accepted:  return .info
        case .scheduled: return .accent
        case .declined:  return .danger
        case .quoted:    return .info
        case .completed: return .success
        case .cancelled: return .neutral
        }
    }

    var sfSymbol: String {
        switch self {
        case .pending:   return "hourglass"
        case .accepted:  return "checkmark.circle.fill"
        case .scheduled: return "calendar.badge.checkmark"
        case .declined:  return "xmark.circle.fill"
        case .quoted:    return "doc.text.fill"
        case .completed: return "checkmark.seal.fill"
        case .cancelled: return "minus.circle.fill"
        }
    }
}

// MARK: - Weekday for availability

enum Weekday: Int, Codable, CaseIterable, Identifiable, Sendable {
    case sunday = 1, monday, tuesday, wednesday, thursday, friday, saturday

    var id: Int { rawValue }

    var short: String {
        switch self {
        case .sunday: return "Sun"
        case .monday: return "Mon"
        case .tuesday: return "Tue"
        case .wednesday: return "Wed"
        case .thursday: return "Thu"
        case .friday: return "Fri"
        case .saturday: return "Sat"
        }
    }

    var full: String {
        switch self {
        case .sunday: return "Sunday"
        case .monday: return "Monday"
        case .tuesday: return "Tuesday"
        case .wednesday: return "Wednesday"
        case .thursday: return "Thursday"
        case .friday: return "Friday"
        case .saturday: return "Saturday"
        }
    }
}
