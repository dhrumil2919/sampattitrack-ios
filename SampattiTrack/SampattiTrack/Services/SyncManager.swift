import Foundation
import SwiftData
import Combine

class SyncManager: ObservableObject {
    private let modelContext: ModelContext
    private let apiClient = APIClient.shared
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: - Sync Logic
    
    func syncAll() async {
        await pullTags()
        await pullAccounts()
        await pullTransactions()
        await pushTransactions()
    }
    
    // MARK: - Pull
    
    func pullTags() async {
        print("Pulling Tags...")
        return await withCheckedContinuation { continuation in
            apiClient.listTags { (result: Result<TagListResponse, APIClient.APIError>) in
                switch result {
                case .success(let response):
                    DispatchQueue.main.async {
                        self.updateLocalTags(response.data)
                        continuation.resume()
                    }
                case .failure(let error):
                    print("Error fetching tags: \(error)")
                    continuation.resume()
                }
            }
        }
    }

    func pullAccounts() async {
        print("Pulling Accounts...")
        return await withCheckedContinuation { continuation in
            apiClient.request("/accounts", method: "GET") { (result: Result<AccountListResponse, APIClient.APIError>) in
                switch result {
                case .success(let response):
                    DispatchQueue.main.async {
                        self.updateLocalAccounts(response.data)
                        continuation.resume()
                    }
                case .failure(let error):
                    print("Error fetching accounts: \(error)")
                    continuation.resume()
                }
            }
        }
    }
    
    func pullTransactions() async {
        print("Pulling Transactions...")
        
        // Remove limits to support full history for charts
        let pageSize = 100
        var offset = 0
        var hasMore = true
        var totalFetched = 0
        
        while hasMore {
            let transactions = await fetchTransactionPage(limit: pageSize, offset: offset)
            
            if transactions.isEmpty {
                hasMore = false
            } else {
                // Process this batch immediately to avoid memory buildup
                await MainActor.run {
                    self.updateLocalTransactions(transactions)
                }
                
                totalFetched += transactions.count
                offset += pageSize
                
                // Stop if we got fewer than requested (last page)
                if transactions.count < pageSize {
                    hasMore = false
                }
            }
        }
        
        print("Synced \(totalFetched) transactions")
    }
    
    private func fetchTransactionPage(limit: Int, offset: Int) async -> [Transaction] {
        return await withCheckedContinuation { continuation in
            let endpoint = "/transactions?limit=\(limit)&offset=\(offset)"
            apiClient.request(endpoint, method: "GET") { (result: Result<TransactionListResponse, APIClient.APIError>) in
                switch result {
                case .success(let response):
                    continuation.resume(returning: response.data.data)
                case .failure(let error):
                    print("Error fetching transactions page: \(error)")
                    continuation.resume(returning: [])
                }
            }
        }
    }
    
    // MARK: - Push
    
