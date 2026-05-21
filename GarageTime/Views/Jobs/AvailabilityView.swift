import SwiftUI
import SwiftData

struct AvailabilityView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \MechanicAvailability.weekdayRaw) private var slots: [MechanicAvailability]
    @State private var editing: MechanicAvailability?

    var body: some View {
        Form {
            Section {
                Text("Customers will see the days and hours you're available before they request work.")
                    .font(.wbCaption)
                    .foregroundStyle(Color.textSecondary)
            }
            ForEach(Weekday.allCases) { weekday in
                Section(header: Text(weekday.full)) {
                    let daySlots = slots.filter { $0.weekday == weekday }
                    if daySlots.isEmpty {
                        Text("Closed")
                            .font(.wbCaption)
                            .foregroundStyle(Color.textTertiary)
                    } else {
                        ForEach(daySlots) { slot in
                            Button { editing = slot } label: {
                                HStack {
                                    Circle()
                                        .fill(slot.isOpen ? Color.statusGreen : Color.statusRed)
                                        .frame(width: 8, height: 8)
                                    Text(slot.displayRange)
                                        .foregroundStyle(Color.textPrimary)
                                    Spacer()
                                    if !slot.notes.isEmpty {
                                        Text(slot.notes)
                                            .font(.wbCaptionSmall)
                                            .foregroundStyle(Color.textTertiary)
                                    }
                                }
                            }
                        }
                        .onDelete { offsets in
                            for index in offsets { context.delete(daySlots[index]) }
                            try? context.save()
                        }
                    }
                    Button {
                        addSlot(weekday: weekday)
                    } label: {
                        Label("Add window", systemImage: "plus")
                            .font(.wbCaption)
                            .foregroundStyle(Color.accentPrimary)
                    }
                }
            }
            Section {
                Button {
                    seedDefaults()
                } label: {
                    Label("Seed Mon–Fri 9–5", systemImage: "sparkles")
                        .foregroundStyle(Color.accentPrimary)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.bgPrimary)
        .wbDismissibleKeyboard()
        .navigationTitle("Availability")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editing) { slot in
            NavigationStack {
                AvailabilityEditorView(slot: slot)
            }
        }
    }

    private func addSlot(weekday: Weekday) {
        let slot = MechanicAvailability(weekday: weekday)
        context.insert(slot)
        try? context.save()
        editing = slot
    }

    private func seedDefaults() {
        for day: Weekday in [.monday, .tuesday, .wednesday, .thursday, .friday] {
            if !slots.contains(where: { $0.weekday == day }) {
                let slot = MechanicAvailability(weekday: day,
                                                startMinute: 9 * 60,
                                                endMinute: 17 * 60)
                context.insert(slot)
            }
        }
        try? context.save()
        HapticsManager.success()
    }
}

// MARK: - Slot editor

struct AvailabilityEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Bindable var slot: MechanicAvailability

    var body: some View {
        Form {
            Section("Day") {
                Picker("Weekday", selection: Binding(
                    get: { slot.weekday },
                    set: { slot.weekday = $0 }
                )) {
                    ForEach(Weekday.allCases) { day in
                        Text(day.full).tag(day)
                    }
                }
            }
            Section("Window") {
                Stepper("Start: \(formatMinutes(slot.startMinute))",
                        value: $slot.startMinute, in: 0...(24 * 60 - 15), step: 15)
                Stepper("End: \(formatMinutes(slot.endMinute))",
                        value: $slot.endMinute, in: 15...(24 * 60), step: 15)
                Toggle("Open this window", isOn: $slot.isOpen)
            }
            Section("Notes") {
                GSTextField(title: "", text: $slot.notes,
                            placeholder: "Mobile only · By appointment · etc.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.bgPrimary)
        .wbDismissibleKeyboard()
        .navigationTitle("Edit Window")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    slot.updatedAt = Date()
                    try? context.save()
                    HapticsManager.success()
                    dismiss()
                }
                .fontWeight(.semibold)
            }
        }
    }

    private func formatMinutes(_ m: Int) -> String {
        let hr = m / 60
        let min = m % 60
        var comps = DateComponents(); comps.hour = hr; comps.minute = min
        let date = Calendar.current.date(from: comps) ?? Date()
        let f = DateFormatter(); f.dateFormat = "h:mm a"
        return f.string(from: date)
    }
}
