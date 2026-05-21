import SwiftUI
import SwiftData

struct CustomersListView: View {
    @Environment(Backend.self) private var backend
    @Environment(\.modelContext) private var context
    @Query(sort: \Customer.lastName) private var customers: [Customer]
    @State private var query: String = ""
    @State private var addingCustomer: Bool = false
    @State private var showingPaywall: Bool = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.bgPrimary.ignoresSafeArea()
                if customers.isEmpty {
                    GSEmptyState(
                        icon: "person.2.fill",
                        title: "No customers yet",
                        message: "Add customers so you can track their vehicles and send quotes.",
                        ctaTitle: "Add Customer",
                        ctaIcon: "plus",
                        ctaAction: handleAdd
                    )
                } else {
                    List {
                        ForEach(filtered) { customer in
                            NavigationLink {
                                CustomerDetailView(customer: customer)
                            } label: {
                                customerRow(customer)
                            }
                            .listRowBackground(Color.bgSecondary)
                        }
                        .onDelete(perform: deleteCustomers)
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                }
            }
            .wbBreadcrumbs([Crumb("Customers", icon: "person.2.fill")])
            .navigationTitle("Customers")
            .searchable(text: $query, prompt: "Search customers")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: handleAdd) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(Color.accentPrimary)
                    }
                }
            }
            .sheet(isPresented: $addingCustomer) {
                NavigationStack {
                    CustomerEditorView(customer: nil) { _ in
                        addingCustomer = false
                    }
                }
            }
            .sheet(isPresented: $showingPaywall) {
                PaywallView()
            }
        }
    }

    private var filtered: [Customer] {
        let q = query.lowercased()
        guard !q.isEmpty else { return customers }
        return customers.filter {
            $0.displayName.lowercased().contains(q) ||
            $0.email.lowercased().contains(q) ||
            $0.phone.lowercased().contains(q) ||
            $0.companyName.lowercased().contains(q)
        }
    }

    private func customerRow(_ customer: Customer) -> some View {
        HStack(spacing: Spacing.s) {
            GSAvatar(initials: customer.initials, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(customer.displayName)
                    .font(.wbBodyMedium)
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)
                Text(customerSubtitle(customer))
                    .font(.wbCaption)
                    .foregroundStyle(Color.textSecondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                if customer.totalBilled > 0 {
                    Text(Money.format(customer.totalBilled))
                        .font(.wbMonoCaption)
                        .foregroundStyle(Color.accentPrimary)
                }
                if customer.totalLaborHours > 0 {
                    Text(WBFormat.hours(customer.totalLaborHours))
                        .font(.wbCaptionSmall)
                        .foregroundStyle(Color.statusBlue)
                }
            }
        }
    }

    private func customerSubtitle(_ customer: Customer) -> String {
        let count = customer.vehicleCount
        return "\(count) \(count == 1 ? "vehicle" : "vehicles")"
    }

    private func handleAdd() {
        let gate = PaywallGate.addCustomer
        if gate.isLocked(for: backend.store.entitlements.tier) {
            showingPaywall = true
        } else {
            addingCustomer = true
        }
        HapticsManager.medium()
    }

    private func deleteCustomers(at offsets: IndexSet) {
        for index in offsets {
            context.delete(filtered[index])
        }
        try? context.save()
    }
}

#Preview {
    CustomersListView()
        .environment(Backend.preview())
        .modelContainer(PreviewModelContainer.shared)
}
