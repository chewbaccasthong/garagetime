import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(Backend.self) private var backend
    @Environment(\.modelContext) private var context
    @Query private var shopSettings: [ShopSettings]
    @AppStorage("wb.haptics.enabled") private var hapticsEnabled: Bool = true
    @AppStorage("wb.appearance") private var appearance: String = "system"
    @State private var showResetConfirm: Bool = false
    @State private var showPaywall: Bool = false
    @State private var showRoleSwitchConfirm: Bool = false
    @State private var pendingRole: UserRole?

    var body: some View {
        Form {
            Section("Role") {
                if let shop = shopSettings.first {
                    Picker("I'm a…", selection: Binding(
                        get: { shop.role ?? .mechanic },
                        set: { newRole in
                            if shop.role != newRole {
                                pendingRole = newRole
                                showRoleSwitchConfirm = true
                            }
                        }
                    )) {
                        ForEach(UserRole.allCases) { r in
                            Label(r.displayName, systemImage: r.sfSymbol).tag(r)
                        }
                    }
                    Text(shop.role?.blurb ?? "")
                        .font(.wbCaptionSmall)
                        .foregroundStyle(Color.textTertiary)
                }
            }

            Section("Subscription") {
                HStack {
                    Text("Tier")
                    Spacer()
                    GSStatusPill(
                        text: backend.store.entitlements.tier.displayName,
                        role: backend.store.entitlements.tier == .free ? .neutral : .accent
                    )
                }
                Button {
                    showPaywall = true
                } label: {
                    Label("Manage / Upgrade", systemImage: "creditcard.fill")
                }
                Button {
                    Task { await backend.store.restore() }
                } label: {
                    Label("Restore Purchases", systemImage: "arrow.clockwise")
                }
            }
            Section("Appearance") {
                Picker("Theme", selection: $appearance) {
                    Text("System").tag("system")
                    Text("Dark").tag("dark")
                    Text("Light").tag("light")
                }
                .pickerStyle(.segmented)
            }
            Section {
                Toggle("Show partner-friendly amounts", isOn: Binding(
                    get: { Money.stealthEnabled },
                    set: { Money.stealthEnabled = $0; HapticsManager.selection() }
                ))
                if Money.stealthEnabled {
                    HStack {
                        Text("Display as")
                        Spacer()
                        Text("\(Int(Money.stealthFactor * 100))% of actual")
                            .font(.wbMonoCaption)
                            .foregroundStyle(Color.accentPrimary)
                    }
                    Slider(
                        value: Binding(
                            get: { Money.stealthFactor },
                            set: { Money.stealthFactor = $0 }
                        ),
                        in: 0.05...1.0,
                        step: 0.05
                    )
                    HStack {
                        Text("Example: a $700 job shows as")
                            .font(.wbCaptionSmall)
                            .foregroundStyle(Color.textTertiary)
                        Spacer()
                        Text(Money.displayCost(700))
                            .font(.wbMonoCaption)
                            .foregroundStyle(Color.statusGreen)
                    }
                    Text("Long-press any amount to peek at the real number. PDFs, the editor, and exports always show actual values.")
                        .font(.wbCaptionSmall)
                        .foregroundStyle(Color.textTertiary)
                }
            } header: {
                Label("Stealth mode", systemImage: "eye.slash.fill")
            }

            Section("Feedback") {
                Toggle("Haptics", isOn: $hapticsEnabled)
            }
            Section("Notifications") {
                Button {
                    Task { _ = await backend.notifications.requestPermission() }
                } label: {
                    Label("Re-request permission", systemImage: "bell.badge.fill")
                }
            }
            Section("Data") {
                Button {
                    loadSampleData()
                } label: {
                    Label("Load sample data", systemImage: "sparkles")
                }
                Button {
                    exportAllJSON()
                } label: {
                    Label("Export all data (JSON)", systemImage: "square.and.arrow.up")
                }
                Button(role: .destructive) {
                    showResetConfirm = true
                } label: {
                    Label("Erase all data", systemImage: "trash")
                }
            }
            Section("iCloud") {
                Label("Garage Time syncs through iCloud automatically.", systemImage: "icloud.fill")
                    .font(.wbCaption)
                    .foregroundStyle(Color.textSecondary)
            }

            #if DEBUG
            Section {
                Picker("Tier override", selection: Binding(
                    get: { DebugTierOverride.current ?? .free },
                    set: { newValue in
                        if let real = backend.store as? RealStoreService {
                            real.applyDebugTier(newValue)
                        }
                        HapticsManager.selection()
                    }
                )) {
                    Text("Free").tag(SubscriptionTier.free)
                    Text("Customer Plus").tag(SubscriptionTier.customerPlus)
                    Text("Shop").tag(SubscriptionTier.shopStandard)
                    Text("Shop Pro").tag(SubscriptionTier.shopPro)
                }
                .pickerStyle(.segmented)

                Text("DEBUG builds default to Shop tier so every feature is unlocked for testing. Switch tier here to verify paywall gates. Stripped from Release builds.")
                    .font(.wbCaptionSmall)
                    .foregroundStyle(Color.textTertiary)
            } header: {
                Label("Developer — Tier override", systemImage: "hammer.fill")
            }
            #endif
        }
        .scrollContentBackground(.hidden)
        .background(Color.bgPrimary)
        .wbDismissibleKeyboard()
        .navigationTitle("Settings")
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
        .confirm(
            isPresented: $showResetConfirm,
            title: "Erase all data?",
            message: "This removes every vehicle, customer, quote, and part from this device. iCloud copies on other devices will sync the deletion.",
            destructiveTitle: "Erase",
            isDestructive: true
        ) {
            eraseAll()
        }
        .confirm(
            isPresented: $showRoleSwitchConfirm,
            title: "Switch role?",
            message: "Your data isn't deleted — just the navigation changes.",
            destructiveTitle: "Switch",
            isDestructive: false
        ) {
            switchRole()
        }
    }

    private func switchRole() {
        guard let role = pendingRole, let shop = shopSettings.first else { return }
        shop.role = role
        shop.updatedAt = Date()
        try? context.save()
        pendingRole = nil
        HapticsManager.success()
    }

    private func loadSampleData() {
        SampleData.seed(into: context)
        HapticsManager.success()
    }

    private func eraseAll() {
        try? context.delete(model: Vehicle.self)
        try? context.delete(model: Customer.self)
        try? context.delete(model: ServiceRecord.self)
        try? context.delete(model: Part.self)
        try? context.delete(model: MaintenanceReminder.self)
        try? context.delete(model: MileageLog.self)
        try? context.delete(model: Quote.self)
        try? context.delete(model: QuoteLineItem.self)
        try? context.save()
        HapticsManager.warning()
    }

    private func exportAllJSON() {
        // Minimal JSON dump of vehicles + service records.
        let descriptor = FetchDescriptor<Vehicle>()
        guard let vehicles = try? context.fetch(descriptor) else { return }
        let payload: [[String: Any]] = vehicles.map { v in
            [
                "id": v.id.uuidString,
                "name": v.name,
                "year": v.year,
                "make": v.make,
                "model": v.model,
                "vin": v.vin,
                "mileage": v.currentMileage,
                "owner": v.ownerType.rawValue,
                "records": (v.serviceRecords ?? []).map { r in
                    [
                        "date": ISO8601DateFormatter().string(from: r.date),
                        "mileage": r.mileageAtService,
                        "category": r.category.rawValue,
                        "title": r.title,
                        "total": r.totalCost,
                    ] as [String: Any]
                },
            ]
        }
        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted]),
              let url = TempFile.write(data, name: "wrenchbook_export", ext: "json") else { return }
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.windows.first?.rootViewController }
            .first?
            .present(UIActivityViewController(activityItems: [url], applicationActivities: nil), animated: true)
    }
}
