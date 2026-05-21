import Foundation
import SwiftData

/// Authoritative list of every `@Model` type the app persists. Used to build the
/// `ModelContainer` once in `GarageTimeApp.init()`. Adding a new entity? Add it here.
enum GarageTimeSchema {
    static let allTypes: [any PersistentModel.Type] = [
        Vehicle.self,
        Customer.self,
        ServiceRecord.self,
        Part.self,
        MaintenanceReminder.self,
        MileageLog.self,
        Quote.self,
        QuoteLineItem.self,
        ShopSettings.self,
        JobRequest.self,
        MechanicAvailability.self,
    ]
}
