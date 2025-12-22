import Foundation

struct Account: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let category: String
    let type: String
    let currency: String?
    let icon: String?
    let parentID: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case category
        case type
        case currency
        case icon
        case parentID = "parent_id"
    }
}

struct AccountListResponse: Codable {
    let success: Bool
    let data: [Account]
}

struct CreateAccountRequest: Codable {
    let id: String?
    let name: String
    let category: String
    let type: String
    let currency: String?
    let parentID: String?
    let relatedAccountID: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case category
        case type
        case currency
        case parentID = "parent_id"
        case relatedAccountID = "related_account_id"
    }
}