    func pushTransactions() async {
        print("Pushing Unsynced Transactions...")
        // Fetch unsynced transactions
        let descriptor = FetchDescriptor<SDTransaction>(predicate: #Predicate { $0.isSynced == false })
        do {
            let unsynced = try modelContext.fetch(descriptor)
            for transaction in unsynced {
                // Convert SDTransaction to API Request Body
                // For now, assuming API accepts similar JSON structure.
                // We'll need a helper to map SDTransaction -> DTO
                 await pushTransaction(transaction)
            }
        } catch {
            print("Error fetching unsynced transactions: \(error)")
        }
    }
    
    private func pushTransaction(_ transaction: SDTransaction) async {
        print("Pushing transaction: \(transaction.desc)")
        
        // Convert SDTransaction back to API body format
        // We need a struct that matches the API expectation for creating/updating a transaction
        // Assuming it matches the `Transaction` struct but for sending.
        // For simplicity, using a dictionary or ad-hoc struct here would be best if we don't have a separate DTO.
        // Let's assume we can map it to something Codable.
        
        let postingsData = (transaction.postings ?? []).map { posting in
            Posting(
                id: posting.id,
                accountID: posting.accountID,
                accountName: posting.accountName,
                amount: posting.amount,
                quantity: posting.quantity,
                unitCode: posting.unitCode,
                tags: nil
            )
        }
        
        // Note: API might expect a slightly different format for create vs update
        // or just a Transaction object.
        let body = Transaction(
            id: transaction.id,
            date: transaction.date,
            description: transaction.desc,
            note: transaction.note,
            postings: postingsData
        )
        
        return await withCheckedContinuation { continuation in
            // Determine if it's CREATE or UPDATE based on some logic?
            // Usually UUID collisions handle this, or we have a separate endpoint.
            // For now assuming POST /transactions handles upsert or we use PUT if exists.
            // Let's stick to POST /transactions for simplicity or PUT /transactions/{id}
            
            // NOTE: Real implementation needs to know if it's new or existing.
            // But since we are sync-ing, maybe we just try to save it.
            
            apiClient.request("/transactions", method: "POST", body: body) { (result: Result<Transaction, APIClient.APIError>) in
                switch result {
                case .success:
                     DispatchQueue.main.async {
                         transaction.isSynced = true
                         try? self.modelContext.save()
                         continuation.resume()
                     }
                case .failure(let error):
                    print("Failed to push transaction: \(error)")
                    continuation.resume()
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    private func updateLocalTags(_ tags: [Tag]) {
        for tag in tags {
            let id = tag.id
            let descriptor = FetchDescriptor<SDTag>(predicate: #Predicate { $0.id == id })

            if let existing = try? modelContext.fetch(descriptor).first {
                existing.name = tag.name
                existing.desc = tag.description
                existing.color = tag.color
                existing.isSynced = true
            } else {
                let newTag = SDTag(
                    id: tag.id,
                    name: tag.name,
                    desc: tag.description,
                    color: tag.color,
                    isSynced: true
                )
                modelContext.insert(newTag)
            }
        }
        try? modelContext.save()
    }

    private func updateLocalAccounts(_ accounts: [Account]) {
        for account in accounts {
            // Check if exists
            let id = account.id
            let descriptor = FetchDescriptor<SDAccount>(predicate: #Predicate { $0.id == id })
            
            if let existing = try? modelContext.fetch(descriptor).first {
                // Update
                existing.name = account.name
                existing.category = account.category
                existing.type = account.type
                existing.currency = account.currency
                existing.icon = account.icon
                existing.parentID = account.parentID
            } else {
                // Insert
                let newAccount = SDAccount(
                    id: account.id,
                    name: account.name,
                    category: account.category,
                    type: account.type,
                    currency: account.currency,
                    icon: account.icon,
                    parentID: account.parentID
                )
                modelContext.insert(newAccount)
            }
        }
        try? modelContext.save()
    }
    
    private func updateLocalTransactions(_ transactions: [Transaction]) {
        // Pre-fetch all tags to link efficiently
        // In a real optimized scenario, we'd only fetch needed tags, but assuming tag count is small (<100)
        let tagDescriptor = FetchDescriptor<SDTag>()
        let allTags = (try? modelContext.fetch(tagDescriptor)) ?? []
        let tagMap = Dictionary(uniqueKeysWithValues: allTags.map { ($0.id, $0) })

        for transaction in transactions {
             let id = transaction.id
             let descriptor = FetchDescriptor<SDTransaction>(predicate: #Predicate { $0.id == id })
            
            if let existing = try? modelContext.fetch(descriptor).first {
                // Update fields if needed. If server is authority, overwrite.
                existing.date = transaction.date
                existing.desc = transaction.description
                existing.note = transaction.note
                existing.isSynced = true // It came from server
                
                // Postings sync is complex because it's a relationship.
                // Simplest strategy: delete existing postings and recreate.
                if let oldPostings = existing.postings {
                    for p in oldPostings {
                        modelContext.delete(p)
                    }
                }
                
                existing.postings = transaction.postings.map { p in
                    let postingTags = p.tags?.compactMap { tagMap[$0.id] }

                    return SDPosting(
                        id: p.id,
                        accountID: p.accountID,
                        accountName: p.accountName,
                        amount: p.amount,
                        quantity: p.quantity,
                        unitCode: p.unitCode,
                        tags: postingTags
                    )
                }
                
            } else {
                let newTransaction = SDTransaction(
                    id: transaction.id,
                    date: transaction.date,
                    desc: transaction.description,
                    note: transaction.note,
                    isSynced: true
                )
                 newTransaction.postings = transaction.postings.map { p in
                    let postingTags = p.tags?.compactMap { tagMap[$0.id] }

                    return SDPosting(
                        id: p.id,
                        accountID: p.accountID,
                        accountName: p.accountName,
                        amount: p.amount,
                        quantity: p.quantity,
                        unitCode: p.unitCode,
                        tags: postingTags
                    )
                }
                modelContext.insert(newTransaction)
            }
        }
        try? modelContext.save()
    }
}
