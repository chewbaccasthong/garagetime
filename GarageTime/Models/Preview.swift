import Foundation
import SwiftData

/// In-memory `ModelContainer` factory for SwiftUI previews and unit tests.
/// Never use in production.
enum PreviewModelContainer {
    @MainActor static let shared: ModelContainer = {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(
            for: Schema(GarageTimeSchema.allTypes),
            configurations: [config]
        )
        seed(container)
        return container
    }()

    @MainActor private static func seed(_ container: ModelContainer) {
        let ctx = container.mainContext

        let shop = ShopSettings()
        shop.businessName = "Garage Time Demo Shop"
        shop.ownerName = "Henry"
        shop.email = "demo@wrenchbook.app"
        shop.phone = "(555) 555-0199"
        shop.defaultLaborRate = 95
        shop.defaultTaxRate = 0.0875
        ctx.insert(shop)

        let alice = Customer(
            firstName: "Alice", lastName: "Nguyen",
            email: "alice@example.com", phone: "(555) 200-1101",
            addressLine1: "100 Oak Lane", city: "Austin", state: "TX", zip: "78704"
        )
        ctx.insert(alice)

        let bob = Customer(
            firstName: "Bob", lastName: "Reyes",
            companyName: "Reyes Landscaping",
            email: "bob@reyesland.com", phone: "(555) 200-9012",
            addressLine1: "44 Maple Court", city: "Austin", state: "TX", zip: "78745"
        )
        ctx.insert(bob)

        let civic = Vehicle(
            name: "Daily Civic", year: 2018, make: "Honda", model: "Civic",
            trim: "Touring", vin: "2HGFC1F75JH523412", licensePlate: "ABC-1234",
            type: .car, powertrain: .ic, ownerType: .personal,
            currentMileage: 78421
        )
        ctx.insert(civic)

        let supermoto = Vehicle(
            name: "Husky 701", year: 2022, make: "Husqvarna", model: "701 Supermoto",
            type: .motorcycle, powertrain: .ic, ownerType: .personal,
            currentMileage: 6310
        )
        ctx.insert(supermoto)

        let bobTruck = Vehicle(
            year: 2014, make: "Ford", model: "F-150", trim: "XLT",
            vin: "1FTFW1ET8EFA12345", licensePlate: "RZL-9087",
            type: .truck, ownerType: .customer,
            currentMileage: 144_200,
            customer: bob
        )
        ctx.insert(bobTruck)

        // A few service records
        let oil = ServiceRecord(
            date: Date().addingTimeInterval(-30 * 86400),
            mileageAtService: 77000,
            category: .oilChange,
            title: "Synthetic 0W-20 + filter",
            laborHours: 0.5, laborRate: 0, laborCost: 0,
            partsCost: 48, feesCost: 0, taxCost: 0, totalCost: 48,
            performedBy: .diy,
            vehicle: civic
        )
        ctx.insert(oil)

        try? ctx.save()
    }
}
