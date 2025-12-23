import Foundation
import Combine
import SwiftData

struct InvestmentXIRR: Identifiable {
    let id: String
    let accountName: String
    let xirr: Double
}

/// DashboardViewModel - OFFLINE-FIRST
/// All data is loaded from local SwiftData. No API calls.
class DashboardViewModel: ObservableObject {
    @Published var summary: ClientDashboardData?
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

    private var container: ModelContainer?

    func setContainer(_ container: ModelContainer) {
        self.container = container
        calculateClientSideData()
    }

    /// Called to refresh dashboard - uses only local data
    func fetchAll() {
        isLoading = true
        errorMessage = nil
        calculateClientSideData()
        isLoading = false
    }

    private func calculateClientSideData() {
        guard let container = container else { return }
        
        Task.detached(priority: .userInitiated) {
            let context = ModelContext(container)
            context.autosaveEnabled = false

            let calculator = DashboardCalculator(modelContext: context)

            let summaryData = calculator.calculateSummary(range: self.selectedRange)
            let history = calculator.calculateNetWorthHistory(range: self.selectedRange)
            let tags = calculator.calculateTagBreakdown(range: self.selectedRange)
            let spending = calculator.calculateMonthlySpending(range: self.selectedRange)
            let recent = calculator.fetchRecentTransactions(limit: 5)

            // Fetch investment accounts with cached XIRR
            let accountsDescriptor = FetchDescriptor<SDAccount>()
            let allAccounts = (try? context.fetch(accountsDescriptor)) ?? []
            
            let investments = allAccounts
                .filter { $0.type == "Investment" }
                .compactMap { account -> InvestmentXIRR? in
                    // Calculate balance from transactions
                    let transactionsDesc = FetchDescriptor<SDTransaction>()
                    let transactions = (try? context.fetch(transactionsDesc)) ?? []
                    
                    var balance: Double = 0
                    for tx in transactions {
                        for posting in tx.postings ?? [] {
                            if posting.accountID == account.id {
                                balance += Double(posting.amount) ?? 0
                            }
                        }
                    }
                    
                    // Only include if has XIRR or substantial balance
                    if let xirr = account.cachedXIRR {
                        return InvestmentXIRR(
                            id: account.id,
                            accountName: account.name,
                            xirr: xirr
                        )
                    } else if balance > 100 {
                        // Include even without XIRR if balance is significant
                        return InvestmentXIRR(
                            id: account.id,
                            accountName: account.name,
                            xirr: 0 // Placeholder
                        )
                    }
                    return nil
                }
                .sorted { ($0.xirr != 0 ? abs($0.xirr) : -1) > ($1.xirr != 0 ? abs($1.xirr) : -1) }
                .prefix(5)

            await MainActor.run {
                self.summary = summaryData
                self.netWorthHistory = history
                self.topTags = tags
                self.monthlyTagSpending = spending
                self.recentTransactions = recent
                
                // Set investment accounts with XIRR
                self.topInvestments = Array(investments)
            }
        }
    }
}
