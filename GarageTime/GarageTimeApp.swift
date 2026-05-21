import SwiftUI
import SwiftData

@main
struct GarageTimeApp: App {
    @State private var backend: Backend

    init() {
        let container = GarageTimeApp.makeContainer()
        let backend = Backend(modelContainer: container)
        _backend = State(initialValue: backend)

        GarageTimeApp.bootstrapShopSettingsIfNeeded(container: container)
        GarageTimeBGTasks.register {
            Task { @MainActor in
                let ctx = container.mainContext
                await backend.reminderEngine.refresh(context: ctx)
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(backend)
                .modelContainer(backend.modelContainer)
                .task {
                    await backend.store.bootstrap()
                    await backend.reminderEngine.refresh(context: backend.modelContainer.mainContext)
                }
                .tint(Color.accentPrimary)
                .preferredColorScheme(.dark)
        }
    }

    // MARK: - Container

    private static func makeContainer() -> ModelContainer {
        let schema = Schema(GarageTimeSchema.allTypes)

        // Try CloudKit first — only works on a real Apple ID with iCloud + the entitlement.
        let cloud = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .private("iCloud.com.henrygawelek.garagetime")
        )
        if let container = try? ModelContainer(for: schema, configurations: [cloud]) {
            return container
        }

        // Fallback: local-only on the same disk file.
        let local = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        if let container = try? ModelContainer(for: schema, configurations: [local]) {
            return container
        }

        // Final fallback: in-memory (won't persist, but the app launches).
        let memory = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try! ModelContainer(for: schema, configurations: [memory])
    }

    @MainActor
    private static func bootstrapShopSettingsIfNeeded(container: ModelContainer) {
        let ctx = container.mainContext
        let descriptor = FetchDescriptor<ShopSettings>()
        if (try? ctx.fetch(descriptor))?.isEmpty ?? true {
            ctx.insert(ShopSettings())
            try? ctx.save()
        }
    }
}
