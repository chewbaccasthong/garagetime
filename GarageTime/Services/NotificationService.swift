import Foundation
import UserNotifications
#if canImport(BackgroundTasks)
import BackgroundTasks
#endif

protocol NotificationScheduling: Sendable {
    func requestPermission() async -> Bool
    func authorizationStatus() async -> UNAuthorizationStatus
    func scheduleReminder(id: String, title: String, body: String, date: Date) async
    func cancel(id: String) async
    func cancelAll() async
}

actor RealNotificationService: NotificationScheduling {
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func requestPermission() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .badge, .sound])
        } catch {
            return false
        }
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await withCheckedContinuation { cont in
            center.getNotificationSettings { settings in
                cont.resume(returning: settings.authorizationStatus)
            }
        }
    }

    func scheduleReminder(id: String, title: String, body: String, date: Date) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: date
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        try? await center.add(request)
    }

    func cancel(id: String) async {
        center.removePendingNotificationRequests(withIdentifiers: [id])
    }

    func cancelAll() async {
        center.removeAllPendingNotificationRequests()
    }
}

actor InMemoryNotificationService: NotificationScheduling {
    struct Pending: Sendable, Equatable {
        let id: String
        let title: String
        let body: String
        let date: Date
    }

    private var pending: [Pending] = []
    var authorized: Bool = true

    func snapshot() -> [Pending] { pending }

    func setAuthorized(_ value: Bool) { authorized = value }

    func requestPermission() async -> Bool { authorized }
    func authorizationStatus() async -> UNAuthorizationStatus { authorized ? .authorized : .denied }

    func scheduleReminder(id: String, title: String, body: String, date: Date) async {
        pending.removeAll { $0.id == id }
        pending.append(Pending(id: id, title: title, body: body, date: date))
    }

    func cancel(id: String) async {
        pending.removeAll { $0.id == id }
    }

    func cancelAll() async {
        pending.removeAll()
    }
}

// MARK: - Background refresh registration

enum GarageTimeBGTasks {
    static let refreshIdentifier = "com.henrygawelek.garagetime.refresh"

    /// Call once in `GarageTimeApp.init()`. Registers the daily background task.
    static func register(handler: @escaping @Sendable () -> Void) {
        #if canImport(BackgroundTasks) && os(iOS)
        BGTaskScheduler.shared.register(forTaskWithIdentifier: refreshIdentifier, using: nil) { task in
            scheduleNext()
            handler()
            task.setTaskCompleted(success: true)
        }
        scheduleNext()
        #endif
    }

    private static func scheduleNext() {
        #if canImport(BackgroundTasks) && os(iOS)
        let request = BGAppRefreshTaskRequest(identifier: refreshIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 12 * 60 * 60) // 12h
        try? BGTaskScheduler.shared.submit(request)
        #endif
    }
}
