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

            // Calculate investment XIRR using client-side calculator
            let accountsDescriptor = FetchDescriptor<SDAccount>()
            let allAccounts = (try? context.fetch(accountsDescriptor)) ?? []
            let transactions = (try? context.fetch(FetchDescriptor<SDTransaction>())) ?? []
            
            let investments = allAccounts
                .filter { $0.type == "Investment" }
                .compactMap { account -> InvestmentXIRR? in
                    // Calculate XIRR using XIRRCalculator
                    let xirr = self.calculateInvestmentXIRR(
                        account: account,
                        transactions: transactions,
                        context: context
                    )
                    
                    // Only include if XIRR could be calculated
                    if let xirrValue = xirr {
                        return InvestmentXIRR(
                            id: account.id,
                            accountName: account.name,
                            xirr: xirrValue
                        )
                    }
                    return nil
                }
                .sorted { abs($0.xirr) > abs($1.xirr) }
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
    
    /// Calculate XIRR for an investment account using local transaction and price data
    private func calculateInvestmentXIRR(account: SDAccount, transactions: [SDTransaction], context: ModelContext) -> Double? {
        var dates: [Date] = []
        var amounts: [Double] = []
        
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        
        // Collect cash flows from transactions
        for tx in transactions {
            for posting in tx.postings ?? [] {
                if posting.accountID == account.id {
                    if let date = formatter.date(from: tx.date),
                       let amount = Double(posting.amount) {
                        dates.append(date)
                        amounts.append(amount)
                    }
                }
            }
        }
        
        guard !dates.isEmpty else { return nil }
        
        // Calculate current market value using latest prices
        var currentValue: Double = 0
        
        // Group postings by unit to calculate quantity held
        var unitQuantities: [String: Double] = [:]
        for tx in transactions {
            for posting in tx.postings ?? [] {
                if posting.accountID == account.id,
                   let unitCode = posting.unitCode,
                   let quantity = Double(posting.quantity ?? posting.amount) {
                    unitQuantities[unitCode, default: 0] += quantity
                }
            }
        }
        
        // Get latest prices for each unit
        for (unitCode, quantity) in unitQuantities {
            var priceFetchDesc = FetchDescriptor<SDPrice>(
                predicate: #Predicate { $0.unitCode == unitCode },
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            )
            priceFetchDesc.fetchLimit = 1
            
            if let latestPrice = try? context.fetch(priceFetchDesc).first,
               let priceValue = Double(latestPrice.price) {
                currentValue += quantity * priceValue
            }
        }
        
        // Add current value as final "exit" cash flow
        if currentValue > 0 {
            dates.append(Date())
            amounts.append(currentValue)  // Positive = current market value
        }
        
        return XIRRCalculator.calculateXIRR(dates: dates, amounts: amounts)
    }
}
