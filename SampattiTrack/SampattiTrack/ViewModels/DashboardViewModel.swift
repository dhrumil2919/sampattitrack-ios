import Foundation
import Combine

struct XIRRResponse: Codable {
    let success: Bool
    let data: XIRRData
}

struct XIRRData: Codable {
    let xirr: Double
}

struct InvestmentXIRR: Identifiable {
    let id: String
    let account: Account
    let xirr: Double
}

class DashboardViewModel: ObservableObject {
    @Published var summary: DashboardData?
    @Published var accounts: [Account] = []
    @Published var recentTransactions: [Transaction] = []
    @Published var topInvestments: [InvestmentXIRR] = []
    @Published var netWorthHistory: [NetWorthDataPoint] = []
    @Published var dailyExpenses: [(day: String, amount: Double)] = []
    @Published var topTags: [TopTag] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    func fetchAll() {
        isLoading = true
        errorMessage = nil
        
        // Fetch summary
        APIClient.shared.request("/dashboard/summary") { (result: Result<DashboardSummaryResponse, APIClient.APIError>) in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    if response.success {
                        self.summary = response.data
                    }
                case .failure(let error):
                    self.errorMessage = "Error: \(error)"
                }
            }
        }
        
        // Fetch accounts
        APIClient.shared.request("/accounts") { (result: Result<AccountListResponse, APIClient.APIError>) in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    if response.success {
                        self.accounts = response.data
                        self.fetchXIRRForInvestments()
                    }
                case .failure:
                    break
                }
            }
        }
        
        // Fetch recent transactions (for display)
        APIClient.shared.request("/transactions?limit=5") { (result: Result<TransactionListResponse, APIClient.APIError>) in
            DispatchQueue.main.async {
                self.isLoading = false
                switch result {
                case .success(let response):
                    if response.success {
                        self.recentTransactions = response.data.data
                    }
                case .failure:
                    break
                }
            }
        }
        
        // Fetch more transactions for daily expense calculation
        APIClient.shared.request("/transactions?limit=100") { (result: Result<TransactionListResponse, APIClient.APIError>) in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    if response.success {
                        self.calculateDailyExpenses(from: response.data.data)
                    }
                case .failure:
                    break
                }
            }
        }
        
        // Fetch net worth history
        APIClient.shared.request("/analysis/net-worth?interval=monthly") { (result: Result<NetWorthHistoryResponse, APIClient.APIError>) in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    if response.success {
                        self.netWorthHistory = response.data.sorted(by: { $0.date < $1.date })
                    }
                case .failure:
                    break
                }
            }
        }
        
        // Fetch top tags
        APIClient.shared.fetchTopTags { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    if response.success {
                        self.topTags = response.data
                    }
                case .failure:
                    break
                }
            }
        }

    }
    
    private func fetchXIRRForInvestments() {
        let investmentTypes = ["Stock", "MutualFund", "Metal", "NPS"]
        let investments = accounts.filter { investmentTypes.contains($0.type) }
        
        guard !investments.isEmpty else { return }
        
        var results: [InvestmentXIRR] = []
        let group = DispatchGroup()
        
        for account in investments {
            group.enter()
            APIClient.shared.request("/analysis/xirr?account_id=\(account.id)") { (result: Result<XIRRResponse, APIClient.APIError>) in
                defer { group.leave() }
                switch result {
                case .success(let response):
                    if response.success {
                        DispatchQueue.main.async {
                            results.append(InvestmentXIRR(id: account.id, account: account, xirr: response.data.xirr))
                        }
                    }
                case .failure:
                    break
                }
            }
        }
        
        group.notify(queue: .main) {
            // Sort by XIRR descending and take top 3
            self.topInvestments = results.sorted { $0.xirr > $1.xirr }.prefix(3).map { $0 }
        }
    }
    
    // Legacy method for compatibility
    func fetchSummary() {
        fetchAll()
    }
    
    func calculateDailyExpenses(from transactions: [Transaction]) {
        // Calculate daily expenses for current month from transactions
        let calendar = Calendar.current
        let now = Date()
        
        guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) else {
            return
        }
        
        // Group transactions by day
        var dailyExpenseMap: [Int: Double] = [:]
        
        for transaction in transactions {
            // Parse transaction date
            let formatter = ISO8601DateFormatter()
            guard let txDate = formatter.date(from: transaction.date),
                  txDate >= monthStart else {
                continue
            }
            
            let day = calendar.component(.day, from: txDate)
            
            // Sum up expense postings (negative amounts from expense accounts)
            for posting in transaction.postings {
                if let account = accounts.first(where: { $0.id == posting.accountID }),
                   account.category == "Expense" {
                    let amount = abs(Double(posting.amount) ?? 0)
                    dailyExpenseMap[day, default: 0] += amount
                }
            }
        }
        
        // Convert to array and sort by day
        var expenses: [(day: String, amount: Double)] = []
        for day in 1...31 {
            if let amount = dailyExpenseMap[day] {
                expenses.append((day: String(day), amount: amount))
            }
        }
        
        self.dailyExpenses = expenses.sorted { Int($0.day) ?? 0 < Int($1.day) ?? 0 }
    }
}
