import SwiftUI
import SwiftData

struct ExportCenterView: View {
    @Environment(Backend.self) private var backend
    @Environment(\.modelContext) private var context
    @Query private var vehicles: [Vehicle]
    @Query private var customers: [Customer]
    @Query private var quotes: [Quote]
    @State private var pdfURL: URL?

    var body: some View {
        List {
            Section("Vehicle Service History") {
                if vehicles.isEmpty {
                    Text("Add a vehicle first.")
                        .font(.wbCaption)
                        .foregroundStyle(Color.textTertiary)
                } else {
                    ForEach(vehicles) { vehicle in
                        Button {
                            exportVehicle(vehicle)
                        } label: {
                            HStack {
                                Image(systemName: vehicle.type.sfSymbol).foregroundStyle(Color.accentPrimary).frame(width: 24)
                                Text(vehicle.displayTitle)
                                    .foregroundStyle(Color.textPrimary)
                                Spacer()
                                Image(systemName: "square.and.arrow.up")
                                    .foregroundStyle(Color.accentPrimary)
                            }
                        }
                    }
                }
            }
            Section("Customer File") {
                if customers.isEmpty {
                    Text("Add a customer first.")
                        .font(.wbCaption)
                        .foregroundStyle(Color.textTertiary)
                } else {
                    ForEach(customers) { customer in
                        Button {
                            exportCustomer(customer)
                        } label: {
                            HStack {
                                GSAvatar(initials: customer.initials, size: 28)
                                Text(customer.displayName)
                                    .foregroundStyle(Color.textPrimary)
                                Spacer()
                                Image(systemName: "square.and.arrow.up")
                                    .foregroundStyle(Color.accentPrimary)
                            }
                        }
                    }
                }
            }
            Section("Quote PDF") {
                if quotes.isEmpty {
                    Text("No quotes yet.")
                        .font(.wbCaption)
                        .foregroundStyle(Color.textTertiary)
                } else {
                    ForEach(quotes.sorted { $0.issueDate > $1.issueDate }) { quote in
                        Button {
                            exportQuote(quote)
                        } label: {
                            HStack {
                                Image(systemName: "doc.text.fill").foregroundStyle(Color.accentPrimary).frame(width: 24)
                                VStack(alignment: .leading) {
                                    Text(quote.quoteNumber)
                                        .foregroundStyle(Color.textPrimary)
                                    Text(quote.customer?.displayName ?? "")
                                        .font(.wbCaption)
                                        .foregroundStyle(Color.textSecondary)
                                }
                                Spacer()
                                Image(systemName: "square.and.arrow.up")
                                    .foregroundStyle(Color.accentPrimary)
                            }
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.bgPrimary)
        .navigationTitle("Export Center")
        .sheet(item: $pdfURL) { url in
            ShareSheet(activityItems: [url])
        }
    }

    private func currentShop() -> ShopSettings {
        let descriptor = FetchDescriptor<ShopSettings>()
        return (try? context.fetch(descriptor))?.first ?? ShopSettings()
    }

    private func exportVehicle(_ vehicle: Vehicle) {
        let data = backend.pdf.export(.vehicleHistory(vehicle, dateRange: nil, includeReceipts: false), shop: currentShop())
        if let url = TempFile.write(data, name: "Service_\(vehicle.year)_\(vehicle.make)_\(vehicle.model)", ext: "pdf") {
            pdfURL = url
        }
    }

    private func exportCustomer(_ customer: Customer) {
        let data = backend.pdf.export(.customerFile(customer), shop: currentShop())
        if let url = TempFile.write(data, name: "Customer_\(customer.displayName)", ext: "pdf") {
            pdfURL = url
        }
    }

    private func exportQuote(_ quote: Quote) {
        let data = backend.pdf.export(.quote(quote), shop: currentShop())
        if let url = TempFile.write(data, name: "Quote_\(quote.quoteNumber)", ext: "pdf") {
            pdfURL = url
        }
    }
}
