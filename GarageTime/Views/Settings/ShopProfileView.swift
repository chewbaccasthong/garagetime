import SwiftUI
import SwiftData

struct ShopProfileView: View {
    @Environment(\.modelContext) private var context
    @Query private var shops: [ShopSettings]
    @State private var local: ShopSettings = ShopSettings()
    @State private var initialized: Bool = false

    var body: some View {
        Form {
            Section("Business") {
                GSTextField(title: "Business name", text: $local.businessName, placeholder: "Smith Auto")
                GSTextField(title: "Owner name", text: $local.ownerName, placeholder: "Henry G.")
                GSTextField(title: "Email", text: $local.email, placeholder: "shop@example.com",
                            keyboard: .emailAddress, autocapitalization: .never, disableAutocorrection: true)
                GSTextField(title: "Phone", text: $local.phone, placeholder: "(555) 555-0199", keyboard: .phonePad)
                GSTextField(title: "Website", text: $local.website, placeholder: "wrenchbook.app",
                            autocapitalization: .never, disableAutocorrection: true)
            }
            Section("Address") {
                GSTextField(title: "Address 1", text: $local.addressLine1)
                GSTextField(title: "Address 2", text: $local.addressLine2)
                HStack(spacing: Spacing.s) {
                    GSTextField(title: "City", text: $local.city)
                    GSTextField(title: "State", text: $local.state, autocapitalization: .characters)
                    GSTextField(title: "ZIP", text: $local.zip, keyboard: .numbersAndPunctuation)
                }
            }
            Section("Logo") {
                HStack(spacing: Spacing.m) {
                    GSPhotoTile(imageData: local.logoData, size: 88, placeholderIcon: "storefront.fill")
                    PhotoPickerButton(imageData: $local.logoData) {
                        Label("Choose logo", systemImage: "photo")
                            .font(.wbCaption)
                            .foregroundStyle(Color.accentPrimary)
                    }
                    if local.logoData != nil {
                        Button(role: .destructive) {
                            local.logoData = nil
                        } label: {
                            Image(systemName: "trash")
                        }
                    }
                }
            }
            Section("Defaults") {
                GSNumberField(title: "Default labor rate ($/hr)", value: $local.defaultLaborRate, icon: "dollarsign.circle.fill")
                GSNumberField(title: "Default tax rate (e.g. 0.0875)", value: $local.defaultTaxRate)
                Picker("Mileage units", selection: $local.mileageUnitRaw) {
                    Text("Miles").tag("mi")
                    Text("Kilometers").tag("km")
                }
            }
            Section("Quote numbering") {
                GSTextField(title: "Prefix", text: $local.quoteNumberPrefix, placeholder: "Q")
                Stepper("Valid \(local.quoteValidDays) days", value: $local.quoteValidDays, in: 1...365, step: 1)
                Text("Next quote: \(local.nextQuoteNumber)")
                    .font(.wbCaption)
                    .foregroundStyle(Color.textSecondary)
            }
            Section("Terms & instructions") {
                GSTextEditor(title: "Quote terms (printed on PDF)", text: $local.quoteTerms,
                             placeholder: "Boilerplate terms…")
                GSTextEditor(title: "Payment instructions (printed on completed PDFs)", text: $local.paymentInstructions,
                             placeholder: "How customers should pay…")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.bgPrimary)
        .wbDismissibleKeyboard()
        .navigationTitle("Shop Profile")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") { save() }
                    .fontWeight(.semibold)
            }
        }
        .onAppear { hydrate() }
    }

    private func hydrate() {
        guard !initialized else { return }
        if let existing = shops.first {
            local = existing
        } else {
            let new = ShopSettings()
            context.insert(new)
            try? context.save()
            local = new
        }
        initialized = true
    }

    private func save() {
        local.updatedAt = Date()
        try? context.save()
        HapticsManager.success()
    }
}
