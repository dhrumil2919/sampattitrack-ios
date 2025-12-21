import Foundation
import Combine

class AccountDetailViewModel: ObservableObject {
    @Published var balance: String = "0.00"
    @Published var history: [AccountHistoryPoint] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let accountID: String
    
    init(accountID: String) {
        self.accountID = accountID
    }
    
    func fetchDetails() {
        isLoading = true
        errorMessage = nil
        
        let dispatchGroup = DispatchGroup()
        
        // Fetch Balance from API
        dispatchGroup.enter()
        APIClient.shared.request("/accounts/\(accountID)/balance") { (result: Result<BalanceResponse, APIClient.APIError>) in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    if response.success {
                        self.balance = response.data.balance
                    }
                case .failure(let error):
                    print("Error fetching balance: \(error)")
                }
                dispatchGroup.leave()
            }
        }
        
        // Fetch History from API
        dispatchGroup.enter()
        APIClient.shared.request("/accounts/\(accountID)/history?interval=daily") { (result: Result<HistoryResponse, APIClient.APIError>) in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                     if response.success {
                         self.history = response.data
                     }
                case .failure(let error):
                     print("Error fetching history: \(error)")
                }
                dispatchGroup.leave()
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            self.isLoading = false
        }
    }
}

struct BalanceResponse: Codable {
    let success: Bool
    let data: BalanceData
}

struct BalanceData: Codable {
    let balance: String
    let currency: String?
}

struct HistoryResponse: Codable {
    let success: Bool
    let data: [AccountHistoryPoint]
}

struct AccountHistoryPoint: Codable, Identifiable {
    let date: String
    let balance: String
    
    var id: String { date }
}
