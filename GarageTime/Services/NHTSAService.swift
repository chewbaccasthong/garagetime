import Foundation

/// Result of decoding a VIN against the NHTSA vPIC API.
struct VINDecodeResult: Sendable, Equatable {
    var year: Int
    var make: String
    var model: String
    var trim: String
    var bodyClass: String
    var fuelType: String
    var manufacturer: String
    var raw: [String: String]   // original variable -> value map

    static let empty = VINDecodeResult(year: 0, make: "", model: "", trim: "", bodyClass: "", fuelType: "", manufacturer: "", raw: [:])

    /// Map NHTSA fuel/body to our `VehicleType` enum.
    var inferredVehicleType: VehicleType {
        let body = bodyClass.lowercased()
        if body.contains("motorcycle") || body.contains("moped") { return .motorcycle }
        if body.contains("truck") || body.contains("pickup") || body.contains("cab") { return .truck }
        if body.contains("car") || body.contains("sedan") || body.contains("coupe") || body.contains("hatch") || body.contains("wagon") || body.contains("convertible") { return .car }
        if !body.isEmpty { return .other }
        return .car
    }

    var inferredPowertrain: Powertrain {
        let f = fuelType.lowercased()
        if f.contains("electric") && !f.contains("hybrid") { return .ev }
        if f.contains("hybrid") || f.contains("phev") { return .hybrid }
        return .ic
    }
}

protocol VINDecoding: Sendable {
    func decode(vin: String) async throws -> VINDecodeResult
}

actor RealNHTSAService: VINDecoding {
    private var cache: [String: VINDecodeResult] = [:]
    private let session: URLSession
    private let baseURL: URL

    init(session: URLSession = .shared,
         baseURL: URL = URL(string: "https://vpic.nhtsa.dot.gov/api/vehicles/")!) {
        self.session = session
        self.baseURL = baseURL
    }

    func decode(vin: String) async throws -> VINDecodeResult {
        let normalized = vin.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !normalized.isEmpty else { return .empty }
        if let cached = cache[normalized] { return cached }

        let url = baseURL.appendingPathComponent("DecodeVin/\(normalized)")
            .appending(queryItems: [URLQueryItem(name: "format", value: "json")])
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
        request.timeoutInterval = 8

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw NSError(domain: "NHTSA", code: 1)
        }

        let payload = try JSONDecoder().decode(NHTSADecodePayload.self, from: data)
        let dict = Dictionary(uniqueKeysWithValues: payload.Results.map { ($0.Variable, $0.Value ?? "") })

        let yearString = dict["Model Year"] ?? ""
        let year = Int(yearString) ?? 0

        let result = VINDecodeResult(
            year: year,
            make: titleCase(dict["Make"] ?? ""),
            model: titleCase(dict["Model"] ?? ""),
            trim: dict["Trim"] ?? "",
            bodyClass: dict["Body Class"] ?? "",
            fuelType: dict["Fuel Type - Primary"] ?? "",
            manufacturer: titleCase(dict["Manufacturer Name"] ?? ""),
            raw: dict
        )
        cache[normalized] = result
        return result
    }

    private func titleCase(_ s: String) -> String {
        s.lowercased().split(separator: " ").map { $0.capitalized }.joined(separator: " ")
    }
}

/// In-memory test fake. Returns canned results for specific VIN prefixes.
final class InMemoryNHTSAService: VINDecoding, @unchecked Sendable {
    var fixtures: [String: VINDecodeResult]

    init(fixtures: [String: VINDecodeResult] = [:]) {
        self.fixtures = fixtures
    }

    func decode(vin: String) async throws -> VINDecodeResult {
        let normalized = vin.uppercased()
        if let exact = fixtures[normalized] { return exact }
        // Match by prefix
        for (key, value) in fixtures where normalized.hasPrefix(key) {
            return value
        }
        return .empty
    }
}

// MARK: - JSON wire format

private struct NHTSADecodePayload: Decodable {
    struct Row: Decodable {
        let Variable: String
        let Value: String?
    }
    let Results: [Row]
}
