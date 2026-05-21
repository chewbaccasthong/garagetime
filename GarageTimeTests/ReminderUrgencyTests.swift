import Testing
import Foundation
@testable import GarageTime

@Suite("Reminders — urgency + progress math")
struct ReminderUrgencyTests {

    @Test("OK when both time and miles are far away")
    func ok() {
        let r = MaintenanceReminder(
            title: "Oil",
            category: .oilChange,
            intervalMiles: 5000,
            intervalMonths: 6,
            lastServiceDate: Calendar.current.date(byAdding: .day, value: -30, to: Date()),
            lastServiceMileage: 50_000,
            notifyDaysBefore: 14,
            notifyMilesBefore: 500
        )
        #expect(r.urgency(currentMileage: 51_000) == .ok)
    }

    @Test("Due soon when within notify window")
    func dueSoon() {
        // last service 165 days ago, interval 6 months ≈ 180 days. 15 days from due.
        let r = MaintenanceReminder(
            title: "Oil",
            category: .oilChange,
            intervalMiles: 0,
            intervalMonths: 6,
            lastServiceDate: Calendar.current.date(byAdding: .day, value: -165, to: Date()),
            lastServiceMileage: 0,
            notifyDaysBefore: 30,
            notifyMilesBefore: 0
        )
        #expect(r.urgency(currentMileage: 0) == .dueSoon)
    }

    @Test("Overdue when past either axis")
    func overdue() {
        let r = MaintenanceReminder(
            title: "Oil",
            category: .oilChange,
            intervalMiles: 5000,
            intervalMonths: 0,
            lastServiceDate: nil,
            lastServiceMileage: 50_000
        )
        #expect(r.urgency(currentMileage: 56_000) == .overdue)
    }

    @Test("Progress goes 0…1+ as miles accumulate")
    func progressClimbs() {
        let r = MaintenanceReminder(
            title: "Oil",
            category: .oilChange,
            intervalMiles: 5000,
            intervalMonths: 0,
            lastServiceMileage: 0
        )
        #expect(r.progress(currentMileage: 0) == 0)
        let half = r.progress(currentMileage: 2500)
        #expect(half == 0.5)
        let over = r.progress(currentMileage: 6000)
        #expect(over > 1.0)
    }
}
