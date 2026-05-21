import SwiftUI
import SwiftData

struct MyRequestsView: View {
    @Environment(\.modelContext) private var context
    @Query private var shopSettings: [ShopSettings]
    @Query(sort: \JobRequest.createdAt, order: .reverse) private var allRequests: [JobRequest]
    @State private var openedRequest: JobRequest?

    private var meCustomer: Customer? { shopSettings.first?.meCustomer }
    private var myRequests: [JobRequest] {
        // In customer mode, a request from "me" might have meCustomer attached, OR
        // (if their vehicle is .personal and there's no meCustomer record) might have
        // no customer at all. Show both rather than risking blank-screen confusion.
        let myID = meCustomer?.id
        return allRequests.filter { r -> Bool in
            if r.customer == nil { return true }
            if let myID, r.customer?.id == myID { return true }
            return false
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.bgPrimary.ignoresSafeArea()
                if myRequests.isEmpty {
                    GSEmptyState(
                        icon: "paperplane",
                        title: "No requests yet",
                        message: "Open the Estimates tab to look up a job and send it to your mechanic."
                    )
                } else {
                    List {
                        ForEach(myRequests) { request in
                            Button { openedRequest = request } label: {
                                requestRow(request)
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(Color.bgSecondary)
                        }
                        .onDelete(perform: cancel)
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                }
            }
            .wbBreadcrumbs([Crumb("Requests", icon: "paperplane.fill")])
            .navigationTitle("My Requests")
            .sheet(item: $openedRequest) { request in
                NavigationStack {
                    JobRequestDetailView(request: request, viewerIsCustomer: true)
                }
            }
        }
    }

    private func requestRow(_ request: JobRequest) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack {
                Image(systemName: request.category.sfSymbol)
                    .foregroundStyle(Color.accentPrimary)
                Text(request.displayTitle)
                    .font(.wbBodyMedium)
                    .foregroundStyle(Color.textPrimary)
                Spacer()
                GSStatusPill(text: request.status.displayName, role: request.status.paletteRole, compact: true)
            }
            HStack {
                Text(request.vehicle?.displayTitle ?? "—")
                    .font(.wbCaption)
                    .foregroundStyle(Color.textSecondary)
                Spacer()
                Text(WBFormat.relative(request.createdAt))
                    .font(.wbCaptionSmall)
                    .foregroundStyle(Color.textTertiary)
            }
            if request.estimatedCost > 0 {
                HStack(spacing: Spacing.s) {
                    Label(Money.format(request.estimatedCost), systemImage: "dollarsign.circle.fill")
                        .font(.wbCaption)
                        .foregroundStyle(Color.accentPrimary)
                    Label(WBFormat.hours(request.estimatedHours), systemImage: "clock.fill")
                        .font(.wbCaption)
                        .foregroundStyle(Color.statusBlue)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private func cancel(at offsets: IndexSet) {
        for index in offsets {
            let r = myRequests[index]
            r.status = .cancelled
        }
        try? context.save()
    }
}
