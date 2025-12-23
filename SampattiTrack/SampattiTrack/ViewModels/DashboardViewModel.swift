import Foundation
import Combine
import SwiftData

struct AggregatePortfolioMetrics {
    var totalInvested: Double = 0
    var totalCurrentValue: Double = 0
    var totalAbsoluteReturn: Double = 0
    var weightedXIRR: Double = 0
    
    var returnPercentage: Double {
        guard totalInvested > 0 else { return 0 }
        return (totalAbsoluteReturn / totalInvested) * 100
    }
}

/// DashboardViewModel - OFFLINE-FIRST
/// All data is loaded from local SwiftData. No API calls.
class DashboardViewModel: ObservableObject {
    @Published var summary: ClientDashboardData?
    @Published var recentTransactions: [Transaction] = []
    @Published var portfolioMetrics: AggregatePortfolioMetrics?
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

            // Calculate aggregate portfolio metrics from all investment accounts
            let accountsDescriptor = FetchDescriptor<SDAccount>()
            let allAccounts = (try? context.fetch(accountsDescriptor)) ?? []
            
            var aggregateMetrics = AggregatePortfolioMetrics()
            var totalWeightedXIRR: Double = 0
            var totalWeight: Double = 0
            
            for account in allAccounts.filter({ $0.type == "Investment" }) {
                // Extract metrics from metadata
                guard let metaDict = account.metadataDictionary,
                      let investedStr = metaDict["invested_amount"] as? String,
                      let currentStr = metaDict["current_value"] as? String,
                      let returnStr = metaDict["absolute_return"] as? String,
                      let invested = Double(investedStr),
                      let current = Double(currentStr),
                      let absReturn = Double(returnStr),
                      let xirr = account.cachedXIRR else {
                    print("[Dashboard] Missing data for account: \(account.name)")
                    continue
                }
                
                aggregateMetrics.totalInvested += invested
                aggregateMetrics.totalCurrentValue += current
                aggregateMetrics.totalAbsoluteReturn += absReturn
                
                // Weight XIRR by invested amount
                totalWeightedXIRR += xirr * invested
                totalWeight += invested
            }
            
            // Calculate weighted average XIRR
            if totalWeight > 0 {
                aggregateMetrics.weightedXIRR = totalWeightedXIRR / totalWeight
            }

            await MainActor.run {
                // Use API-cached net worth if available (matches web frontend approach)
                let cachedNetWorth = UserDefaults.standard.string(forKey: "cached_net_worth")
                
                if let apiNetWorth = cachedNetWorth {
                    // Override with API value (web uses net worth history API)
                    self.summary = ClientDashboardData(
                        netWorth: apiNetWorth,
                        lastMonthIncome: summaryData.lastMonthIncome,
                        lastMonthExpenses: summaryData.lastMonthExpenses,
                        yearlyIncome: summaryData.yearlyIncome,
                        yearlyExpenses: summaryData.yearlyExpenses,
                        totalAssets: summaryData.totalAssets,
                        totalLiabilities: summaryData.totalLiabilities,
                        savingsRate: summaryData.savingsRate,
                        yearlySavings: summaryData.yearlySavings,
                        averageGrowthRate: summaryData.averageGrowthRate,
                        netWorthGrowth: summaryData.netWorthGrowth,
                        expenseGrowth: summaryData.expenseGrowth,
                        savingsRateChange: summaryData.savingsRateChange,
                        cashFlowRatio: summaryData.cashFlowRatio,
                        monthlyBurnRate: summaryData.monthlyBurnRate,
                        runwayDays: summaryData.runwayDays,
                        debtToAssetRatio: summaryData.debtToAssetRatio
                    )
                    print("[Dashboard] Using API-cached net worth: \(apiNetWorth)")
                } else {
                    // Fallback to calculated value if API hasn't synced yet
                    self.summary = summaryData
                    print("[Dashboard] Using locally calculated net worth: \(summaryData.netWorth)")
                }
                
                self.netWorthHistory = history
                self.topTags = Array(tags.prefix(5))
                self.monthlyTagSpending = spending
                self.recentTransactions = recent
                self.portfolioMetrics = aggregateMetrics
                self.isLoading = false
            }
        }
    }
}
