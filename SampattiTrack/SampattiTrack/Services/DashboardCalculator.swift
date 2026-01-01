import Foundation
import SwiftData

// DashboardData is defined in Models/Dashboard.swift
// We just need to ensure that model has all fields we need.
// Checking Models/Dashboard.swift:
// It lacks `averageGrowthRate`.
// We should update Models/Dashboard.swift to include it, or define a local struct `ClientDashboardData` to avoid conflict.
// Let's use `ClientDashboardData` to be safe and avoid modifying the API model which might expect specific fields.

struct ClientDashboardData {
    let netWorth: String
    let lastMonthIncome: String
    let lastMonthExpenses: String
    let yearlyIncome: String
    let yearlyExpenses: String
    let totalAssets: String
    let totalLiabilities: String
    let savingsRate: Double
    let yearlySavings: String
    let averageGrowthRate: Double
    let netWorthGrowth: Double
    let expenseGrowth: Double
    let savingsRateChange: Double
    
    // New KPI Metrics
    let cashFlowRatio: Double        // income / expenses (> 1 = positive cash flow)
    let monthlyBurnRate: Double      // average monthly expenses
    let runwayDays: Int              // assets / daily burn rate
    let debtToAssetRatio: Double     // liabilities / assets (as positive percentage)

    // Helper to convert to DashboardData (if needed) but we use this struct in ViewModel now.
}

struct DateRange {
    let start: Date
    let end: Date
    let name: String

    static func lastMonth() -> DateRange {
        let calendar = Calendar.current
        let now = Date()
        let lastMonth = calendar.date(byAdding: .month, value: -1, to: now)!
        let start = calendar.date(from: calendar.dateComponents([.year, .month], from: lastMonth))!
        let end = calendar.date(byAdding: .month, value: 1, to: start)!.addingTimeInterval(-1)
        return DateRange(start: start, end: end, name: "Last Month")
    }

    static func ytd() -> DateRange {
        let calendar = Calendar.current
        let now = Date()
        let start = calendar.date(from: calendar.dateComponents([.year], from: now))!
        return DateRange(start: start, end: now, name: "YTD")
    }

    static func thisMonth() -> DateRange {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.year, .month], from: now)
        let start = calendar.date(from: components)!
        return DateRange(start: start, end: now, name: "This Month")
    }

    static func all() -> DateRange {
         return DateRange(start: Date.distantPast, end: Date(), name: "All Time")
    }
}

class DashboardCalculator {
    private let modelContext: ModelContext
    
