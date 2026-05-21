import SwiftUI
import SwiftData
import Charts

enum ReportScope: String, CaseIterable, Hashable {
    case personal, customer
    var displayName: String { rawValue.capitalized }
}

enum ReportRange: String, CaseIterable, Hashable {
    case d30, d90, ytd, all
    var displayName: String {
        switch self {
        case .d30: return "30d"
        case .d90: return "90d"
        case .ytd: return "YTD"
        case .all: return "All"
        }
    }
    func startDate(now: Date = Date()) -> Date? {
        let cal = Calendar.current
        switch self {
        case .d30: return cal.date(byAdding: .day, value: -30, to: now)
        case .d90: return cal.date(byAdding: .day, value: -90, to: now)
        case .ytd:
            return cal.dateInterval(of: .year, for: now)?.start
        case .all: return nil
        }
    }
}

struct ReportsView: View {
    @Query private var vehicles: [Vehicle]
    @Query private var serviceRecords: [ServiceRecord]
    @Query private var quotes: [Quote]
    @State private var scope: ReportScope = .personal
    @State private var range: ReportRange = .ytd

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.m) {
                scopeChips
                rangeChips
                statsBlock
                categoryChart
                hoursChart
                vehiclesChart
                if scope == .customer {
                    revenueByCustomer
                }
            }
            .padding(Spacing.m)
        }
        .wbScreenBackground()
        .navigationTitle("Reports")
    }

    private var scopeChips: some View {
        Picker("Scope", selection: $scope) {
            ForEach(ReportScope.allCases, id: \.self) { Text($0.displayName).tag($0) }
        }
        .pickerStyle(.segmented)
    }

    private var rangeChips: some View {
        Picker("Range", selection: $range) {
            ForEach(ReportRange.allCases, id: \.self) { Text($0.displayName).tag($0) }
        }
        .pickerStyle(.segmented)
    }

    private var filteredRecords: [ServiceRecord] {
        let withScope = serviceRecords.filter { record in
            guard let vehicle = record.vehicle else { return scope == .personal }
            return scope == .personal ? vehicle.ownerType == .personal : vehicle.ownerType == .customer
        }
        guard let start = range.startDate() else { return withScope }
        return withScope.filter { $0.date >= start }
    }

    private var totalDollars: Double {
        Money.sum(filteredRecords.map(\.totalCost))
    }

    private var totalLaborDollars: Double {
        Money.sum(filteredRecords.map(\.effectiveLaborCost))
    }

    private var totalPartsDollars: Double {
        Money.sum(filteredRecords.map(\.partsCost))
    }

    private var totalHours: Double {
        filteredRecords.reduce(0) { $0 + $1.laborHours }
    }

    private var totalMilesCovered: Int {
        let byVehicle = Dictionary(grouping: filteredRecords, by: { $0.vehicle?.id ?? UUID() })
        return byVehicle.values.reduce(0) { partial, records in
            guard let max = records.map(\.mileageAtService).max(),
                  let min = records.map(\.mileageAtService).min(),
                  max > min else { return partial }
            return partial + (max - min)
        }
    }

    private var costPerMile: String {
        guard totalMilesCovered > 0 else { return "—" }
        return Money.format(totalDollars / Double(totalMilesCovered))
    }

    private var statsBlock: some View {
        VStack(spacing: Spacing.s) {
            HStack(spacing: Spacing.s) {
                GSStatBlock(
                    label: scope == .personal ? "Total spent" : "Total billed",
                    value: Money.format(totalDollars),
                    icon: "dollarsign.circle.fill",
                    role: .accent
                )
                GSStatBlock(
                    label: "Hours worked",
                    value: WBFormat.hours(totalHours),
                    icon: "clock.fill",
                    role: .info
                )
            }
            HStack(spacing: Spacing.s) {
                GSStatBlock(
                    label: "Labor",
                    value: Money.format(totalLaborDollars),
                    icon: "wrench.and.screwdriver.fill"
                )
                GSStatBlock(
                    label: "Parts",
                    value: Money.format(totalPartsDollars),
                    icon: "shippingbox.fill"
                )
            }
            GSStatBlock(
                label: "Cost / mile",
                value: costPerMile,
                icon: "gauge.high"
            )
        }
    }

    @ViewBuilder
    private var categoryChart: some View {
        let byCategory = Dictionary(grouping: filteredRecords, by: { $0.category })
        let data: [(ServiceCategory, Double)] = byCategory
            .map { ($0.key, Money.sum($0.value.map(\.totalCost))) }
            .sorted(by: { $0.1 > $1.1 })
            .prefix(8)
            .map { ($0.0, $0.1) }

        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Cost by category")
                .font(.wbHeadline)
                .foregroundStyle(Color.textPrimary)
            if data.isEmpty {
                Text("No records in range")
                    .font(.wbCaption)
                    .foregroundStyle(Color.textTertiary)
            } else {
                Chart {
                    ForEach(data, id: \.0) { entry in
                        BarMark(
                            x: .value("Cost", entry.1),
                            y: .value("Category", entry.0.displayName)
                        )
                        .foregroundStyle(Color.accentPrimary)
                    }
                }
                .frame(height: CGFloat(data.count) * 28 + 20)
            }
        }
        .padding(Spacing.m)
        .background(RoundedRectangle(cornerRadius: Radius.l).fill(Color.bgSecondary))
    }

    @ViewBuilder
    private var hoursChart: some View {
        let byCategory = Dictionary(grouping: filteredRecords, by: { $0.category })
        let data: [(ServiceCategory, Double)] = byCategory
            .map { ($0.key, $0.value.reduce(0) { $0 + $1.laborHours }) }
            .filter { $0.1 > 0 }
            .sorted(by: { $0.1 > $1.1 })
            .prefix(8)
            .map { ($0.0, $0.1) }

        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Hours by category")
                .font(.wbHeadline)
                .foregroundStyle(Color.textPrimary)
            if data.isEmpty {
                Text("No time logged in range")
                    .font(.wbCaption)
                    .foregroundStyle(Color.textTertiary)
            } else {
                Chart {
                    ForEach(data, id: \.0) { entry in
                        BarMark(
                            x: .value("Hours", entry.1),
                            y: .value("Category", entry.0.displayName)
                        )
                        .foregroundStyle(Color.statusBlue)
                    }
                }
                .frame(height: CGFloat(data.count) * 28 + 20)
            }
        }
        .padding(Spacing.m)
        .background(RoundedRectangle(cornerRadius: Radius.l).fill(Color.bgSecondary))
    }

    @ViewBuilder
    private var vehiclesChart: some View {
        let byVehicle = Dictionary(grouping: filteredRecords, by: { $0.vehicle?.id ?? UUID() })
        let data: [(String, Double)] = byVehicle.compactMap { entry -> (String, Double)? in
            let total = Money.sum(entry.value.map(\.totalCost))
            guard let v = entry.value.first?.vehicle else { return nil }
            return (v.displayTitle, total)
        }
        .sorted { $0.1 > $1.1 }
        .prefix(8)
        .map { ($0.0, $0.1) }

        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("By vehicle")
                .font(.wbHeadline)
                .foregroundStyle(Color.textPrimary)
            if data.isEmpty {
                Text("No records in range")
                    .font(.wbCaption)
                    .foregroundStyle(Color.textTertiary)
            } else {
                Chart {
                    ForEach(data, id: \.0) { entry in
                        BarMark(
                            x: .value("Vehicle", entry.0),
                            y: .value("Cost", entry.1)
                        )
                        .foregroundStyle(Color.accentPrimary)
                    }
                }
                .frame(height: 220)
            }
        }
        .padding(Spacing.m)
        .background(RoundedRectangle(cornerRadius: Radius.l).fill(Color.bgSecondary))
    }

    private func computeRevenueByCustomer() -> [(String, Double)] {
        let customerQuotes = quotes.filter { $0.status == .completed }
        let grouped: [UUID: [Quote]] = Dictionary(grouping: customerQuotes, by: { $0.customer?.id ?? UUID() })
        var rows: [(String, Double)] = []
        for (_, list) in grouped {
            let total = Money.sum(list.map(\.total))
            guard let name = list.first?.customer?.displayName else { continue }
            rows.append((name, total))
        }
        return Array(rows.sorted { $0.1 > $1.1 }.prefix(6))
    }

    @ViewBuilder
    private var revenueByCustomer: some View {
        let byCustomer = computeRevenueByCustomer()

        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Revenue by customer (completed quotes)")
                .font(.wbHeadline)
                .foregroundStyle(Color.textPrimary)
            if byCustomer.isEmpty {
                Text("No completed quotes")
                    .font(.wbCaption)
                    .foregroundStyle(Color.textTertiary)
            } else {
                ForEach(byCustomer, id: \.0) { row in
                    HStack {
                        Text(row.0).foregroundStyle(Color.textPrimary)
                        Spacer()
                        Text(Money.format(row.1))
                            .font(.wbMonoBody)
                            .foregroundStyle(Color.accentPrimary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(Spacing.m)
        .background(RoundedRectangle(cornerRadius: Radius.l).fill(Color.bgSecondary))
    }
}
