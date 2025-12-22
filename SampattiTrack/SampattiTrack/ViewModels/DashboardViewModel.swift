import Foundation
import Combine
import SwiftData

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
    @Published var summary: ClientDashboardData?
    @Published var accounts: [Account] = []
    @Published var recentTransactions: [Transaction] = []
    @Published var topInvestments: [InvestmentXIRR] = []
    @Published var netWorthHistory: [NetWorthDataPoint] = []
    @Published var monthlyTagSpending: [(month: String, tags: [(tag: String, amount: Double)])] = []
    @Published var topTags: [TopTag] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    @Published var selectedRange: DateRange = .lastMonth() {
        didSet {
            calculateClientSideData()
        }
    }

    // Use ModelContainer to create background context safely
    private var container: ModelContainer?

    func setContainer(_ container: ModelContainer) {
        self.container = container
        // Initial calculation
        calculateClientSideData()
    }

    func fetchAll() {
        isLoading = true
        errorMessage = nil
        
        calculateClientSideData()
        
        // Fetch accounts for XIRR
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
        
        // Fetch recent transactions (API)
        // We do this via API for now, but also have local fallback in calculateClientSideData
        // Actually, let's move recent transactions to local calc to ensure offline support.
        // API call removed.
        
        self.isLoading = false
    }

    private func calculateClientSideData() {
        guard let container = container else { return }
        
        Task.detached(priority: .userInitiated) {
            // Create a new context on this background thread
            let context = ModelContext(container)
            // Disable autosave for read-only operations to improve performance
            context.autosaveEnabled = false

            let calculator = DashboardCalculator(modelContext: context)

            let summaryData = calculator.calculateSummary(range: self.selectedRange)
            let history = calculator.calculateNetWorthHistory(range: self.selectedRange)
            let tags = calculator.calculateTagBreakdown(range: self.selectedRange)
            let spending = calculator.calculateMonthlySpending(range: self.selectedRange)
            let recent = calculator.fetchRecentTransactions(limit: 5)

            await MainActor.run {
                self.summary = summaryData
                self.netWorthHistory = history
                self.topTags = tags
                self.monthlyTagSpending = spending
                self.recentTransactions = recent
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
            self.topInvestments = results.sorted { $0.xirr > $1.xirr }.prefix(3).map { $0 }
        }
    }
}
