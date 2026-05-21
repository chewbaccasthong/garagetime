import SwiftUI
import SwiftData

/// Single screen used by both mechanic and customer. The `viewerIsCustomer` flag
/// trims the action set; mechanic gets accept/decline/schedule/quote, customer gets cancel.
struct JobRequestDetailView: View {
    @Environment(Backend.self) private var backend
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Bindable var request: JobRequest
    let viewerIsCustomer: Bool

    @State private var openedQuote: Quote?

    var body: some View {
        Form {
            // Header
            Section {
                HStack {
                    Image(systemName: request.category.sfSymbol)
                        .foregroundStyle(Color.accentPrimary)
                    Text(request.displayTitle)
                        .font(.wbHeadline)
                    Spacer()
                    GSStatusPill(text: request.status.displayName, role: request.status.paletteRole)
                }
                if let v = request.vehicle {
                    HStack {
                        Image(systemName: v.type.sfSymbol).foregroundStyle(Color.textSecondary)
                        Text(v.displayTitle).foregroundStyle(Color.textPrimary)
                    }
                }
                if let c = request.customer {
                    HStack {
                        Image(systemName: "person.fill").foregroundStyle(Color.textSecondary)
                        Text(c.displayName).foregroundStyle(Color.textPrimary)
                    }
                }
                HStack {
                    Image(systemName: "calendar").foregroundStyle(Color.textSecondary)
                    Text("Submitted \(WBFormat.shortDateTime.string(from: request.createdAt))")
                        .foregroundStyle(Color.textSecondary)
                        .font(.wbCaption)
                }
            }

            // Customer notes
            if !request.customerNotes.isEmpty {
                Section("Customer notes") {
                    Text(request.customerNotes)
                        .foregroundStyle(Color.textPrimary)
                }
            }

            // Estimate (read or write depending on viewer)
            Section(viewerIsCustomer ? "Estimate" : "Your estimate") {
                if viewerIsCustomer {
                    estimateReadOnly
                } else {
                    GSNumberField(title: "Estimated hours", value: $request.estimatedHours, icon: "clock.fill")
                    GSNumberField(title: "Estimated cost",  value: $request.estimatedCost, icon: "dollarsign.circle.fill")
                    GSTextEditor(title: "Notes (visible to customer)",
                                 text: $request.estimateNotes,
                                 placeholder: "Assumptions, exclusions, parts not included…",
                                 minHeight: 70)
                }
            }

            // Scheduling
            Section("Schedule") {
                if viewerIsCustomer {
                    if let when = request.scheduledDate {
                        Label(WBFormat.shortDateTime.string(from: when),
                              systemImage: "calendar.badge.checkmark")
                            .foregroundStyle(Color.accentPrimary)
                    } else if let pref = request.requestedDate {
                        Text("Requested for \(WBFormat.shortDate.string(from: pref))")
                            .foregroundStyle(Color.textSecondary)
                    } else {
                        Text("Not yet scheduled")
                            .foregroundStyle(Color.textTertiary)
                    }
                } else {
                    DatePicker("Scheduled for", selection: Binding(
                        get: { request.scheduledDate ?? Date().addingTimeInterval(86400) },
                        set: { request.scheduledDate = $0; if request.status == .accepted { request.status = .scheduled } }
                    ))
                }
            }

            // Mechanic private notes (mechanic view only)
            if !viewerIsCustomer {
                Section("Private notes") {
                    GSTextEditor(title: "", text: $request.mechanicNotes,
                                 placeholder: "Internal notes, parts to order, anything the customer shouldn't see…",
                                 minHeight: 80)
                }
            }

            // Linked quote
            if let quote = request.quote {
                Section("Linked quote") {
                    Button {
                        openedQuote = quote
                    } label: {
                        HStack {
                            Image(systemName: "doc.text.fill")
                                .foregroundStyle(Color.accentPrimary)
                            Text(quote.quoteNumber).foregroundStyle(Color.textPrimary)
                            Spacer()
                            Text(Money.format(quote.total))
                                .font(.wbMonoBody)
                                .foregroundStyle(Color.textPrimary)
                        }
                    }
                }
            }

            // Actions
            Section("Actions") {
                if viewerIsCustomer {
                    customerActions
                } else {
                    mechanicActions
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.bgPrimary)
        .wbDismissibleKeyboard()
        .navigationTitle("Job Request")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { save(); dismiss() }
                    .fontWeight(.semibold)
            }
        }
        .sheet(item: $openedQuote) { quote in
            NavigationStack { QuoteBuilderView(quote: quote) }
        }
    }

