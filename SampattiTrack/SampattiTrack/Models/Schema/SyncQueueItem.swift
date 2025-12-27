import Foundation
import SwiftData

/// Sync status for queue items to enable smart retry with exponential backoff
enum SyncStatus: String, Codable {
    case pending    // Not yet attempted
    case retrying   // Failed but will retry
    case failed     // Permanently failed (max retries exceeded)
    case succeeded  // Successfully synced (should be deleted from queue)
}

/// Offline queue for pending sync operations
/// Stores raw JSON data to avoid SwiftData relationship memory issues
/// Now includes sync status and retry metadata for exponential backoff
@Model
final class SyncQueueItem {
    @Attribute(.unique) var id: UUID
    var operationType: String  // "CREATE_TRANSACTION", "UPDATE_TRANSACTION", etc.
    var endpoint: String       // "/transactions"
    var method: String         // "POST", "PUT", "DELETE"
    var jsonData: Data         // Raw JSON payload
    var createdAt: Date
    var retryCount: Int
    
    // OFFLINE-FIRST: Sync status tracking
    var syncStatus: String     // Stored as String to work with SwiftData
    var lastAttemptAt: Date?   // When was the last sync attempt
    
    init(
        id: UUID = UUID(),
        operationType: String,
        endpoint: String,
        method: String,
        jsonData: Data,
        createdAt: Date = Date(),
        retryCount: Int = 0,
        syncStatus: SyncStatus = .pending,
        lastAttemptAt: Date? = nil
    ) {
        self.id = id
        self.operationType = operationType
        self.endpoint = endpoint
        self.method = method
        self.jsonData = jsonData
        self.createdAt = createdAt
        self.retryCount = retryCount
        self.syncStatus = syncStatus.rawValue
        self.lastAttemptAt = lastAttemptAt
    }
    
    // MARK: - Computed Properties
    
    var status: SyncStatus {
        get { SyncStatus(rawValue: syncStatus) ?? .pending }
        set { syncStatus = newValue.rawValue }
    }
    
    /// Calculate exponential backoff delay in seconds
    /// Formula: min(300, 2^retryCount) seconds
    /// Examples: 1s, 2s, 4s, 8s, 16s, 32s, 64s, 128s, 256s, 300s (max)
    var backoffDelaySeconds: TimeInterval {
        let exponentialDelay = pow(2.0, Double(retryCount))
        return min(300.0, exponentialDelay) // Cap at 5 minutes
    }
    
    /// Check if enough time has passed since last attempt to retry
    var canRetry: Bool {
        guard let lastAttempt = lastAttemptAt else {
            return true // Never attempted, can retry
        }
        let timeSinceLastAttempt = Date().timeIntervalSince(lastAttempt)
        return timeSinceLastAttempt >= backoffDelaySeconds
    }
}
