import SwiftUI
import SwiftData

struct CustomerPickerSheet: View {
    @Binding var selected: Customer?
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Customer.lastName) private var customers: [Customer]
    @State private var query: String = ""
    @State private var addingNew: Bool = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(filtered) { customer in
                    Button {
                        selected = customer
                        dismiss()
                    } label: {
                        HStack(spacing: Spacing.s) {
                            GSAvatar(initials: customer.initials, size: 36)
                            VStack(alignment: .leading) {
                                Text(customer.displayName)
                                    .foregroundStyle(Color.textPrimary)
                                if !customer.phone.isEmpty || !customer.email.isEmpty {
                                    Text([customer.phone, customer.email].filter { !$0.isEmpty }.joined(separator: " · "))
                                        .font(.wbCaption)
                                        .foregroundStyle(Color.textSecondary)
                                }
                            }
                            Spacer()
                            if selected?.id == customer.id {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.accentPrimary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Choose customer")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, prompt: "Search customers")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        addingNew = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $addingNew) {
                NavigationStack {
                    CustomerEditorView(customer: nil) { saved in
                        if let saved {
                            selected = saved
                            dismiss()
                        }
                        addingNew = false
                    }
                }
            }
        }
    }

    private var filtered: [Customer] {
        let q = query.lowercased()
        guard !q.isEmpty else { return customers }
        return customers.filter {
            $0.displayName.lowercased().contains(q)
                || $0.email.lowercased().contains(q)
                || $0.phone.lowercased().contains(q)
        }
    }
}
