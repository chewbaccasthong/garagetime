import SwiftUI
import SwiftData

/// One-time role picker. Shown when `ShopSettings.role` is nil.
struct OnboardingView: View {
    @Environment(\.modelContext) private var context
    @Query private var allShops: [ShopSettings]

    @State private var step: Step = .role
    @State private var selectedRole: UserRole = .mechanic
    @State private var displayName: String = ""
    @State private var email: String = ""
    @State private var phone: String = ""
    @State private var businessName: String = ""
    @State private var mechanicLookupName: String = ""

    private enum Step { case role, profile }

    var body: some View {
        ZStack {
            Color.bgPrimary.ignoresSafeArea()
            ScrollView {
                VStack(spacing: Spacing.l) {
                    hero
                    switch step {
                    case .role:    roleCards
                    case .profile: profileForm
                    }
                    bottomCTA
                }
                .padding(Spacing.l)
            }
            .wbDismissibleKeyboard()
            .tapToDismissKeyboard()
        }
    }

    private var hero: some View {
        VStack(spacing: Spacing.s) {
            ZStack {
                Circle().fill(Color.accentPrimary.opacity(0.18)).frame(width: 96, height: 96)
                Image(systemName: "wrench.and.screwdriver.fill")
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundStyle(Color.accentPrimary)
            }
            Text("Welcome to Garage Time")
                .font(.wbDisplayMedium)
                .foregroundStyle(Color.textPrimary)
            Text(step == .role
                 ? "Pick how you'll use the app. You can switch later in Settings."
                 : "Tell us a little about you. This is how others will see you.")
                .font(.wbBody)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.textSecondary)
                .padding(.horizontal, Spacing.l)
        }
        .padding(.top, Spacing.l)
    }

    private var roleCards: some View {
        VStack(spacing: Spacing.s) {
            ForEach(UserRole.allCases) { role in
                roleCard(role)
            }
        }
    }

    private func roleCard(_ role: UserRole) -> some View {
        let isSelected = selectedRole == role
        return Button {
            HapticsManager.selection()
            withAnimation(Motion.snap) { selectedRole = role }
        } label: {
            HStack(alignment: .top, spacing: Spacing.m) {
                ZStack {
                    Circle().fill(Color.accentPrimary.opacity(0.18)).frame(width: 56, height: 56)
                    Image(systemName: role.sfSymbol)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(Color.accentPrimary)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("I'm a \(role.displayName)")
                        .font(.wbHeadline)
                        .foregroundStyle(Color.textPrimary)
                    Text(role.blurb)
                        .font(.wbCaption)
                        .foregroundStyle(Color.textSecondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.accentPrimary : Color.textTertiary)
            }
            .padding(Spacing.m)
            .background(
                RoundedRectangle(cornerRadius: Radius.l, style: .continuous)
                    .fill(Color.bgSecondary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.l, style: .continuous)
                    .strokeBorder(isSelected ? Color.accentPrimary : Color.dividerColor,
                                  lineWidth: isSelected ? 2 : 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var profileForm: some View {
        VStack(spacing: Spacing.m) {
            if selectedRole == .mechanic {
                GSTextField(title: "Your name", text: $displayName,
                            placeholder: "Henry G.",
                            icon: "person.fill",
                            textContentType: .name)
                GSTextField(title: "Shop / business name (optional)", text: $businessName,
                            placeholder: "Henry's Mobile Mechanic",
                            icon: "storefront.fill",
                            textContentType: .organizationName)
                GSTextField(title: "Phone", text: $phone,
                            placeholder: "(555) 555-0199",
                            icon: "phone.fill",
                            keyboard: .phonePad,
                            textContentType: .telephoneNumber)
                GSTextField(title: "Email", text: $email,
                            placeholder: "you@example.com",
                            icon: "envelope.fill",
                            keyboard: .emailAddress,
                            textContentType: .emailAddress,
                            autocapitalization: .never,
                            disableAutocorrection: true)
            } else {
                GSTextField(title: "Your name", text: $displayName,
                            placeholder: "Alice Nguyen",
                            icon: "person.fill",
                            textContentType: .name)
                GSTextField(title: "Phone", text: $phone,
                            placeholder: "(555) 555-0199",
                            icon: "phone.fill",
                            keyboard: .phonePad,
                            textContentType: .telephoneNumber)
                GSTextField(title: "Email", text: $email,
                            placeholder: "you@example.com",
                            icon: "envelope.fill",
                            keyboard: .emailAddress,
                            textContentType: .emailAddress,
                            autocapitalization: .never,
                            disableAutocorrection: true)
                GSTextField(title: "Your mechanic's name (optional)", text: $mechanicLookupName,
                            placeholder: "Henry G.",
                            icon: "wrench.and.screwdriver.fill")
            }
        }
    }

    private var bottomCTA: some View {
        VStack(spacing: Spacing.xs) {
            switch step {
            case .role:
                GSButton(title: "Continue", icon: "arrow.right",
                         style: .primary, size: .large) {
                    withAnimation { step = .profile }
                }
            case .profile:
                GSButton(title: "Finish setup", icon: "checkmark.seal.fill",
                         style: .primary, size: .large,
                         isEnabled: !displayName.isEmpty) {
                    finish()
                }
                Button("Back") {
                    withAnimation { step = .role }
                }
                .font(.wbCaption)
                .foregroundStyle(Color.textSecondary)
            }
        }
        .padding(.top, Spacing.s)
    }

    private func finish() {
        let shop = allShops.first ?? {
            let new = ShopSettings()
            context.insert(new)
            return new
        }()

        shop.role = selectedRole
        shop.hasCompletedOnboarding = true
        shop.updatedAt = Date()

        switch selectedRole {
        case .mechanic:
            shop.ownerName = displayName
            shop.mechanicDisplayName = displayName
            if !businessName.isEmpty { shop.businessName = businessName }
            if !phone.isEmpty { shop.phone = phone }
            if !email.isEmpty { shop.email = email }
        case .customer:
            // Create a Customer record to represent "me".
            let firstName: String
            let lastName: String
            let parts = displayName.split(separator: " ", maxSplits: 1).map(String.init)
            firstName = parts.first ?? displayName
            lastName  = parts.count > 1 ? parts[1] : ""
            let me = Customer(firstName: firstName, lastName: lastName,
                              email: email, phone: phone)
            context.insert(me)
            shop.meCustomer = me
            if !mechanicLookupName.isEmpty {
                shop.mechanicDisplayName = mechanicLookupName
            }
        }

        try? context.save()
        HapticsManager.success()
    }
}

#Preview {
    OnboardingView()
        .environment(Backend.preview())
        .modelContainer(PreviewModelContainer.shared)
}
