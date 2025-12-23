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
    let tags: [TagDTO]?
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
    let metadata: [String: GenericJSON]? // Capture unique metadata
}

// MARK: - Helper for AnyCodable
enum GenericJSON: Codable, Sendable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case null
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let x = try? container.decode(String.self) { self = .string(x); return }
        if let x = try? container.decode(Double.self) { self = .number(x); return }
        if let x = try? container.decode(Bool.self) { self = .bool(x); return }
        if container.decodeNil() { self = .null; return }
        throw DecodingError.typeMismatch(GenericJSON.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Wrong type for GenericJSON"))
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let x): try container.encode(x)
        case .number(let x): try container.encode(x)
        case .bool(let x): try container.encode(x)
        case .null: try container.encodeNil()
        }
    }
    
    var anyValue: Any? {
        switch self {
        case .string(let s): return s
        case .number(let n): return n
        case .bool(let b): return b
        case .null: return nil
        }
    }
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
                unit_code: p.unitCode,
                tags: nil  // Tags are not sent when creating transactions from offline queue
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
        
        print("[SyncActor] Upserting data (incremental sync)...")
        // Use upsert instead of delete-all to prevent data invalidation
        try upsertTags(tags)
        try upsertAccounts(accounts)
        try upsertUnits(units)
        try upsertTransactions(transactions)
        
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
    
    /// DEPRECATED: Only for initial sync or reset. Use upsert methods for regular sync.
    private func deleteAllLocalData() throws {
        // Use batch delete for maximum efficiency
        try modelContext.delete(model: SDPosting.self)
        try modelContext.delete(model: SDTransaction.self)
        try modelContext.delete(model: SDAccount.self)
        try modelContext.delete(model: SDTag.self)
        try modelContext.delete(model: SDUnit.self)
        try modelContext.save()
    }
    
    // MARK: - Upsert Methods (Incremental Sync)
    
    private func upsertTags(_ tags: [TagDTO]) throws {
        print("[SyncActor] Upserting \(tags.count) tags...")
        
        for tagDTO in tags {
            let tagID = tagDTO.id.uuidString
            let fetchDesc = FetchDescriptor<SDTag>(
                predicate: #Predicate { $0.id == tagID }
            )
            
            if let existing = try? modelContext.fetch(fetchDesc).first {
                // Update existing
                existing.name = tagDTO.name
                existing.desc = tagDTO.description
                existing.color = tagDTO.color
                existing.isSynced = true
            } else {
                // Insert new
                let newTag = SDTag(
                    id: tagID,
                    name: tagDTO.name,
                    desc: tagDTO.description,
                    color: tagDTO.color,
                    isSynced: true
                )
                modelContext.insert(newTag)
            }
        }
        try modelContext.save()
        print("[SyncActor] Upserted \(tags.count) tags")
    }
    
    private func upsertAccounts(_ accounts: [AccountDTO]) throws {
        print("[SyncActor] Upserting \(accounts.count) accounts...")
        
        for accountDTO in accounts {
            // Convert GenericJSON metadata to Data
            var metadataData: Data? = nil
            if let meta = accountDTO.metadata {
                let dict = meta.mapValues { $0.anyValue }
                let validDict = dict.compactMapValues { $0 }
                if !validDict.isEmpty {
                    metadataData = try? JSONSerialization.data(withJSONObject: validDict, options: [])
                }
            }
            
            let fetchDesc = FetchDescriptor<SDAccount>(
                predicate: #Predicate { $0.id == accountDTO.id }
            )
            
            if let existing = try? modelContext.fetch(fetchDesc).first {
                // Update existing
                existing.name = accountDTO.name
                existing.category = accountDTO.category
                existing.type = accountDTO.type
                existing.currency = accountDTO.currency ?? "INR"
                existing.icon = accountDTO.icon
                existing.parentID = accountDTO.parent_id
                existing.metadata = metadataData
            } else {
                // Insert new
                let newAccount = SDAccount(
                    id: accountDTO.id,
                    name: accountDTO.name,
                    category: accountDTO.category,
                    type: accountDTO.type,
                    currency: accountDTO.currency ?? "INR",
                    icon: accountDTO.icon,
                    parentID: accountDTO.parent_id,
                    metadata: metadataData
                )
                modelContext.insert(newAccount)
            }
        }
        try modelContext.save()
        print("[SyncActor] Upserted \(accounts.count) accounts")
    }
    
    private func upsertUnits(_ units: [UnitDTO]) throws {
        print("[SyncActor] Upserting \(units.count) units...")
        
        for unitDTO in units {
            let fetchDesc = FetchDescriptor<SDUnit>(
                predicate: #Predicate { $0.code == unitDTO.code }
            )
            
            if let existing = try? modelContext.fetch(fetchDesc).first {
                // Update existing
                existing.name = unitDTO.name
                existing.symbol = unitDTO.symbol
                existing.type = unitDTO.type
                existing.isSynced = true
            } else {
                // Insert new
                let newUnit = SDUnit(
                    code: unitDTO.code,
                    name: unitDTO.name,
                    symbol: unitDTO.symbol,
                    type: unitDTO.type,
                    isSynced: true
                )
                modelContext.insert(newUnit)
            }
        }
        try modelContext.save()
        print("[SyncActor] Upserted \(units.count) units")
    }
    
    private func upsertTransactions(_ transactions: [TransactionDTO]) throws {
        print("[SyncActor] Upserting \(transactions.count) transactions...")
        
        // Process in tiny batches with autoreleasepool
        let batchSize = 10
        var processed = 0
        var inserted = 0
        var skipped = 0
        
        for batch in transactions.chunked(into: batchSize) {
            autoreleasepool {
                // Fetch ALL tags fresh for this batch to avoid stale references
                let allTagsDesc = FetchDescriptor<SDTag>()
                let allTags = (try? modelContext.fetch(allTagsDesc)) ?? []
                let tagsByID = Dictionary(uniqueKeysWithValues: allTags.map { ($0.id, $0) })
                
                for txDTO in batch {
                    // Check if transaction already exists (transactions are immutable)
                    let txFetchDesc = FetchDescriptor<SDTransaction>(
                        predicate: #Predicate { $0.id == txDTO.id }
                    )
                    
                    if let existingTx = try? modelContext.fetch(txFetchDesc).first {
                        // Transaction exists - skip (transactions are immutable in ledger)
                        // Mark as synced if it wasn't
                        if !existingTx.isSynced {
                            existingTx.isSynced = true
                        }
                        skipped += 1
                        continue
                    }
                    
                    // Insert new transaction
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
                        // Link tags if present - use fresh tag instances from batch dictionary
                        var linkedTags: [SDTag]? = nil
                        if let tagDTOs = pDTO.tags, !tagDTOs.isEmpty {
                            linkedTags = []
                            for tagDTO in tagDTOs {
                                let tagID = tagDTO.id.uuidString
                                // Use pre-fetched tag from dictionary
                                if let existingTag = tagsByID[tagID] {
                                    linkedTags?.append(existingTag)
                                } else {
                                    // Fallback: create if not found (shouldn't happen if tags were synced first)
                                    print("[SyncActor] WARNING: Tag \(tagID) not found in context, creating new one")
                                    let newTag = SDTag(
                                        id: tagID,
                                        name: tagDTO.name,
                                        desc: tagDTO.description,
                                        color: tagDTO.color,
                                        isSynced: true
                                    )
                                    modelContext.insert(newTag)
                                    linkedTags?.append(newTag)
                                }
                            }
                        }

                        let posting = SDPosting(
                            id: pDTO.id,
                            accountID: pDTO.account_id,
                            amount: pDTO.amount,
                            quantity: pDTO.quantity,
                            unitCode: pDTO.unit_code,
                            tags: linkedTags
                        )
                        posting.transaction = tx // Set relationship
                        modelContext.insert(posting)
                        postings.append(posting)
                    }
                    tx.postings = postings
                    inserted += 1
                }
                
                processed += batch.count
                try? modelContext.save()
                print("[SyncActor] Batch \(processed)/\(transactions.count): +\(inserted-skipped) new, ~\(skipped) existing")
            }
        }
        print("[SyncActor] Upserted transactions: \(inserted) inserted, \(skipped) skipped (already exist)")
    }
    
    /// DEPRECATED: Replaced by upsertTransactions
    private func insertTransactions(_ transactions: [TransactionDTO]) throws {
        print("[SyncActor] Inserting \(transactions.count) transactions...")
        
        // Process in tiny batches with autoreleasepool
        let batchSize = 10
        var processed = 0
        
        for batch in transactions.chunked(into: batchSize) {
            autoreleasepool {
                // Fetch ALL tags fresh for this batch to avoid stale references
                let allTagsDesc = FetchDescriptor<SDTag>()
                let allTags = (try? modelContext.fetch(allTagsDesc)) ?? []
                let tagsByID = Dictionary(uniqueKeysWithValues: allTags.map { ($0.id, $0) })
                
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
                        // Link tags if present - use fresh tag instances from batch dictionary
                        var linkedTags: [SDTag]? = nil
                        if let tagDTOs = pDTO.tags, !tagDTOs.isEmpty {
                            linkedTags = []
                            for tagDTO in tagDTOs {
                                let tagID = tagDTO.id.uuidString
                                // Use pre-fetched tag from dictionary
                                if let existingTag = tagsByID[tagID] {
                                    linkedTags?.append(existingTag)
                                } else {
                                    // Fallback: create if not found (shouldn't happen if tags were synced first)
                                    print("[SyncActor] WARNING: Tag \(tagID) not found in context, creating new one")
                                    let newTag = SDTag(
                                        id: tagID,
                                        name: tagDTO.name,
                                        desc: tagDTO.description,
                                        color: tagDTO.color,
                                        isSynced: true
                                    )
                                    modelContext.insert(newTag)
                                    linkedTags?.append(newTag)
                                }
                            }
                        }

                        let posting = SDPosting(
                            id: pDTO.id,
                            accountID: pDTO.account_id,
                            amount: pDTO.amount,
                            quantity: pDTO.quantity,
                            unitCode: pDTO.unit_code,
                            tags: linkedTags
                        )
                        posting.transaction = tx // Set relationship
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
    
    // MARK: - XIRR Fetching
    
    private func fetchAndCacheXIRR(for accounts: [AccountDTO]) async throws {
        print("[SyncActor] Fetching XIRR for investment accounts...")
        
        let investmentAccounts = accounts.filter { $0.type == "Investment" }
        
        guard !investmentAccounts.isEmpty else {
            print("[SyncActor] No investment accounts found")
            return
        }
        
        print("[SyncActor] Found \(investmentAccounts.count) investment accounts")
        
        for account in investmentAccounts {
            // Fetch XIRR from API
            if let xirr = try? await fetchXIRRForAccount(accountId: account.id) {
                // Update cached XIRR in SDAccount
                let accountDescriptor = FetchDescriptor<SDAccount>(
                    predicate: #Predicate { $0.id == account.id }
                )
                
                if let sdAccount = try? modelContext.fetch(accountDescriptor).first {
                    sdAccount.cachedXIRR = xirr
                    sdAccount.xirrCachedAt = Date()
                    try? modelContext.save()
                    print("[SyncActor] ✓ Cached XIRR for \(account.name): \(String(format: "%.2f%%", xirr))")
                }
            }
        }
    }
    
    nonisolated private func fetchXIRRForAccount(accountId: String) async throws -> Double {
        struct XIRRResponse: Codable {
            let success: Bool
            let data: XIRRData
        }
        
        struct XIRRData: Codable {
            let account_id: String
            let xirr: Double
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let endpoint = "/analysis/xirr?account_id=\(accountId)"
            APIClient.shared.request(endpoint, method: "GET") { (result: Result<XIRRResponse, APIClient.APIError>) in
                switch result {
                case .success(let response):
                    continuation.resume(returning: response.data.xirr)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
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
