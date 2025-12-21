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
    
    init(id: UUID = UUID(), accountID: String, accountName: String? = nil, amount: String, quantity: String? = nil, unitCode: String? = nil) {
        self.id = id
        self.accountID = accountID
        self.accountName = accountName
        self.amount = amount
        self.quantity = quantity
        self.unitCode = unitCode
    }
}
