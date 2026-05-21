import SwiftUI
import SwiftData
import StoreKit

struct QuoteBuilderView: View {
    @Environment(Backend.self) private var backend
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Bindable var quote: Quote

    @State private var showCustomerPicker: Bool = false
    @State private var showVehiclePicker: Bool = false
    @State private var showSignature: Bool = false
    @State private var showPDFPreview: Bool = false
    @State private var pdfURL: URL?
    @State private var addLineMenu: Bool = false
    @State private var confirmConvert: Bool = false

    var body: some View {
        Form {
            // Header
            Section("Customer & Vehicle") {
                Button { showCustomerPicker = true } label: {
                    pickerRow(title: "Customer", value: quote.customer?.displayName ?? "Choose customer")
                }
                Button { showVehiclePicker = true } label: {
                    pickerRow(title: "Vehicle", value: quote.vehicle?.displayTitle ?? "Choose vehicle")
                }
                .disabled(quote.customer == nil)
            }

            // Meta
            Section("Quote") {
                HStack {
                    Text("Number").foregroundStyle(Color.textSecondary)
                    Spacer()
                    Text(quote.quoteNumber)
                        .font(.wbMonoBody)
                }
                DatePicker("Issue date", selection: $quote.issueDate, displayedComponents: .date)
                DatePicker("Valid through", selection: $quote.expiryDate, displayedComponents: .date)
                HStack {
                    Text("Status")
                    Spacer()
                    GSStatusPill(text: quote.status.displayName, role: quote.status.paletteRole)
                }
            }

            // Line items
            Section {
                if quote.sortedLineItems.isEmpty {
                    Text("No line items yet. Add labor, parts, fees, or discounts.")
                        .font(.wbCaption)
                        .foregroundStyle(Color.textTertiary)
                        .padding(.vertical, 6)
                } else {
                    ForEach(quote.sortedLineItems) { item in
                        NavigationLink {
                            LineItemEditorView(quote: quote, item: item)
                        } label: {
                            lineItemRow(item)
                        }
                    }
                    .onDelete(perform: deleteLineItems)
                    .onMove(perform: moveLineItems)
                }
                addLineMenuView
            } header: {
                HStack {
                    Text("Line items")
                    Spacer()
                    EditButton()
                        .font(.wbCaption)
                        .foregroundStyle(Color.accentPrimary)
                }
            }

            // Totals
            Section("Totals") {
                totalRow("Subtotal labor", value: Money.format(quote.subtotalLabor))
                totalRow("Subtotal parts", value: Money.format(quote.subtotalParts))
                if quote.subtotalFees > 0 {
                    totalRow("Fees", value: Money.format(quote.subtotalFees))
                }
                if quote.discountAmount > 0 {
                    totalRow("Discount", value: "−" + Money.format(quote.discountAmount))
                }
                HStack {
                    Text("Tax rate")
                    Spacer()
                    GSNumberField(title: "", value: $quote.taxRate, allowsDecimal: true, placeholder: "0")
                        .frame(width: 80)
                    Text(WBFormat.percent(quote.taxRate))
                        .font(.wbCaptionSmall)
                        .foregroundStyle(Color.textTertiary)
                }
                totalRow("Tax", value: Money.format(quote.taxAmount))
                HStack {
                    Text("TOTAL")
                        .font(.wbHeadline)
                    Spacer()
                    Text(Money.format(quote.total))
                        .font(.wbDisplayMedium)
                        .foregroundStyle(Color.accentPrimary)
                }
            }

            // Notes
            Section("Customer notes (on PDF)") {
                GSTextEditor(title: "", text: $quote.customerNotes, placeholder: "Anything the customer will see on the PDF…")
            }
            Section("Internal notes (private)") {
                GSTextEditor(title: "", text: $quote.internalNotes, placeholder: "Diagnostic notes, things to remember…")
            }

            // Actions
            Section("Workflow") {
                statusActionButtons
                Button { exportPDF() } label: {
                    Label("Preview / Export PDF", systemImage: "doc.text.fill")
                }
                Button { showSignature = true } label: {
                    Label(quote.signaturePngData == nil ? "Capture signature" : "Re-sign", systemImage: "signature")
                }
                if quote.status == .approved {
                    Button {
                        confirmConvert = true
                    } label: {
                        Label("Convert to Service Record", systemImage: "checkmark.seal.fill")
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.bgPrimary)
        .wbDismissibleKeyboard()
        .navigationTitle("Quote \(quote.quoteNumber)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
                    .fontWeight(.semibold)
            }
        }
        .onChange(of: quote.taxRate) { _, _ in quote.recompute(); try? context.save() }
        .onAppear { quote.recompute() }
        .sheet(isPresented: $showCustomerPicker) {
            CustomerPickerSheet(selected: Binding(
                get: { quote.customer },
                set: { quote.customer = $0; try? context.save() }
            ))
        }
        .sheet(isPresented: $showVehiclePicker) {
            VehiclePickerSheet(customer: quote.customer, selected: Binding(
                get: { quote.vehicle },
                set: { quote.vehicle = $0; try? context.save() }
            ))
        }
        .sheet(isPresented: $showSignature) {
            QuoteSignatureView(quote: quote)
        }
        .sheet(item: $pdfURL) { url in
            ShareSheet(activityItems: [url])
        }
        .confirm(
            isPresented: $confirmConvert,
            title: "Convert quote to service record?",
            message: "Garage Time will create a service record from this quote and mark the quote completed.",
            destructiveTitle: "Convert",
            isDestructive: false
        ) {
            convertToServiceRecord()
        }
    }

    private func pickerRow(title: String, value: String) -> some View {
        HStack {
            Text(title).foregroundStyle(Color.textSecondary)
            Spacer()
            Text(value)
                .foregroundStyle(Color.textPrimary)
                .lineLimit(1)
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.textTertiary)
        }
    }

    private func lineItemRow(_ item: QuoteLineItem) -> some View {
        HStack(spacing: Spacing.s) {
            Image(systemName: item.type.sfSymbol)
                .frame(width: 22)
                .foregroundStyle(Color.accentPrimary)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.itemDescription.isEmpty ? item.type.displayName : item.itemDescription)
                    .font(.wbBody)
                    .foregroundStyle(Color.textPrimary)
                let q = item.type == .labor ? (item.hours ?? item.quantity) : item.quantity
                let u = item.type == .labor ? (item.laborRate ?? item.unitPrice) : item.unitPrice
                Text("\(String(format: "%g", q)) × \(Money.format(u))")
                    .font(.wbCaption)
                    .foregroundStyle(Color.textSecondary)
            }
            Spacer()
            Text(Money.format(item.lineTotal))
                .font(.wbMonoBody)
                .foregroundStyle(Color.textPrimary)
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private var addLineMenuView: some View {
        Menu {
            Button { addLine(type: .labor) }    label: { Label("Labor", systemImage: "wrench.and.screwdriver.fill") }
            Button { addLine(type: .part) }     label: { Label("Part", systemImage: "shippingbox.fill") }
            Button { addLine(type: .fee) }      label: { Label("Fee", systemImage: "dollarsign.circle.fill") }
            Button { addLine(type: .discount) } label: { Label("Discount", systemImage: "tag.fill") }
        } label: {
            Label("Add line item", systemImage: "plus")
                .foregroundStyle(Color.accentPrimary)
        }
    }

    @ViewBuilder
    private var statusActionButtons: some View {
        let s = quote.status
        if s == .draft {
            Button {
                quote.status = .sent
                try? context.save()
                HapticsManager.success()
            } label: {
                Label("Mark Sent", systemImage: "paperplane.fill")
            }
        }
        if s == .sent {
            Button {
                quote.status = .approved
                quote.approvedDate = Date()
                try? context.save()
                HapticsManager.success()
            } label: {
                Label("Mark Approved", systemImage: "checkmark.circle.fill")
            }
            Button(role: .destructive) {
                quote.status = .declined
                try? context.save()
            } label: {
                Label("Mark Declined", systemImage: "xmark.circle.fill")
            }
        }
    }

    private func addLine(type: QuoteLineItemType) {
        let item = QuoteLineItem(
            sortOrder: (quote.lineItems?.count ?? 0),
            type: type,
            itemDescription: "",
            quantity: 1,
            unitPrice: 0,
            lineTotal: 0,
            taxable: type != .discount,
            quote: quote
        )
        context.insert(item)
        quote.lineItems = (quote.lineItems ?? []) + [item]
        try? context.save()
        quote.recompute()
    }

    private func deleteLineItems(at offsets: IndexSet) {
        let items = quote.sortedLineItems
        for index in offsets {
            context.delete(items[index])
        }
        try? context.save()
        quote.recompute()
    }

    private func moveLineItems(from source: IndexSet, to destination: Int) {
        var items = quote.sortedLineItems
        items.move(fromOffsets: source, toOffset: destination)
        for (index, item) in items.enumerated() {
            item.sortOrder = index
        }
        try? context.save()
    }

    private func totalRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(Color.textSecondary)
            Spacer()
            Text(value)
                .font(.wbMonoBody)
                .foregroundStyle(Color.textPrimary)
        }
    }

    private func exportPDF() {
        let shopDescriptor = FetchDescriptor<ShopSettings>()
        let shop = (try? context.fetch(shopDescriptor))?.first ?? ShopSettings()
        let data = backend.pdf.export(.quote(quote), shop: shop)
        quote.pdfData = data
        try? context.save()
        if let url = TempFile.write(data, name: "Quote_\(quote.quoteNumber)", ext: "pdf") {
            pdfURL = url
        }
    }

    private func convertToServiceRecord() {
        guard let vehicle = quote.vehicle else { return }
        let record = ServiceRecord(
            date: Date(),
            mileageAtService: vehicle.currentMileage,
            category: .other,
            title: "From quote \(quote.quoteNumber)",
            details: quote.customerNotes,
            laborCost: quote.subtotalLabor,
            partsCost: quote.subtotalParts,
            feesCost: quote.subtotalFees,
            taxCost: quote.taxAmount,
            totalCost: quote.total,
            performedBy: .shop,
            shopName: "",
            derivedFromQuote: quote,
            vehicle: vehicle
        )
        context.insert(record)
        quote.status = .completed
        quote.completedDate = Date()
        try? context.save()
        HapticsManager.success()
    }
}

