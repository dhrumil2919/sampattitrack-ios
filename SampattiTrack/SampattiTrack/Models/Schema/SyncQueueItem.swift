import Foundation
import SwiftData

/// Offline queue for pending sync operations
/// Stores raw JSON data to avoid SwiftData relationship memory issues
@Model
final class SyncQueueItem {
    @Attribute(.unique) var id: UUID
    var operationType: String  // "CREATE_TRANSACTION", "UPDATE_TRANSACTION", etc.
    var endpoint: String       // "/transactions"
    var method: String         // "POST", "PUT", "DELETE"
    var jsonData: Data         // Raw JSON payload
    var createdAt: Date
    var retryCount: Int
    
    init(
        id: UUID = UUID(),
        operationType: String,
        endpoint: String,
        method: String,
        jsonData: Data,
        createdAt: Date = Date(),
        retryCount: Int = 0
    ) {
        self.id = id
        self.operationType = operationType
        self.endpoint = endpoint
        self.method = method
        self.jsonData = jsonData
        self.createdAt = createdAt
        self.retryCount = retryCount
    }
}
