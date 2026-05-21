import Foundation
import SwiftData

@Model
final class MaintenanceReminder {
    var id: UUID = UUID()
    var title: String = ""
    var categoryRaw: String = ReminderCategory.other.rawValue

    /// Either of these may be zero (meaning "ignore that axis").
    var intervalMiles: Int = 0
    var intervalMonths: Int = 0

    var lastServiceDate: Date?
    var lastServiceMileage: Int = 0

    var isActive: Bool = true
    var notifyDaysBefore: Int = 14
    var notifyMilesBefore: Int = 500

    var vehicle: Vehicle?

    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(
        id: UUID = UUID(),
        title: String = "",
        category: ReminderCategory = .other,
        intervalMiles: Int = 0,
        intervalMonths: Int = 0,
        lastServiceDate: Date? = nil,
        lastServiceMileage: Int = 0,
        isActive: Bool = true,
        notifyDaysBefore: Int = 14,
        notifyMilesBefore: Int = 500,
        vehicle: Vehicle? = nil
    ) {
        self.id = id
        self.title = title
        self.categoryRaw = category.rawValue
        self.intervalMiles = intervalMiles
        self.intervalMonths = intervalMonths
        self.lastServiceDate = lastServiceDate
        self.lastServiceMileage = lastServiceMileage
        self.isActive = isActive
        self.notifyDaysBefore = notifyDaysBefore
        self.notifyMilesBefore = notifyMilesBefore
        self.vehicle = vehicle
    }
}

extension MaintenanceReminder {
    var category: ReminderCategory {
        get { ReminderCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }

    /// Display title — uses `title` if set, otherwise category's display name.
    var displayTitle: String {
        title.isEmpty ? category.displayName : title
    }

    /// Date the reminder is next due, computed from `lastServiceDate + intervalMonths`.
    var nextDueDate: Date? {
        guard intervalMonths > 0, let last = lastServiceDate else { return nil }
        return Calendar.current.date(byAdding: .month, value: intervalMonths, to: last)
    }

    /// Mileage at which the reminder is next due. Treats 0 anchor as "from a clean slate".
    var nextDueMileage: Int? {
        guard intervalMiles > 0 else { return nil }
        return lastServiceMileage + intervalMiles
    }

    /// Days until due. Negative = overdue. Nil if no date interval.
    func daysUntilDue(now: Date = Date()) -> Int? {
        guard let due = nextDueDate else { return nil }
        return Calendar.current.dateComponents([.day], from: now, to: due).day
    }

    /// Miles until due. Negative = overdue. Nil if no mileage interval.
    func milesUntilDue(currentMileage: Int) -> Int? {
        guard let due = nextDueMileage else { return nil }
        return due - currentMileage
    }

    /// Urgency takes the more-pressing axis (whichever is closer).
    func urgency(now: Date = Date(), currentMileage: Int) -> ReminderUrgency {
        let days = daysUntilDue(now: now)
        let miles = milesUntilDue(currentMileage: currentMileage)

        if let d = days, d < 0 { return .overdue }
        if let m = miles, m < 0 { return .overdue }

        let dueByDate: Bool = {
            guard let d = days else { return false }
            return d <= notifyDaysBefore
        }()
        let dueByMiles: Bool = {
            guard let m = miles else { return false }
            return m <= notifyMilesBefore
        }()

        return (dueByDate || dueByMiles) ? .dueSoon : .ok
    }

    /// 0…1 progress to next service, using whichever axis is more advanced.
    func progress(now: Date = Date(), currentMileage: Int) -> Double {
        var fractions: [Double] = []

        if intervalMonths > 0, let last = lastServiceDate {
            let elapsedDays = max(0, Calendar.current.dateComponents([.day], from: last, to: now).day ?? 0)
            let totalDays = max(1, intervalMonths * 30)
            fractions.append(Double(elapsedDays) / Double(totalDays))
        }
        if intervalMiles > 0 {
            let elapsedMiles = max(0, currentMileage - lastServiceMileage)
            fractions.append(Double(elapsedMiles) / Double(intervalMiles))
        }
        return min(1.5, fractions.max() ?? 0)  // can exceed 1.0 to show overdue overshoot
    }
}