// MARK: - Line item editor

struct LineItemEditorView: View {
    @Environment(\.modelContext) private var context
    @Bindable var quote: Quote
    @Bindable var item: QuoteLineItem

    var body: some View {
        Form {
            Section {
                Picker("Type", selection: Binding(get: { item.type }, set: { item.type = $0 })) {
                    ForEach(QuoteLineItemType.allCases) { t in
                        Label(t.displayName, systemImage: t.sfSymbol).tag(t)
                    }
                }
                .pickerStyle(.segmented)
            }
            Section("Description") {
                GSTextField(title: "", text: $item.itemDescription, placeholder: descriptionPlaceholder)
            }
            if item.type == .labor {
                Section("Labor") {
                    GSNumberField(title: "Hours", value: Binding(
                        get: { item.hours ?? item.quantity },
                        set: { item.hours = $0; item.quantity = $0 }
                    ), allowsDecimal: true)
                    GSNumberField(title: "Rate / hr", value: Binding(
                        get: { item.laborRate ?? item.unitPrice },
                        set: { item.laborRate = $0; item.unitPrice = $0 }
                    ), allowsDecimal: true)
                }
            } else {
                Section("Pricing") {
                    GSNumberField(title: "Quantity", value: $item.quantity)
                    GSNumberField(title: "Unit price", value: $item.unitPrice)
                }
            }
            Section {
                Toggle("Taxable", isOn: $item.taxable)
            }
            Section {
                HStack {
                    Text("Line total")
                    Spacer()
                    Text(Money.format(item.lineTotal))
                        .font(.wbMonoBody)
                        .foregroundStyle(Color.accentPrimary)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.bgPrimary)
        .wbDismissibleKeyboard()
        .navigationTitle(item.type.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: item.quantity)    { _, _ in saveAndRecompute() }
        .onChange(of: item.unitPrice)   { _, _ in saveAndRecompute() }
        .onChange(of: item.hours ?? 0)  { _, _ in saveAndRecompute() }
        .onChange(of: item.laborRate ?? 0) { _, _ in saveAndRecompute() }
        .onChange(of: item.taxable)     { _, _ in saveAndRecompute() }
        .onChange(of: item.typeRaw)     { _, _ in saveAndRecompute() }
    }

    private func saveAndRecompute() {
        item.recomputeLineTotal()
        quote.recompute()
        try? context.save()
    }

    private var descriptionPlaceholder: String {
        switch item.type {
        case .labor:    return "e.g. Brake pad replacement"
        case .part:     return "e.g. Front brake pads — OE Bosch"
        case .fee:      return "e.g. Shop supplies"
        case .discount: return "e.g. Repeat customer 10%"
        }
    }
}
