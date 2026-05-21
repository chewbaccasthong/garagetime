import Foundation

/// A curated link to an external parts catalog with the vehicle's VIN/year/make/model pre-applied.
struct PartsLink: Identifiable, Sendable, Hashable {
    let id = UUID()
    let supplier: String
    let url: URL
    let sfSymbol: String
    let description: String
}

/// NHTSA recall row for a vehicle.
struct Recall: Identifiable, Sendable, Hashable {
    let id = UUID()
    let campaignNumber: String
    let component: String
    let summary: String
    let consequence: String
    let remedy: String
    let reportDate: Date?
}

protocol PartsFinding: Sendable {
    func links(for vehicle: Vehicle) -> [PartsLink]
    func recalls(year: Int, make: String, model: String) async throws -> [Recall]
}

struct RealPartsFinderService: PartsFinding {

    // MARK: - Links

    func links(for vehicle: Vehicle) -> [PartsLink] {
        var links: [PartsLink] = []

        let make = vehicle.make.lowercased().replacingOccurrences(of: " ", with: "+")
        let model = vehicle.model.lowercased().replacingOccurrences(of: " ", with: "+")
        let year = vehicle.year

        // RockAuto — by year/make/model
        if let url = URL(string: "https://www.rockauto.com/en/parts/?carcode=&offset=0&year=\(year)&make=\(make)&model=\(model)") {
            links.append(PartsLink(
                supplier: "RockAuto",
                url: url,
                sfSymbol: "wrench.adjustable.fill",
                description: "OEM + aftermarket, broad catalog"
            ))
        }
        // Amazon Motors
        if let q = "\(year) \(vehicle.make) \(vehicle.model)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let url = URL(string: "https://www.amazon.com/s?k=\(q)&i=automotive") {
            links.append(PartsLink(
                supplier: "Amazon",
                url: url,
                sfSymbol: "shippingbox.fill",
                description: "Universal parts, fast ship"
            ))
        }
        // eBay Motors
        if let q = "\(year) \(vehicle.make) \(vehicle.model)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let url = URL(string: "https://www.ebay.com/sch/i.html?_nkw=\(q)&_sacat=6028") {
            links.append(PartsLink(
                supplier: "eBay Motors",
                url: url,
                sfSymbol: "tag.fill",
                description: "Used + new, lots of variety"
            ))
        }
        // VIN-prefilled manufacturer search (best-effort)
        if !vehicle.vin.isEmpty, let url = URL(string: "https://www.google.com/search?q=\(vehicle.vin)+parts") {
            links.append(PartsLink(
                supplier: "Web by VIN",
                url: url,
                sfSymbol: "magnifyingglass",
                description: "Open web search for VIN-specific parts"
            ))
        }
        return links
    }

    // MARK: - Recalls

    func recalls(year: Int, make: String, model: String) async throws -> [Recall] {
        var components = URLComponents(string: "https://api.nhtsa.gov/recalls/recallsByVehicle")!
        components.queryItems = [
            URLQueryItem(name: "make", value: make),
            URLQueryItem(name: "model", value: model),
            URLQueryItem(name: "modelYear", value: String(year)),
        ]
        guard let url = components.url else { return [] }
        var req = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
        req.timeoutInterval = 10
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return [] }

        let payload = try JSONDecoder().decode(NHTSARecallsPayload.self, from: data)
        let df = DateFormatter()
        df.dateFormat = "dd/MM/yyyy"
        return payload.results.map { row in
            Recall(
                campaignNumber: row.NHTSACampaignNumber ?? "",
                component: row.Component ?? "",
                summary: row.Summary ?? "",
                consequence: row.Consequence ?? "",
                remedy: row.Remedy ?? "",
                reportDate: row.ReportReceivedDate.flatMap(df.date(from:))
            )
        }
    }
}

final class InMemoryPartsFinderService: PartsFinding, @unchecked Sendable {
    var fixedLinks: [PartsLink] = []
    var fixedRecalls: [Recall] = []

    func links(for vehicle: Vehicle) -> [PartsLink] { fixedLinks }
    func recalls(year: Int, make: String, model: String) async throws -> [Recall] { fixedRecalls }
}

// MARK: - NHTSA recall JSON

private struct NHTSARecallsPayload: Decodable {
    struct Row: Decodable {
        let NHTSACampaignNumber: String?
        let Component: String?
        let Summary: String?
        let Consequence: String?
        let Remedy: String?
        let ReportReceivedDate: String?
    }
    let results: [Row]
}
