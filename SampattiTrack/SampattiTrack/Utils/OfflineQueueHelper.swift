import Foundation
import SwiftData

/// Helper class to queue offline operations for all entities
/// Centralizes the logic for creating queue items
class OfflineQueueHelper {
    
    // MARK: - Transaction Operations
    
    static func queueTransaction(
        id: UUID,
        date: String,
        description: String,
        note: String?,
        postings: [[String: Any]],
        context: ModelContext
    ) throws {
        let transactionJSON: [String: Any] = [
            "id": id.uuidString,
            "date": date,
            "description": description,
            "note": note as Any,
            "postings": postings
        ]
        
        try queueOperation(
            operationType: "CREATE_TRANSACTION",
            endpoint: "/transactions",
            method: "POST",
            payload: transactionJSON,
            context: context
        )
    }
    
    static func queueTransactionUpdate(
        id: UUID,
        date: String,
        description: String,
        note: String?,
        postings: [[String: Any]],
        context: ModelContext
    ) throws {
        let transactionJSON: [String: Any] = [
            "id": id.uuidString,
            "date": date,
            "description": description,
            "note": note as Any,
            "postings": postings
        ]
        
        try queueOperation(
            operationType: "UPDATE_TRANSACTION",
            endpoint: "/transactions/\(id.uuidString)",
            method: "PUT",
            payload: transactionJSON,
            context: context
        )
    }
    
    // MARK: - Account Operations
    
    static func queueAccount(
        id: String,
        name: String,
        category: String,
        type: String,
        currency: String?,
        icon: String?,
        parentID: String?,
        relatedAccountId: String?,
        metadata: [String: Any]?,
        context: ModelContext
    ) throws {
        var accountJSON: [String: Any] = [
            "id": id,
            "name": name,
            "category": category,
            "type": type
        ]
        
        // Add optional fields only if not nil
        if let currency = currency { accountJSON["currency"] = currency }
        if let icon = icon { accountJSON["icon"] = icon }
        if let parentID = parentID { accountJSON["parent_id"] = parentID }
        if let relatedAccountId = relatedAccountId { accountJSON["related_account_id"] = relatedAccountId }
        if let metadata = metadata { accountJSON["metadata"] = metadata }
        
        try queueOperation(
            operationType: "CREATE_ACCOUNT",
            endpoint: "/accounts",
            method: "POST",
            payload: accountJSON,
            context: context
        )
    }
    
    static func queueAccountUpdate(
        id: String,
        name: String,
        category: String,
        type: String,
        currency: String?,
        icon: String?,
        parentID: String?,
        relatedAccountId: String?,
        metadata: [String: Any]?,
        context: ModelContext
    ) throws {
        var accountJSON: [String: Any] = [
            "id": id,
            "name": name,
            "category": category,
            "type": type
        ]
        
        if let currency = currency { accountJSON["currency"] = currency }
        if let icon = icon { accountJSON["icon"] = icon }
        if let parentID = parentID { accountJSON["parent_id"] = parentID }
        if let relatedAccountId = relatedAccountId { accountJSON["related_account_id"] = relatedAccountId }
        if let metadata = metadata { accountJSON["metadata"] = metadata }
        
        try queueOperation(
            operationType: "UPDATE_ACCOUNT",
            endpoint: "/accounts/\(id)",
            method: "PUT",
            payload: accountJSON,
            context: context
        )
    }
    
    // MARK: - Unit Operations
    
    static func queueUnit(
        code: String,
        name: String,
        symbol: String?,
        type: String,
        context: ModelContext
    ) throws {
        let unitJSON: [String: Any] = [
            "code": code,
            "name": name,
            "symbol": symbol as Any,
            "type": type
        ]
        
        try queueOperation(
            operationType: "CREATE_UNIT",
            endpoint: "/units",
            method: "POST",
            payload: unitJSON,
            context: context
        )
    }
    
    static func queueUnitUpdate(
        code: String,
        name: String,
        symbol: String?,
        type: String,
        context: ModelContext
    ) throws {
        let unitJSON: [String: Any] = [
            "code": code,
            "name": name,
            "symbol": symbol as Any,
            "type": type
        ]
        
        try queueOperation(
            operationType: "UPDATE_UNIT",
            endpoint: "/units/\(code)",
            method: "PUT",
            payload: unitJSON,
            context: context
        )
    }
    
    // MARK: - Delete Operations
    
    static func queueTransactionDelete(id: UUID, context: ModelContext) throws {
        try queueOperation(
            operationType: "DELETE_TRANSACTION",
            endpoint: "/transactions/\(id.uuidString)",
            method: "DELETE",
            payload: [:],
            context: context
        )
    }
    
    static func queueAccountDelete(id: String, context: ModelContext) throws {
        try queueOperation(
            operationType: "DELETE_ACCOUNT",
            endpoint: "/accounts/\(id)",
            method: "DELETE",
            payload: [:],
            context: context
        )
    }
    
    static func queueUnitDelete(code: String, context: ModelContext) throws {
        try queueOperation(
            operationType: "DELETE_UNIT",
            endpoint: "/units/\(code)",
            method: "DELETE",
            payload: [:],
            context: context
        )
    }
    
    // MARK: - Private Helper
    
    private static func queueOperation(
        operationType: String,
        endpoint: String,
        method: String,
        payload: [String: Any],
        context: ModelContext
    ) throws {
        let jsonData = try JSONSerialization.data(withJSONObject: payload)
        
        let queueItem = SyncQueueItem(
            operationType: operationType,
            endpoint: endpoint,
            method: method,
            jsonData: jsonData
        )
        
        context.insert(queueItem)
        try context.save()
        
        print("[OfflineQueue] Queued: \(operationType) to \(endpoint)")
    }
}
