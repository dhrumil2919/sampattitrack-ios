import SwiftData
import Foundation

// MARK: - DTOs (Sendable, thread-safe)

struct TransactionDTO: Codable, Sendable {
    let id: UUID
    let date: String
    let description: String
    let note: String?
    let postings: [PostingDTO]
}

struct PostingDTO: Codable, Sendable {
    let id: UUID
    let account_id: String
    let amount: String
    let quantity: String
    let unit_code: String?
}

struct TagDTO: Codable, Sendable {
    let id: UUID
    let name: String
    let description: String?
    let color: String?
}

struct AccountDTO: Codable, Sendable {
    let id: String
    let name: String
    let type: String
    let category: String
    let currency: String?  // Optional - backend excludes this from JSON
    let icon: String?
    let parent_id: String?
}

struct UnitDTO: Codable, Sendable {
    let code: String
    let name: String
    let symbol: String?
    let type: String
}

struct SyncResponseDTO: Codable {
    let success: Bool
    let tags: [TagDTO]
    let accounts: [AccountDTO]
    let units: [UnitDTO]
    let transactions: [TransactionDTO]
}

// MARK: - SyncActor (Memory-Isolated)

@ModelActor
actor SyncActor {
    // MARK: - Public Interface
    
    func performFullSync() async throws {
        print("[SyncActor] Starting full sync...")
        
        // Push local changes first
        try await pushLocalChanges()
        
        // Pull remote data
        try await pullRemoteData()
        
        print("[SyncActor] Sync complete")
    }
    
    // MARK: - Push Logic (Queue-Based)
    
    private func pushLocalChanges() async throws {
        print("[SyncActor] Processing offline queue...")
        
        // Fetch all pending queue items
        let queueDescriptor = FetchDescriptor<SyncQueueItem>(
            sortBy: [SortDescriptor(\.createdAt)]
        )
        
        let queueItems = try modelContext.fetch(queueDescriptor)
        
        guard !queueItems.isEmpty else {
            print("[SyncActor] No queued operations")
            return
        }
        
        print("[SyncActor] Processing \(queueItems.count) queued operations...")
        
        for item in queueItems {
            let success = await processQueueItem(item)
            
            if success {
                // Remove from queue
                modelContext.delete(item)
                try modelContext.save()
                print("[SyncActor] ✓ Completed: \(item.operationType)")
            } else {
                // Increment retry count
                item.retryCount += 1
                try modelContext.save()
                print("[SyncActor] ✗ Failed: \(item.operationType) (retry \(item.retryCount))")
            }
        }
    }
    
    nonisolated private func processQueueItem(_ item: SyncQueueItem) async -> Bool {
        return await withCheckedContinuation { continuation in
            // Convert Data back to dictionary for API call
            guard let jsonObject = try? JSONSerialization.jsonObject(with: item.jsonData),
                  let jsonDict = jsonObject as? [String: Any] else {
                continuation.resume(returning: false)
                return
            }
            
            struct GenericResponse: Codable {
                let success: Bool
            }
            
            // Make API call with raw JSON
            APIClient.shared.requestRaw(
                item.endpoint,
                method: item.method,
                body: jsonDict
            ) { (result: Result<GenericResponse, APIClient.APIError>) in
                switch result {
                case .success:
                    continuation.resume(returning: true)
                case .failure(let error):
                    print("[SyncActor] Queue item failed: \(error)")
                    continuation.resume(returning: false)
                }
            }
        }
    }
    
    private func fetchUnsyncedTransactionIDs() throws -> [PersistentIdentifier] {
        let descriptor = FetchDescriptor<SDTransaction>(
            predicate: #Predicate { $0.isSynced == false }
        )
        
        let transactions = try modelContext.fetch(descriptor)
        return transactions.map { $0.persistentModelID }
    }
    
    private func convertTransactionToDTO(id: PersistentIdentifier) throws -> TransactionDTO? {
        guard let tx = modelContext.model(for: id) as? SDTransaction else {
            return nil
        }
        
        // Fetch postings separately to avoid loading relationship
        let postingDescriptor = FetchDescriptor<SDPosting>(
            predicate: #Predicate<SDPosting> { posting in
                // Match postings by checking if they belong to this transaction
                // Since we can't directly query the relationship, we'll load them
                // This is still a problem - need to store transaction_id on posting
                true
            }
        )
        
        let allPostings = try modelContext.fetch(postingDescriptor)
        let txPostings = allPostings.filter { posting in
            // Filter postings that belong to this transaction
            tx.postings?.contains(where: { $0.id == posting.id }) ?? false
        }
        
        let postingDTOs = txPostings.map { p in
            PostingDTO(
                id: p.id,
                account_id: p.accountID,
                amount: p.amount,
                quantity: p.quantity ?? p.amount,
                unit_code: p.unitCode
            )
        }
        
        return TransactionDTO(
            id: tx.id,
            date: tx.date,
            description: tx.desc,
            note: tx.note,
            postings: postingDTOs
        )
    }
    
    nonisolated private func pushTransactionDTO(_ dto: TransactionDTO) async -> Bool {
        struct PushResponse: Codable {
            let success: Bool
        }
        
        return await withCheckedContinuation { continuation in
            APIClient.shared.request("/transactions", method: "POST", body: dto) { (result: Result<PushResponse, APIClient.APIError>) in
                switch result {
                case .success:
                    continuation.resume(returning: true)
                case .failure(let error):
                    print("[SyncActor] Push failed: \(error)")
                    continuation.resume(returning: false)
                }
            }
        }
    }
    
    private func markTransactionSynced(id: PersistentIdentifier) throws {
        guard let tx = modelContext.model(for: id) as? SDTransaction else {
            return
        }
        tx.isSynced = true
        try modelContext.save()
    }
    
    // MARK: - Pull Logic (Individual Endpoints)
    
    private func pullRemoteData() async throws {
        print("[SyncActor] Fetching remote data from individual endpoints...")
        
        // Fetch from individual endpoints
        let tags = try await fetchTags()
        let accounts = try await fetchAccounts()
        let units = try await fetchUnits()
        let transactions = try await fetchTransactions()
        
        print("[SyncActor] Deleting old local data...")
        // Batch delete all existing data
        try deleteAllLocalData()
        
        print("[SyncActor] Inserting fresh data...")
        // Insert fresh data
        try insertTags(tags)
        try insertAccounts(accounts)
        try insertUnits(units)
        try insertTransactions(transactions)
        
        print("[SyncActor] Pull complete")
    }
    
    // MARK: - Individual Fetch Methods
    
    nonisolated private func fetchTags() async throws -> [TagDTO] {
        struct TagListResponse: Codable {
            let success: Bool
            let data: [TagDTO]
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            APIClient.shared.request("/tags", method: "GET") { (result: Result<TagListResponse, APIClient.APIError>) in
                switch result {
                case .success(let response):
                    continuation.resume(returning: response.data)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    nonisolated private func fetchAccounts() async throws -> [AccountDTO] {
        struct AccountListResponse: Codable {
            let success: Bool
            let data: [AccountDTO]
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            APIClient.shared.request("/accounts", method: "GET") { (result: Result<AccountListResponse, APIClient.APIError>) in
                switch result {
                case .success(let response):
                    continuation.resume(returning: response.data)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    nonisolated private func fetchUnits() async throws -> [UnitDTO] {
        struct UnitListResponse: Codable {
            let success: Bool
            let data: [UnitDTO]
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            APIClient.shared.request("/units", method: "GET") { (result: Result<UnitListResponse, APIClient.APIError>) in
                switch result {
                case .success(let response):
                    continuation.resume(returning: response.data)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    nonisolated private func fetchTransactions() async throws -> [TransactionDTO] {
        struct TransactionListResponse: Codable {
            let success: Bool
            let data: TransactionDataWrapper
        }
        
        struct TransactionDataWrapper: Codable {
            let data: [TransactionDTO]
            let total: Int
        }
        
        var allTransactions: [TransactionDTO] = []
        var offset = 0
        let limit = 50 // Match backend default limit
        
        while true {
            let currentOffset = offset
            let endpoint = "/transactions?limit=\(limit)&offset=\(currentOffset)"
            print("[SyncActor] Fetching transactions offset \(currentOffset)...")
            
            let batch: [TransactionDTO] = try await withCheckedThrowingContinuation { continuation in
                APIClient.shared.request(endpoint, method: "GET") { (result: Result<TransactionListResponse, APIClient.APIError>) in
                    switch result {
                    case .success(let response):
                        continuation.resume(returning: response.data.data)
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
            }
            
            if batch.isEmpty {
                break
            }
            
            allTransactions.append(contentsOf: batch)
            
            if batch.count < limit {
                break // No more pages
            }
            
            offset += limit
        }
        
        print("[SyncActor] Fetched total \(allTransactions.count) transactions")
        return allTransactions
    }
    
    private func deleteAllLocalData() throws {
        // Use batch delete for maximum efficiency
        try modelContext.delete(model: SDPosting.self)
        try modelContext.delete(model: SDTransaction.self)
        try modelContext.delete(model: SDAccount.self)
        try modelContext.delete(model: SDTag.self)
        try modelContext.delete(model: SDUnit.self)
        try modelContext.save()
    }
    
    private func insertTags(_ tags: [TagDTO]) throws {
        print("[SyncActor] Inserting \(tags.count) tags...")
        for tag in tags {
            let sdTag = SDTag(
                id: tag.id.uuidString,
                name: tag.name,
                desc: tag.description,
                color: tag.color,
                isSynced: true
            )
            modelContext.insert(sdTag)
        }
        try modelContext.save()
    }
    
    private func insertAccounts(_ accounts: [AccountDTO]) throws {
        print("[SyncActor] Inserting \(accounts.count) accounts...")
        for account in accounts {
            let sdAccount = SDAccount(
                id: account.id,
                name: account.name,
                category: account.category,
                type: account.type,
                currency: account.currency ?? "INR",  // Default to INR if not provided
                icon: account.icon,
                parentID: account.parent_id
            )
            modelContext.insert(sdAccount)
        }
        try modelContext.save()
    }
    
    private func insertUnits(_ units: [UnitDTO]) throws {
       print("[SyncActor] Inserting \(units.count) units...")
        for unit in units {
            let sdUnit = SDUnit(
                code: unit.code,
                name: unit.name,
                symbol: unit.symbol,
                type: unit.type,
                isSynced: true
            )
            modelContext.insert(sdUnit)
        }
        try modelContext.save()
    }
    
    private func insertTransactions(_ transactions: [TransactionDTO]) throws {
        print("[SyncActor] Inserting \(transactions.count) transactions...")
        
        // Process in tiny batches with autoreleasepool
        let batchSize = 10
        var processed = 0
        
        for batch in transactions.chunked(into: batchSize) {
            autoreleasepool {
                for txDTO in batch {
                    let tx = SDTransaction(
                        id: txDTO.id,
                        date: txDTO.date,
                        desc: txDTO.description,
                        note: txDTO.note,
                        isSynced: true
                    )
                    modelContext.insert(tx)
                    
                    // Insert postings
                    var postings: [SDPosting] = []
                    for pDTO in txDTO.postings {
                        let posting = SDPosting(
                            id: pDTO.id,
                            accountID: pDTO.account_id,
                            amount: pDTO.amount,
                            quantity: pDTO.quantity,
                            unitCode: pDTO.unit_code,
                            tags: nil
                        )
                        modelContext.insert(posting)
                        postings.append(posting)
                    }
                    tx.postings = postings
                }
                
                processed += batch.count
                try? modelContext.save()
                print("[SyncActor] Saved batch: \(processed)/\(transactions.count)")
            }
        }
    }
}

// MARK: - Array Extension

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
