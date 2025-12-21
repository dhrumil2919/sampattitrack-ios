import Foundation
import Combine

class AccountListViewModel: ObservableObject {
    @Published var accounts: [Account] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    func fetchAccounts() {
        isLoading = true
        errorMessage = nil
        
        APIClient.shared.request("/accounts") { (result: Result<AccountListResponse, APIClient.APIError>) in
            DispatchQueue.main.async {
                self.isLoading = false
                switch result {
                case .success(let response):
                    if response.success {
                        self.accounts = response.data
                    } else {
                        self.errorMessage = "Failed to load accounts"
                    }
                case .failure(let error):
                    self.errorMessage = "Error: \(error)"
                }
            }
        }
    }
}
