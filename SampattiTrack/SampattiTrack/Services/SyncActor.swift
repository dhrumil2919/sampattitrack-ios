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

struct PriceDTO: Codable, Sendable {
    let commodity_id: String
    let commodity_name: String
    let type: String
    let last_date: String
    let last_price: String
    let one_day_change: String?
    let one_week_change: String?
    let one_month_change: String?
    let one_year_change: String?
    let ytd_change: String?
}

struct PortfolioItemDTO: Codable, Sendable {
    let account_id: String
    let account_name: String
    let type: String
    let category: String
    let currency: String
    let symbol: String?
    let quantity: String
    let invested_amount: String
    let current_value: String
    let absolute_return: String
    let xirr: Double
}

struct NetWorthHistoryDTO: Codable, Sendable {
    let date: String
    let net_worth: String
    let assets: String
    let liabilities: String
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
        let prices = try await fetchPrices()
        let portfolio = try await fetchPortfolioAnalysis()
        let netWorthHistory = try await fetchNetWorthHistory()
        
        // Fetch tax and capital gains data
        let taxAnalysis = try await fetchTaxAnalysis()
        let currentYear = Calendar.current.component(.year, from: Date())
        let capitalGains = try await fetchCapitalGains(year: currentYear)
        let cashFlow = try await fetchCashFlow()
        let portfolioAnalysis = try await fetchPortfolioAssets()
        
        print("[SyncActor] Upserting data (incremental sync)...")
        // Use upsert instead of delete-all to prevent data invalidation
        try upsertTags(tags)
        try upsertAccounts(accounts)
        try upsertUnits(units)
        try upsertPrices(prices)
        try upsertPortfolioXIRR(portfolio)
        try cacheNetWorthHistory(netWorthHistory)
        try upsertTransactions(transactions)
        
        // Cache tax and capital gains data
        try cacheTaxData(taxAnalysis)
        try cacheCapitalGains(capitalGains)
        try cacheCashFlow(cashFlow)
        try cachePortfolioAnalysis(portfolioAnalysis)
        
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
        try modelContext.delete(model: SDPrice.self)
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
    
