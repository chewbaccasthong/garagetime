import SwiftUI
import SwiftData

enum BulkImportMode: String, CaseIterable, Identifiable {
    case paste = "Paste text"
    case scan = "Scan receipts"
    case handwriting = "Handwritten"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .paste: return "text.alignleft"
        case .scan: return "doc.text.viewfinder"
        case .handwriting: return "scribble.variable"
        }
    }
}

struct BulkImportView: View {
    @Environment(Backend.self) private var backend
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Vehicle.updatedAt, order: .reverse) private var vehicles: [Vehicle]

    let initialVehicle: Vehicle?

    @State private var mode: BulkImportMode = .paste
    @State private var selectedVehicle: Vehicle?
    @State private var pastedText: String = ""
    @State private var drafts: [ImportDraft] = []
    @State private var editing: ImportDraft?
    @State private var showScanner: Bool = false
    @State private var importedCount: Int = 0
    @State private var showSuccess: Bool = false

    init(initialVehicle: Vehicle? = nil) {
        self.initialVehicle = initialVehicle
    }

    @State private var showPaywall: Bool = false

    var body: some View {
        NavigationStack {
            Group {
                if PaywallGate.bulkImport.isLocked(for: backend.effectiveEntitlements()) {
                    lockedView
                } else {
                    unlockedView
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
                if !drafts.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Import \(drafts.count)") { commitAll() }
                            .fontWeight(.semibold)
                            .disabled(selectedVehicle == nil)
                    }
                }
            }
            .sheet(item: $editing) { draft in
                NavigationStack { DraftEditorView(draft: draft) { updated in
                    if let i = drafts.firstIndex(where: { $0.id == updated.id }) {
                        drafts[i] = updated
                    }
                    editing = nil
                } }
            }
            .fullScreenCover(isPresented: $showScanner) {
                VisionScannerView(mode: .freeform) { text in
                    showScanner = false
                    appendScannedReceipt(text: text)
                } onCancel: { showScanner = false }
                    .ignoresSafeArea()
            }
            .alert("Imported \(importedCount) records", isPresented: $showSuccess) {
                Button("OK", role: .cancel) { dismiss() }
            }
            .onAppear {
                if selectedVehicle == nil { selectedVehicle = initialVehicle ?? vehicles.first }
            }
        }
    }

    // MARK: - Gated views

    /// Shown when the user doesn't have Shop Pro. Upsells the feature without nagging.
    private var lockedView: some View {
        VStack(spacing: Spacing.l) {
            Spacer()
            ZStack {
                Circle().fill(Color.accentPrimary.opacity(0.18)).frame(width: 110, height: 110)
                Image(systemName: "square.and.arrow.down.on.square.fill")
                    .font(.system(size: 42, weight: .semibold))
                    .foregroundStyle(Color.accentPrimary)
            }
            VStack(spacing: Spacing.xs) {
                Text("Bulk Import is a Shop Pro feature")
                    .font(.wbTitleLarge)
                    .foregroundStyle(Color.textPrimary)
                    .multilineTextAlignment(.center)
                Text("Import old service records by pasting text, scanning receipts, or photographing handwritten notes. Garage Time translates each into structured records you can edit.")
                    .font(.wbBody)
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.l)
            }
            GSButton(title: "See plans", icon: "creditcard.fill", style: .primary) {
                showPaywall = true
            }
            .padding(.horizontal, Spacing.l)
            Spacer()
        }
        .padding(Spacing.l)
    }

    private var unlockedView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.m) {
                introBlock
                vehiclePicker
                modePicker
                sourceArea
                if !drafts.isEmpty { resultsArea }
            }
            .padding(Spacing.m)
        }
    }

    // MARK: - Sections

    private var introBlock: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Bring your history with you")
                .font(.wbTitleLarge)
                .foregroundStyle(Color.textPrimary)
            Text("Paste a list, scan old receipts, or photograph your handwritten log book — Garage Time will translate it into structured service records you can edit.")
                .font(.wbCaption)
                .foregroundStyle(Color.textSecondary)
        }
    }

    private var vehiclePicker: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Import into")
                .font(.wbCaption)
                .foregroundStyle(Color.textSecondary)
            HStack {
                Image(systemName: selectedVehicle?.type.sfSymbol ?? "car.fill")
                    .foregroundStyle(Color.accentPrimary)
                Picker("Vehicle", selection: $selectedVehicle) {
                    Text("Choose a vehicle").tag(Vehicle?.none)
                    ForEach(vehicles) { v in
                        Text(v.displayTitle).tag(Optional(v))
                    }
                }
                .pickerStyle(.menu)
                .tint(Color.textPrimary)
            }
            .padding(Spacing.s)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Radius.m, style: .continuous)
                    .fill(Color.bgSecondary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.m, style: .continuous)
                    .strokeBorder(Color.dividerColor, lineWidth: 0.5)
            )
        }
    }

    private var modePicker: some View {
        Picker("Mode", selection: $mode) {
            ForEach(BulkImportMode.allCases) { m in
                Text(m.rawValue).tag(m)
            }
        }
        .pickerStyle(.segmented)
    }

    @ViewBuilder
    private var sourceArea: some View {
        switch mode {
        case .paste:        pasteArea
        case .scan:         scanArea
        case .handwriting:  handwritingArea
        }
    }

    private var pasteArea: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            GSTextEditor(
                title: "Paste old records",
                text: $pastedText,
                placeholder: """
                One record per line. Examples:

                5/14/2024 oil change at 78,000 mi — $48
                April 2 2024 brake pads $110 75,200 mi
                2024-01-10 chain lube 6100 mi
                """,
                minHeight: 220
            )
            HStack {
                GSButton(title: "Parse text", icon: "wand.and.stars", style: .primary) {
                    drafts = backend.bulkImport.parseText(pastedText)
                    HapticsManager.success()
                }
                .disabled(pastedText.trimmingCharacters(in: .whitespaces).isEmpty)
                if !drafts.isEmpty {
                    GSButton(title: "Clear", icon: "trash", style: .ghost) {
                        drafts = []
                    }
                }
            }
        }
    }

    private var scanArea: some View {
        VStack(spacing: Spacing.s) {
            Text("Scan one receipt at a time. Each scan adds a draft you can edit below.")
                .font(.wbCaption)
                .foregroundStyle(Color.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            GSButton(title: "Scan receipt", icon: "doc.text.viewfinder",
                     style: .primary, size: .large) {
                showScanner = true
            }
        }
    }

    private var handwritingArea: some View {
        VStack(spacing: Spacing.s) {
            Text("Photograph or paste a handwritten log. The parser is a little more forgiving — review each row before importing.")
                .font(.wbCaption)
                .foregroundStyle(Color.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            GSButton(title: "Scan handwritten page",
                     icon: "scribble.variable",
                     style: .primary,
                     size: .large) {
                showScanner = true
            }
            GSTextEditor(
                title: "Or paste transcribed text",
                text: $pastedText,
                placeholder: "Type out your handwritten notes — the parser tolerates messy formats.",
                minHeight: 160
            )
            GSButton(title: "Parse", icon: "wand.and.stars", style: .secondary) {
                drafts = backend.bulkImport.parseHandwriting(pastedText)
                HapticsManager.success()
            }
            .disabled(pastedText.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    private var resultsArea: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            HStack {
                Text("\(drafts.count) draft\(drafts.count == 1 ? "" : "s")")
                    .font(.wbHeadline)
                    .foregroundStyle(Color.textPrimary)
                Spacer()
                Text(confidenceSummary)
                    .font(.wbCaptionSmall)
                    .foregroundStyle(Color.textTertiary)
            }
            ForEach(drafts) { draft in
                Button { editing = draft } label: {
                    draftRow(draft)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, Spacing.s)
    }

    private func draftRow(_ draft: ImportDraft) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack {
                Image(systemName: draft.category.sfSymbol).foregroundStyle(Color.accentPrimary)
                Text(draft.title.isEmpty ? draft.category.displayName : draft.title)
                    .font(.wbBodyMedium)
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)
                Spacer()
                GSStatusPill(text: draft.confidence.displayName,
                             role: draft.confidence.paletteRole, compact: true)
            }
            HStack(spacing: Spacing.s) {
                if let date = draft.date {
                    Label(WBFormat.shortDate.string(from: date), systemImage: "calendar")
                        .font(.wbCaptionSmall)
                        .foregroundStyle(Color.textSecondary)
                }
                if let mi = draft.mileage {
                    Label("\(mi) mi", systemImage: "speedometer")
                        .font(.wbCaptionSmall)
                        .foregroundStyle(Color.textSecondary)
                }
                if draft.totalCost > 0 {
                    Label(Money.format(draft.totalCost), systemImage: "dollarsign.circle.fill")
                        .font(.wbCaptionSmall)
                        .foregroundStyle(Color.accentPrimary)
                }
                if draft.laborHours > 0 {
                    Label(WBFormat.hours(draft.laborHours), systemImage: "clock.fill")
                        .font(.wbCaptionSmall)
                        .foregroundStyle(Color.statusBlue)
                }
                Spacer()
            }
            Text("Tap to edit")
                .font(.wbCaptionSmall)
                .foregroundStyle(Color.textTertiary)
        }
        .padding(Spacing.m)
        .background(
            RoundedRectangle(cornerRadius: Radius.m, style: .continuous)
                .fill(Color.bgSecondary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.m, style: .continuous)
                .strokeBorder(Color.dividerColor, lineWidth: 0.5)
        )
    }

    private var confidenceSummary: String {
        let high = drafts.filter { $0.confidence == .high }.count
        let med  = drafts.filter { $0.confidence == .medium }.count
        let low  = drafts.filter { $0.confidence == .low }.count
        return "\(high) good · \(med) check · \(low) review"
    }

    // MARK: - Actions

    private func appendScannedReceipt(text: String) {
        guard !text.isEmpty else { return }
        let draft = backend.bulkImport.parseReceipt(text, ocr: backend.ocr)
        drafts.append(draft)
        HapticsManager.success()
    }

    private func commitAll() {
        guard let vehicle = selectedVehicle else { return }
        var inserted = 0
        for draft in drafts {
            let record = ServiceRecord(
                date: draft.date ?? Date(),
                mileageAtService: draft.mileage ?? vehicle.currentMileage,
                category: draft.category,
                title: draft.title,
                laborHours: draft.laborHours,
                laborCost: draft.laborCost,
                partsCost: draft.partsCost,
                totalCost: 0,        // recompute below to include all fields
                performedBy: .shop,  // imports are usually past shop visits; user can change
                vehicle: vehicle
            )
            record.recomputeTotal()
            // If the parser captured a single "total" and we didn't break it down, store it
            // as parts cost (closest single field). recomputeTotal already reads parts.
            if record.totalCost == 0, draft.totalCost > 0 {
                record.partsCost = draft.totalCost
                record.totalCost = draft.totalCost
            }
            context.insert(record)
            inserted += 1
        }
        try? context.save()
        importedCount = inserted
        drafts = []
        pastedText = ""
        HapticsManager.success()
        showSuccess = true
    }
}

// MARK: - Single-draft editor

struct DraftEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: ImportDraft
    let onSave: (ImportDraft) -> Void

    init(draft: ImportDraft, onSave: @escaping (ImportDraft) -> Void) {
        _draft = State(initialValue: draft)
        self.onSave = onSave
    }

    var body: some View {
        Form {
            Section("Category & title") {
                Picker("Category", selection: $draft.category) {
                    ForEach(ServiceCategory.allCases) { c in
                        Label(c.displayName, systemImage: c.sfSymbol).tag(c)
                    }
                }
                GSTextField(title: "Title", text: $draft.title, placeholder: draft.category.displayName)
            }
            Section("When & mileage") {
                DatePicker("Date", selection: Binding(
                    get: { draft.date ?? Date() },
                    set: { draft.date = $0 }
                ), displayedComponents: .date)
                GSNumberField(title: "Mileage",
                              value: Binding(
                                get: { Double(draft.mileage ?? 0) },
                                set: { draft.mileage = Int($0) }
                              ),
                              allowsDecimal: false)
            }
            Section("Cost & time") {
                GSNumberField(title: "Total $", value: $draft.totalCost)
                GSNumberField(title: "Parts $", value: $draft.partsCost)
                GSNumberField(title: "Labor $", value: $draft.laborCost)
                GSNumberField(title: "Labor hours", value: $draft.laborHours)
            }
            Section("Source text") {
                Text(draft.sourceText)
                    .font(.wbCaptionSmall)
                    .foregroundStyle(Color.textTertiary)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.bgPrimary)
        .wbDismissibleKeyboard()
        .navigationTitle("Edit draft")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    onSave(draft)
                }
                .fontWeight(.semibold)
            }
        }
    }
}

#Preview {
    BulkImportView()
        .environment(Backend.preview())
        .modelContainer(PreviewModelContainer.shared)
}