    // MARK: - Sub-views

    @ViewBuilder
    private var estimateReadOnly: some View {
        if request.estimatedCost > 0 {
            HStack {
                Label(Money.format(request.estimatedCost), systemImage: "dollarsign.circle.fill")
                    .foregroundStyle(Color.accentPrimary)
                Spacer()
                Label(WBFormat.hours(request.estimatedHours), systemImage: "clock.fill")
                    .foregroundStyle(Color.statusBlue)
            }
            if !request.estimateNotes.isEmpty {
                Text(request.estimateNotes)
                    .font(.wbCaption)
                    .foregroundStyle(Color.textSecondary)
            }
        } else {
            Text("Mechanic hasn't given an estimate yet.")
                .font(.wbCaption)
                .foregroundStyle(Color.textTertiary)
        }
    }

    @ViewBuilder
    private var mechanicActions: some View {
        switch request.status {
        case .pending:
            Button { setStatus(.accepted) } label: { Label("Accept", systemImage: "checkmark.circle.fill") }
            Button { generateQuote() }     label: { Label("Convert to Quote", systemImage: "doc.text.fill") }
            Button(role: .destructive) { setStatus(.declined) }
                label: { Label("Decline", systemImage: "xmark.circle.fill") }
        case .accepted, .scheduled:
            Button { generateQuote() }     label: { Label("Convert to Quote", systemImage: "doc.text.fill") }
            Button { setStatus(.completed) } label: { Label("Mark Completed", systemImage: "checkmark.seal.fill") }
            Button(role: .destructive) { setStatus(.declined) }
                label: { Label("Decline", systemImage: "xmark.circle.fill") }
        case .quoted:
            Button { setStatus(.completed) } label: { Label("Mark Completed", systemImage: "checkmark.seal.fill") }
        case .completed, .declined, .cancelled:
            Text("Final state — no further actions.")
                .font(.wbCaption)
                .foregroundStyle(Color.textTertiary)
        }
    }

    @ViewBuilder
    private var customerActions: some View {
        switch request.status {
        case .pending, .accepted, .scheduled, .quoted:
            Button(role: .destructive) { setStatus(.cancelled) } label: {
                Label("Cancel request", systemImage: "xmark.circle.fill")
            }
        default:
            EmptyView()
        }
    }

    // MARK: - Actions

    private func setStatus(_ status: JobStatus) {
        request.status = status
        request.updatedAt = Date()
        try? context.save()
        HapticsManager.success()
    }

    private func save() {
        request.updatedAt = Date()
        try? context.save()
    }

    private func generateQuote() {
        guard let customer = request.customer, let vehicle = request.vehicle else { return }
        let shopDescriptor = FetchDescriptor<ShopSettings>()
        let shop = (try? context.fetch(shopDescriptor))?.first ?? ShopSettings()
        let quote = Quote(
            quoteNumber: backend.quoteNumbers.nextNumber(in: context),
            status: .draft,
            issueDate: Date(),
            expiryDate: Calendar.current.date(byAdding: .day, value: shop.quoteValidDays, to: Date()) ?? Date(),
            taxRate: shop.defaultTaxRate,
            customer: customer,
            vehicle: vehicle
        )
        context.insert(quote)

        // Seed a labor line from the estimate
        if request.estimatedHours > 0 || request.estimatedCost > 0 {
            let rate = vehicle.laborRateOverride ?? shop.defaultLaborRate
            let line = QuoteLineItem(
                sortOrder: 0,
                type: .labor,
                itemDescription: "From request — \(request.displayTitle)",
                quantity: request.estimatedHours,
                unitPrice: rate,
                hours: request.estimatedHours,
                laborRate: rate,
                quote: quote
            )
            line.recomputeLineTotal()
            context.insert(line)
            quote.lineItems = [line]
            quote.recompute()
        }

        request.quote = quote
        request.status = .quoted
        request.updatedAt = Date()
        try? context.save()
        HapticsManager.success()
        openedQuote = quote
    }
}
