import Foundation
import SwiftData

@MainActor
class DataRepository {
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: - Transactions
    
    func saveTransaction(id: UUID = UUID(), date: String, desc: String, note: String?, postings: [SDPosting]) {
        let transaction = SDTransaction(id: id, date: date, desc: desc, note: note)
        transaction.postings = postings
        transaction.isSynced = false
        modelContext.insert(transaction)
    }
    
    func fetchTransactions() throws -> [SDTransaction] {
        let descriptor = FetchDescriptor<SDTransaction>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        return try modelContext.fetch(descriptor)
    }
    
    // MARK: - Accounts
    
    func saveAccount(_ account: SDAccount) {
        modelContext.insert(account)
    }
    
    func fetchAccounts() throws -> [SDAccount] {
        let descriptor = FetchDescriptor<SDAccount>(sortBy: [SortDescriptor(\.name)])
        return try modelContext.fetch(descriptor)
    }
    
    // MARK: - General
    
    func saveContext() throws {
        try modelContext.save()
    }
}
