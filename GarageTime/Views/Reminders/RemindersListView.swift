import SwiftUI
import SwiftData

struct RemindersListView: View {
    @Environment(Backend.self) private var backend
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<MaintenanceReminder> { $0.isActive == true })
    private var allReminders: [MaintenanceReminder]
    @State private var addingReminder: Bool = false
    @State private var selectedVehicleForPreset: Vehicle?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.bgPrimary.ignoresSafeArea()
                if allReminders.isEmpty {
                    GSEmptyState(
                        icon: "bell.fill",
                        title: "No reminders yet",
                        message: "Add reminders for oil changes, brake fluid, chain lube, and more — Garage Time will nudge you before they're due."
                    )
                } else {
                    list
                }
            }
            .wbBreadcrumbs([Crumb("Reminders", icon: "bell.fill")])
            .navigationTitle("Reminders")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button { addingReminder = true } label: { Label("Custom reminder", systemImage: "plus") }
                        Button { selectedVehicleForPreset = nil; presetsPickerShown = true } label: { Label("From preset", systemImage: "list.bullet.rectangle") }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(Color.accentPrimary)
                    }
                }
            }
            .sheet(isPresented: $addingReminder) {
                NavigationStack {
                    ReminderEditorView(reminder: nil)
                }
            }
            .sheet(isPresented: $presetsPickerShown) {
                NavigationStack {
                    PresetsPickerView()
                }
            }
        }
    }

    @State private var presetsPickerShown: Bool = false

    private var list: some View {
        List {
            ForEach(groupedByVehicle.keys.sorted(by: { ($0?.displayTitle ?? "") < ($1?.displayTitle ?? "") }), id: \.self) { vehicle in
                Section(header: vehicleSection(vehicle)) {
                    ForEach(groupedByVehicle[vehicle] ?? []) { reminder in
                        NavigationLink {
                            ReminderEditorView(reminder: reminder)
                        } label: {
                            reminderRow(reminder, vehicle: vehicle)
                        }
                        .listRowBackground(Color.bgSecondary)
                        .swipeActions(edge: .trailing) {
                            Button { complete(reminder, vehicle: vehicle) } label: {
                                Label("Done", systemImage: "checkmark")
                            }
                            .tint(.green)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }

    private var groupedByVehicle: [Vehicle?: [MaintenanceReminder]] {
        Dictionary(grouping: allReminders, by: { $0.vehicle })
    }

    private func vehicleSection(_ vehicle: Vehicle?) -> some View {
        HStack {
            if let vehicle {
                Image(systemName: vehicle.type.sfSymbol)
                    .foregroundStyle(Color.accentPrimary)
                Text(vehicle.displayTitle)
                    .font(.wbCaption)
                    .foregroundStyle(Color.textSecondary)
            } else {
                Text("Unassigned").font(.wbCaption).foregroundStyle(Color.textSecondary)
            }
        }
    }

    private func reminderRow(_ reminder: MaintenanceReminder, vehicle: Vehicle?) -> some View {
        let currentMileage = vehicle?.currentMileage ?? 0
        let urgency = reminder.urgency(now: Date(), currentMileage: currentMileage)
        let progress = reminder.progress(now: Date(), currentMileage: currentMileage)

        return VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack {
                Image(systemName: reminder.category.sfSymbol)
                    .foregroundStyle(Color.accentPrimary)
                Text(reminder.displayTitle)
                    .font(.wbBodyMedium)
                    .foregroundStyle(Color.textPrimary)
                Spacer()
                GSStatusPill(text: urgency.displayName, role: urgency.paletteRole, compact: true)
            }
            GSProgressBar(progress: progress, role: urgency.paletteRole)
            HStack(spacing: Spacing.s) {
                if let days = reminder.daysUntilDue() {
                    Label(days < 0 ? "\(-days)d overdue" : "in \(days)d",
                          systemImage: "calendar")
                        .font(.wbCaptionSmall)
                        .foregroundStyle(Color.textTertiary)
                }
                if let miles = reminder.milesUntilDue(currentMileage: currentMileage) {
                    Label(miles < 0 ? "\(-miles) mi overdue" : "in \(miles) mi",
                          systemImage: "speedometer")
                        .font(.wbCaptionSmall)
                        .foregroundStyle(Color.textTertiary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func complete(_ reminder: MaintenanceReminder, vehicle: Vehicle?) {
        let date = Date()
        let mileage = vehicle?.currentMileage ?? reminder.lastServiceMileage
        Task {
            await backend.reminderEngine.complete(
                reminder,
                serviceDate: date,
                serviceMileage: mileage,
                in: context
            )
        }
        HapticsManager.success()
    }
}

#Preview {
    RemindersListView()
        .environment(Backend.preview())
        .modelContainer(PreviewModelContainer.shared)
}
