import SwiftUI

struct VehicleCardView: View {
    let vehicle: Vehicle
    let urgency: ReminderUrgency

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Photo / placeholder
            ZStack(alignment: .topLeading) {
                Group {
                    if let data = vehicle.photoData, let ui = UIImage(data: data) {
                        Image(uiImage: ui)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Color.bgTertiary
                            .overlay(
                                Image(systemName: vehicle.type.sfSymbol)
                                    .font(.system(size: 38, weight: .regular))
                                    .foregroundStyle(Color.textTertiary)
                            )
                    }
                }
                .frame(height: 110)
                .clipped()
                .clipShape(
                    UnevenRoundedRectangle(topLeadingRadius: Radius.l, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: Radius.l, style: .continuous)
                )

                HStack(spacing: 4) {
                    statusDot
                    if vehicle.isVINVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.statusBlue)
                    }
                }
                .padding(Spacing.xs)

                if vehicle.ownerType == .customer, let customer = vehicle.customer {
                    HStack(spacing: 4) {
                        Image(systemName: "person.fill")
                            .font(.system(size: 9, weight: .bold))
                        Text(customer.displayName)
                            .font(.wbCaptionSmall)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.accentPrimary))
                    .foregroundStyle(Color.textOnAccent)
                    .padding(Spacing.xs)
                    .frame(maxWidth: .infinity, alignment: .topTrailing)
                }
            }

            // Title block
            VStack(alignment: .leading, spacing: 4) {
                Text(vehicle.displayTitle)
                    .font(.wbBodyMedium)
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)
                if !vehicle.subtitle.isEmpty {
                    Text(vehicle.subtitle)
                        .font(.wbCaption)
                        .foregroundStyle(Color.textSecondary)
                        .lineLimit(1)
                }
                HStack(spacing: Spacing.xs) {
                    Text(WBFormat.mileage(vehicle.currentMileage, unit: vehicle.mileageUnit))
                        .font(.wbCaptionSmall)
                        .foregroundStyle(Color.textTertiary)
                    Spacer()
                    if vehicle.totalSpent > 0 {
                        MoneyText(value: vehicle.totalSpent,
                                  font: .wbMonoCaption,
                                  color: .accentPrimary)
                    }
                }
            }
            .padding(Spacing.s)
        }
        .background(
            RoundedRectangle(cornerRadius: Radius.l, style: .continuous)
                .fill(Color.bgSecondary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.l, style: .continuous)
                .strokeBorder(Color.dividerColor, lineWidth: 0.5)
        )
    }

    private var statusDot: some View {
        Circle()
            .fill(urgencyColor)
            .frame(width: 10, height: 10)
            .overlay(
                Circle()
                    .strokeBorder(Color.bgPrimary, lineWidth: 1.5)
            )
    }

    private var urgencyColor: Color {
        switch urgency {
        case .ok:       return .statusGreen
        case .dueSoon:  return .statusAmber
        case .overdue:  return .statusRed
        }
    }
}
