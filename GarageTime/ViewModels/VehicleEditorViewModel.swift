import Foundation
import SwiftData

@MainActor
@Observable
final class VehicleEditorViewModel {

    // MARK: - Editable state

    var name: String = ""
    var year: Int = 0
    var make: String = ""
    var model: String = ""
    var trim: String = ""
    var vin: String = ""
    var licensePlate: String = ""
    var type: VehicleType = .car
    var powertrain: Powertrain = .ic
    var ownerType: OwnerType = .personal
    var currentMileage: Int = 0
    var mileageUnit: MileageUnit = .mi
    var photoData: Data?
    var purchaseDate: Date?
    var purchasePrice: Double = 0
    var notes: String = ""
    var selectedCustomer: Customer?
    var laborRateOverride: Double?
    var isVINVerified: Bool = false

    // MARK: - UI state

    var isScanningVIN: Bool = false
    var isDecoding: Bool = false
    var decodeError: String?
    var showCustomerPicker: Bool = false

    // MARK: - Validation

    var isValid: Bool {
        // At minimum we want either a name or year+make+model.
        if !name.isEmpty { return true }
        return year > 0 && !make.isEmpty && !model.isEmpty
    }

    var ownerValid: Bool {
        ownerType == .personal || selectedCustomer != nil
    }

    var canSave: Bool { isValid && ownerValid }

    // MARK: - Lifecycle

    private let backend: Backend
    private let context: ModelContext
    private(set) var editingVehicle: Vehicle?

    init(backend: Backend, context: ModelContext, vehicle: Vehicle? = nil) {
        self.backend = backend
        self.context = context
        self.editingVehicle = vehicle
        if let vehicle { hydrate(from: vehicle) }
    }

    private func hydrate(from vehicle: Vehicle) {
        name = vehicle.name
        year = vehicle.year
        make = vehicle.make
        model = vehicle.model
        trim = vehicle.trim
        vin = vehicle.vin
        licensePlate = vehicle.licensePlate
        type = vehicle.type
        powertrain = vehicle.powertrain
        ownerType = vehicle.ownerType
        currentMileage = vehicle.currentMileage
        mileageUnit = vehicle.mileageUnit
        photoData = vehicle.photoData
        purchaseDate = vehicle.purchaseDate
        purchasePrice = vehicle.purchasePrice
        notes = vehicle.notes
        selectedCustomer = vehicle.customer
        laborRateOverride = vehicle.laborRateOverride
        isVINVerified = vehicle.isVINVerified
    }

    // MARK: - VIN scan + decode

    func decodeVIN() async {
        let cleaned = vin.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard cleaned.count >= 17 else { return }
        isDecoding = true
        decodeError = nil
        defer { isDecoding = false }
        do {
            let result = try await backend.nhtsa.decode(vin: cleaned)
            // Only fill blanks — don't overwrite the user's manual edits.
            if year == 0, result.year > 0 { year = result.year }
            if make.isEmpty, !result.make.isEmpty { make = result.make }
            if model.isEmpty, !result.model.isEmpty { model = result.model }
            if trim.isEmpty, !result.trim.isEmpty { trim = result.trim }
            // Only override classifications if user hasn't changed defaults
            if type == .car { type = result.inferredVehicleType }
            if powertrain == .ic { powertrain = result.inferredPowertrain }
            // Mark the VIN as verified — used to show a trust badge + discourages
            // dealer inventory uploads using junk VINs.
            if result.year > 0 || !result.make.isEmpty {
                isVINVerified = true
            }
        } catch {
            decodeError = "Couldn't decode this VIN — check it's all 17 characters."
        }
    }

    // MARK: - Save

    func save() -> Vehicle {
        let vehicle = editingVehicle ?? Vehicle()
        vehicle.name = name
        vehicle.year = year
        vehicle.make = make
        vehicle.model = model
        vehicle.trim = trim
        vehicle.vin = vin.uppercased()
        vehicle.licensePlate = licensePlate
        vehicle.type = type
        vehicle.powertrain = powertrain
        vehicle.ownerType = ownerType
        vehicle.currentMileage = currentMileage
        vehicle.mileageUnit = mileageUnit
        vehicle.photoData = photoData
        vehicle.purchaseDate = purchaseDate
        vehicle.purchasePrice = purchasePrice
        vehicle.notes = notes
        vehicle.customer = ownerType == .customer ? selectedCustomer : nil
        vehicle.laborRateOverride = laborRateOverride
        vehicle.isVINVerified = isVINVerified
        vehicle.updatedAt = Date()

        if editingVehicle == nil {
            context.insert(vehicle)
        }
        try? context.save()
        return vehicle
    }
}
