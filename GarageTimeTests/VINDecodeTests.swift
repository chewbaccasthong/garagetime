import Testing
@testable import GarageTime

@Suite("VIN — inferred classification")
struct VINDecodeTests {

    @Test("Motorcycle body class infers .motorcycle")
    func motorcycleType() {
        let r = VINDecodeResult(year: 2022, make: "Yamaha", model: "MT-07", trim: "",
                                bodyClass: "Motorcycle - Standard",
                                fuelType: "Gasoline", manufacturer: "Yamaha", raw: [:])
        #expect(r.inferredVehicleType == .motorcycle)
        #expect(r.inferredPowertrain == .ic)
    }

    @Test("Truck body class infers .truck")
    func truckType() {
        let r = VINDecodeResult(year: 2020, make: "Ford", model: "F-150", trim: "",
                                bodyClass: "Pickup", fuelType: "Gasoline",
                                manufacturer: "Ford", raw: [:])
        #expect(r.inferredVehicleType == .truck)
    }

    @Test("Electric fuel type infers .ev")
    func evPowertrain() {
        let r = VINDecodeResult(year: 2023, make: "Tesla", model: "Model 3", trim: "",
                                bodyClass: "Sedan/Saloon", fuelType: "Electric",
                                manufacturer: "Tesla", raw: [:])
        #expect(r.inferredPowertrain == .ev)
        #expect(r.inferredVehicleType == .car)
    }

    @Test("Hybrid fuel type infers .hybrid")
    func hybridPowertrain() {
        let r = VINDecodeResult(year: 2021, make: "Toyota", model: "Camry", trim: "SE",
                                bodyClass: "Sedan/Saloon", fuelType: "Gasoline, Hybrid",
                                manufacturer: "Toyota", raw: [:])
        #expect(r.inferredPowertrain == .hybrid)
    }
}
