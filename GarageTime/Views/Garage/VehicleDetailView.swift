import SwiftUI
import SwiftData

enum VehicleDetailTab: String, CaseIterable, Hashable {
    case overview, service, parts, reminders, quotes, costs
    var displayName: String {
        switch self {
        case .overview:  return "Overview"
        case .service:   return "Service"
        case .parts:     return "Parts"
        case .reminders: return "Reminders"
        case .quotes:    return "Quotes"
        case .costs:     return "Costs"
        }
    }
}

struct VehicleDetailView: View {
    @Environment(Backend.self) private var backend
    @Environment(\.modelContext) private var context
    @Bindable var vehicle: Vehicle

    @State private var tab: VehicleDetailTab = .overview
    @State private var addingService: Bool = false
    @State private var addingPart: Bool = false
    @State private var addingReminder: Bool = false
    @State private var editingVehicle: Bool = false
    @State private var exportingPDF: Bool = false
    @State private var exportURL: URL?

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                photoHeader
                quickStats
                segmentedHeader
                Group {
                    switch tab {
                    case .overview:  overviewTab
                    case .service:   serviceTab
                    case .parts:     partsTab
                    case .reminders: remindersTab
                    case .quotes:    quotesTab
                    case .costs:     costsTab
                    }
                }
                .padding(.horizontal, Spacing.m)
                .padding(.top, Spacing.s)
                .padding(.bottom, Spacing.xl)
            }
        }
        .wbScreenBackground()
        .wbBreadcrumbs([
            Crumb("Garage", icon: "car.2.fill"),
            Crumb(vehicle.displayTitle, icon: vehicle.type.sfSymbol),
            Crumb(tab.displayName),
        ])
        .navigationTitle(vehicle.displayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { editingVehicle = true } label: { Label("Edit", systemImage: "pencil") }
                    Button { exportHistoryPDF() } label: { Label("Export History PDF", systemImage: "square.and.arrow.up") }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $editingVehicle) {
            NavigationStack {
                VehicleEditorView(vehicle: vehicle) {}
            }
        }
        .sheet(isPresented: $addingService) {
            NavigationStack {
                ServiceRecordEditorView(vehicle: vehicle, record: nil)
            }
        }
        .sheet(isPresented: $addingPart) {
            NavigationStack {
                PartEditorView(vehicle: vehicle, part: nil)
            }
        }
        .sheet(isPresented: $addingReminder) {
            NavigationStack {
                ReminderEditorView(reminder: nil)
            }
        }
        .sheet(item: $exportURL) { url in
            ShareSheet(activityItems: [url])
        }
    }

    // MARK: - Header

    private var photoHeader: some View {
        ZStack(alignment: .bottomLeading) {
            Group {
                if let data = vehicle.photoData, let ui = UIImage(data: data) {
                    Image(uiImage: ui).resizable().scaledToFill()
                } else {
                    LinearGradient(colors: [Color.bgTertiary, Color.bgSecondary], startPoint: .top, endPoint: .bottom)
                        .overlay(
                            Image(systemName: vehicle.type.sfSymbol)
                                .font(.system(size: 70, weight: .ultraLight))
                                .foregroundStyle(Color.textTertiary)
                        )
                }
            }
            .frame(height: 220)
            .clipped()

            LinearGradient(
                colors: [.black.opacity(0.55), .clear, .black.opacity(0.4)],
                startPoint: .bottom, endPoint: .top
            )
            .frame(height: 220)

            VStack(alignment: .leading, spacing: 4) {
                if vehicle.ownerType == .customer, let customer = vehicle.customer {
                    GSStatusPill(text: customer.displayName, role: .accent, icon: "person.fill")
                }
                Text(vehicle.displayTitle)
                    .font(.wbDisplayMedium)
                    .foregroundStyle(.white)
                if !vehicle.subtitle.isEmpty {
                    Text(vehicle.subtitle)
                        .font(.wbCallout)
                        .foregroundStyle(.white.opacity(0.85))
                }
            }
            .padding(Spacing.m)
        }
    }

    private var quickStats: some View {
        VStack(spacing: Spacing.s) {
            HStack(spacing: Spacing.s) {
                GSStatBlock(label: "Mileage", value: "\(vehicle.currentMileage)", detail: vehicle.mileageUnit.rawValue, icon: "speedometer")
                GSStatBlock(label: "Hours", value: WBFormat.hours(vehicle.totalLaborHours), icon: "clock.fill", role: .info)
            }
            HStack(spacing: Spacing.s) {
                GSStatBlock(label: "Records", value: "\(vehicle.serviceRecords?.count ?? 0)", icon: "wrench.adjustable.fill")
                GSStatBlock(label: vehicle.ownerType == .customer ? "Billed" : "Spent",
                            value: Money.displayCost(vehicle.totalSpent),
                            icon: "dollarsign.circle.fill",
                            role: .accent)
            }
        }
        .padding(Spacing.m)
    }

    private var segmentedHeader: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.xs) {
                ForEach(availableTabs, id: \.self) { t in
                    Button {
                        withAnimation(Motion.snap) { tab = t }
                    } label: {
                        Text(t.displayName)
                            .font(.wbCaption)
                            .fontWeight(tab == t ? .semibold : .medium)
                            .foregroundStyle(tab == t ? Color.textOnAccent : Color.textPrimary)
                            .padding(.horizontal, Spacing.s)
                            .padding(.vertical, 6)
                            .background(
                                Capsule().fill(tab == t ? Color.accentPrimary : Color.bgSecondary)
                            )
                            .overlay(
                                Capsule().strokeBorder(
                                    tab == t ? Color.clear : Color.dividerColor,
                                    lineWidth: 0.5
                                )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Spacing.m)
        }
    }

    private var availableTabs: [VehicleDetailTab] {
        VehicleDetailTab.allCases.filter { tab in
            switch tab {
            case .quotes: return vehicle.ownerType == .customer
            case .costs:  return true
            default:      return true
            }
        }
    }

    // MARK: - Tabs

    private var overviewTab: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            specRow("Year", value: vehicle.year > 0 ? String(vehicle.year) : "—")
            specRow("Make", value: vehicle.make.isEmpty ? "—" : vehicle.make)
            specRow("Model", value: vehicle.model.isEmpty ? "—" : vehicle.model)
            specRow("Trim", value: vehicle.trim.isEmpty ? "—" : vehicle.trim)
            specRow("VIN", value: vehicle.vin.isEmpty ? "—" : vehicle.vin, mono: true)
            specRow("Plate", value: vehicle.licensePlate.isEmpty ? "—" : vehicle.licensePlate, mono: true)
            specRow("Type", value: vehicle.type.displayName)
            specRow("Powertrain", value: vehicle.powertrain.displayName)
            if !vehicle.notes.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Notes")
                        .font(.wbCaption)
                        .foregroundStyle(Color.textSecondary)
                    Text(vehicle.notes)
                        .font(.wbBody)
                        .foregroundStyle(Color.textPrimary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Spacing.m)
                .background(RoundedRectangle(cornerRadius: Radius.l).fill(Color.bgSecondary))
            }
        }
    }

    private func specRow(_ label: String, value: String, mono: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(.wbCaption)
                .foregroundStyle(Color.textSecondary)
            Spacer()
            Text(value)
                .font(mono ? .wbMonoBody : .wbBody)
                .foregroundStyle(Color.textPrimary)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, Spacing.m)
        .background(RoundedRectangle(cornerRadius: Radius.m).fill(Color.bgSecondary))
    }

    private var serviceTab: some View {
        VStack(spacing: Spacing.s) {
            GSButton(title: "Add Service Record", icon: "plus", style: .primary) {
                addingService = true
            }
            let records = (vehicle.serviceRecords ?? []).sorted { $0.date > $1.date }
            if records.isEmpty {
                Text("No service records yet.")
                    .font(.wbCaption)
                    .foregroundStyle(Color.textTertiary)
                    .padding(Spacing.m)
            } else {
                ForEach(records) { record in
                    NavigationLink {
                        ServiceRecordEditorView(vehicle: vehicle, record: record)
                    } label: {
                        GSLineItemRow(
                            leadingIcon: record.category.sfSymbol,
                            title: record.title.isEmpty ? record.category.displayName : record.title,
                            subtitle: serviceRowSubtitle(record),
                            trailing: Money.format(record.totalCost),
                            trailingSubtitle: record.performedBy.displayName,
                            role: record.performedBy == .shop ? .accent : .neutral
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var partsTab: some View {
        VStack(spacing: Spacing.s) {
            GSButton(title: "Add Part", icon: "plus", style: .primary) {
                addingPart = true
            }
            let parts = vehicle.parts ?? []
            if parts.isEmpty {
                Text("No parts yet.")
                    .font(.wbCaption)
                    .foregroundStyle(Color.textTertiary)
                    .padding(Spacing.m)
            } else {
                ForEach(parts) { part in
                    NavigationLink {
                        PartEditorView(vehicle: vehicle, part: part)
                    } label: {
                        GSLineItemRow(
                            leadingIcon: part.isOnShelf ? "tray.fill" : "shippingbox.fill",
                            title: part.displayTitle,
                            subtitle: [part.brand, part.partNumber].filter { !$0.isEmpty }.joined(separator: " · "),
                            trailing: Money.format(part.price),
                            trailingSubtitle: part.isOnShelf ? "On shelf" : "Installed",
                            role: part.isOnShelf ? .warning : .neutral
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var remindersTab: some View {
        VStack(spacing: Spacing.s) {
            GSButton(title: "Add Reminder", icon: "plus", style: .primary) {
                addingReminder = true
            }
            let reminders = vehicle.reminders ?? []
            if reminders.isEmpty {
                Text("No reminders yet.")
                    .font(.wbCaption)
                    .foregroundStyle(Color.textTertiary)
                    .padding(Spacing.m)
            } else {
                ForEach(reminders) { reminder in
                    NavigationLink {
                        ReminderEditorView(reminder: reminder)
                    } label: {
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            HStack {
                                Image(systemName: reminder.category.sfSymbol)
                                    .foregroundStyle(Color.accentPrimary)
                                Text(reminder.displayTitle)
                                    .font(.wbBodyMedium)
                                    .foregroundStyle(Color.textPrimary)
                                Spacer()
                                let urgency = reminder.urgency(now: Date(), currentMileage: vehicle.currentMileage)
                                GSStatusPill(text: urgency.displayName, role: urgency.paletteRole, compact: true)
                            }
                            GSProgressBar(
                                progress: reminder.progress(now: Date(), currentMileage: vehicle.currentMileage),
                                role: reminder.urgency(now: Date(), currentMileage: vehicle.currentMileage).paletteRole
                            )
                        }
                        .padding(Spacing.m)
                        .background(RoundedRectangle(cornerRadius: Radius.m).fill(Color.bgSecondary))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var quotesTab: some View {
        VStack(spacing: Spacing.s) {
            let quotes = vehicle.quotes ?? []
            if quotes.isEmpty {
                Text("No quotes for this vehicle yet.")
                    .font(.wbCaption)
                    .foregroundStyle(Color.textTertiary)
                    .padding(Spacing.m)
            } else {
                ForEach(quotes.sorted { $0.issueDate > $1.issueDate }) { quote in
                    NavigationLink {
                        QuoteBuilderView(quote: quote)
                    } label: {
                        GSLineItemRow(
                            leadingIcon: "doc.text.fill",
                            title: quote.quoteNumber,
                            subtitle: WBFormat.shortDate.string(from: quote.issueDate),
                            trailing: Money.format(quote.total),
                            trailingSubtitle: quote.status.displayName,
                            role: quote.status == .completed ? .success : .neutral
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var costsTab: some View {
        let records = vehicle.serviceRecords ?? []
        let byCategory = Dictionary(grouping: records, by: { $0.category })

        return VStack(alignment: .leading, spacing: Spacing.s) {
            // Big summary card
            VStack(alignment: .leading, spacing: Spacing.s) {
                HStack {
                    Text(vehicle.ownerType == .customer ? "Billing summary" : "Cost summary")
                        .font(.wbHeadline)
                        .foregroundStyle(Color.textPrimary)
                    Spacer()
                    Text(Money.format(vehicle.totalSpent))
                        .font(.wbDisplayMedium)
                        .foregroundStyle(Color.accentPrimary)
                }
                Divider().background(Color.dividerColor)
                breakdownLine("Labor", icon: "wrench.and.screwdriver.fill",
                              value: Money.format(vehicle.totalLaborCost))
                breakdownLine("Parts", icon: "shippingbox.fill",
                              value: Money.format(vehicle.totalPartsCost))
                if vehicle.totalFeesAndTax > 0 {
                    breakdownLine("Fees + tax", icon: "doc.text.fill",
                                  value: Money.format(vehicle.totalFeesAndTax))
                }
                breakdownLine("Time", icon: "clock.fill",
                              value: WBFormat.hours(vehicle.totalLaborHours),
                              accent: true)
            }
            .padding(Spacing.m)
            .background(RoundedRectangle(cornerRadius: Radius.l).fill(Color.bgSecondary))

            // By-category breakdown
            if !byCategory.isEmpty {
                Text("By category")
                    .font(.wbCaption)
                    .foregroundStyle(Color.textSecondary)
                    .padding(.top, Spacing.s)
                ForEach(byCategory.keys.sorted { $0.displayName < $1.displayName }, id: \.self) { cat in
                    let group = byCategory[cat] ?? []
                    let total = Money.sum(group.map(\.totalCost))
                    let hours = group.reduce(0) { $0 + $1.laborHours }
                    GSLineItemRow(
                        leadingIcon: cat.sfSymbol,
                        title: cat.displayName,
                        subtitle: hoursAndCountSubtitle(records: group.count, hours: hours),
                        trailing: Money.format(total),
                        trailingSubtitle: nil,
                        role: .neutral
                    )
                }
            }
        }
    }

    private func serviceRowSubtitle(_ record: ServiceRecord) -> String {
        var parts: [String] = [
            WBFormat.shortDate.string(from: record.date),
            "\(record.mileageAtService) mi",
        ]
        if record.laborHours > 0 {
            parts.append(WBFormat.hours(record.laborHours))
        }
        return parts.joined(separator: " · ")
    }

    private func hoursAndCountSubtitle(records: Int, hours: Double) -> String {
        let countText = "\(records) \(records == 1 ? "record" : "records")"
        if hours <= 0 { return countText }
        return "\(countText) · \(WBFormat.hours(hours))"
    }

    @ViewBuilder
    private func breakdownLine(_ label: String, icon: String, value: String, accent: Bool = false) -> some View {
        HStack(spacing: Spacing.s) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(accent ? Color.accentPrimary : Color.textSecondary)
                .frame(width: 18)
            Text(label)
                .font(.wbBody)
                .foregroundStyle(Color.textPrimary)
            Spacer()
            Text(value)
                .font(.wbMonoBody)
                .foregroundStyle(accent ? Color.accentPrimary : Color.textPrimary)
        }
    }

    private func exportHistoryPDF() {
        let shopDescriptor = FetchDescriptor<ShopSettings>()
        let shop = (try? context.fetch(shopDescriptor))?.first ?? ShopSettings()
        let data = backend.pdf.export(.vehicleHistory(vehicle, dateRange: nil, includeReceipts: false), shop: shop)
        if let url = TempFile.write(data, name: "ServiceHistory_\(vehicle.year)_\(vehicle.make)_\(vehicle.model)", ext: "pdf") {
            exportURL = url
        }
    }
}
