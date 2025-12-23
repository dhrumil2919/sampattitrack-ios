import Foundation
import SwiftData
import Combine

/// AccountListViewModel - OFFLINE-FIRST
/// Uses local SwiftData. This ViewModel is now DEPRECATED - AccountListView uses @Query directly.
/// Keeping for backwards compatibility but all methods are no-ops.
class AccountListViewModel: ObservableObject {
    @Published var accounts: [Account] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    /// DEPRECATED: AccountListView now uses @Query on SDAccount
    func fetchAccounts() {
        // No-op - data comes from SwiftData @Query
        isLoading = false
    }
}
