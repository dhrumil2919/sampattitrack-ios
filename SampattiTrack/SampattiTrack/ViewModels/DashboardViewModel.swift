import Foundation
import Combine
import SwiftData

struct PortfolioGroupMetrics: Identifiable {
    let id: String
    let name: String
    var totalInvested: Double
    var totalCurrentValue: Double
    var totalAbsoluteReturn: Double
    var weightedXIRR: Double

    var returnPercentage: Double {
        guard totalInvested > 0 else { return 0 }
        return (totalAbsoluteReturn / totalInvested) * 100
    }
}

struct AggregatePortfolioMetrics {
    var totalInvested: Double = 0
    var totalCurrentValue: Double = 0
    var totalAbsoluteReturn: Double = 0
    var weightedXIRR: Double = 0
    var groups: [PortfolioGroupMetrics] = []
    
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
    @Published var monthlyExpenses: [(month: String, amount: Double)] = []
    @Published var monthlyIncome: [(month: String, amount: Double)] = []
    @Published var monthlySavings: [(month: String, rate: Double, absolute: Double)] = []
    @Published var topTags: [TopTag] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // Tax and Capital Gains data
    @Published var taxAnalysis: TaxAnalysis?
    @Published var capitalGains: CapitalGainsReport?
    @Published var cashFlowData: [CashFlowDataPoint] = []
    @Published var portfolioAssets: [AssetPerformance] = []
    
    
    @Published var selectedRange: DateRange = .lastMonth() {
        didSet {
            calculateClientSideData()
        }
    }

    private var container: ModelContainer?
    
    // OFFLINE-FIRST: References for UI status indicators
    weak var syncManager: SyncManager?
    weak var networkMonitor: NetworkMonitor?

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

            // Load cached cash flow data first
            var cashFlow: [CashFlowDataPoint] = []
            if let cfData = UserDefaults.standard.data(forKey: "cached_cash_flow"),
               let cf = try? JSONDecoder().decode([CashFlowDataPoint].self, from: cfData) {
                cashFlow = cf
            }
            
            // Load cached portfolio assets locally to avoid closure capture issues
            var localPortfolioAssets: [AssetPerformance] = []
            if let pData = UserDefaults.standard.data(forKey: "cached_portfolio_analysis"),
               let pAssets = try? JSONDecoder().decode([AssetPerformance].self, from: pData) {
                localPortfolioAssets = pAssets
            }
            
            // Calculate income/expense/savings from cash flow API data based on selectedRange
            let now = Date()
            let calendar = Calendar.current
            
            // Use selectedRange start and end dates directly
            let rangeStart = self.selectedRange.start
            let rangeEnd = self.selectedRange.end
            
            // Filter cash flow data based on selected range
            var filteredIncome: Double = 0
            var filteredExpenses: Double = 0
            var filteredSavings: Double = 0
            var monthCount = 0
            
            for dataPoint in cashFlow {
                guard let date = dataPoint.date else { continue }
                
                if date >= rangeStart && date <= rangeEnd {
                    filteredIncome += dataPoint.incomeValue
                    filteredExpenses += dataPoint.expenseValue
                    filteredSavings += dataPoint.netSavingsValue
                    monthCount += 1
                }
            }
            
            // Calculate savings rate for the selected range
            let savingsRate = filteredIncome > 0 ? ((filteredIncome - filteredExpenses) / filteredIncome) * 100 : 0
            
            // Calculate MoM expense growth (compare last two months in cash flow)
            var expenseGrowth: Double = 0
            if cashFlow.count >= 2 {
                let sortedCashFlow = cashFlow.sorted { ($0.date ?? Date.distantPast) < ($1.date ?? Date.distantPast) }
                if let lastMonth = sortedCashFlow.suffix(2).first,
                   let currentMonth = sortedCashFlow.last {
                    let lastExpense = lastMonth.expenseValue
                    let currentExpense = currentMonth.expenseValue
                    if lastExpense > 0 {
                        expenseGrowth = ((currentExpense - lastExpense) / lastExpense) * 100
                    }
                }
            }
            
            // Calculate Financial KPIs from cash flow data
            
            // 1. Cash Flow Ratio = Income / Expenses
            let cashFlowRatio = filteredExpenses > 0 ? filteredIncome / filteredExpenses : 0
            
            // 2. Monthly Burn Rate = Average monthly expenses
            let monthlyBurnRate = monthCount > 0 ? filteredExpenses / Double(monthCount) : 0
            
            // 3. Runway Days - need current liquid assets
            // Get assets from summaryData (still use calculator for balance sheet items)
            let summaryData = calculator.calculateSummary(range: self.selectedRange)
            let liquidAssets = Double(summaryData.totalAssets) ?? 0
            let runwayDays = monthlyBurnRate > 0 ? Int((liquidAssets / monthlyBurnRate) * 30) : 999999
            
            // 4. Debt to Asset Ratio - from balance sheet
            let totalLiabilities = Double(summaryData.totalLiabilities) ?? 0
            let debtToAssetRatio = liquidAssets > 0 ? (abs(totalLiabilities) / liquidAssets) * 100 : 0
            
            let history = calculator.calculateNetWorthHistory(range: self.selectedRange)
            let tags = calculator.calculateTagBreakdown(range: self.selectedRange)
            let spending = calculator.calculateMonthlySpending(range: self.selectedRange)
            let recent = calculator.fetchRecentTransactions(limit: 5)

