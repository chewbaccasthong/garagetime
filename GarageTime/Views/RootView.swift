import SwiftUI
import SwiftData

enum MechanicTab: Hashable {
    case garage, customers, quotes, jobs, more
}

enum CustomerTab: Hashable {
    case mygarage, estimate, requests, more
}

struct RootView: View {
    @Environment(Backend.self) private var backend
    @Environment(\.modelContext) private var context
    @Query private var shopSettings: [ShopSettings]

    @State private var mechanicSelection: MechanicTab = .garage
    @State private var customerSelection: CustomerTab = .mygarage
    @State private var showWalkthrough: Bool = false

    var body: some View {
        Group {
            if let role = shopSettings.first?.role {
                switch role {
                case .mechanic: mechanicTabs
                case .customer: customerTabs
                }
            } else {
                OnboardingView()
            }
        }
        .tint(Color.accentPrimary)
        .sheet(isPresented: $showWalkthrough) {
            WalkthroughView()
        }
        .onChange(of: shopSettings.first?.hasCompletedOnboarding ?? false) { _, completed in
            if completed,
               let shop = shopSettings.first,
               !shop.hasCompletedWalkthrough {
                showWalkthrough = true
            }
        }
        .onAppear {
            if let shop = shopSettings.first,
               shop.hasCompletedOnboarding,
               !shop.hasCompletedWalkthrough {
                showWalkthrough = true
            }
        }
    }

    // MARK: - Mechanic experience

    private var mechanicTabs: some View {
        TabView(selection: $mechanicSelection) {
            GarageView()
                .tabItem { Label("Garage", systemImage: "car.2.fill") }
                .tag(MechanicTab.garage)

            CustomersListView()
                .tabItem { Label("Customers", systemImage: "person.2.fill") }
                .tag(MechanicTab.customers)

            QuotesHubView()
                .tabItem { Label("Quotes", systemImage: "doc.text.fill") }
                .tag(MechanicTab.quotes)

            JobsHubView()
                .tabItem { Label("Jobs", systemImage: "tray.full.fill") }
                .tag(MechanicTab.jobs)
                .badge(pendingJobCount)

            MoreView()
                .tabItem { Label("More", systemImage: "ellipsis.circle.fill") }
                .tag(MechanicTab.more)
        }
    }

    // MARK: - Customer experience

    private var customerTabs: some View {
        TabView(selection: $customerSelection) {
            GarageView()
                .tabItem { Label("My Garage", systemImage: "car.fill") }
                .tag(CustomerTab.mygarage)

            EstimateView()
                .tabItem { Label("Estimates", systemImage: "wand.and.stars") }
                .tag(CustomerTab.estimate)

            MyRequestsView()
                .tabItem { Label("Requests", systemImage: "paperplane.fill") }
                .tag(CustomerTab.requests)

            MoreView()
                .tabItem { Label("More", systemImage: "ellipsis.circle.fill") }
                .tag(CustomerTab.more)
        }
    }

    private var pendingJobCount: Int {
        let descriptor = FetchDescriptor<JobRequest>(
            predicate: #Predicate { $0.statusRaw == "pending" }
        )
        return (try? context.fetchCount(descriptor)) ?? 0
    }
}

#Preview {
    RootView()
        .environment(Backend.preview())
        .modelContainer(PreviewModelContainer.shared)
}