    // Optimization: Reuse formatter to avoid expensive re-creation
    private let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        formatter.timeZone = Calendar.current.timeZone
        return formatter
    }()

    // MARK: - Caching for Performance
    private var cachedTransactions: [SDTransaction]?
    private var cacheDate: Date?
    private let cacheExpiry: TimeInterval = 60 // 1 minute cache
    
    // Cached posting aggregates for net worth calculation
    private var cachedAssets: Double?
    private var cachedLiabilities: Double?

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    /// Invalidate cache when data changes
    func invalidateCache() {
        cachedTransactions = nil
        cacheDate = nil
        cachedAssets = nil
        cachedLiabilities = nil
    }
    
    /// Get cached transactions or fetch fresh if expired
    private func getCachedTransactions() -> [SDTransaction] {
        if let cached = cachedTransactions,
           let date = cacheDate,
           Date().timeIntervalSince(date) < cacheExpiry {
            return cached
        }
        let transactions = fetchAllTransactionsInternal()
        cachedTransactions = transactions
        cacheDate = Date()
        return transactions
    }

    // MARK: - Summary

    func calculateSummary(range: DateRange) -> ClientDashboardData {
        // Use cached transactions for ALL calculations
        let allTransactions = getCachedTransactions()
        
        // Filter for the selected range
        let startStr = dateFormatter.string(from: range.start)
        let endStr = dateFormatter.string(from: range.end)
        
        let rangeTransactions = allTransactions.filter { $0.date >= startStr && $0.date <= endStr }
        
        let income = calculateTotal(transactions: rangeTransactions, type: .income)
        let expenses = calculateTotal(transactions: rangeTransactions, type: .expense)

        // YTD - filter from cached transactions
        let ytdRange = DateRange.ytd()
        let ytdStartStr = dateFormatter.string(from: ytdRange.start)
        let ytdEndStr = dateFormatter.string(from: ytdRange.end)
        let ytdTransactions = allTransactions.filter { $0.date >= ytdStartStr && $0.date <= ytdEndStr }
        let ytdIncome = calculateTotal(transactions: ytdTransactions, type: .income)
        let ytdExpenses = calculateTotal(transactions: ytdTransactions, type: .expense)
        let ytdSavings = ytdIncome - ytdExpenses

        // Net Worth is point-in-time (Now) - use cached components
        let (assets, liabilities) = calculateNetWorthComponentsCached()
        let netWorth = assets + liabilities // Liabilities are negative

        let savingsRate = income > 0 ? ((income - expenses) / income) * 100 : 0.0

        let avgGrowth = calculateAverageGrowthRateCached(allTransactions: allTransactions, range: range)

        // Calculate MoM Metrics using cached transactions
        let (nwGrowth, expGrowth, savRateChange) = calculateMoMMetricsCached(allTransactions: allTransactions)
        
        // Calculate new KPI Metrics
        let cashFlowRatio = expenses > 0 ? income / expenses : (income > 0 ? Double.infinity : 0)
        
        // Monthly burn rate: average expenses over last 6 months
        let sixMonthsAgo = Calendar.current.date(byAdding: .month, value: -6, to: Date())!
        let sixMonthStr = dateFormatter.string(from: sixMonthsAgo)
        let recentTransactions = allTransactions.filter { $0.date >= sixMonthStr }
        let recentExpenses = calculateTotal(transactions: recentTransactions, type: .expense)
        let monthlyBurnRate = recentExpenses / 6.0
        
        // Runway days: assets / daily burn rate
        let dailyBurnRate = monthlyBurnRate / 30.0
        let runwayDays = dailyBurnRate > 0 ? Int(assets / dailyBurnRate) : Int.max
        
        // Debt-to-asset ratio (as positive percentage)
        let absLiabilities = abs(liabilities)
        let debtToAssetRatio = assets > 0 ? (absLiabilities / assets) * 100 : 0

        return ClientDashboardData(
            netWorth: String(netWorth),
            lastMonthIncome: String(income),
            lastMonthExpenses: String(expenses),
            yearlyIncome: String(ytdIncome),
            yearlyExpenses: String(ytdExpenses),
            totalAssets: String(assets),
            totalLiabilities: String(liabilities),
            savingsRate: savingsRate,
            yearlySavings: String(ytdSavings),
            averageGrowthRate: avgGrowth,
            netWorthGrowth: nwGrowth,
            expenseGrowth: expGrowth,
            savingsRateChange: savRateChange,
            cashFlowRatio: cashFlowRatio,
            monthlyBurnRate: monthlyBurnRate,
            runwayDays: min(runwayDays, 9999), // Cap at 9999 for display
            debtToAssetRatio: debtToAssetRatio
        )
    }

    /// Optimized MoM metrics using cached transactions (reduces 4 fetches to 0)
    private func calculateMoMMetricsCached(allTransactions: [SDTransaction]) -> (Double, Double, Double) {
        let now = Date()
        let calendar = Calendar.current

        // Define "Current" as Last 30 Days
        guard let startCurrent = calendar.date(byAdding: .day, value: -30, to: now),
              let startPrevious = calendar.date(byAdding: .day, value: -30, to: startCurrent) else {
            return (0, 0, 0)
        }
        
        let nowStr = dateFormatter.string(from: now)
        let startCurrentStr = dateFormatter.string(from: startCurrent)
        let startPreviousStr = dateFormatter.string(from: startPrevious)

        // Filter from cached transactions instead of fetching
        let currentTx = allTransactions.filter { $0.date >= startCurrentStr && $0.date <= nowStr }
        let previousTx = allTransactions.filter { $0.date >= startPreviousStr && $0.date < startCurrentStr }

        let currentExpenses = calculateTotal(transactions: currentTx, type: .expense)
        let previousExpenses = calculateTotal(transactions: previousTx, type: .expense)
        let expenseGrowth = previousExpenses != 0 ? ((currentExpenses - previousExpenses) / previousExpenses) * 100 : 0.0

        let currentIncome = calculateTotal(transactions: currentTx, type: .income)
        let previousIncome = calculateTotal(transactions: previousTx, type: .income)
        let currentSavingsRate = currentIncome > 0 ? ((currentIncome - currentExpenses) / currentIncome) * 100 : 0.0
        let previousSavingsRate = previousIncome > 0 ? ((previousIncome - previousExpenses) / previousIncome) * 100 : 0.0
        let savingsRateChange = currentSavingsRate - previousSavingsRate

        // Net Worth Growth using cached data
        let nwNow = calculateNetWorthFromCache(allTransactions, upTo: nowStr)
        let nwPrev = calculateNetWorthFromCache(allTransactions, upTo: startCurrentStr)
        let nwGrowth = nwPrev != 0 ? ((nwNow - nwPrev) / abs(nwPrev)) * 100 : 0.0

        return (nwGrowth, expenseGrowth, savingsRateChange)
    }
    
    /// Calculate net worth at a point in time using cached transactions
    private func calculateNetWorthFromCache(_ transactions: [SDTransaction], upTo dateStr: String) -> Double {
        var total: Double = 0
        for tx in transactions {
            if tx.date <= dateStr {
                total += calculateNetImpact(tx)
            }
        }
        return total
    }

    // MARK: - Charts

    func calculateNetWorthHistory(range: DateRange) -> [NetWorthDataPoint] {
        // 1. Calculate Opening Balance (Net Worth) at `range.start`
        // Sum of all postings before start date where account type is Asset (+) or Liability (-)

        let start = range.start
        let startStr = dateFormatter.string(from: start)
        let endStr = dateFormatter.string(from: range.end)

        // Fetch opening balance efficiently
        // We only need the SUM of amounts for Asset/Liability postings before startStr
        // SwiftData doesn't support complex aggregation yet, so we fetch Postings directly.
        // Fetching just SDPostings is lighter than SDTransactions.
        // Also filtering by account category if possible.
        // For now, to be safe and accurate without complex complex predicates, we iterate.
        // BUT we optimize by NOT fetching the entire object graph if we can help it.
        // Actually, let's just iterate all transactions but sorted, and stop when needed?
        // No, we need sum of *previous*.

        // Optimization: Fetch all transactions sorted by date.
        // This is O(N) but avoids multiple queries.
        // To reduce memory, we don't hold them in array if we can enumerate.
        // But context.fetch returns [T].
        // Limit properties fetched? Not easily in SwiftData.

        let allTransactions = getCachedTransactions()

        var currentNetWorth: Double = 0
        var history: [NetWorthDataPoint] = []
        var rangeTransactions: [SDTransaction] = []

        for tx in allTransactions {
            if tx.date < startStr {
                currentNetWorth += calculateNetImpact(tx)
            } else if tx.date <= endStr {
                rangeTransactions.append(tx)
            }
        }

        // Group by Month (YYYY-MM) for cleaner history
        let grouped = Dictionary(grouping: rangeTransactions) { String($0.date.prefix(7)) } // YYYY-MM
        let sortedMonths = grouped.keys.sorted()

        // Add start point
        history.append(NetWorthDataPoint(date: startStr, assets: "0", liabilities: "0", netWorth: String(currentNetWorth)))

        for month in sortedMonths {
            // Process all transactions in this month
            if let txs = grouped[month] {
                for tx in txs {
                    currentNetWorth += calculateNetImpact(tx)
                }
                // Add point for end of month
                // Use the last date found in that month or the actual month end?
                // Using the month string "YYYY-MM" or the actual date of last tx
                if let lastTxDate = txs.max(by: { $0.date < $1.date })?.date {
                    history.append(NetWorthDataPoint(date: lastTxDate, assets: "0", liabilities: "0", netWorth: String(currentNetWorth)))
                }
            }
        }

        return history
    }

    func calculateTagBreakdown(range: DateRange) -> [TopTag] {
        let transactions = fetchTransactions(in: range)
        var tagAmounts: [String: Double] = [:] // TagID -> Amount
        var tagNames: [String: String] = [:]   // TagID -> Name

        for tx in transactions {
            guard let postings = tx.postings else { continue }

            // Identify if this transaction is an Expense
            // We only want to track expenses for "Tag Breakdown" usually
            let type = tx.determineType()
            guard type == .expense else { continue }

            for posting in postings {
                // If posting is positive (destination of expense), it holds the tags usually?
                // Actually in double entry: Expense account is debited (positive amount usually in Beancount/Ledger if strict).
                // But in this system, Expense amounts seem to be negative in postings?
                // Let's check `SDExtensions`.
                // "Sum of positive amounts" -> displayAmount.
                // Usually Expense Account Posting has Positive Value (Debit) and Asset has Negative (Credit).
                // Or vice versa depending on sign convention.

                // Let's assume we sum up the posting that has the tag.
                if let tags = posting.tags, !tags.isEmpty {
                    let amount = abs(Double(posting.amount) ?? 0)
                    for tag in tags {
                        tagAmounts[tag.id, default: 0] += amount
                        tagNames[tag.id] = tag.name
                    }
                }
            }
        }

        // Top 9 + Others
        let sorted = tagAmounts.sorted { $0.value > $1.value }
        var result: [TopTag] = []

        let top9 = sorted.prefix(9)
        for (id, amount) in top9 {
            result.append(TopTag(tagId: id, tagName: tagNames[id] ?? "Unknown", amount: String(amount)))
        }

        // Others
        if sorted.count > 9 {
            let othersAmount = sorted.dropFirst(9).reduce(0) { $0 + $1.value }
            result.append(TopTag(tagId: "others", tagName: "Others", amount: String(othersAmount)))
        }

        return result
    }

    func calculateMonthlySpending(range: DateRange) -> [(month: String, tags: [(tag: String, amount: Double)])] {
        // For Stacked Bar Chart
        let transactions = fetchTransactions(in: range)
        var monthlyData: [String: [String: Double]] = [:] // "YYYY-MM" -> [TagName -> Amount]

        for tx in transactions {
            let type = tx.determineType()
            guard type == .expense else { continue }

            // Extract Month
            let month = String(tx.date.prefix(7)) // YYYY-MM

            guard let postings = tx.postings else { continue }
            for posting in postings {
                if let tags = posting.tags, !tags.isEmpty {
                    let amount = abs(Double(posting.amount) ?? 0)
                    for tag in tags {
                        monthlyData[month, default: [:]][tag.name, default: 0] += amount
                    }
                }
            }
        }

        return monthlyData.sorted { $0.key < $1.key }.map { (month, tagsMap) in
            let tagsList = tagsMap.map { (tag: $0.key, amount: $0.value) }.sorted { $0.amount > $1.amount }
            return (month: month, tags: tagsList)
        }
    }
    
    // MARK: - Monthly Trend Data for Charts
    
    /// Calculate monthly expense totals for trend chart
    func calculateMonthlyExpenses(range: DateRange) -> [(month: String, amount: Double)] {
        let allTransactions = getCachedTransactions()
        let startStr = dateFormatter.string(from: range.start)
        let endStr = dateFormatter.string(from: range.end)
        
        var monthlyData: [String: Double] = [:]
        
        for tx in allTransactions {
            guard tx.date >= startStr && tx.date <= endStr else { continue }
            guard tx.determineType() == .expense else { continue }
            
            let month = String(tx.date.prefix(7)) // YYYY-MM
            monthlyData[month, default: 0] += tx.displayAmount
        }
        
        return monthlyData.sorted { $0.key < $1.key }.map { (month: $0.key, amount: $0.value) }
    }
    
    /// Calculate monthly income totals for trend chart
    func calculateMonthlyIncome(range: DateRange) -> [(month: String, amount: Double)] {
        let allTransactions = getCachedTransactions()
        let startStr = dateFormatter.string(from: range.start)
        let endStr = dateFormatter.string(from: range.end)
        
        var monthlyData: [String: Double] = [:]
        
        for tx in allTransactions {
            guard tx.date >= startStr && tx.date <= endStr else { continue }
            guard tx.determineType() == .income else { continue }
            
            let month = String(tx.date.prefix(7)) // YYYY-MM
            monthlyData[month, default: 0] += tx.displayAmount
        }
        
        return monthlyData.sorted { $0.key < $1.key }.map { (month: $0.key, amount: $0.value) }
    }
    
    /// Calculate monthly savings (income - expenses) for trend chart
    func calculateMonthlySavings(range: DateRange) -> [(month: String, savings: Double)] {
        let incomeData = calculateMonthlyIncome(range: range)
        let expenseData = calculateMonthlyExpenses(range: range)
        
        let incomeMap = Dictionary(uniqueKeysWithValues: incomeData.map { ($0.month, $0.amount) })
        let expenseMap = Dictionary(uniqueKeysWithValues: expenseData.map { ($0.month, $0.amount) })
        
        let allMonths = Set(incomeMap.keys).union(Set(expenseMap.keys)).sorted()
        
        return allMonths.map { month in
            let income = incomeMap[month] ?? 0
            let expense = expenseMap[month] ?? 0
            return (month: month, savings: income - expense)
        }
    }

    /// Calculate monthly savings rate (income - expenses) / income, plus absolute savings
    func calculateMonthlySavingsRate(range: DateRange) -> [(month: String, rate: Double, absolute: Double)] {
        let incomeData = calculateMonthlyIncome(range: range)
        let expenseData = calculateMonthlyExpenses(range: range)

        let incomeMap = Dictionary(uniqueKeysWithValues: incomeData.map { ($0.month, $0.amount) })
        let expenseMap = Dictionary(uniqueKeysWithValues: expenseData.map { ($0.month, $0.amount) })

        let allMonths = Set(incomeMap.keys).union(Set(expenseMap.keys)).sorted()

        return allMonths.map { month in
            let income = incomeMap[month] ?? 0
            let expense = expenseMap[month] ?? 0
            let savings = income - expense
            let rate = income > 0 ? (savings / income) * 100 : 0
            return (month: month, rate: rate, absolute: savings)
        }
    }

    // MARK: - Recent Transactions

    func fetchRecentTransactions(limit: Int) -> [Transaction] {
        // Fetch most recent transactions sorted by date desc
        let descriptor = FetchDescriptor<SDTransaction>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        // SwiftData FetchDescriptor doesn't support fetchLimit in all versions easily via simple init,
        // but let's see if we can just fetch all and prefix, or if FetchLimit works.
        // Actually FetchDescriptor has fetchLimit property.

        var descriptorWithLimit = descriptor
        descriptorWithLimit.fetchLimit = limit

        let sdTransactions = (try? modelContext.fetch(descriptorWithLimit)) ?? []
        return sdTransactions.map { $0.toTransaction }
    }

    // MARK: - Helpers

    private func fetchTransactions(in range: DateRange) -> [SDTransaction] {
        // Note: SwiftData predicate with Date comparison on String fields is tricky.
        // Assuming dates are strictly ISO8601 YYYY-MM-DD
        let startStr = dateFormatter.string(from: range.start)
        let endStr = dateFormatter.string(from: range.end)

        // Fetch all and filter in memory if Predicate fails on strings?
        // String comparison works for ISO8601.

        // However, SwiftData Predicate is restrictive.
        // Let's try to use a Predicate.
        let descriptor = FetchDescriptor<SDTransaction>(
            predicate: #Predicate { $0.date >= startStr && $0.date <= endStr }
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    /// Internal fetch that bypasses cache - used by getCachedTransactions()
    private func fetchAllTransactionsInternal() -> [SDTransaction] {
        let descriptor = FetchDescriptor<SDTransaction>(sortBy: [SortDescriptor(\.date)])
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private func calculateTotal(transactions: [SDTransaction], type: Transaction.TransactionType) -> Double {
        var total: Double = 0
        for tx in transactions {
            if tx.determineType() == type {
                total += tx.displayAmount
            }
        }
        return total
    }

    private func calculateNetImpact(_ tx: SDTransaction) -> Double {
        // Net impact on Net Worth.
        // Sum of changes to Asset and Liability accounts.
        // Asset (+), Liability (-) (as liability balance is usually negative? or positive debt?)
        // In this app, it seems Liability amounts are negative.
        // So Sum(AssetPostings) + Sum(LiabilityPostings) = Net Change

        guard let postings = tx.postings else { return 0 }
        var impact: Double = 0

        for p in postings {
            if let cat = p.category {
                if cat == "Assets" || cat == "Asset" {
                    impact += Double(p.amount) ?? 0
                } else if cat == "Liabilities" || cat == "Liability" {
                    impact += Double(p.amount) ?? 0
                }
            }
        }
        return impact
    }

    /// Cached version of net worth components calculation
    private func calculateNetWorthComponentsCached() -> (Double, Double) {
        // Return cached values if available
        if let assets = cachedAssets, let liabilities = cachedLiabilities {
            return (assets, liabilities)
        }
        
        // Fetch all accounts to get categories
        let accountsDesc = FetchDescriptor<SDAccount>()
        let accounts = (try? modelContext.fetch(accountsDesc)) ?? []
        let accountCategoryMap = Dictionary(uniqueKeysWithValues: accounts.map { ($0.id, $0.category) })
        
        // Calculate from cached transactions
        let allTransactions = getCachedTransactions()
        var assets: Double = 0
        var liabilities: Double = 0
        
        print("[DashboardCalc] Calculating net worth from \(allTransactions.count) transactions")
        
        for tx in allTransactions {
            guard let postings = tx.postings else { continue }
            for p in postings {
                // Get category from account map
                if let category = accountCategoryMap[p.accountID] {
                    let amount = Double(p.amount) ?? 0
                    if category == "Asset" {
                        assets += amount
                    } else if category == "Liability" {
                        liabilities += amount
                    }
                }
            }
        }
        
        print("[DashboardCalc] Net Worth: Assets=\(assets), Liabilities=\(liabilities), Total=\(assets + liabilities)")
        
        // Cache the results
        cachedAssets = assets
        cachedLiabilities = liabilities
        
        return (assets, liabilities)
    }

    /// Optimized average growth rate using pre-fetched transactions
    private func calculateAverageGrowthRateCached(allTransactions: [SDTransaction], range: DateRange) -> Double {
        let history = calculateNetWorthHistoryCached(allTransactions: allTransactions, range: range)
        guard history.count >= 2 else { return 0 }

        var growths: [Double] = []
        for i in 1..<history.count {
            let prev = Double(history[i-1].netWorthValue)
            let curr = Double(history[i].netWorthValue)
            if prev != 0 {
                let growth = (curr - prev) / abs(prev)
                growths.append(growth)
            }
        }

        guard !growths.isEmpty else { return 0 }
        return (growths.reduce(0, +) / Double(growths.count)) * 100
    }
    
    /// Optimized net worth history using pre-fetched transactions
    private func calculateNetWorthHistoryCached(allTransactions: [SDTransaction], range: DateRange) -> [NetWorthDataPoint] {
        let startStr = dateFormatter.string(from: range.start)
        let endStr = dateFormatter.string(from: range.end)

        var currentNetWorth: Double = 0
        var history: [NetWorthDataPoint] = []
        var rangeTransactions: [SDTransaction] = []

        for tx in allTransactions {
            if tx.date < startStr {
                currentNetWorth += calculateNetImpact(tx)
            } else if tx.date <= endStr {
                rangeTransactions.append(tx)
            }
        }

        let grouped = Dictionary(grouping: rangeTransactions) { String($0.date.prefix(7)) }
        let sortedMonths = grouped.keys.sorted()
        
        history.append(NetWorthDataPoint(date: startStr, assets: "0", liabilities: "0", netWorth: String(currentNetWorth)))

        for month in sortedMonths {
            if let txs = grouped[month] {
                for tx in txs {
                    currentNetWorth += calculateNetImpact(tx)
                }
                if let lastTxDate = txs.max(by: { $0.date < $1.date })?.date {
                    history.append(NetWorthDataPoint(date: lastTxDate, assets: "0", liabilities: "0", netWorth: String(currentNetWorth)))
                }
            }
        }

        return history
    }
}
