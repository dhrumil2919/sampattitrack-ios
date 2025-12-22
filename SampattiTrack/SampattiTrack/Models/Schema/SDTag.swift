import Foundation
import SwiftData

@Model
class SDTag {
    @Attribute(.unique) var id: String
    var name: String
    var desc: String? // Description
    var color: String?

    // Sync Metadata
    var isSynced: Bool = true
    var updatedAt: Date = Date()

    // Relationship
    var postings: [SDPosting]?

    init(id: String, name: String, desc: String? = nil, color: String? = nil, isSynced: Bool = true) {
        self.id = id
        self.name = name
        self.desc = desc
        self.color = color
        self.isSynced = isSynced
        self.updatedAt = Date()
    }

    var toTag: Tag {
        Tag(
            id: id,
            name: name,
            description: desc,
            color: color,
            createdAt: "", // Not stored locally
            updatedAt: ""  // Not stored locally
        )
    }
}
