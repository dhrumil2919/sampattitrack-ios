import Foundation
import SwiftData

@Model
class SDPrice {
    @Attribute(.unique) var id: UUID
    var unitCode: String  // The commodity/unit code (e.g., "AAPL", "NIFTY")
    var date: String      // ISO date format YYYY-MM-DD
    var price: String     // Decimal value as string
    var currency: String
    var source: String?
    var createdAt: Date
    
    init(id: UUID = UUID(), unitCode: String, date: String, price: String, currency: String, source: String? = nil) {
        self.id = id
        self.unitCode = unitCode
        self.date = date
        self.price = price
        self.currency = currency
        self.source = source
        self.createdAt = Date()
    }
}
