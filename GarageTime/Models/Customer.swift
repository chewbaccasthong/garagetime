import Foundation
import SwiftData

@Model
final class Customer {
    var id: UUID = UUID()
    var firstName: String = ""
    var lastName: String = ""
    var companyName: String = ""
    var email: String = ""
    var phone: String = ""
    var addressLine1: String = ""
    var addressLine2: String = ""
    var city: String = ""
    var state: String = ""
    var zip: String = ""
    var notes: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    @Relationship(deleteRule: .nullify, inverse: \Vehicle.customer)
    var vehicles: [Vehicle]? = []

    @Relationship(deleteRule: .nullify, inverse: \Quote.customer)
    var quotes: [Quote]? = []

    @Relationship(deleteRule: .nullify, inverse: \JobRequest.customer)
    var jobRequests: [JobRequest]? = []

    /// Inverse for `ShopSettings.meCustomer` — only ever 0 or 1.
    @Relationship(deleteRule: .nullify, inverse: \ShopSettings.meCustomer)
    var meCustomerOf: [ShopSettings]? = []

    init(
        id: UUID = UUID(),
        firstName: String = "",
        lastName: String = "",
        companyName: String = "",
        email: String = "",
        phone: String = "",
        addressLine1: String = "",
        addressLine2: String = "",
        city: String = "",
        state: String = "",
        zip: String = "",
        notes: String = ""
    ) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.companyName = companyName
        self.email = email
        self.phone = phone
        self.addressLine1 = addressLine1
        self.addressLine2 = addressLine2
        self.city = city
        self.state = state
        self.zip = zip
        self.notes = notes
    }
}

extension Customer {
    /// "Jane Smith" or "Jane Smith — Smith Auto" if companyName present.
    var displayName: String {
        let person = [firstName, lastName].filter { !$0.isEmpty }.joined(separator: " ")
        switch (person.isEmpty, companyName.isEmpty) {
        case (false, false): return "\(person) — \(companyName)"
        case (false, true):  return person
        case (true,  false): return companyName
        case (true,  true):  return "Unnamed customer"
        }
    }

    /// Used for initials in avatar bubbles.
    var initials: String {
        let f = firstName.first.map(String.init) ?? ""
        let l = lastName.first.map(String.init) ?? ""
        if !f.isEmpty || !l.isEmpty { return (f + l).uppercased() }
        if let c = companyName.first { return String(c).uppercased() }
        return "?"
    }

    var vehicleCount: Int { vehicles?.count ?? 0 }

    var totalBilled: Double {
        let quoteTotals = (quotes ?? [])
            .filter { $0.status == .completed }
            .map { $0.total }
        return Money.sum(quoteTotals)
    }

    /// Sum of hours worked on this customer's vehicles across every service record.
    var totalLaborHours: Double {
        let allRecords = (vehicles ?? []).flatMap { $0.serviceRecords ?? [] }
        return allRecords.reduce(0) { $0 + $1.laborHours }
    }

    /// Total parts dollars across all this customer's vehicles.
    var totalPartsCost: Double {
        let allRecords = (vehicles ?? []).flatMap { $0.serviceRecords ?? [] }
        return Money.sum(allRecords.map { $0.partsCost })
    }

    /// Total labor dollars across all this customer's vehicles.
    var totalLaborCost: Double {
        let allRecords = (vehicles ?? []).flatMap { $0.serviceRecords ?? [] }
        return Money.sum(allRecords.map { $0.effectiveLaborCost })
    }

    var lastServiceDate: Date? {
        let allRecords = (vehicles ?? []).flatMap { $0.serviceRecords ?? [] }
        return allRecords.map(\.date).max()
    }

    /// Single-line postal address. Empty if none entered.
    var formattedAddress: String {
        let cityStateZip = [city, state, zip].filter { !$0.isEmpty }.joined(separator: ", ")
        let lines = [addressLine1, addressLine2, cityStateZip].filter { !$0.isEmpty }
        return lines.joined(separator: "\n")
    }
}
