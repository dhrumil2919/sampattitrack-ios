import Foundation
import SwiftData
import Combine

/// Simple history point for account balance over time  
struct BalanceHistoryPoint: Identifiable {
    var id: String { date }
    let date: String
    let balance: Double
    let investedAmount: Double  // For investment accounts
}

/// Investment metrics for investment-type accounts
struct InvestmentMetrics {
    var netInvestment: Double = 0
    var totalDeposits: Double = 0
    var totalWithdrawals: Double = 0
    var totalReturn: Double = 0
    var returnPercentage: Double = 0
    var xirr: Double?  // Cached XIRR from API
}

/// AccountDetailViewModel - OFFLINE-FIRST
/// Uses local SwiftData for account details. No API calls.
class AccountDetailViewModel: ObservableObject {
    @Published var balance: Double = 0
    @Published var historyData: [BalanceHistoryPoint] = []
    @Published var investmentMetrics: InvestmentMetrics?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    let accountID: String
    private var container: ModelContainer?
    
    init(accountID: String) {
        self.accountID = accountID
    }
    
    func setContainer(_ container: ModelContainer) {
        self.container = container
        fetchBalance()
    }
    
    /// Fetch balance and metrics from LOCAL transactions - no API call
    func fetchBalance() {
        guard let container = container else { return }
        
        Task.detached(priority: .userInitiated) {
            let context = ModelContext(container)
            context.autosaveEnabled = false
            
            // Calculate balance from local transactions
            let descriptor = FetchDescriptor<SDTransaction>()
            let transactions = (try? context.fetch(descriptor)) ?? []
            
            var total: Double = 0
            var history: [BalanceHistoryPoint] = []
            var runningBalance: Double = 0
            var runningInvested: Double = 0
            
            var totalDeposits: Double = 0
            var totalWithdrawals: Double = 0
            
            // Sort transactions by date
            let sortedTx = transactions.sorted { $0.date < $1.date }
            
            for tx in sortedTx {
                var txInvestmentChange: Double = 0
                var txBalanceChange: Double = 0
                
                for posting in tx.postings ?? [] {
                    if posting.accountID == self.accountID {
                        let amount = Double(posting.amount) ?? 0
                        total += amount
                        runningBalance += amount
                        txBalanceChange += amount
                        
                        // Track investment flow (deposits = positive, withdrawals = negative)
                        // For investment accounts, we consider inflow/outflow
                        if amount > 0 {
                            totalDeposits += amount
                            txInvestmentChange += amount
                        } else {
                            totalWithdrawals += abs(amount)
                            txInvestmentChange += amount  // negative
                        }
                    }
                }
                
                runningInvested += txInvestmentChange
                
                // Add history point for transactions involving this account
                let hasAccount = tx.postings?.contains { $0.accountID == self.accountID } ?? false
                if hasAccount {
                    history.append(BalanceHistoryPoint(
                        date: tx.date,
                        balance: runningBalance,
                        investedAmount: runningInvested
                    ))
                }
            }
            
            // Calculate investment metrics
            let investmentMetrics = InvestmentMetrics(
                netInvestment: runningInvested,
                totalDeposits: totalDeposits,
                totalWithdrawals: totalWithdrawals,
                totalReturn: total - runningInvested,
                returnPercentage: runningInvested != 0 ? ((total - runningInvested) / abs(runningInvested)) * 100 : 0,
                xirr: nil  // Will be fetched from API and cached
            )
            
            await MainActor.run {
                self.balance = total
                self.historyData = Array(history.suffix(90))  // Last 90 days
                self.investmentMetrics = investmentMetrics
                self.isLoading = false
            }
        }
    }
    
    /// Fetch and cache XIRR from API
    func fetchXIRR(apiClient: APIClient, account: SDAccount, context: ModelContext) async {
        do {
            let response = try await apiClient.request(
                "/api/v1/analysis/xirr/\(accountID)",
                method: "GET",
                body: nil as String?
            )
            
            if let data = response.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let dataObj = json["data"] as? [String: Any],
               let xirr = dataObj["xirr"] as? Double {
                
                // Cache in SDAccount
                await MainActor.run {
                    account.cachedXIRR = xirr
                    account.xirrCachedAt = Date()
                    try? context.save()
                    
                    // Update published metrics
                    if var metrics = self.investmentMetrics {
                        metrics.xirr = xirr
                        self.investmentMetrics = metrics
                    }
                }
            }
        } catch {
            print("[XIRR] Failed to fetch XIRR for \(accountID): \(error)")
        }
    }
}
