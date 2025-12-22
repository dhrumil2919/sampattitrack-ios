import Foundation
import SwiftData

@Model
class SDPosting {
    @Attribute(.unique) var id: UUID
    var accountID: String
    var accountName: String?
    var amount: String
    var quantity: String?
    var unitCode: String?
    
    var transaction: SDTransaction?
    
    @Relationship(inverse: \SDTag.postings)
    var tags: [SDTag]?

    init(id: UUID = UUID(), accountID: String, accountName: String? = nil, amount: String, quantity: String? = nil, unitCode: String? = nil, tags: [SDTag]? = nil) {
        self.id = id
        self.accountID = accountID
        self.accountName = accountName
        self.amount = amount
        self.quantity = quantity
        self.unitCode = unitCode
        self.tags = tags
    }
}
