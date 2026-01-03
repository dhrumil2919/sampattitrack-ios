import Foundation
import SwiftData

// DashboardData is defined in Models/Dashboard.swift
// We just need to ensure that model has all fields we need.

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

        // Get configured start month (default: 4 for April)
        let startMonth = UserDefaults.standard.integer(forKey: "financial_year_start_month")
        let fyStartMonth = startMonth > 0 ? startMonth : 4

        let currentYear = calendar.component(.year, from: now)
        let currentMonth = calendar.component(.month, from: now)

        // If current month is before FY start month, FY started in previous year
        // e.g., If now is Feb 2025 and FY starts in April, start date is April 1, 2024
        let startYear = currentMonth < fyStartMonth ? currentYear - 1 : currentYear

        var components = DateComponents()
        components.year = startYear
        components.month = fyStartMonth
        components.day = 1

        let start = calendar.date(from: components) ?? calendar.date(from: calendar.dateComponents([.year], from: now))!

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

    // Optimization: Cache lightweight struct with pre-calculated values
    // to avoid repetitive string-to-double conversions and array iterations.
    private struct CachedTransaction {
        let date: String
        let type: Transaction.TransactionType
        let displayAmount: Double
        let assetImpact: Double
        let liabilityImpact: Double

        var netImpact: Double { assetImpact + liabilityImpact }
    }

    private var cachedData: [CachedTransaction]?
    private var cacheDate: Date?
    private let cacheExpiry: TimeInterval = 60 // 1 minute cache

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    /// Invalidate cache when data changes
    func invalidateCache() {
        cachedData = nil
        cacheDate = nil
    }
    
    /// Get cached transactions or fetch fresh if expired
    private func getCachedData() -> [CachedTransaction] {
        if let cached = cachedData,
           let date = cacheDate,
           Date().timeIntervalSince(date) < cacheExpiry {
            return cached
        }

        let transactions = fetchAllTransactionsInternal()

        // OPTIMIZATION: Perform expensive calculations (parsing strings, iterating postings)
        // ONCE during cache population, rather than on every chart access.
        let cached = transactions.map { tx -> CachedTransaction in
            let type = tx.determineType()
            let displayAmount = tx.displayAmount

            var assetImpact: Double = 0
            var liabilityImpact: Double = 0

            if let postings = tx.postings {
                for p in postings {
                    let amount = Double(p.amount) ?? 0
                    if let cat = p.category {
                        if cat == "Assets" || cat == "Asset" {
                            assetImpact += amount
                        } else if cat == "Liabilities" || cat == "Liability" {
                            liabilityImpact += amount
                        }
                    }
                }
            }

            return CachedTransaction(
                date: tx.date,
                type: type,
                displayAmount: displayAmount,
                assetImpact: assetImpact,
                liabilityImpact: liabilityImpact
            )
        }

        cachedData = cached
        cacheDate = Date()
        return cached
    }

    // MARK: - Summary

    func calculateSummary(range: DateRange) -> ClientDashboardData {
        // Use cached data for ALL calculations
        let allTransactions = getCachedData()
        
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
    private func calculateMoMMetricsCached(allTransactions: [CachedTransaction]) -> (Double, Double, Double) {
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
    private func calculateNetWorthFromCache(_ transactions: [CachedTransaction], upTo dateStr: String) -> Double {
        var total: Double = 0
        for tx in transactions {
            if tx.date <= dateStr {
                total += tx.netImpact
            }
        }
        return total
    }

    // MARK: - Charts

    func calculateNetWorthHistory(range: DateRange) -> [NetWorthDataPoint] {
        let start = range.start
        let startStr = dateFormatter.string(from: start)
        let endStr = dateFormatter.string(from: range.end)

        let allTransactions = getCachedData()

        var currentNetWorth: Double = 0
        var history: [NetWorthDataPoint] = []
        var rangeTransactions: [CachedTransaction] = []

        // O(N) iteration over cached, pre-calculated structs
        for tx in allTransactions {
            if tx.date < startStr {
                currentNetWorth += tx.netImpact
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
            if let txs = grouped[month] {
                for tx in txs {
                    currentNetWorth += tx.netImpact
                }
                // Use the last date found in that month
                if let lastTxDate = txs.max(by: { $0.date < $1.date })?.date {
                    history.append(NetWorthDataPoint(date: lastTxDate, assets: "0", liabilities: "0", netWorth: String(currentNetWorth)))
                }
            }
        }

        return history
    }

    func calculateTagBreakdown(range: DateRange) -> [TopTag] {
        // Requires Tag details, so we use direct DB fetch or we would need to cache tags.
        // For now, keep using direct fetch for this detailed view.
        let transactions = fetchTransactions(in: range)
        var tagAmounts: [String: Double] = [:] // TagID -> Amount
        var tagNames: [String: String] = [:]   // TagID -> Name

        for tx in transactions {
            guard let postings = tx.postings else { continue }
            let type = tx.determineType()
            guard type == .expense else { continue }

            for posting in postings {
                if let tags = posting.tags, !tags.isEmpty {
                    let amount = abs(Double(posting.amount) ?? 0)
                    for tag in tags {
                        tagAmounts[tag.id, default: 0] += amount
                        tagNames[tag.id] = tag.name
                    }
                }
            }
        }

        let sorted = tagAmounts.sorted { $0.value > $1.value }
        var result: [TopTag] = []

        let top9 = sorted.prefix(9)
        for (id, amount) in top9 {
            result.append(TopTag(tagId: id, tagName: tagNames[id] ?? "Unknown", amount: String(amount)))
        }

        if sorted.count > 9 {
            let othersAmount = sorted.dropFirst(9).reduce(0) { $0 + $1.value }
            result.append(TopTag(tagId: "others", tagName: "Others", amount: String(othersAmount)))
        }

        return result
    }

    func calculateMonthlySpending(range: DateRange) -> [(month: String, tags: [(tag: String, amount: Double)])] {
        // Requires Tag details, keep using direct fetch.
        let transactions = fetchTransactions(in: range)
        var monthlyData: [String: [String: Double]] = [:]

        for tx in transactions {
            let type = tx.determineType()
            guard type == .expense else { continue }

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
    
    func calculateMonthlyExpenses(range: DateRange) -> [(month: String, amount: Double)] {
        let allTransactions = getCachedData()
        let startStr = dateFormatter.string(from: range.start)
        let endStr = dateFormatter.string(from: range.end)
        
        var monthlyData: [String: Double] = [:]
        
        for tx in allTransactions {
            guard tx.date >= startStr && tx.date <= endStr else { continue }
            guard tx.type == .expense else { continue }
            
            let month = String(tx.date.prefix(7)) // YYYY-MM
            monthlyData[month, default: 0] += tx.displayAmount
        }
        
        return monthlyData.sorted { $0.key < $1.key }.map { (month: $0.key, amount: $0.value) }
    }
    
    func calculateMonthlyIncome(range: DateRange) -> [(month: String, amount: Double)] {
        let allTransactions = getCachedData()
        let startStr = dateFormatter.string(from: range.start)
        let endStr = dateFormatter.string(from: range.end)
        
        var monthlyData: [String: Double] = [:]
        
        for tx in allTransactions {
            guard tx.date >= startStr && tx.date <= endStr else { continue }
            guard tx.type == .income else { continue }
            
            let month = String(tx.date.prefix(7)) // YYYY-MM
            monthlyData[month, default: 0] += tx.displayAmount
        }
        
        return monthlyData.sorted { $0.key < $1.key }.map { (month: $0.key, amount: $0.value) }
    }
    
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
        let descriptor = FetchDescriptor<SDTransaction>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        var descriptorWithLimit = descriptor
        descriptorWithLimit.fetchLimit = limit
        let sdTransactions = (try? modelContext.fetch(descriptorWithLimit)) ?? []
        return sdTransactions.map { $0.toTransaction }
    }

    // MARK: - Helpers

    private func fetchTransactions(in range: DateRange) -> [SDTransaction] {
        let startStr = dateFormatter.string(from: range.start)
        let endStr = dateFormatter.string(from: range.end)
        let descriptor = FetchDescriptor<SDTransaction>(
            predicate: #Predicate { $0.date >= startStr && $0.date <= endStr }
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private func fetchAllTransactionsInternal() -> [SDTransaction] {
        let descriptor = FetchDescriptor<SDTransaction>(sortBy: [SortDescriptor(\.date)])
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private func calculateTotal(transactions: [CachedTransaction], type: Transaction.TransactionType) -> Double {
        var total: Double = 0
        for tx in transactions {
            if tx.type == type {
                total += tx.displayAmount
            }
        }
        return total
    }

    /// Cached version of net worth components calculation
    private func calculateNetWorthComponentsCached() -> (Double, Double) {
        // Calculate from cached transactions efficiently
        let allTransactions = getCachedData()
        var assets: Double = 0
        var liabilities: Double = 0
        
        for tx in allTransactions {
            assets += tx.assetImpact
            liabilities += tx.liabilityImpact
        }
        
        print("[DashboardCalc] Net Worth: Assets=\(assets), Liabilities=\(liabilities), Total=\(assets + liabilities)")
        return (assets, liabilities)
    }

    /// Optimized average growth rate using pre-fetched transactions
    private func calculateAverageGrowthRateCached(allTransactions: [CachedTransaction], range: DateRange) -> Double {
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
    private func calculateNetWorthHistoryCached(allTransactions: [CachedTransaction], range: DateRange) -> [NetWorthDataPoint] {
        let startStr = dateFormatter.string(from: range.start)
        let endStr = dateFormatter.string(from: range.end)

        var currentNetWorth: Double = 0
        var history: [NetWorthDataPoint] = []
        var rangeTransactions: [CachedTransaction] = []

        for tx in allTransactions {
            if tx.date < startStr {
                currentNetWorth += tx.netImpact
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
                    currentNetWorth += tx.netImpact
                }
                if let lastTxDate = txs.max(by: { $0.date < $1.date })?.date {
                    history.append(NetWorthDataPoint(date: lastTxDate, assets: "0", liabilities: "0", netWorth: String(currentNetWorth)))
                }
            }
        }

        return history
    }
}
