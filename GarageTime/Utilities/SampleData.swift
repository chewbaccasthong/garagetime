import Foundation
import SwiftData

/// Quick-and-dirty seed so a fresh install has something to look at.
/// Called from Settings → "Load sample data".
@MainActor
enum SampleData {
    static func seed(into context: ModelContext) {
        // Shop settings — fill if blank
        let shopDescriptor = FetchDescriptor<ShopSettings>()
        let shop = (try? context.fetch(shopDescriptor))?.first ?? ShopSettings()
        if shop.businessName.isEmpty {
            shop.businessName = "Henry's Mobile Mechanic"
            shop.ownerName = "Henry G."
            shop.phone = "(512) 555-0199"
            shop.email = "henry@wrenchbook.app"
            shop.addressLine1 = "123 Garage Lane"
            shop.city = "Austin"; shop.state = "TX"; shop.zip = "78704"
            shop.defaultLaborRate = 95
            shop.defaultTaxRate = 0.0825
        }
        if shop.persistentModelID.id == nil {
            context.insert(shop)
        }
        // Default to mechanic role when seeding, so the Jobs tab appears
        if shop.role == nil {
            shop.role = .mechanic
            shop.mechanicDisplayName = shop.ownerName
            shop.hasCompletedOnboarding = true
        }

        // Customers
        let alice = Customer(
            firstName: "Alice", lastName: "Nguyen",
            email: "alice@example.com", phone: "(512) 555-2200",
            addressLine1: "100 Oak Ln", city: "Austin", state: "TX", zip: "78704"
        )
        let bob = Customer(
            firstName: "Bob", lastName: "Reyes",
            companyName: "Reyes Landscaping",
            email: "bob@reyesland.com", phone: "(512) 555-9012",
            addressLine1: "44 Maple Ct", city: "Austin", state: "TX", zip: "78745"
        )
        context.insert(alice)
        context.insert(bob)

        // Personal vehicles
        let civic = Vehicle(
            name: "Daily Civic", year: 2018, make: "Honda", model: "Civic",
            trim: "Touring", vin: "2HGFC1F75JH523412", licensePlate: "ABC-1234",
            type: .car, powertrain: .ic, ownerType: .personal,
            currentMileage: 78421
        )
        let supermoto = Vehicle(
            name: "Husky 701", year: 2022, make: "Husqvarna", model: "701 Supermoto",
            type: .motorcycle, powertrain: .ic, ownerType: .personal,
            currentMileage: 6310
        )
        context.insert(civic)
        context.insert(supermoto)

        // Customer vehicles
        let bobTruck = Vehicle(
            year: 2014, make: "Ford", model: "F-150", trim: "XLT",
            vin: "1FTFW1ET8EFA12345", licensePlate: "RZL-9087",
            type: .truck, powertrain: .ic, ownerType: .customer,
            currentMileage: 144_200,
            customer: bob,
            laborRateOverride: 110
        )
        let aliceCar = Vehicle(
            year: 2021, make: "Toyota", model: "Camry", trim: "SE",
            licensePlate: "ALC-5566",
            type: .car, powertrain: .hybrid, ownerType: .customer,
            currentMileage: 38900,
            customer: alice
        )
        context.insert(bobTruck)
        context.insert(aliceCar)

        // Personal service records — DIY logs time, no labor money
        let oil = ServiceRecord(
            date: Date().addingTimeInterval(-30 * 86400),
            mileageAtService: 77000,
            category: .oilChange,
            title: "Synthetic 0W-20 + filter",
            details: "Mobil 1, Mann filter",
            laborHours: 0.75,
            partsCost: 48,
            performedBy: .diy,
            vehicle: civic
        )
        oil.recomputeTotal()
        context.insert(oil)

        let brakes = ServiceRecord(
            date: Date().addingTimeInterval(-90 * 86400),
            mileageAtService: 75000,
            category: .brakes,
            title: "Front brake pads",
            details: "OEM pads, no rotor work",
            laborHours: 2.5,
            partsCost: 110,
            performedBy: .diy,
            vehicle: civic
        )
        brakes.recomputeTotal()
        context.insert(brakes)

        let chain = ServiceRecord(
            date: Date().addingTimeInterval(-14 * 86400),
            mileageAtService: 6100,
            category: .chain,
            title: "Chain clean + lube",
            laborHours: 0.5,
            partsCost: 18,
            performedBy: .diy,
            vehicle: supermoto
        )
        chain.recomputeTotal()
        context.insert(chain)

        // Customer service record — billable shop work
        let bobOil = ServiceRecord(
            date: Date().addingTimeInterval(-7 * 86400),
            mileageAtService: 143_800,
            category: .oilChange,
            title: "Synthetic + filter",
            laborHours: 0.5,
            laborRate: 110,
            partsCost: 65,
            taxCost: 9.90,
            performedBy: .shop,
            shopName: "Henry's Mobile Mechanic",
            vehicle: bobTruck
        )
        bobOil.recomputeTotal()
        context.insert(bobOil)

        let bobTrans = ServiceRecord(
            date: Date().addingTimeInterval(-45 * 86400),
            mileageAtService: 141_200,
            category: .transmission,
            title: "Trans fluid + filter",
            laborHours: 2.0,
            laborRate: 110,
            partsCost: 145,
            taxCost: 29.85,
            performedBy: .shop,
            shopName: "Henry's Mobile Mechanic",
            vehicle: bobTruck
        )
        bobTrans.recomputeTotal()
        context.insert(bobTrans)

        // Reminders
        context.insert(MaintenanceReminder(
            title: "Oil change",
            category: .oilChange,
            intervalMiles: 5000,
            intervalMonths: 6,
            lastServiceDate: Date().addingTimeInterval(-30 * 86400),
            lastServiceMileage: 77000,
            vehicle: civic
        ))
        context.insert(MaintenanceReminder(
            title: "Chain lube",
            category: .chainLube,
            intervalMiles: 500,
            intervalMonths: 0,
            lastServiceDate: Date().addingTimeInterval(-14 * 86400),
            lastServiceMileage: 6100,
            vehicle: supermoto
        ))
        context.insert(MaintenanceReminder(
            title: "Brake fluid",
            category: .brakeFluid,
            intervalMiles: 0,
            intervalMonths: 24,
            lastServiceDate: Date().addingTimeInterval(-700 * 86400),
            lastServiceMileage: 70000,
            vehicle: civic
        ))

        // Sample quote (draft)
        let quote = Quote(
            quoteNumber: "Q-2026-0001",
            status: .draft,
            issueDate: Date(),
            expiryDate: Date().addingTimeInterval(30 * 86400),
            taxRate: 0.0825,
            customer: bob,
            vehicle: bobTruck
        )
        context.insert(quote)
        let line1 = QuoteLineItem(sortOrder: 0, type: .labor,    itemDescription: "Front brake job", quantity: 2.5, unitPrice: 110, hours: 2.5, laborRate: 110, quote: quote)
        let line2 = QuoteLineItem(sortOrder: 1, type: .part,     itemDescription: "Brake pads + rotors", quantity: 1, unitPrice: 240, quote: quote)
        let line3 = QuoteLineItem(sortOrder: 2, type: .fee,      itemDescription: "Shop supplies", quantity: 1, unitPrice: 12, quote: quote)
        let line4 = QuoteLineItem(sortOrder: 3, type: .discount, itemDescription: "Repeat customer 5%", quantity: 1, unitPrice: 25.6, taxable: false, quote: quote)
        for line in [line1, line2, line3, line4] {
            context.insert(line)
            line.recomputeLineTotal()
        }
        quote.lineItems = [line1, line2, line3, line4]
        quote.recompute()

        // Availability — open Mon–Fri 9–5
        for day: Weekday in [.monday, .tuesday, .wednesday, .thursday, .friday] {
            context.insert(MechanicAvailability(
                weekday: day,
                startMinute: 9 * 60,
                endMinute: 17 * 60
            ))
        }

        // A sample pending job request from Alice
        let req = JobRequest(
            status: .pending,
            category: .oilChange,
            title: "Oil change",
            customerNotes: "Hey, due for an oil change soon. Any time next week?",
            estimatedHours: 0.5,
            estimatedCost: 95,
            customer: alice,
            vehicle: aliceCar
        )
        context.insert(req)

        try? context.save()
    }
}
