import SwiftUI
import SwiftData

/// Customer-facing estimate lookup. Pick a service category → see what the mechanic
/// has historically charged, in time and cost. Optionally request the job.
struct EstimateView: View {
    @Environment(Backend.self) private var backend
    @Environment(\.modelContext) private var context
    @Query private var shopSettings: [ShopSettings]
    @Query(sort: \Vehicle.updatedAt, order: .reverse) private var vehicles: [Vehicle]

    @State private var category: ServiceCategory = .oilChange
    @State private var vehicle: Vehicle?
    @State private var notes: String = ""
    @State private var requestSent: Bool = false

    private var meCustomer: Customer? { shopSettings.first?.meCustomer }

    /// Vehicles the customer-mode user owns: anything they marked as `.personal` PLUS
    /// anything explicitly attached to their `meCustomer` record. Personal is the
    /// natural mode for "this is my vehicle", so we include both for forgiveness.
    private var myVehicles: [Vehicle] {
        let myID = meCustomer?.id
        return vehicles.filter { v -> Bool in
            if v.ownerType == .personal { return true }
            if let myID, v.customer?.id == myID { return true }
            return false
        }
    }

    private var currentEstimate: Estimate? {
        backend.estimates.estimate(for: category,
                                   vehicleType: vehicle?.type,
                                   in: context)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.m) {
                    headerBlurb
                    pickerCard
                    if let estimate = currentEstimate {
                        estimateCard(estimate)
                        requestBlock(estimate)
                    } else {
                        emptyHistoryCard
                    }
                }
                .padding(Spacing.m)
            }
            .wbScreenBackground()
            .wbBreadcrumbs([
                Crumb("Estimates", icon: "wand.and.stars"),
                Crumb(category.displayName, icon: category.sfSymbol),
            ])
            .wbDismissibleKeyboard()
            .navigationTitle("Get an Estimate")
            .alert("Request sent", isPresented: $requestSent) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Your mechanic will see this in their Jobs tab and respond.")
            }
        }
    }

    private var headerBlurb: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Lookup")
                .font(.wbCaption)
                .foregroundStyle(Color.textSecondary)
            Text("What does \(shopSettings.first?.resolvedMechanicName ?? "your mechanic") usually charge?")
                .font(.wbTitleLarge)
                .foregroundStyle(Color.textPrimary)
            Text("Estimates come from your mechanic's own past service records. Pick a job and a vehicle to see the typical price + time.")
                .font(.wbCaption)
                .foregroundStyle(Color.textTertiary)
        }
    }

    private var pickerCard: some View {
        VStack(spacing: Spacing.s) {
            // Category
            HStack {
                Image(systemName: category.sfSymbol)
                    .foregroundStyle(Color.accentPrimary)
                    .frame(width: 24)
                Picker("Service", selection: $category) {
                    ForEach(ServiceCategory.allCases) { c in
                        Text(c.displayName).tag(c)
                    }
                }
                .pickerStyle(.menu)
                .tint(Color.textPrimary)
            }
            Divider().background(Color.dividerColor)
            // Vehicle
            HStack {
                Image(systemName: vehicle?.type.sfSymbol ?? "car.fill")
                    .foregroundStyle(Color.accentPrimary)
                    .frame(width: 24)
                Picker("Vehicle", selection: $vehicle) {
                    Text("Any vehicle").tag(Vehicle?.none)
                    ForEach(myVehicles) { v in
                        Text(v.displayTitle).tag(Optional(v))
                    }
                }
                .pickerStyle(.menu)
                .tint(Color.textPrimary)
            }
        }
        .padding(Spacing.m)
        .background(
            RoundedRectangle(cornerRadius: Radius.l, style: .continuous)
                .fill(Color.bgSecondary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.l, style: .continuous)
                .strokeBorder(Color.dividerColor, lineWidth: 0.5)
        )
    }

    private func estimateCard(_ estimate: Estimate) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            HStack {
                Text("Typical price")
                    .font(.wbCaption)
                    .foregroundStyle(Color.textSecondary)
                Spacer()
                if estimate.isLowConfidence {
                    GSStatusPill(text: "Low confidence", role: .warning, compact: true)
                } else {
                    GSStatusPill(text: "\(estimate.sampleCount) past jobs", role: .success, compact: true)
                }
            }
            HStack(alignment: .firstTextBaseline) {
                Text(Money.format(estimate.costMedian))
                    .font(.wbDisplayLarge)
                    .foregroundStyle(Color.accentPrimary)
                Text("median")
                    .font(.wbCaption)
                    .foregroundStyle(Color.textTertiary)
            }
            Text("Range: \(estimate.costRangeDisplay)")
                .font(.wbCaption)
                .foregroundStyle(Color.textSecondary)

            Divider().background(Color.dividerColor).padding(.vertical, Spacing.xs)

            HStack {
                Image(systemName: "clock.fill")
                    .foregroundStyle(Color.statusBlue)
                VStack(alignment: .leading) {
                    Text("Typical time")
                        .font(.wbCaption)
                        .foregroundStyle(Color.textSecondary)
                    Text(estimate.hoursRangeDisplay)
                        .font(.wbHeadline)
                        .foregroundStyle(Color.textPrimary)
                }
                Spacer()
            }

            if let scopedTo = estimate.scopedVehicleType {
                Text("Scoped to \(scopedTo.displayName.lowercased()) jobs only.")
                    .font(.wbCaptionSmall)
                    .foregroundStyle(Color.textTertiary)
            } else if vehicle != nil {
                Text("Not enough records for this vehicle type — showing all vehicles.")
                    .font(.wbCaptionSmall)
                    .foregroundStyle(Color.textTertiary)
            }
            if let last = estimate.lastSeen {
                Text("Most recent comparable job: \(WBFormat.relative(last))")
                    .font(.wbCaptionSmall)
                    .foregroundStyle(Color.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.m)
        .background(
            RoundedRectangle(cornerRadius: Radius.l, style: .continuous)
                .fill(Color.bgSecondary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.l, style: .continuous)
                .strokeBorder(Color.dividerColor, lineWidth: 0.5)
        )
    }

    private func requestBlock(_ estimate: Estimate) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text("Request this job")
                .font(.wbHeadline)
                .foregroundStyle(Color.textPrimary)
            GSTextEditor(title: "What's going on? (optional)",
                         text: $notes,
                         placeholder: "Any details that help the mechanic prep?",
                         minHeight: 80)
            GSButton(title: "Send request to mechanic",
                     icon: "paperplane.fill",
                     style: .primary) {
                sendRequest(snapshot: estimate)
            }
            .disabled(vehicle == nil)
            if vehicle == nil {
                Text("Pick one of your vehicles to send a request.")
                    .font(.wbCaptionSmall)
                    .foregroundStyle(Color.textTertiary)
            }
        }
    }

    private var emptyHistoryCard: some View {
        VStack(spacing: Spacing.s) {
            Image(systemName: "tray")
                .font(.system(size: 28))
                .foregroundStyle(Color.textTertiary)
            Text("No past jobs for this category yet")
                .font(.wbHeadline)
                .foregroundStyle(Color.textPrimary)
            Text("Your mechanic hasn't logged this category of work before. You can still send a request — they'll respond with an estimate.")
                .font(.wbCaption)
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
            GSTextEditor(title: "Details",
                         text: $notes,
                         placeholder: "Tell your mechanic what you need…",
                         minHeight: 80)
            GSButton(title: "Send request anyway",
                     icon: "paperplane.fill",
                     style: .primary) {
                sendRequest(snapshot: nil)
            }
            .disabled(vehicle == nil)
        }
        .padding(Spacing.m)
        .background(
            RoundedRectangle(cornerRadius: Radius.l, style: .continuous)
                .fill(Color.bgSecondary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.l, style: .continuous)
                .strokeBorder(Color.dividerColor, lineWidth: 0.5)
        )
    }

    private func sendRequest(snapshot: Estimate?) {
        let customer = meCustomer ?? bootstrapMeCustomer()
        guard let v = vehicle else { return }
        let req = JobRequest(
            status: .pending,
            category: category,
            title: category.displayName,
            customerNotes: notes,
            estimatedHours: snapshot?.hoursMedian ?? 0,
            estimatedCost: snapshot?.costMedian ?? 0,
            estimateNotes: snapshot.map { "Customer saw estimate $\(Money.format($0.costMedian)) / \($0.hoursRangeDisplay)" } ?? "",
            customer: customer,
            vehicle: v
        )
        context.insert(req)
        try? context.save()
        HapticsManager.success()
        notes = ""
        requestSent = true
    }

    private func bootstrapMeCustomer() -> Customer {
        let me = Customer(firstName: "Me", lastName: "")
        context.insert(me)
        if let shop = shopSettings.first {
            shop.meCustomer = me
        }
        try? context.save()
        return me
    }
}

#Preview {
    EstimateView()
        .environment(Backend.preview())
        .modelContainer(PreviewModelContainer.shared)
}