    nonisolated private func fetchPrices() async throws -> [PriceDTO] {
        struct PriceListResponse: Codable {
            let success: Bool
            let data: [PriceDTO]
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            APIClient.shared.request("/prices/stats", method: "GET") { (result: Result<PriceListResponse, APIClient.APIError>) in
                switch result {
                case .success(let response):
                    continuation.resume(returning: response.data)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func upsertPrices(_ prices: [PriceDTO]) throws {
        print("[SyncActor] Upserting \(prices.count) prices...")
        
        for priceDTO in prices {
            // Check if price exists for this unit+date combination
            let fetchDesc = FetchDescriptor<SDPrice>(
                predicate: #Predicate { $0.unitCode == priceDTO.commodity_id && $0.date == priceDTO.last_date }
            )
            
            if let existing = try? modelContext.fetch(fetchDesc).first {
                // Update existing price
                existing.price = priceDTO.last_price
                existing.currency = "INR"  // Prices from stats are in INR
            } else {
                // Insert new price
                let newPrice = SDPrice(
                    unitCode: priceDTO.commodity_id,
                    date: priceDTO.last_date,
                    price: priceDTO.last_price,
                    currency: "INR",
                    source: "stats"
                )
                modelContext.insert(newPrice)
            }
        }
        try modelContext.save()
        print("[SyncActor] Upserted \(prices.count) prices")
    }
    
    nonisolated private func fetchPortfolioAnalysis() async throws -> [PortfolioItemDTO] {
        struct PortfolioResponse: Codable {
            let success: Bool
            let data: [PortfolioItemDTO]
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            APIClient.shared.request("/analysis/portfolio", method: "GET") { (result: Result<PortfolioResponse, APIClient.APIError>) in
                switch result {
                case .success(let response):
                    continuation.resume(returning: response.data)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func upsertPortfolioXIRR(_ portfolio: [PortfolioItemDTO]) throws {
        print("[SyncActor] Upserting portfolio metrics for \(portfolio.count) accounts...")
        
        for item in portfolio {
            print("[SyncActor]   - Account: \(item.account_name)")
            print("[SyncActor]     XIRR: \(item.xirr)")
            print("[SyncActor]     Invested: \(item.invested_amount)")
            print("[SyncActor]     Current: \(item.current_value)")
            print("[SyncActor]     Return: \(item.absolute_return)")
            
            // Update cached XIRR and metrics in SDAccount
            let fetchDesc = FetchDescriptor<SDAccount>(
                predicate: #Predicate { $0.id == item.account_id }
            )
            
            if let existing = try? modelContext.fetch(fetchDesc).first {
                existing.cachedXIRR = item.xirr
                existing.xirrCachedAt = Date()
                
                // Also cache portfolio metrics in metadata for dashboard display
                // Get existing metadata dictionary or create new one
                var metaDict = existing.metadataDictionary ?? [:]
                metaDict["invested_amount"] = item.invested_amount
                metaDict["current_value"] = item.current_value
                metaDict["absolute_return"] = item.absolute_return
                
                // Encode back to Data
                if let jsonData = try? JSONSerialization.data(withJSONObject: metaDict) {
                    existing.metadata = jsonData
                    print("[SyncActor]     ✓ Updated account \(existing.name)")
                } else {
                    print("[SyncActor]     ✗ Failed to encode metadata for \(existing.name)")
                }
            } else {
                print("[SyncActor]     ✗ Account not found: \(item.account_id)")
            }
        }
        try modelContext.save()
        print("[SyncActor] Upserted portfolio metrics for \(portfolio.count) accounts")
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
    
    // MARK: - Net Worth History
    
    nonisolated private func fetchNetWorthHistory() async throws -> [NetWorthHistoryDTO] {
        struct NetWorthResponse: Codable {
            let success: Bool
            let data: [NetWorthHistoryDTO]
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            APIClient.shared.request("/analysis/net-worth?interval=daily", method: "GET") { (result: Result<NetWorthResponse, APIClient.APIError>) in
                switch result {
                case .success(let response):
                    continuation.resume(returning: response.data)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func cacheNetWorthHistory(_ history: [NetWorthHistoryDTO]) throws {
        guard let latest = history.last else {
            print("[SyncActor] No net worth history to cache")
            return
        }
        
        print("[SyncActor] Caching latest net worth: \(latest.net_worth) from \(latest.date)")
        
        // Store the latest value in UserDefaults for dashboard
        UserDefaults.standard.set(latest.net_worth, forKey: "cached_net_worth")
        UserDefaults.standard.set(latest.assets, forKey: "cached_assets")
        UserDefaults.standard.set(latest.liabilities, forKey: "cached_liabilities")
        UserDefaults.standard.set(latest.date, forKey: "cached_net_worth_date")
    }
    
    // MARK: - Tax Analysis
    
    nonisolated private func fetchTaxAnalysis() async throws -> TaxAnalysis {
        return try await withCheckedThrowingContinuation { continuation in
            APIClient.shared.request("/analysis/tax", method: "GET") { (result: Result<TaxAnalysisResponse, APIClient.APIError>) in
                switch result {
                case .success(let response):
                    continuation.resume(returning: response.data)
                case .failure(let error):
                    print("[SyncActor] Failed to fetch tax analysis: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func cacheTaxData(_ data: TaxAnalysis) throws {
        print("[SyncActor] Caching tax analysis data...")
        
        // Encode and store in UserDefaults
        if let encoded = try? JSONEncoder().encode(data) {
            UserDefaults.standard.set(encoded, forKey: "cached_tax_analysis")
            print("[SyncActor] Cached tax analysis: Total Tax = \(data.totalTax), Rate = \(data.taxRate)%")
        }
    }
    
    // MARK: - Capital Gains
    
    nonisolated private func fetchCapitalGains(year: Int) async throws -> CapitalGainsReport {
        return try await withCheckedThrowingContinuation { continuation in
            APIClient.shared.request("/analysis/tax/gains?year=\(year)", method: "GET") { (result: Result<CapitalGainsResponse, APIClient.APIError>) in
                switch result {
                case .success(let response):
                    continuation.resume(returning: response.data)
                case .failure(let error):
                    print("[SyncActor] Failed to fetch capital gains: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func cacheCapitalGains(_ data: CapitalGainsReport) throws {
        print("[SyncActor] Caching capital gains data for year \(data.year)...")
        
        // Encode and store in UserDefaults
        if let encoded = try? JSONEncoder().encode(data) {
            UserDefaults.standard.set(encoded, forKey: "cached_capital_gains")
            print("[SyncActor] Cached capital gains: STCG = \(data.totalSTCG), LTCG = \(data.totalLTCG), Total Tax = \(data.totalTax)")
        }
    }
    
    // MARK: - Cash Flow
    
    nonisolated private func fetchCashFlow() async throws -> [CashFlowDataPoint] {
        return try await withCheckedThrowingContinuation { continuation in
            APIClient.shared.request("/analysis/cash-flow?interval=monthly", method: "GET") { (result: Result<CashFlowResponse, APIClient.APIError>) in
                switch result {
                case .success(let response):
                    continuation.resume(returning: response.data)
                case .failure(let error):
                    print("[SyncActor] Failed to fetch cash flow: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func cacheCashFlow(_ data: [CashFlowDataPoint]) throws {
        print("[SyncActor] Caching cash flow data (\(data.count) months)...")
        
        // Encode and store in UserDefaults
        if let encoded = try? JSONEncoder().encode(data) {
            UserDefaults.standard.set(encoded, forKey: "cached_cash_flow")
            print("[SyncActor] Cached \(data.count) cash flow data points")
        }
    }
    
    nonisolated private func fetchPortfolioAssets() async throws -> [AssetPerformance] {
        print("[SyncActor] Fetching portfolio analysis...")
        return try await withCheckedThrowingContinuation { continuation in
            APIClient.shared.request("/analysis/portfolio", method: "GET") { (result: Result<PortfolioAnalysisResponse, APIClient.APIError>) in
                switch result {
                case .success(let response):
                    print("[SyncActor] Fetched \(response.data.count) portfolio assets")
                    continuation.resume(returning: response.data)
                case .failure(let error):
                    print("[SyncActor] Failed to fetch portfolio assets: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    nonisolated private func cachePortfolioAnalysis(_ data: [AssetPerformance]) throws {
        // Encode and store in UserDefaults
        if let encoded = try? JSONEncoder().encode(data) {
            UserDefaults.standard.set(encoded, forKey: "cached_portfolio_analysis")
            print("[SyncActor] Cached \(data.count) portfolio assets")
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
