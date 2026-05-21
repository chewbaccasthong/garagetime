import SwiftUI
import SwiftData

enum JobsFilter: String, CaseIterable, Hashable, Identifiable {
    case incoming, accepted, scheduled, quoted, completed, all
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .incoming:  return "Incoming"
        case .accepted:  return "Accepted"
        case .scheduled: return "Scheduled"
        case .quoted:    return "Quoted"
        case .completed: return "Completed"
        case .all:       return "All"
        }
    }
    func matches(_ status: JobStatus) -> Bool {
        switch self {
        case .all:       return true
        case .incoming:  return status == .pending
        case .accepted:  return status == .accepted
        case .scheduled: return status == .scheduled
        case .quoted:    return status == .quoted
        case .completed: return status == .completed
        }
    }
}

struct JobsHubView: View {
    @Environment(Backend.self) private var backend
    @Environment(\.modelContext) private var context
    @Query(sort: \JobRequest.createdAt, order: .reverse) private var jobs: [JobRequest]
    @State private var filter: JobsFilter = .incoming
    @State private var openedRequest: JobRequest?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.bgPrimary.ignoresSafeArea()
                if jobs.isEmpty {
                    GSEmptyState(
                        icon: "tray.full",
                        title: "No job requests yet",
                        message: "When a customer sends you a job request, it'll land here."
                    )
                } else {
                    VStack(spacing: 0) {
                        GSChipBar(items: JobsFilter.allCases, selection: $filter, label: { $0.displayName }, icon: nil)
                        statsHeader
                        List {
                            ForEach(filteredJobs) { job in
                                Button { openedRequest = job } label: {
                                    jobRow(job)
                                }
                                .buttonStyle(.plain)
                                .listRowBackground(Color.bgSecondary)
                            }
                        }
                        .listStyle(.insetGrouped)
                        .scrollContentBackground(.hidden)
                    }
                }
            }
            .wbBreadcrumbs([Crumb("Jobs", icon: "tray.full.fill")])
            .navigationTitle("Jobs")
            .sheet(item: $openedRequest) { request in
                NavigationStack {
                    JobRequestDetailView(request: request, viewerIsCustomer: false)
                }
            }
        }
    }

    private var filteredJobs: [JobRequest] { jobs.filter { filter.matches($0.status) } }

    private var statsHeader: some View {
        HStack(spacing: Spacing.s) {
            GSStatBlock(label: "Incoming", value: "\(incomingCount)",
                        icon: "tray.full.fill",
                        role: incomingCount > 0 ? .warning : .neutral)
            GSStatBlock(label: "Scheduled", value: "\(scheduledCount)",
                        icon: "calendar.badge.checkmark",
                        role: .info)
        }
        .padding(Spacing.m)
    }

    private var incomingCount: Int  { jobs.filter { $0.status == .pending }.count }
    private var scheduledCount: Int { jobs.filter { $0.status == .scheduled }.count }

    private func jobRow(_ job: JobRequest) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack {
                Image(systemName: job.category.sfSymbol)
                    .foregroundStyle(Color.accentPrimary)
                Text(job.customer?.displayName ?? "Unknown")
                    .font(.wbBodyMedium)
                    .foregroundStyle(Color.textPrimary)
                Spacer()
                GSStatusPill(text: job.status.displayName, role: job.status.paletteRole, compact: true)
            }
            HStack {
                Text(job.displayTitle)
                    .font(.wbCaption)
                    .foregroundStyle(Color.textSecondary)
                if let v = job.vehicle {
                    Text("·")
                    Text(v.displayTitle)
                        .font(.wbCaptionSmall)
                        .foregroundStyle(Color.textTertiary)
                        .lineLimit(1)
                }
                Spacer()
                Text(WBFormat.relative(job.createdAt))
                    .font(.wbCaptionSmall)
                    .foregroundStyle(Color.textTertiary)
            }
            if job.estimatedCost > 0 {
                HStack(spacing: Spacing.s) {
                    Label(Money.format(job.estimatedCost), systemImage: "dollarsign.circle.fill")
                        .font(.wbCaption)
                        .foregroundStyle(Color.accentPrimary)
                    Label(WBFormat.hours(job.estimatedHours), systemImage: "clock.fill")
                        .font(.wbCaption)
                        .foregroundStyle(Color.statusBlue)
                }
            }
        }
        .padding(.vertical, 2)
    }
}
