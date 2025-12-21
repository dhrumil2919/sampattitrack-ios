import Foundation

struct User: Codable, Identifiable {
    let id: UUID
    let username: String
    let email: String?
    let role: String?
    let createdAt: String?
    let updatedAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case username
        case email
        case role
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
