import SwiftUI
import SwiftData

struct GarageView: View {
    @Environment(Backend.self) private var backend
    @Environment(\.modelContext) private var context

    @Query(sort: \Vehicle.updatedAt, order: .reverse) private var vehicles: [Vehicle]
    @Query private var shopSettings: [ShopSettings]
    @State private var vm: GarageViewModel?
    @State private var showingPaywall: Bool = false
    @State private var blockReason: QuotaBlockReason?
    @State private var showBlockAlert: Bool = false

    private var isMechanicMode: Bool { shopSettings.first?.role == .mechanic }
    private var availableFilters: [GarageFilter] {
        // Customer mode never sees "Customers" filter — they have no customers.
        isMechanicMode ? GarageFilter.allCases : [.all, .personal]
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.bgPrimary.ignoresSafeArea()
                if let vm {
                    content(vm: vm)
                } else {
                    ProgressView()
                }
            }
            .wbBreadcrumbs([Crumb("Garage", icon: "car.2.fill")])
            .navigationTitle("Garage")
            .toolbar { toolbar }
            .searchable(text: Binding(
                get: { vm?.searchQuery ?? "" },
                set: { vm?.searchQuery = $0 }
            ), prompt: "Search vehicles")
            .sheet(isPresented: Binding(
                get: { vm?.addingVehicle ?? false },
                set: { vm?.addingVehicle = $0 }
            )) {
                if let vm {
                    NavigationStack {
                        VehicleEditorView(vehicle: nil) {
                            vm.addingVehicle = false
                        }
                    }
                }
            }
            .sheet(isPresented: $showingPaywall) {
                PaywallView()
            }
            .alert(blockReason?.title ?? "Limit hit",
                   isPresented: $showBlockAlert,
                   presenting: blockReason) { _ in
                Button("OK", role: .cancel) {}
            } message: { reason in
                Text(reason.message)
            }
            .onAppear {
                if vm == nil {
                    vm = GarageViewModel(context: context)
                }
            }
        }
    }

    @ViewBuilder
    private func content(vm: GarageViewModel) -> some View {
        let visible = vm.vehicles(from: vehicles)
        VStack(spacing: 0) {
            if availableFilters.count > 1 {
                GSChipBar(
                    items: availableFilters,
                    selection: Binding(get: { vm.filter }, set: { vm.filter = $0 }),
                    label: { $0.displayName },
                    icon: { filter in
                        switch filter {
                        case .all: return "car.2.fill"
                        case .personal: return "house.fill"
                        case .customer: return "person.fill"
                        }
                    }
                )
            }

            if visible.isEmpty {
                GSEmptyState(
                    icon: "car.fill",
                    title: vehicles.isEmpty ? "No vehicles yet" : "No matches",
                    message: vehicles.isEmpty
                        ? "Add your first car, truck, or motorcycle to get started."
                        : "Try a different filter or search term.",
                    ctaTitle: vehicles.isEmpty ? "Add Vehicle" : nil,
                    ctaIcon: "plus",
                    ctaAction: vehicles.isEmpty ? { handleAdd(vm: vm) } : nil
                )
            } else {
                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(.flexible(), spacing: Spacing.m), GridItem(.flexible(), spacing: Spacing.m)],
                        spacing: Spacing.m
                    ) {
                        ForEach(visible) { vehicle in
                            NavigationLink {
                                VehicleDetailView(vehicle: vehicle)
                            } label: {
                                VehicleCardView(vehicle: vehicle, urgency: vm.summary(for: vehicle, currentMileage: vehicle.currentMileage))
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button(role: .destructive) {
                                    vm.deleteVehicle(vehicle)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .padding(Spacing.m)
                }
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                if let vm { handleAdd(vm: vm) }
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Color.accentPrimary)
            }
        }
    }

    private func handleAdd(vm: GarageViewModel) {
        HapticsManager.medium()
        let entitlements = backend.effectiveEntitlements()
        let decision = backend.quota.check(
            currentTotal: vehicles.count,
            entitlements: entitlements,
            now: Date()
        )
        switch decision {
        case .allowed:
            vm.addingVehicle = true
        case .blocked(let reason):
            blockReason = reason
            // For tier-limit blocks, show paywall directly (most actionable).
            // Rate-limit blocks show the alert with the explanation.
            if case .tierLimit = reason {
                showingPaywall = true
            } else {
                showBlockAlert = true
            }
        }
    }
}

#Preview {
    GarageView()
        .environment(Backend.preview())
        .modelContainer(PreviewModelContainer.shared)
}
