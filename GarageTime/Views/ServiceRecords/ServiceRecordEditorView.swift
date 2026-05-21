import SwiftUI
import SwiftData

struct ServiceRecordEditorView: View {
    @Environment(Backend.self) private var backend
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let vehicle: Vehicle
    let record: ServiceRecord?

    @State private var date: Date = Date()
    @State private var mileage: Int = 0
    @State private var category: ServiceCategory = .other
    @State private var title: String = ""
    @State private var details: String = ""
    @State private var laborHours: Double = 0
    @State private var laborRate: Double = 0
    @State private var laborCost: Double = 0
    @State private var partsCost: Double = 0
    @State private var feesCost: Double = 0
    @State private var taxCost: Double = 0
    @State private var performedBy: PerformedBy = .diy
    @State private var shopName: String = ""
    @State private var receiptPhotoData: Data?
    @State private var additionalPhotos: [Data] = []
    @State private var showOCRScanner: Bool = false
    @State private var showPaywall: Bool = false

    var body: some View {
        Form {
            Section("When") {
                DatePicker("Date", selection: $date, displayedComponents: .date)
                GSNumberField(title: "Mileage at service",
                              value: Binding(get: { Double(mileage) }, set: { mileage = Int($0) }),
                              icon: "speedometer",
                              allowsDecimal: false)
            }
            Section("What") {
                Picker("Category", selection: $category) {
                    ForEach(ServiceCategory.allCases) { c in
                        Label(c.displayName, systemImage: c.sfSymbol).tag(c)
                    }
                }
                GSTextField(title: "Title", text: $title, placeholder: "e.g. Synthetic 0W-20 + filter")
                GSTextEditor(title: "Details", text: $details, placeholder: "Notes about what was done…")
            }
            Section("Performed by") {
                Picker("By", selection: $performedBy) {
                    ForEach(PerformedBy.allCases) { Text($0.displayName).tag($0) }
                }
                .pickerStyle(.segmented)
                if performedBy == .shop {
                    GSTextField(title: "Shop name", text: $shopName, placeholder: "Joe's Garage")
                }
            }
            Section {
                GSNumberField(title: "Hours worked", value: $laborHours, icon: "clock.fill")
                Text(timeHelperText)
                    .font(.wbCaptionSmall)
                    .foregroundStyle(Color.textTertiary)
            } header: { Text("Time spent") }

            Section {
                if vehicle.ownerType == .customer || performedBy == .shop {
                    GSNumberField(title: "Rate / hr", value: $laborRate, icon: "dollarsign.circle")
                    GSNumberField(title: "Labor $ (override, optional)", value: $laborCost)
                    Text("Leave override blank — labor cost is computed as hours × rate. Override only if you billed a flat amount.")
                        .font(.wbCaptionSmall)
                        .foregroundStyle(Color.textTertiary)
                } else {
                    // DIY on a personal vehicle — labor money usually isn't tracked.
                    Toggle("Track labor cost (uncommon for DIY)", isOn: Binding(
                        get: { laborRate > 0 || laborCost > 0 },
                        set: { enabled in
                            if !enabled { laborRate = 0; laborCost = 0 }
                        }
                    ))
                    if laborRate > 0 || laborCost > 0 {
                        GSNumberField(title: "Rate / hr", value: $laborRate)
                        GSNumberField(title: "Labor $ (override)", value: $laborCost)
                    }
                }
                HStack {
                    Text("Labor cost")
                        .foregroundStyle(Color.textSecondary)
                    Spacer()
                    Text(Money.format(currentLaborCost))
                        .font(.wbMonoBody)
                        .foregroundStyle(currentLaborCost == 0 ? Color.textTertiary : Color.textPrimary)
                }
            } header: { Text("Labor cost") }

            Section {
                GSNumberField(title: "Parts $", value: $partsCost, icon: "shippingbox.fill")
                HStack(spacing: Spacing.s) {
                    GSNumberField(title: "Fees", value: $feesCost)
                    GSNumberField(title: "Tax", value: $taxCost)
                }
            } header: { Text("Other costs") }

            Section {
                breakdownRow("Time", value: WBFormat.hours(laborHours), accent: false)
                breakdownRow("Labor", value: Money.format(currentLaborCost), accent: false)
                breakdownRow("Parts", value: Money.format(partsCost), accent: false)
                if feesCost > 0 { breakdownRow("Fees", value: Money.format(feesCost), accent: false) }
                if taxCost > 0 { breakdownRow("Tax", value: Money.format(taxCost), accent: false) }
                HStack {
                    Text("Total")
                        .font(.wbHeadline)
                    Spacer()
                    Text(Money.format(currentTotal))
                        .font(.wbDisplayMedium)
                        .foregroundStyle(Color.accentPrimary)
                }
            } header: { Text("Summary") }
            Section("Receipt") {
                HStack(spacing: Spacing.m) {
                    GSPhotoTile(imageData: receiptPhotoData, size: 88, placeholderIcon: "doc.text.viewfinder")
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        PhotoPickerButton(imageData: $receiptPhotoData) {
                            Label("Choose photo", systemImage: "photo.on.rectangle.angled")
                                .font(.wbCaption)
                                .foregroundStyle(Color.accentPrimary)
                        }
                        Button {
                            scanReceipt()
                        } label: {
                            Label("Scan receipt (OCR)", systemImage: "viewfinder")
                                .font(.wbCaption)
                        }
                        if receiptPhotoData != nil {
                            Button(role: .destructive) {
                                receiptPhotoData = nil
                            } label: {
                                Label("Remove", systemImage: "trash")
                                    .font(.wbCaptionSmall)
                            }
                        }
                    }
                    Spacer()
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.bgPrimary)
        .wbDismissibleKeyboard()
        .navigationTitle(record == nil ? "New Service" : "Edit Service")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") { save() }
                    .fontWeight(.semibold)
            }
        }
        .fullScreenCover(isPresented: $showOCRScanner) {
            VisionScannerView(mode: .freeform) { text in
                showOCRScanner = false
                applyReceipt(text: text)
            } onCancel: {
                showOCRScanner = false
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
        .onAppear { hydrate() }
    }

    private var currentLaborCost: Double {
        if laborCost > 0 { return laborCost }
        return Money.lineTotal(quantity: laborHours, unitPrice: laborRate)
    }

    private var currentTotal: Double {
        Money.sum([currentLaborCost, partsCost, feesCost, taxCost])
    }

    private var timeHelperText: String {
        if vehicle.ownerType == .customer {
            return "Hours you spent on this customer's vehicle. Always tracked, even if labor isn't billed."
        }
        return performedBy == .shop
            ? "Hours the shop billed you for."
            : "Your wrench time. Track even if you don't bill yourself."
    }

    @ViewBuilder
    private func breakdownRow(_ label: String, value: String, accent: Bool) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(Color.textSecondary)
            Spacer()
            Text(value)
                .font(.wbMonoBody)
                .foregroundStyle(accent ? Color.accentPrimary : Color.textPrimary)
        }
    }

    private func hydrate() {
        if let r = record {
            date = r.date
            mileage = r.mileageAtService
            category = r.category
            title = r.title
            details = r.details
            laborHours = r.laborHours
            laborRate = r.laborRate
            laborCost = r.laborCost
            partsCost = r.partsCost
            feesCost = r.feesCost
            taxCost = r.taxCost
            performedBy = r.performedBy
            shopName = r.shopName
            receiptPhotoData = r.receiptPhotoData
            additionalPhotos = r.additionalPhotos ?? []
        } else {
            mileage = vehicle.currentMileage
            laborRate = vehicle.laborRateOverride ?? 0
        }
    }

    private func save() {
        let r = record ?? ServiceRecord()
        r.date = date
        r.mileageAtService = mileage
        r.category = category
        r.title = title
        r.details = details
        r.laborHours = laborHours
        r.laborRate = laborRate
        r.laborCost = laborCost
        r.partsCost = partsCost
        r.feesCost = feesCost
        r.taxCost = taxCost
        r.performedBy = performedBy
        r.shopName = shopName
        r.receiptPhotoData = receiptPhotoData
        r.additionalPhotos = additionalPhotos
        r.vehicle = vehicle
        r.updatedAt = Date()
        r.recomputeTotal()
        if record == nil { context.insert(r) }
        if r.mileageAtService > vehicle.currentMileage {
            vehicle.currentMileage = r.mileageAtService
        }
        try? context.save()
        HapticsManager.success()
        dismiss()
    }

    private func scanReceipt() {
        let gate = PaywallGate.useOCR
        if gate.isLocked(for: backend.store.entitlements.tier) {
            showPaywall = true
            return
        }
        showOCRScanner = true
    }

    private func applyReceipt(text: String) {
        guard !text.isEmpty else { return }
        let draft = backend.ocr.parse(text: text)
        if let total = draft.total, partsCost == 0, laborCost == 0 {
            partsCost = total
        }
        if let d = draft.date { date = d }
        if let vendor = draft.vendor, performedBy == .shop, shopName.isEmpty {
            shopName = vendor
        }
        HapticsManager.success()
    }
}
