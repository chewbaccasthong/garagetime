import SwiftUI
import SwiftData

struct CustomerDetailView: View {
    @Environment(Backend.self) private var backend
    @Environment(\.modelContext) private var context
    let customer: Customer
    @State private var showEditor: Bool = false
    @State private var exportingPDF: Bool = false
    @State private var exportURL: URL?

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.m) {
                header
                stats
                vehiclesSection
                quotesSection
            }
            .padding(Spacing.m)
        }
        .wbScreenBackground()
        .wbBreadcrumbs([
            Crumb("Customers", icon: "person.2.fill"),
            Crumb(customer.displayName, icon: "person.fill"),
        ])
        .navigationTitle(customer.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { showEditor = true } label: { Label("Edit", systemImage: "pencil") }
                    Button { exportCustomerPDF() } label: { Label("Export Customer File", systemImage: "square.and.arrow.up") }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showEditor) {
            NavigationStack {
                CustomerEditorView(customer: customer)
            }
        }
        .sheet(item: $exportURL) { url in
            ShareSheet(activityItems: [url])
        }
    }

    private var header: some View {
        VStack(spacing: Spacing.s) {
            GSAvatar(initials: customer.initials, size: 80)
            Text(customer.displayName)
                .font(.wbTitleLarge)
                .foregroundStyle(Color.textPrimary)
            if !customer.email.isEmpty || !customer.phone.isEmpty {
                Text([customer.phone, customer.email].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.wbBody)
                    .foregroundStyle(Color.textSecondary)
            }
            if !customer.formattedAddress.isEmpty {
                Text(customer.formattedAddress)
                    .font(.wbCaption)
                    .foregroundStyle(Color.textTertiary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(Spacing.l)
        .wbCard()
    }

    private var stats: some View {
        VStack(spacing: Spacing.s) {
            HStack(spacing: Spacing.s) {
                GSStatBlock(label: "Vehicles", value: "\(customer.vehicleCount)", icon: "car.2.fill")
                GSStatBlock(label: "Hours", value: WBFormat.hours(customer.totalLaborHours),
                            icon: "clock.fill", role: .info)
            }
            HStack(spacing: Spacing.s) {
                GSStatBlock(label: "Labor", value: Money.format(customer.totalLaborCost),
                            icon: "wrench.and.screwdriver.fill")
                GSStatBlock(label: "Parts", value: Money.format(customer.totalPartsCost),
                            icon: "shippingbox.fill")
            }
            HStack(spacing: Spacing.s) {
                GSStatBlock(label: "Billed (quotes)", value: Money.format(customer.totalBilled),
                            icon: "dollarsign.circle.fill", role: .accent)
                GSStatBlock(label: "Quotes", value: "\(customer.quotes?.count ?? 0)",
                            icon: "doc.text.fill")
            }
        }
    }

    @ViewBuilder
    private var vehiclesSection: some View {
        GSSectionHeader(title: "Vehicles", actionTitle: nil)
        if let vehicles = customer.vehicles, !vehicles.isEmpty {
            ForEach(vehicles) { vehicle in
                NavigationLink {
                    VehicleDetailView(vehicle: vehicle)
                } label: {
                    GSLineItemRow(
                        leadingIcon: vehicle.type.sfSymbol,
                        title: vehicle.displayTitle,
                        subtitle: vehicle.subtitle.isEmpty ? "\(vehicle.currentMileage) mi" : vehicle.subtitle,
                        trailing: nil,
                        trailingSubtitle: vehicle.lastServiceDate.map { WBFormat.relative($0) },
                        role: .accent
                    )
                }
                .buttonStyle(.plain)
            }
        } else {
            Text("No vehicles yet")
                .font(.wbCaption)
                .foregroundStyle(Color.textTertiary)
                .padding(Spacing.m)
        }
    }

    @ViewBuilder
    private var quotesSection: some View {
        GSSectionHeader(title: "Quotes", actionTitle: nil)
        if let quotes = customer.quotes, !quotes.isEmpty {
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
        } else {
            Text("No quotes yet")
                .font(.wbCaption)
                .foregroundStyle(Color.textTertiary)
                .padding(Spacing.m)
        }
    }

    private func exportCustomerPDF() {
        let descriptor = FetchDescriptor<ShopSettings>()
        let shop = (try? context.fetch(descriptor))?.first ?? ShopSettings()
        let data = backend.pdf.export(.customerFile(customer), shop: shop)
        if let url = TempFile.write(data, name: "Customer_\(customer.lastName.isEmpty ? customer.firstName : customer.lastName)", ext: "pdf") {
            exportURL = url
        }
    }
}

extension URL: Identifiable {
    public var id: String { absoluteString }
}
