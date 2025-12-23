import Foundation
import SwiftData
import Combine

/// TransactionListViewModel - OFFLINE-FIRST
/// Uses local SwiftData. This ViewModel is now DEPRECATED - TransactionListView uses @Query directly.
/// Keeping for backwards compatibility but all methods are no-ops.
class TransactionListViewModel: ObservableObject {
    @Published var transactions: [Transaction] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    /// DEPRECATED: TransactionListView now uses @Query on SDTransaction
    func fetchTransactions(accountID: String? = nil) {
        // No-op - data comes from SwiftData @Query
        isLoading = false
    }
}
