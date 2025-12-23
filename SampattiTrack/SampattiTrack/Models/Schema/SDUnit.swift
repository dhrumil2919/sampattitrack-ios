import Foundation
import SwiftData

/// SDUnit stores financial units locally for offline access.
/// Units represent currencies or commodities (e.g., INR, USD, GOLD).
@Model
final class SDUnit {
    /// Unique identifier for the unit (e.g., "INR", "USD", "ICICI_BLUECHIP")
    @Attribute(.unique) var code: String
    
    /// Display name for the unit
    var name: String
    
    /// Symbol for the unit (e.g., "₹", "$")
    var symbol: String?
    
    /// Type of unit: "currency" or "commodity"
    var type: String
    
    /// Whether this unit has been synced with the server
    var isSynced: Bool
    
    init(code: String, name: String, symbol: String? = nil, type: String = "currency", isSynced: Bool = true) {
        self.code = code
        self.name = name
        self.symbol = symbol
        self.type = type
        self.isSynced = isSynced
    }
}
