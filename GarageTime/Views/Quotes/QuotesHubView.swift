import SwiftUI
import SwiftData

enum QuoteHubFilter: String, CaseIterable, Hashable, Identifiable {
    case all, draft, sent, approved, declined, expired, completed
    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }

    func matches(_ status: QuoteStatus) -> Bool {
        switch self {
        case .all:       return true
        case .draft:     return status == .draft
        case .sent:      return status == .sent
        case .approved:  return status == .approved
        case .declined:  return status == .declined
        case .expired:   return status == .expired
        case .completed: return status == .completed
        }
    }
}

struct QuotesHubView: View {
    @Environment(Backend.self) private var backend
    @Environment(\.modelContext) private var context
    @Query(sort: \Quote.issueDate, order: .reverse) private var quotes: [Quote]
    @State private var filter: QuoteHubFilter = .all
    @State private var newQuoteCustomer: Customer?
    @State private var showCustomerPicker: Bool = false
    @State private var openedQuote: Quote?
    @State private var showingPaywall: Bool = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.bgPrimary.ignoresSafeArea()
                if quotes.isEmpty {
                    GSEmptyState(
                        icon: "doc.text.fill",
                        title: "No quotes yet",
                        message: "Quote customer work with line items, fees, and tax. Sign and send a PDF.",
                        ctaTitle: "New Quote",
                        ctaIcon: "plus",
                        ctaAction: handleNew
                    )
                } else {
                    content
                }
            }
            .wbBreadcrumbs([Crumb("Quotes", icon: "doc.text.fill")])
            .navigationTitle("Quotes")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: handleNew) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(Color.accentPrimary)
                    }
                }
            }
            .sheet(isPresented: $showCustomerPicker) {
                CustomerPickerSheet(selected: Binding(
                    get: { newQuoteCustomer },
                    set: { newQuoteCustomer = $0 }
                ))
                .onDisappear {
                    if let customer = newQuoteCustomer {
                        createQuote(for: customer)
                    }
                }
            }
            .sheet(item: $openedQuote) { quote in
                NavigationStack { QuoteBuilderView(quote: quote) }
            }
            .sheet(isPresented: $showingPaywall) {
                PaywallView()
            }
        }
    }

    private var content: some View {
        VStack(spacing: 0) {
            statsHeader
            GSChipBar(items: QuoteHubFilter.allCases, selection: $filter, label: { $0.displayName }, icon: nil)
            List {
                ForEach(filteredQuotes) { quote in
                    Button {
                        openedQuote = quote
                    } label: {
                        quoteRow(quote)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color.bgSecondary)
                }
                .onDelete(perform: deleteQuotes)
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
        }
    }

    private var statsHeader: some View {
        HStack(spacing: Spacing.s) {
            GSStatBlock(label: "Outstanding", value: Money.format(outstandingValue), icon: "hourglass", role: .warning)
            GSStatBlock(label: "Conversion", value: conversionPercent, icon: "checkmark.seal.fill", role: .success)
        }
        .padding(Spacing.m)
    }

    private var filteredQuotes: [Quote] {
        quotes.filter { filter.matches($0.status) }
    }

    private var outstandingValue: Double {
        Money.sum(quotes.filter { $0.status == .sent || $0.status == .approved }.map(\.total))
    }

    private var conversionPercent: String {
        let sent = quotes.filter { $0.status == .sent || $0.status == .approved || $0.status == .completed }.count
        guard sent > 0 else { return "—" }
        let won = quotes.filter { $0.status == .approved || $0.status == .completed }.count
        let pct = Double(won) / Double(sent)
        return WBFormat.percent(pct)
    }

    private func quoteRow(_ quote: Quote) -> some View {
        HStack(spacing: Spacing.s) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: Spacing.xs) {
                    Text(quote.quoteNumber)
                        .font(.wbMonoCaption)
                        .foregroundStyle(Color.textSecondary)
                    GSStatusPill(text: quote.status.displayName, role: quote.status.paletteRole, compact: true)
                }
                Text(quote.customer?.displayName ?? "—")
                    .font(.wbBodyMedium)
                    .foregroundStyle(Color.textPrimary)
                Text(quote.vehicle?.displayTitle ?? "")
                    .font(.wbCaption)
                    .foregroundStyle(Color.textSecondary)
                    .lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(Money.format(quote.total))
                    .font(.wbMonoBody)
                    .foregroundStyle(Color.textPrimary)
                Text(WBFormat.relative(quote.issueDate))
                    .font(.wbCaptionSmall)
                    .foregroundStyle(Color.textTertiary)
            }
        }
        .padding(.vertical, 4)
    }

    private func handleNew() {
        let gate = PaywallGate.createQuote
        if gate.isLocked(for: backend.store.entitlements.tier) {
            showingPaywall = true
            return
        }
        showCustomerPicker = true
    }

    private func createQuote(for customer: Customer) {
        let shopDescriptor = FetchDescriptor<ShopSettings>()
        let shop = (try? context.fetch(shopDescriptor))?.first ?? ShopSettings()
        let quote = Quote(
            quoteNumber: backend.quoteNumbers.nextNumber(in: context),
            status: .draft,
            issueDate: Date(),
            expiryDate: Calendar.current.date(byAdding: .day, value: shop.quoteValidDays, to: Date()) ?? Date(),
            taxRate: shop.defaultTaxRate,
            customer: customer,
            vehicle: customer.vehicles?.first
        )
        context.insert(quote)
        try? context.save()
        HapticsManager.success()
        newQuoteCustomer = nil
        openedQuote = quote
    }

    private func deleteQuotes(at offsets: IndexSet) {
        for index in offsets {
            context.delete(filteredQuotes[index])
        }
        try? context.save()
    }
}

#Preview {
    QuotesHubView()
        .environment(Backend.preview())
        .modelContainer(PreviewModelContainer.shared)
}
