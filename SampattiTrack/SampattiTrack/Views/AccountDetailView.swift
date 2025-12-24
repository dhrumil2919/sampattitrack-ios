import SwiftUI
import SwiftData
import Charts

/// AccountDetailView - OFFLINE-FIRST
/// Enhanced with comprehensive KPI cards and investment metrics
struct AccountDetailView: View {
    let account: Account
    @StateObject private var viewModel: AccountDetailViewModel
    @Environment(\.modelContext) private var modelContext
    @Query private var accounts: [SDAccount]
    
    init(account: Account) {
        self.account = account
        _viewModel = StateObject(wrappedValue: AccountDetailViewModel(accountID: account.id))
    }
    
    var sdAccount: SDAccount? {
        accounts.first { $0.id == account.id }
    }
    
    var isInvestment: Bool {
        ["Investment", "Stock", "MutualFund", "Metal", "NPS"].contains(account.type)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Enhanced Header
                VStack(spacing: 8) {
                    Text(account.name)
                        .font(.title2)
                        .fontWeight(. bold)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    HStack {
                        Text(account.type)
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(6)
                        
                        Text(account.category.uppercased())
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                
                // KPI Cards Grid
                if isInvestment, let sdAcc = sdAccount {
                    VStack(spacing: 12) {
                        // Get values from metadata
                        let metaDict = sdAcc.metadataDictionary
                        let currentBalance = viewModel.balance
                        let investedAmount = metaDict?["invested_amount"] as? String
                        let currentValue = metaDict?["current_value"] as? String
                        let absoluteReturn = metaDict?["absolute_return"] as? String
                        let xirr = sdAcc.cachedXIRR
                        
                        // Calculate return percentage
                        let invested = investedAmount.flatMap({ Double($0) }) ?? 0
                        let absReturn = absoluteReturn.flatMap({ Double($0) }) ?? 0
                        let returnPct = invested > 0 ? (absReturn / invested) * 100 : 0
                        
                        // Get deposit/withdrawal from calculated metrics (if available)
                        let totalInvestment = viewModel.investmentMetrics?.totalDeposits ?? invested
                        let totalWithdrawal = viewModel.investmentMetrics?.totalWithdrawals ?? 0
                        
                        // Row 1: Current Balance and Net Investment
                        HStack(spacing: 12) {
                            KPICard(
                                title: "Current Balance",
                                value: CurrencyFormatter.format(String(invested + absReturn)),
                                color: .blue,
                                subtitle: nil
                            )
                            
                            KPICard(
                                title: "Net Investment",
                                value: CurrencyFormatter.format(investedAmount ?? "0"),
                                color: .cyan,
                                subtitle: nil
                            )
                        }
                        
                        // Row 2: Investment and Withdrawal
                        HStack(spacing: 12) {
                            KPICard(
                                title: "Investment",
                                value: CurrencyFormatter.format(String(totalInvestment)),
                                color: .green,
                                subtitle: nil
                            )
                            
                            KPICard(
                                title: "Withdrawal",
                                value: CurrencyFormatter.format(String(totalWithdrawal)),
                                color: .orange,
                                subtitle: nil
                            )
                        }
                        
                        // Row 3: Total Return and XIRR
                        HStack(spacing: 12) {
                            KPICard(
                                title: "Total Return",
                                value: CurrencyFormatter.format(absoluteReturn ?? "0"),
                                color: absReturn >= 0 ? .green : .red,
                                subtitle: String(format: "%.2f%%", returnPct)
                            )
                            
                            if let xirrValue = xirr {
                                KPICard(
                                    title: "XIRR",
                                    value: String(format: "%.2f%%", xirrValue),
                                    color: xirrValue >= 0 ? .green : .red,
                                    subtitle: "Annualized"
                                )
                            } else {
                                KPICard(
                                    title: "XIRR",
                                    value: "--",
                                    color: .gray,
                                    subtitle: "Not available"
                                )
                            }
                        }
                    }
                    .padding(.horizontal)
                } else {
                    // Simple balance card for non-investment accounts
                    KPICard(
                        title: "Current Balance",
                        value: CurrencyFormatter.format(String(viewModel.balance)),
                        color: account.category == "Liability" ? .red : .green,
                        subtitle: nil
                    )
                    .padding(.horizontal)
                }
                
                // Recent Transactions Link
                NavigationLink(destination: TransactionListView(accountID: account.id)) {
                    HStack {
                        Text("View All Transactions")
                            .fontWeight(.semibold)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(10)
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink(destination: EditAccountView(account: account)) {
                    Text("Edit")
                }
            }
        }
        .onAppear {
            // Inject container and fetch local data
            if let container = try? modelContext.container {
                viewModel.setContainer(container)
                
                // Load cached XIRR if available
                if let sdAcc = sdAccount {
                    viewModel.loadCachedXIRR(account: sdAcc)
                }
            }
        }
    }
}

// MARK: - KPI Card Component
struct KPICard: View {
    let title: String
    let value: String
    let color: Color
    let subtitle: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(color.opacity(0.8))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(10)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}
