import SwiftUI
import SwiftData

struct ReminderEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Vehicle.updatedAt, order: .reverse) private var vehicles: [Vehicle]
    let reminder: MaintenanceReminder?

    @State private var title: String = ""
    @State private var category: ReminderCategory = .oilChange
    @State private var intervalMiles: Int = 5000
    @State private var intervalMonths: Int = 6
    @State private var lastServiceDate: Date? = nil
    @State private var lastServiceMileage: Int = 0
    @State private var vehicle: Vehicle?
    @State private var notifyDaysBefore: Int = 14
    @State private var notifyMilesBefore: Int = 500

    var body: some View {
        Form {
            Section("Vehicle") {
                Picker("Vehicle", selection: $vehicle) {
                    Text("Unassigned").tag(Vehicle?.none)
                    ForEach(vehicles) { v in
                        Text(v.displayTitle).tag(Optional(v))
                    }
                }
            }
            Section("What") {
                Picker("Category", selection: $category) {
                    ForEach(ReminderCategory.allCases) { c in
                        Label(c.displayName, systemImage: c.sfSymbol).tag(c)
                    }
                }
                GSTextField(title: "Title (optional)", text: $title, placeholder: category.displayName)
            }
            Section("Interval") {
                Stepper("Every \(intervalMiles) mi", value: $intervalMiles, in: 0...300_000, step: 500)
                Stepper("Every \(intervalMonths) months", value: $intervalMonths, in: 0...60, step: 1)
            }
            Section("Last service") {
                DatePicker("Date", selection: Binding(
                    get: { lastServiceDate ?? .now },
                    set: { lastServiceDate = $0 }
                ), displayedComponents: .date)
                GSNumberField(title: "Mileage", value: Binding(
                    get: { Double(lastServiceMileage) },
                    set: { lastServiceMileage = Int($0) }
                ), allowsDecimal: false)
            }
            Section("Notifications") {
                Stepper("Notify \(notifyDaysBefore) days before", value: $notifyDaysBefore, in: 0...60, step: 1)
                Stepper("Notify \(notifyMilesBefore) mi before", value: $notifyMilesBefore, in: 0...5000, step: 100)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.bgPrimary)
        .wbDismissibleKeyboard()
        .navigationTitle(reminder == nil ? "New Reminder" : "Edit Reminder")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") { save() }
                    .fontWeight(.semibold)
            }
        }
        .onAppear { hydrate() }
    }

    private func hydrate() {
        if let r = reminder {
            title = r.title
            category = r.category
            intervalMiles = r.intervalMiles
            intervalMonths = r.intervalMonths
            lastServiceDate = r.lastServiceDate
            lastServiceMileage = r.lastServiceMileage
            vehicle = r.vehicle
            notifyDaysBefore = r.notifyDaysBefore
            notifyMilesBefore = r.notifyMilesBefore
        } else if vehicle == nil {
            vehicle = vehicles.first
        }
    }

    private func save() {
        let r = reminder ?? MaintenanceReminder()
        r.title = title
        r.category = category
        r.intervalMiles = intervalMiles
        r.intervalMonths = intervalMonths
        r.lastServiceDate = lastServiceDate
        r.lastServiceMileage = lastServiceMileage
        r.vehicle = vehicle
        r.notifyDaysBefore = notifyDaysBefore
        r.notifyMilesBefore = notifyMilesBefore
        r.updatedAt = Date()
        if reminder == nil { context.insert(r) }
        try? context.save()
        HapticsManager.success()
        dismiss()
    }
}

// MARK: - Presets picker

struct PresetsPickerView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Vehicle.updatedAt, order: .reverse) private var vehicles: [Vehicle]
    @State private var selectedVehicle: Vehicle?
    @State private var selectedPresets: Set<String> = []

    var body: some View {
        Form {
            Section("Apply to") {
                Picker("Vehicle", selection: $selectedVehicle) {
                    Text("Choose").tag(Vehicle?.none)
                    ForEach(vehicles) { v in
                        Text(v.displayTitle).tag(Optional(v))
                    }
                }
            }
            if let v = selectedVehicle {
                let presets = ReminderPresets.presets(for: v.type, powertrain: v.powertrain)
                Section("Presets") {
                    ForEach(presets) { preset in
                        Toggle(isOn: Binding(
                            get: { selectedPresets.contains(preset.id) },
                            set: { include in
                                if include { selectedPresets.insert(preset.id) }
                                else { selectedPresets.remove(preset.id) }
                            }
                        )) {
                            HStack {
                                Image(systemName: preset.category.sfSymbol)
                                    .foregroundStyle(Color.accentPrimary)
                                VStack(alignment: .leading) {
                                    Text(preset.title)
                                    Text(intervalLabel(preset))
                                        .font(.wbCaption)
                                        .foregroundStyle(Color.textSecondary)
                                }
                            }
                        }
                    }
                }
                Section {
                    Button("Select all") {
                        selectedPresets = Set(presets.map(\.id))
                    }
                    Button("Clear") {
                        selectedPresets = []
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.bgPrimary)
        .wbDismissibleKeyboard()
        .navigationTitle("Reminder Presets")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Add \(selectedPresets.count)") {
                    applySelected()
                }
                .disabled(selectedVehicle == nil || selectedPresets.isEmpty)
                .fontWeight(.semibold)
            }
        }
        .onAppear { selectedVehicle = vehicles.first }
    }

    private func intervalLabel(_ preset: ReminderPresets.Preset) -> String {
        var parts: [String] = []
        if preset.intervalMiles > 0 { parts.append("\(preset.intervalMiles) mi") }
        if preset.intervalMonths > 0 { parts.append("\(preset.intervalMonths) mo") }
        return parts.joined(separator: " · ")
    }

    private func applySelected() {
        guard let vehicle = selectedVehicle else { return }
        let presets = ReminderPresets.presets(for: vehicle.type, powertrain: vehicle.powertrain)
        for preset in presets where selectedPresets.contains(preset.id) {
            let reminder = MaintenanceReminder(
                title: preset.title,
                category: preset.category,
                intervalMiles: preset.intervalMiles,
                intervalMonths: preset.intervalMonths,
                lastServiceMileage: vehicle.currentMileage,
                vehicle: vehicle
            )
            context.insert(reminder)
        }
        try? context.save()
        HapticsManager.success()
        dismiss()
    }
}
