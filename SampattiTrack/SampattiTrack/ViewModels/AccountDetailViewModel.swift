import Foundation
import SwiftData
import Combine

/// Simple history point for account balance over time  
struct BalanceHistoryPoint: Identifiable {
    var id: String { date }
    let date: String
    let balance: Double
}

/// AccountDetailViewModel - OFFLINE-FIRST
/// Uses local SwiftData for account details. No API calls.
class AccountDetailViewModel: ObservableObject {
    @Published var balance: Double = 0
    @Published var historyData: [BalanceHistoryPoint] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    let accountID: String
    private var container: ModelContainer?
    
    init(accountID: String) {
        self.accountID = accountID
    }
    
    func setContainer(_ container: ModelContainer) {
        self.container = container
        fetchBalance()
    }
    
    /// Fetch balance from LOCAL transactions - no API call
    func fetchBalance() {
        guard let container = container else { return }
        
        Task.detached(priority: .userInitiated) {
            let context = ModelContext(container)
            context.autosaveEnabled = false
            
            // Calculate balance from local transactions
            let descriptor = FetchDescriptor<SDTransaction>()
            let transactions = (try? context.fetch(descriptor)) ?? []
            
            var total: Double = 0
            var history: [BalanceHistoryPoint] = []
            var runningBalance: Double = 0
            
            // Sort transactions by date
            let sortedTx = transactions.sorted { $0.date < $1.date }
            
            for tx in sortedTx {
                for posting in tx.postings ?? [] {
                    if posting.accountID == self.accountID {
                        let amount = Double(posting.amount) ?? 0
                        total += amount
                        runningBalance += amount
                    }
                }
                // Add history point for transactions involving this account
                let hasAccount = tx.postings?.contains { $0.accountID == self.accountID } ?? false
                if hasAccount {
                    history.append(BalanceHistoryPoint(date: tx.date, balance: runningBalance))
                }
            }
            
            await MainActor.run {
                self.balance = total
                self.historyData = Array(history.suffix(30))
                self.isLoading = false
            }
        }
    }
}