            // Timeline charts always use YTD or longer range
            let ytdRange = DateRange.ytd()
            let mExpenses = calculator.calculateMonthlyExpenses(range: ytdRange)
            let mIncome = calculator.calculateMonthlyIncome(range: ytdRange)
            let mSavings = calculator.calculateMonthlySavingsRate(range: ytdRange)

            // Calculate aggregate portfolio metrics from all investment accounts
            let accountsDescriptor = FetchDescriptor<SDAccount>()
            let allAccounts = (try? context.fetch(accountsDescriptor)) ?? []
            
            var aggregateMetrics = AggregatePortfolioMetrics()
            var totalWeightedXIRR: Double = 0
            var totalWeight: Double = 0
            
            // Temporary storage for group aggregation
            var groupAggregates: [String: (invested: Double, current: Double, absReturn: Double, xirrWeighted: Double, xirrWeight: Double)] = [:]

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

                // Grouping Logic
                let groupID: String
                if account.id == "Assets:Gold" {
                    groupID = account.id
                } else {
                    groupID = account.parentID ?? account.id
                }

                var currentGroup = groupAggregates[groupID] ?? (0, 0, 0, 0, 0)
                currentGroup.invested += invested
                currentGroup.current += current
                currentGroup.absReturn += absReturn
                currentGroup.xirrWeighted += xirr * invested
                currentGroup.xirrWeight += invested
                groupAggregates[groupID] = currentGroup
            }
            
            // Calculate weighted average XIRR for total
            if totalWeight > 0 {
                aggregateMetrics.weightedXIRR = totalWeightedXIRR / totalWeight
            }

            // Process Groups
            var groups: [PortfolioGroupMetrics] = []
            for (groupID, data) in groupAggregates {
                let finalXIRR = data.xirrWeight > 0 ? (data.xirrWeighted / data.xirrWeight) : 0

                // Resolve Name
                var groupName = groupID
                if let groupAccount = allAccounts.first(where: { $0.id == groupID }) {
                    groupName = groupAccount.name
                } else {
                    groupName = groupID.split(separator: ":").last.map(String.init) ?? groupID
                }

                let groupMetric = PortfolioGroupMetrics(
                    id: groupID,
                    name: groupName,
                    totalInvested: data.invested,
                    totalCurrentValue: data.current,
                    totalAbsoluteReturn: data.absReturn,
                    weightedXIRR: finalXIRR
                )
                groups.append(groupMetric)
            }

            // Sort groups by current value descending
            aggregateMetrics.groups = groups.sorted(by: { $0.totalCurrentValue > $1.totalCurrentValue })

            await MainActor.run { [localPortfolioAssets] in
                // Use API-cached net worth if available
                let cachedNetWorth = UserDefaults.standard.string(forKey: "cached_net_worth")
                
                // Create summary with cash flow API data
                if let apiNetWorth = cachedNetWorth {
                    self.summary = ClientDashboardData(
                        netWorth: apiNetWorth,
                        lastMonthIncome: String(filteredIncome),
                        lastMonthExpenses: String(filteredExpenses),
                        yearlyIncome: String(filteredIncome),
                        yearlyExpenses: String(filteredExpenses),
                        totalAssets: summaryData.totalAssets,
                        totalLiabilities: summaryData.totalLiabilities,
                        savingsRate: savingsRate,
                        yearlySavings: String(filteredSavings),
                        averageGrowthRate: summaryData.averageGrowthRate,
                        netWorthGrowth: summaryData.netWorthGrowth,
                        expenseGrowth: expenseGrowth,
                        savingsRateChange: summaryData.savingsRateChange,
                        cashFlowRatio: cashFlowRatio,
                        monthlyBurnRate: monthlyBurnRate,
                        runwayDays: runwayDays,
                        debtToAssetRatio: debtToAssetRatio
                    )
                    print("[Dashboard] Using filter:\(self.selectedRange) Income=\(filteredIncome), Expenses=\(filteredExpenses), CashFlowRatio=\(cashFlowRatio), BurnRate=\(monthlyBurnRate), Runway=\(runwayDays)days")
                } else {
                    // Fallback to calculated values
                    self.summary = summaryData
                }
                
                // Load cached tax analysis
                if let taxData = UserDefaults.standard.data(forKey: "cached_tax_analysis"),
                   let tax = try? JSONDecoder().decode(TaxAnalysis.self, from: taxData) {
                    self.taxAnalysis = tax
                    print("[Dashboard] Loaded cached tax analysis: Rate = \(tax.taxRate)%")
                }
                
                // Load cached capital gains
                if let cgData = UserDefaults.standard.data(forKey: "cached_capital_gains"),
                   let cg = try? JSONDecoder().decode(CapitalGainsReport.self, from: cgData) {
                    self.capitalGains = cg
                    print("[Dashboard] Loaded cached capital gains for year \(cg.year)")
                }
                
                // Store cash flow data
                self.cashFlowData = cashFlow
                
                self.netWorthHistory = history
                self.topTags = Array(tags.prefix(5))
                self.monthlyTagSpending = spending
                self.monthlyExpenses = mExpenses
                self.monthlyIncome = mIncome
                self.monthlySavings = mSavings
                self.recentTransactions = recent
                self.portfolioMetrics = aggregateMetrics
                self.portfolioAssets = localPortfolioAssets
                self.isLoading = false
            } // MainActor.run
        } // Task.detached
    }
}
