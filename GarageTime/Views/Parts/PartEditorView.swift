import SwiftUI
import SwiftData

struct PartEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let vehicle: Vehicle
    let part: Part?

    @State private var name: String = ""
    @State private var partNumber: String = ""
    @State private var brand: String = ""
    @State private var supplier: String = ""
    @State private var price: Double = 0
    @State private var costBasis: Double = 0
    @State private var quantity: Int = 1
    @State private var installDate: Date?
    @State private var isOnShelf: Bool = false
    @State private var warrantyMonths: Int = 0
    @State private var warrantyMileage: Int = 0
    @State private var notes: String = ""
    @State private var photoData: Data?

    var body: some View {
        Form {
            Section("Part") {
                GSTextField(title: "Name", text: $name, placeholder: "Brake pads")
                HStack(spacing: Spacing.s) {
                    GSTextField(title: "Brand", text: $brand, placeholder: "Bosch")
                    GSTextField(title: "Part #", text: $partNumber, placeholder: "DR1234", monospaced: true)
                }
                GSTextField(title: "Supplier", text: $supplier, placeholder: "RockAuto")
            }
            Section("Pricing & quantity") {
                HStack(spacing: Spacing.s) {
                    GSNumberField(title: "Price", value: $price, icon: "dollarsign.circle")
                    GSNumberField(title: "Cost basis", value: $costBasis, icon: "dollarsign.circle.fill")
                }
                GSNumberField(title: "Quantity",
                              value: Binding(get: { Double(quantity) }, set: { quantity = Int($0) }),
                              allowsDecimal: false)
            }
            Section("Inventory") {
                Toggle("On shelf (not installed)", isOn: $isOnShelf)
                if !isOnShelf {
                    DatePicker("Install date", selection: Binding(
                        get: { installDate ?? .now },
                        set: { installDate = $0 }
                    ), displayedComponents: .date)
                }
            }
            Section("Warranty") {
                Stepper("\(warrantyMonths) months", value: $warrantyMonths, in: 0...120, step: 1)
                Stepper("\(warrantyMileage) mi", value: $warrantyMileage, in: 0...500_000, step: 1000)
            }
            Section("Photo") {
                HStack(spacing: Spacing.m) {
                    GSPhotoTile(imageData: photoData, size: 80, placeholderIcon: "shippingbox")
                    PhotoPickerButton(imageData: $photoData) {
                        Label("Choose photo", systemImage: "photo.on.rectangle.angled")
                            .font(.wbCaption)
                            .foregroundStyle(Color.accentPrimary)
                    }
                }
            }
            Section("Notes") {
                GSTextEditor(title: "", text: $notes, placeholder: "Anything else…")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.bgPrimary)
        .wbDismissibleKeyboard()
        .navigationTitle(part == nil ? "New Part" : "Edit Part")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") { save() }
                    .fontWeight(.semibold)
            }
        }
        .onAppear { hydrate() }
    }

    private func hydrate() {
        guard let p = part else { return }
        name = p.name; partNumber = p.partNumber; brand = p.brand; supplier = p.supplier
        price = p.price; costBasis = p.costBasis ?? 0; quantity = p.quantity
        installDate = p.installDate; isOnShelf = p.isOnShelf
        warrantyMonths = p.warrantyMonths; warrantyMileage = p.warrantyMileage
        notes = p.notes; photoData = p.photoData
    }

    private func save() {
        let p = part ?? Part()
        p.name = name; p.partNumber = partNumber; p.brand = brand; p.supplier = supplier
        p.price = price; p.costBasis = costBasis > 0 ? costBasis : nil; p.quantity = quantity
        p.installDate = isOnShelf ? nil : installDate
        p.isOnShelf = isOnShelf
        p.warrantyMonths = warrantyMonths; p.warrantyMileage = warrantyMileage
        p.notes = notes; p.photoData = photoData
        p.vehicle = vehicle
        p.updatedAt = Date()
        if part == nil { context.insert(p) }
        try? context.save()
        HapticsManager.success()
        dismiss()
    }
}
