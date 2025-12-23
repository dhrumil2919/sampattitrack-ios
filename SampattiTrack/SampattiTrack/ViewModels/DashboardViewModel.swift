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

            await MainActor.run {
                self.summary = summaryData
                self.netWorthHistory = history
                self.topTags = tags
                self.monthlyTagSpending = spending
                self.recentTransactions = recent
                
                // XIRR removed - requires server calculation
                // TODO: Calculate XIRR locally from transaction history if needed
                self.topInvestments = []
            }
        }
    }
}
