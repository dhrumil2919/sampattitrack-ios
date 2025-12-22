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

    static func last30Days() -> DateRange {
        let now = Date()
        let start = Calendar.current.date(byAdding: .day, value: -30, to: now)!
        return DateRange(start: start, end: now, name: "Last 30 Days")
    }

    static func all() -> DateRange {
         return DateRange(start: Date.distantPast, end: Date(), name: "All Time")
    }
}

class DashboardCalculator {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Summary

    func calculateSummary(range: DateRange) -> ClientDashboardData {
        let transactions = fetchTransactions(in: range)

        let income = calculateTotal(transactions: transactions, type: .income)
        let expenses = calculateTotal(transactions: transactions, type: .expense)

        // YTD Logic needs a separate query if range is not YTD
        let ytdRange = DateRange.ytd()
        let ytdTransactions = fetchTransactions(in: ytdRange)
        let ytdIncome = calculateTotal(transactions: ytdTransactions, type: .income)
        let ytdExpenses = calculateTotal(transactions: ytdTransactions, type: .expense)
        let ytdSavings = ytdIncome - ytdExpenses

        // Net Worth is point-in-time (Now)
        let (assets, liabilities) = calculateNetWorthComponents()
        let netWorth = assets + liabilities // Liabilities are negative

        let savingsRate = income > 0 ? ((income - expenses) / income) * 100 : 0.0

        let avgGrowth = calculateAverageGrowthRate(range: range)

        return ClientDashboardData(
            netWorth: String(netWorth),
            lastMonthIncome: String(income),
            lastMonthExpenses: String(expenses),
            yearlyIncome: String(ytdIncome),
            yearlyExpenses: String(ytdExpenses),
            totalAssets: String(assets),
            totalLiabilities: String(liabilities), // keeping sign logic consistent with display
            savingsRate: savingsRate,
            yearlySavings: String(ytdSavings),
            averageGrowthRate: avgGrowth
        )
    }

    // MARK: - Charts

    func calculateNetWorthHistory(range: DateRange) -> [NetWorthDataPoint] {
        // 1. Calculate Opening Balance (Net Worth) at `range.start`
        // Sum of all postings before start date where account type is Asset (+) or Liability (-)

        let start = range.start
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        let startStr = formatter.string(from: start)
        let endStr = formatter.string(from: range.end)

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

        let allTransactions = fetchAllTransactions()

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
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        let startStr = formatter.string(from: range.start)
        let endStr = formatter.string(from: range.end)

        // Fetch all and filter in memory if Predicate fails on strings?
        // String comparison works for ISO8601.

        // However, SwiftData Predicate is restrictive.
        // Let's try to use a Predicate.
        let descriptor = FetchDescriptor<SDTransaction>(
            predicate: #Predicate { $0.date >= startStr && $0.date <= endStr }
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private func fetchAllTransactions() -> [SDTransaction] {
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

    private func calculateNetWorthComponents() -> (Double, Double) {
        // Fetch all accounts to determine category
        // Then sum balances? No, we need sum of all postings ever for those accounts.

        let descriptor = FetchDescriptor<SDPosting>()
        // This might be huge. Optimization: Fetch accounts, then perform aggregation?
        // SwiftData doesn't support aggregate queries well yet.
        // Alternative: Iterate all transactions? Slow.

        // Let's stick to iterating all transactions/postings once or maintaining a cache.
        // For now, iterating all postings.

        let allPostings = (try? modelContext.fetch(descriptor)) ?? []

        var assets: Double = 0
        var liabilities: Double = 0

        for p in allPostings {
            if let cat = p.category {
                if cat == "Assets" || cat == "Asset" {
                    assets += Double(p.amount) ?? 0
                } else if cat == "Liabilities" || cat == "Liability" {
                    liabilities += Double(p.amount) ?? 0
                }
            }
        }

        return (assets, liabilities)
    }

    private func calculateAverageGrowthRate(range: DateRange) -> Double {
        // Average Month-over-Month Growth Rate (%)

        let history = calculateNetWorthHistory(range: range)
        // History is now grouped by month (mostly)

        guard history.count >= 2 else { return 0 }

        var growths: [Double] = []

        // Compare consecutive points (which represent month ends)
        for i in 1..<history.count {
            let prev = Double(history[i-1].netWorthValue)
            let curr = Double(history[i].netWorthValue)

            if prev != 0 {
                let growth = (curr - prev) / abs(prev)
                growths.append(growth)
            }
        }

        guard !growths.isEmpty else { return 0 }
        let avg = growths.reduce(0, +) / Double(growths.count)
        return avg * 100
    }
}
