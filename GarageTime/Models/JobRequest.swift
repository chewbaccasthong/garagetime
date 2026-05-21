import Foundation
import SwiftData

/// A customer-initiated request for work. Lives in the same store as `ServiceRecord`
/// and `Quote`; mechanic accepts/declines/schedules/quotes it.
@Model
final class JobRequest {
    var id: UUID = UUID()
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    // Lifecycle
    var statusRaw: String = JobStatus.pending.rawValue
    var requestedDate: Date?      // customer's preferred date (optional)
    var scheduledDate: Date?      // mechanic-set when status = .scheduled

    // What
    var categoryRaw: String = ServiceCategory.other.rawValue
    var title: String = ""
    var customerNotes: String = ""        // customer-facing context, "weird noise from front left"
    var mechanicNotes: String = ""        // mechanic's private response/scratch
    @Attribute(.externalStorage) var photoData: [Data]? = []

    // Estimate snapshot (filled when mechanic accepts/responds)
    var estimatedHours: Double = 0
    var estimatedCost: Double = 0
    var estimateNotes: String = ""        // "Assumes standard front pads, no rotor work"

    // Who
    var customer: Customer?
    var vehicle: Vehicle?

    // Back-link if mechanic converted to a quote
    var quote: Quote?

    init(
        id: UUID = UUID(),
        status: JobStatus = .pending,
        requestedDate: Date? = nil,
        scheduledDate: Date? = nil,
        category: ServiceCategory = .other,
        title: String = "",
        customerNotes: String = "",
        mechanicNotes: String = "",
        photoData: [Data] = [],
        estimatedHours: Double = 0,
        estimatedCost: Double = 0,
        estimateNotes: String = "",
        customer: Customer? = nil,
        vehicle: Vehicle? = nil,
        quote: Quote? = nil
    ) {
        self.id = id
        self.statusRaw = status.rawValue
        self.requestedDate = requestedDate
        self.scheduledDate = scheduledDate
        self.categoryRaw = category.rawValue
        self.title = title
        self.customerNotes = customerNotes
        self.mechanicNotes = mechanicNotes
        self.photoData = photoData
        self.estimatedHours = estimatedHours
        self.estimatedCost = estimatedCost
        self.estimateNotes = estimateNotes
        self.customer = customer
        self.vehicle = vehicle
        self.quote = quote
    }
}

extension JobRequest {
    var status: JobStatus {
        get { JobStatus(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }

    var category: ServiceCategory {
        get { ServiceCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }

    var displayTitle: String {
        title.isEmpty ? category.displayName : title
    }
}
