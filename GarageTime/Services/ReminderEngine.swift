import Foundation
import SwiftData

/// Coordinates `MaintenanceReminder` ↔ `UserNotifications` scheduling.
/// Recalculates next due, removes stale, schedules upcoming.
@MainActor
final class ReminderEngine {
    private let notifications: NotificationScheduling

    init(notifications: NotificationScheduling) {
        self.notifications = notifications
    }

    /// Recompute every active reminder and reschedule notifications.
    func refresh(context: ModelContext) async {
        let descriptor = FetchDescriptor<MaintenanceReminder>(
            predicate: #Predicate { $0.isActive == true }
        )
        guard let reminders = try? context.fetch(descriptor) else { return }

        await notifications.cancelAll()

        for reminder in reminders {
            guard let vehicle = reminder.vehicle else { continue }
            let urgency = reminder.urgency(now: Date(), currentMileage: vehicle.currentMileage)

            // Schedule a notification at the date-side trigger or as soon as urgency flips to dueSoon.
            if urgency == .overdue {
                // Notify immediately (well, in 60s) if user hasn't seen
                let date = Date().addingTimeInterval(60)
                await notifications.scheduleReminder(
                    id: reminder.id.uuidString,
                    title: "Overdue: \(reminder.displayTitle)",
                    body: "\(vehicle.displayTitle) — see Garage Time to log this service.",
                    date: date
                )
                continue
            }

            if let due = reminder.nextDueDate {
                let advance = Calendar.current.date(
                    byAdding: .day,
                    value: -reminder.notifyDaysBefore,
                    to: due
                ) ?? due
                if advance > Date() {
                    await notifications.scheduleReminder(
                        id: reminder.id.uuidString,
                        title: "Due soon: \(reminder.displayTitle)",
                        body: "\(vehicle.displayTitle) — \(daysAway(due)).",
                        date: advance
                    )
                }
            }
        }
    }

    /// Mark a reminder completed: capture the service record, reset interval anchor,
    /// and re-schedule notifications.
    func complete(_ reminder: MaintenanceReminder,
                  serviceDate: Date,
                  serviceMileage: Int,
                  in context: ModelContext) async {
        reminder.lastServiceDate = serviceDate
        reminder.lastServiceMileage = serviceMileage
        reminder.updatedAt = Date()
        try? context.save()
        await refresh(context: context)
    }

    // MARK: - Helpers

    private func daysAway(_ date: Date) -> String {
        let comps = Calendar.current.dateComponents([.day], from: Date(), to: date)
        guard let d = comps.day else { return "soon" }
        if d == 0 { return "today" }
        if d == 1 { return "tomorrow" }
        if d < 0 { return "\(-d) days overdue" }
        return "in \(d) days"
    }
}
