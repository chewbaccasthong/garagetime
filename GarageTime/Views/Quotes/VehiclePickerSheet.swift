import SwiftUI
import SwiftData

struct VehiclePickerSheet: View {
    let customer: Customer?
    @Binding var selected: Vehicle?
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Vehicle.updatedAt, order: .reverse) private var allVehicles: [Vehicle]

    var body: some View {
        NavigationStack {
            List {
                ForEach(visibleVehicles) { vehicle in
                    Button {
                        selected = vehicle
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: vehicle.type.sfSymbol)
                                .foregroundStyle(Color.accentPrimary)
                                .frame(width: 24)
                            VStack(alignment: .leading) {
                                Text(vehicle.displayTitle)
                                    .foregroundStyle(Color.textPrimary)
                                if !vehicle.subtitle.isEmpty {
                                    Text(vehicle.subtitle)
                                        .font(.wbCaption)
                                        .foregroundStyle(Color.textSecondary)
                                }
                            }
                            Spacer()
                            if selected?.id == vehicle.id {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.accentPrimary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Choose vehicle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .overlay {
                if visibleVehicles.isEmpty {
                    GSEmptyState(
                        icon: "car.fill",
                        title: "No vehicles",
                        message: customer == nil
                            ? "Add a vehicle to choose one for this quote."
                            : "This customer has no vehicles yet. Add one from the Customer detail screen."
                    )
                }
            }
        }
    }

    private var visibleVehicles: [Vehicle] {
        if let customer {
            return allVehicles.filter { $0.customer?.id == customer.id }
        }
        return allVehicles
    }
}
