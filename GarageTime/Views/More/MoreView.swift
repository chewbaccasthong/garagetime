import SwiftUI
import SwiftData

struct MoreView: View {
    @Environment(Backend.self) private var backend
    @Query private var shopSettings: [ShopSettings]

    private var role: UserRole { shopSettings.first?.role ?? .mechanic }

    var body: some View {
        NavigationStack {
            List {
                if let shop = shopSettings.first, shop.isTrialActive {
                    Section {
                        HStack(spacing: Spacing.s) {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(Color.accentPrimary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(shop.trialTier?.displayName ?? "Trial") trial active")
                                    .font(.wbBodyMedium)
                                    .foregroundStyle(Color.textPrimary)
                                Text("\(shop.trialDaysRemaining) day\(shop.trialDaysRemaining == 1 ? "" : "s") left — pick a plan to continue.")
                                    .font(.wbCaption)
                                    .foregroundStyle(Color.textSecondary)
                            }
                            Spacer()
                            NavigationLink {
                                SettingsView()
                            } label: {
                                Text("Upgrade")
                                    .font(.wbCaption)
                                    .foregroundStyle(Color.accentPrimary)
                            }
                        }
                    }
                }
                Section {
                    NavigationLink {
                        ReportsView()
                    } label: {
                        Label("Reports", systemImage: "chart.bar.xaxis")
                    }
                    NavigationLink {
                        ExportCenterView()
                    } label: {
                        Label("Export Center", systemImage: "square.and.arrow.up.on.square")
                    }
                    NavigationLink {
                        BulkImportView()
                    } label: {
                        Label("Bulk Import", systemImage: "square.and.arrow.down.on.square.fill")
                    }
                }
                if role == .mechanic {
                    Section {
                        NavigationLink {
                            ShopProfileView()
                        } label: {
                            Label("Shop Profile", systemImage: "storefront.fill")
                        }
                        NavigationLink {
                            AvailabilityView()
                        } label: {
                            Label("Availability", systemImage: "calendar")
                        }
                    }
                }
                Section {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Label("Settings", systemImage: "gearshape.fill")
                    }
                }
                Section {
                    NavigationLink {
                        AboutView()
                    } label: {
                        Label("About", systemImage: "info.circle.fill")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.bgPrimary)
            .wbBreadcrumbs([Crumb("More", icon: "ellipsis.circle.fill")])
            .navigationTitle("More")
        }
    }
}

struct AboutView: View {
    @Environment(\.modelContext) private var context
    @Query private var shopSettings: [ShopSettings]
    @State private var showWalkthrough: Bool = false

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.l) {
                ZStack {
                    Circle().fill(Color.accentPrimary.opacity(0.16)).frame(width: 96, height: 96)
                    Image(systemName: "wrench.and.screwdriver.fill")
                        .font(.system(size: 38, weight: .semibold))
                        .foregroundStyle(Color.accentPrimary)
                }
                Text("Garage Time")
                    .font(.wbDisplayMedium)
                    .foregroundStyle(Color.textPrimary)
                Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0") (\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"))")
                    .font(.wbCaption)
                    .foregroundStyle(Color.textTertiary)
                Text("Track vehicles, quote work, get paid.")
                    .font(.wbBody)
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)

                VStack(spacing: Spacing.xs) {
                    Link("Privacy Policy", destination: URL(string: "https://chewbaccasthong.github.io/garagetime/#privacy")!)
                    Link("Terms of Service", destination: URL(string: "https://chewbaccasthong.github.io/garagetime/#terms")!)
                    Link("Support", destination: URL(string: "mailto:support@wrenchbook.app")!)
                }
                .font(.wbBody)
                .foregroundStyle(Color.accentPrimary)

                GSButton(title: "Replay the tour", icon: "play.fill",
                         style: .secondary, fullWidth: false) {
                    if let shop = shopSettings.first {
                        shop.hasCompletedWalkthrough = false
                        try? context.save()
                    }
                    showWalkthrough = true
                }
                .padding(.top, Spacing.m)
            }
            .padding(Spacing.xl)
            .frame(maxWidth: .infinity)
        }
        .wbScreenBackground()
        .navigationTitle("About")
        .sheet(isPresented: $showWalkthrough) {
            WalkthroughView()
        }
    }
}
