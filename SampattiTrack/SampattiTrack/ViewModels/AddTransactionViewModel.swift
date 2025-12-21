import Foundation
import Combine

class AddTransactionViewModel: ObservableObject {
    @Published var description: String = ""
    @Published var note: String = ""
    @Published var date: Date = Date()
    @Published var postings: [EditablePosting] = [
        EditablePosting(accountID: "", amount: "", quantity: ""),
        EditablePosting(accountID: "", amount: "", quantity: "")
    ]
    
    @Published var accounts: [Account] = []
    @Published var units: [FinancialUnit] = []
    @Published var availableTags: [Tag] = []
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    
    struct EditablePosting: Identifiable {
        let id = UUID()
        var accountID: String
        var amount: String
        var quantity: String
        var unitCode: String = "INR"
        var price: String = "1"
        var tags: [String] = []
    }
    
    var totalAmount: Double {
        postings.reduce(0.0) { $0 + (Double($1.amount) ?? 0) }
    }
    
    var isBalanced: Bool {
        abs(totalAmount) < 0.01
    }
    
    func fetchAccounts() {
        isLoading = true
        
        // Fetch accounts
        APIClient.shared.request("/accounts") { (result: Result<AccountListResponse, APIClient.APIError>) in
            DispatchQueue.main.async {
                self.isLoading = false
                switch result {
                case .success(let response):
                    if response.success {
                        self.accounts = response.data
                    }
                case .failure(let error):
                    self.errorMessage = "Failed to load accounts: \(error)"
                }
            }
        }
        
        // Fetch units
        APIClient.shared.listUnits { (result: Result<UnitListResponse, APIClient.APIError>) in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    if response.success {
                        self.units = response.data
                    }
                case .failure:
                    // Don't show error for units, just use defaults
                    break
                }
            }
        }
        
        // Fetch available tags
        APIClient.shared.listTags { (result: Result<TagListResponse, APIClient.APIError>) in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    if response.success {
                        self.availableTags = response.data
                    }
                case .failure:
                    break
                }
            }
        }
    }
    
    func addPosting() {
        postings.append(EditablePosting(accountID: "", amount: "", quantity: ""))
    }
    
    func removePosting(at index: Int) {
        guard postings.count > 2 else { return }
        postings.remove(at: index)
    }
    
    func fetchPriceForPosting(at index: Int, date: String) {
        let unitCode = postings[index].unitCode
        guard unitCode != "INR" else {
            // For INR, price = 1
            postings[index].price = "1"
            recalculateAmount(at: index)
            return
        }
        
        APIClient.shared.lookupPrice(unitCode: unitCode, date: date) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    if response.success {
                        self.postings[index].price = response.data.price
                        self.recalculateAmount(at: index)
                    }
                case .failure(let error):
                    self.errorMessage = "Price lookup failed: \(error)"
                }
            }
        }
    }
    
    func recalculateAmount(at index: Int) {
        let qty = Double(postings[index].quantity) ?? 0
        let price = Double(postings[index].price) ?? 0
        postings[index].amount = String(qty * price)
    }
    
    func createTransaction() {
        guard isBalanced else {
            errorMessage = "Transaction does not balance. Imbalance: \(CurrencyFormatter.formatCheck(abs(totalAmount)))"
            return
        }
        
        guard postings.allSatisfy({ !$0.accountID.isEmpty }) else {
            errorMessage = "Please select an account for each posting"
            return
        }
        
        isSaving = true
        errorMessage = nil
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: date)
        
        let postingRequests = postings.map { p in
            CreatePosting(
                accountID: p.accountID,
                amount: p.amount,
                quantity: p.quantity.isEmpty ? p.amount : p.quantity,
                unitCode: p.unitCode,
                tags: p.tags.isEmpty ? nil : p.tags
            )
        }
        
        let request = CreateTransactionRequest(
            date: dateString,
            description: description,
            note: note,
            postings: postingRequests
        )

        APIClient.shared.request("/transactions", method: "POST", body: request) { (result: Result<TransactionResponse, APIClient.APIError>) in
            DispatchQueue.main.async {
                self.isSaving = false
                switch result {
                case .success(let response):
                    if response.success {
                        self.successMessage = "Transaction Created!"
                    } else {
                        self.errorMessage = "Failed to create transaction"
                    }
                case .failure(let error):
                    self.errorMessage = "Error: \(error)"
                }
            }
        }
    }
}

struct CreateTransactionRequest: Codable {
    let date: String
    let description: String
    let note: String
    let postings: [CreatePosting]
}

struct CreatePosting: Codable {
    let accountID: String
    let amount: String
    let quantity: String
    let unitCode: String?
    let tags: [String]?
    
    enum CodingKeys: String, CodingKey {
        case accountID = "account_id"
        case amount
        case quantity
        case unitCode = "unit_code"
        case tags
    }
}

struct TransactionResponse: Codable {
    let success: Bool
}
