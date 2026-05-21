import Foundation
import SwiftData

/// Holds every service the app depends on. Built once in `GarageTimeApp.init()`
/// and passed down through the environment.
@MainActor
@Observable
final class Backend {
    let modelContainer: ModelContainer
    let nhtsa: any VINDecoding
    let ocr: any ReceiptOCRing
    let notifications: any NotificationScheduling
    let pdf: any PDFExporting
    let parts: any PartsFinding
    let quoteNumbers: any QuoteNumberMinting
    let signature: any SignatureRendering
    let store: any StoreVending
    let estimates: any EstimateProviding
    let quota: any VehicleQuotaChecking
    let bulkImport: any BulkImportParsing
    let reminderEngine: ReminderEngine

    init(
        modelContainer: ModelContainer,
        nhtsa: any VINDecoding = RealNHTSAService(),
        ocr: any ReceiptOCRing = RealOCRService(),
        notifications: any NotificationScheduling = RealNotificationService(),
        pdf: any PDFExporting = RealPDFExportService(),
        parts: any PartsFinding = RealPartsFinderService(),
        quoteNumbers: any QuoteNumberMinting = RealQuoteNumberService(),
        signature: any SignatureRendering = RealSignatureService(),
        store: any StoreVending = RealStoreService(),
        estimates: any EstimateProviding = RealEstimateService(),
        quota: any VehicleQuotaChecking = RealVehicleQuotaService.shared,
        bulkImport: any BulkImportParsing = RealBulkImportService()
    ) {
        self.modelContainer = modelContainer
        self.nhtsa = nhtsa
        self.ocr = ocr
        self.notifications = notifications
        self.pdf = pdf
        self.parts = parts
        self.quoteNumbers = quoteNumbers
        self.signature = signature
        self.store = store
        self.estimates = estimates
        self.quota = quota
        self.bulkImport = bulkImport
        self.reminderEngine = ReminderEngine(notifications: notifications)
    }

    /// Effective entitlements, accounting for an active local trial.
    /// Reads the singleton `ShopSettings` from the main context — cheap, called per render.
    @MainActor
    func effectiveEntitlements() -> Entitlements {
        let descriptor = FetchDescriptor<ShopSettings>()
        let shop = (try? modelContainer.mainContext.fetch(descriptor))?.first
        return TrialEntitlement.resolve(store: store, settings: shop)
    }

    /// In-memory backend for SwiftUI previews and tests.
    @MainActor static func preview() -> Backend {
        Backend(
            modelContainer: PreviewModelContainer.shared,
            nhtsa: InMemoryNHTSAService(fixtures: [
                "2HGFC1F75JH": VINDecodeResult(
                    year: 2018, make: "Honda", model: "Civic",
                    trim: "Touring", bodyClass: "Sedan",
                    fuelType: "Gasoline", manufacturer: "Honda Mfg",
                    raw: [:]
                )
            ]),
            ocr: InMemoryOCRService(),
            notifications: InMemoryNotificationService(),
            pdf: InMemoryPDFExportService(),
            parts: InMemoryPartsFinderService(),
            quoteNumbers: InMemoryQuoteNumberService(),
            signature: InMemorySignatureService(),
            store: InMemoryStoreService(),
            estimates: InMemoryEstimateService(),
            quota: InMemoryVehicleQuotaService(),
            bulkImport: RealBulkImportService()
        )
    }
}
