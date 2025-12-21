import Foundation

// MARK: - Tag Models

struct Tag: Codable, Identifiable {
    let id: String
    let name: String
    let description: String?
    let color: String?
    let createdAt: String
    let updatedAt: String
    
    enum CodingKeys: String, CodingKey {
        case id, name, description, color
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct TopTag: Codable, Identifiable {
    let tagId: String
    let tagName: String
    let amount: String
    
    var id: String { tagId }
    
    var amountValue: Double {
        Double(amount) ?? 0.0
    }
    
    enum CodingKeys: String, CodingKey {
        case tagId = "tag_id"
        case tagName = "tag_name"
        case amount
    }
}

// MARK: - API Response Models

struct TopTagsResponse: Codable {
    let success: Bool
    let data: [TopTag]
}

struct TagListResponse: Codable {
    let success: Bool
    let data: [Tag]
}

struct SingleTagResponse: Codable {
    let success: Bool
    let data: Tag
}

struct CreateTagRequest: Codable {
    let name: String
    let description: String?
    let color: String?
}

struct EmptyResponse: Codable {
    let success: Bool
}
