import Foundation
import SwiftData

/// A single weekday window the mechanic is available. There can be many per day
/// (e.g. 9-12 + 14-18). Used by the customer-mode UI to show "Mechanic is open Mon–Fri".
@Model
final class MechanicAvailability {
    var id: UUID = UUID()

    /// 1 = Sunday … 7 = Saturday (matches `Weekday.rawValue`).
    var weekdayRaw: Int = Weekday.monday.rawValue

    /// Minutes from midnight (e.g. 9*60 = 540 for 9 am).
    var startMinute: Int = 9 * 60
    var endMinute: Int = 17 * 60

    var isOpen: Bool = true
    var notes: String = ""

    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(
        id: UUID = UUID(),
        weekday: Weekday = .monday,
        startMinute: Int = 9 * 60,
        endMinute: Int = 17 * 60,
        isOpen: Bool = true,
        notes: String = ""
    ) {
        self.id = id
        self.weekdayRaw = weekday.rawValue
        self.startMinute = startMinute
        self.endMinute = endMinute
        self.isOpen = isOpen
        self.notes = notes
    }
}

extension MechanicAvailability {
    var weekday: Weekday {
        get { Weekday(rawValue: weekdayRaw) ?? .monday }
        set { weekdayRaw = newValue.rawValue }
    }

    /// "9:00 AM – 5:00 PM"
    var displayRange: String {
        "\(format(startMinute)) – \(format(endMinute))"
    }

    private func format(_ minute: Int) -> String {
        let hr = minute / 60
        let min = minute % 60
        var comps = DateComponents()
        comps.hour = hr; comps.minute = min
        let date = Calendar.current.date(from: comps) ?? Date()
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: date)
    }
}
