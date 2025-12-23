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
    
    // Additional metadata storage (JSON)
    var metadata: Data?
    
    // Cached XIRR value (fetched from API, stored locally)
    var cachedXIRR: Double?
    var xirrCachedAt: Date?
    
    init(id: String, name: String, category: String, type: String, currency: String? = nil, icon: String? = nil, parentID: String? = nil, metadata: Data? = nil, isSynced: Bool = true) {
        self.id = id
        self.name = name
        self.category = category
        self.type = type
        self.currency = currency
        self.icon = icon
        self.parentID = parentID
        self.metadata = metadata
        self.isSynced = isSynced
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
    
    // MARK: - Metadata Helpers
    
    var metadataDictionary: [String: Any]? {
        guard let data = metadata else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }
    
    var creditLimit: Double? {
        // Handle both Int and Double/Float values from JSON
        if let val = metadataDictionary?["credit_limit"] as? Double { return val }
        if let val = metadataDictionary?["credit_limit"] as? Int { return Double(val) }
        return nil
    }
    
    var statementDay: Int? {
        if let val = metadataDictionary?["statement_day"] as? Int { return val }
        if let val = metadataDictionary?["statement_day"] as? Double { return Int(val) }
        return nil
    }
    
    var dueDay: Int? {
        if let val = metadataDictionary?["due_day"] as? Int { return val }
        if let val = metadataDictionary?["due_day"] as? Double { return Int(val) }
        return nil
    }
    
    var lastDigits: String? {
        return metadataDictionary?["last_digits"] as? String
    }
    
    var network: String? {
        return metadataDictionary?["network"] as? String
    }
}
