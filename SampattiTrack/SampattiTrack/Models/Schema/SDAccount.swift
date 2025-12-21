import Foundation
import SwiftData

@Model
class SDAccount {
    @Attribute(.unique) var id: String
    var name: String
    var category: String
    var type: String
    var currency: String?
    var icon: String?
    var parentID: String?
    
    // Sync Metadata
    var isSynced: Bool = true // Accounts are mostly read-only/pulled from server initially
    var updatedAt: Date = Date()
    
    init(id: String, name: String, category: String, type: String, currency: String? = nil, icon: String? = nil, parentID: String? = nil) {
        self.id = id
        self.name = name
        self.category = category
        self.type = type
        self.currency = currency
        self.icon = icon
        self.parentID = parentID
        self.updatedAt = Date()
    }
    
    var toAccount: Account {
        Account(
            id: id,
            name: name,
            category: category,
            type: type,
            currency: currency,
            icon: icon,
            parentID: parentID
        )
    }
}
