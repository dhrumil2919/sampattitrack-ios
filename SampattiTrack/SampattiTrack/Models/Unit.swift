import Foundation

struct FinancialUnit: Codable, Identifiable {
    let code: String
    let name: String
    let type: String
    let symbol: String?
    let provider: String?
    let currency: String
    
    var id: String { code }
    
    enum CodingKeys: String, CodingKey {
        case code
        case name
        case type
        case symbol
        case provider
        case currency
    }
}

struct UnitListResponse: Codable {
    let success: Bool
    let data: [FinancialUnit]
}

struct PriceLookupResponse: Codable {
    let success: Bool
    let data: PriceData
}

struct PriceData: Codable {
    let price: String
}
