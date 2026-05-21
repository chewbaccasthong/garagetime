import SwiftUI
import SwiftData

struct CustomerEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let customer: Customer?
    var onDone: (Customer?) -> Void = { _ in }

    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var companyName: String = ""
    @State private var email: String = ""
    @State private var phone: String = ""
    @State private var addressLine1: String = ""
    @State private var addressLine2: String = ""
    @State private var city: String = ""
    @State private var state: String = ""
    @State private var zip: String = ""
    @State private var notes: String = ""

    var body: some View {
        Form {
            Section("Name") {
                HStack(spacing: Spacing.s) {
                    GSTextField(title: "First", text: $firstName, placeholder: "First")
                    GSTextField(title: "Last", text: $lastName, placeholder: "Last")
                }
                GSTextField(title: "Company (optional)", text: $companyName, placeholder: "Acme Trucking")
            }
            Section("Contact") {
                GSTextField(title: "Phone", text: $phone, placeholder: "(555) 555-0199", icon: "phone.fill", keyboard: .phonePad, textContentType: .telephoneNumber)
                GSTextField(title: "Email", text: $email, placeholder: "name@example.com", icon: "envelope.fill", keyboard: .emailAddress, textContentType: .emailAddress, autocapitalization: .never, disableAutocorrection: true)
            }
            Section("Address") {
                GSTextField(title: "Address 1", text: $addressLine1, placeholder: "Street")
                GSTextField(title: "Address 2", text: $addressLine2, placeholder: "Apt / Suite")
                HStack(spacing: Spacing.s) {
                    GSTextField(title: "City", text: $city, placeholder: "City")
                    GSTextField(title: "State", text: $state, placeholder: "TX", autocapitalization: .characters)
                    GSTextField(title: "ZIP", text: $zip, placeholder: "00000", keyboard: .numbersAndPunctuation)
                }
            }
            Section("Notes") {
                GSTextEditor(title: "", text: $notes, placeholder: "Anything to remember about this customer…")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.bgPrimary)
        .wbDismissibleKeyboard()
        .navigationTitle(customer == nil ? "New Customer" : "Edit Customer")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") {
                    dismiss()
                    onDone(nil)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    let saved = save()
                    HapticsManager.success()
                    dismiss()
                    onDone(saved)
                }
                .fontWeight(.semibold)
                .disabled(!hasMinimum)
            }
        }
        .onAppear { hydrate() }
    }

    private var hasMinimum: Bool {
        !firstName.isEmpty || !lastName.isEmpty || !companyName.isEmpty
    }

    private func hydrate() {
        guard let c = customer else { return }
        firstName = c.firstName
        lastName = c.lastName
        companyName = c.companyName
        email = c.email
        phone = c.phone
        addressLine1 = c.addressLine1
        addressLine2 = c.addressLine2
        city = c.city
        state = c.state
        zip = c.zip
        notes = c.notes
    }

    private func save() -> Customer {
        let saved = customer ?? Customer()
        saved.firstName = firstName
        saved.lastName = lastName
        saved.companyName = companyName
        saved.email = email
        saved.phone = phone
        saved.addressLine1 = addressLine1
        saved.addressLine2 = addressLine2
        saved.city = city
        saved.state = state
        saved.zip = zip
        saved.notes = notes
        saved.updatedAt = Date()
        if customer == nil {
            context.insert(saved)
        }
        try? context.save()
        return saved
    }
}
