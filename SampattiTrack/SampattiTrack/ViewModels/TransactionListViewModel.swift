import Foundation
import Combine

class TransactionListViewModel: ObservableObject {
    @Published var transactions: [Transaction] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // Support filtering by account
    let accountID: String?
    
    init(accountID: String? = nil) {
        self.accountID = accountID
    }
    
    func fetchTransactions() {
        isLoading = true
        errorMessage = nil
        
        var endpoint = "/transactions?limit=50&offset=0"
        if let accID = accountID {
            endpoint += "&account_id=\(accID)"
        }
        
        APIClient.shared.request(endpoint) { (result: Result<TransactionListResponse, APIClient.APIError>) in
            DispatchQueue.main.async {
                self.isLoading = false
                switch result {
                case .success(let response):
                    if response.success {
                        self.transactions = response.data.data
                    } else {
                        self.errorMessage = "Failed to load transactions"
                    }
                case .failure(let error):
                    self.errorMessage = "Error: \(error)"
                }
            }
        }
    }
}
