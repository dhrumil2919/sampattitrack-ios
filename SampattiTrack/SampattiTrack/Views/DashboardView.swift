import SwiftUI
import SwiftData

struct DashboardView: View {
    @StateObject private var viewModel = DashboardViewModel()
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var syncManager: SyncManager
    @EnvironmentObject var networkMonitor: NetworkMonitor
    
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Time Range Picker - PRESERVED
                    TimeRangePicker(selection: $viewModel.selectedRange)
                        .padding(.horizontal, -16) // Edge-to-edge

                    if viewModel.isLoading && viewModel.summary == nil {
                        ProgressView()
                            .padding(.top, 100)
                    } else if let summary = viewModel.summary {
                        
                        // Net Worth Hero Card with Navigation
                        NavigationLink(destination: NetWorthGrowthView(
                            netWorthHistory: viewModel.netWorthHistory,
                            currentNetWorth: summary.netWorth,
                            growth: summary.netWorthGrowth
                        )) {
                            NetWorthCard(netWorth: summary.netWorth, growth: summary.netWorthGrowth)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // Quick Stats Grid
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                            NavigationLink(destination: MOMDetailView(
                                title: "Income Trend",
                                data: viewModel.prepareMOMData(from: viewModel.cashFlowData) { $0.incomeValue },
                                valueFormatter: { CurrencyFormatter.format(String($0)) },
                                color: .green
                            )) {
                                StatCard(
                                    icon: "arrow.up.circle.fill",
                                    title: "Income",
                                    value: CurrencyFormatter.format(summary.lastMonthIncome),
                                    subtitle: "Avg Growth: \(String(format: "%.1f", summary.averageGrowthRate))%",
                                    color: .green
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            NavigationLink(destination: MOMDetailView(
                                title: "Expense Trend",
                                data: viewModel.prepareMOMData(from: viewModel.cashFlowData) { $0.expenseValue },
                                valueFormatter: { CurrencyFormatter.format(String($0)) },
                                color: .red
                            )) {
                                StatCard(
                                    icon: "arrow.down.circle.fill",
                                    title: "Expenses",
                                    value: CurrencyFormatter.format(summary.lastMonthExpenses),
                                    subtitle: "MoM: \(summary.expenseGrowth > 0 ? "+" : "")\(String(format: "%.1f", summary.expenseGrowth))%",
                                    color: .red
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            NavigationLink(destination: HierarchicalAssetsView(
                                assets: viewModel.portfolioAssets,
                                totalAssets: summary.totalAssets,
                                totalLiabilities: summary.totalLiabilities,
                                parentPath: "Assets"  // Start from children of Assets
                            )) {
                                StatCard(
                                    icon: "banknote.fill",
                                    title: "Assets",
                                    value: CurrencyFormatter.format(summary.totalAssets),
                                    subtitle: nil,
                                    color: .blue
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            StatCard(
                                icon: "creditcard.fill",
                                title: "Liabilities",
                                value: CurrencyFormatter.format(summary.totalLiabilities),
                                subtitle: nil,
                                color: .red
                            )
                            
                            // Checking Accounts Card - shows individual bank accounts
                            NavigationLink(destination: AccountsListView(
                                title: "Checking Accounts",
                                accounts: viewModel.portfolioAssets.filter { 
                                    $0.accountID.hasPrefix("Assets:Checking:") && 
                                    $0.accountID.components(separatedBy: ":").count == 3  // Direct children only
                                }
                            )) {
                                let checkingTotal = viewModel.portfolioAssets
                                    .filter { $0.accountID.hasPrefix("Assets:Checking:") }
                                    .reduce(0) { $0 + $1.currentValueValue }
                                StatCard(
                                    icon: "building.columns.fill",
                                    title: "Checking",
                                    value: CurrencyFormatter.format(String(checkingTotal)),
                                    subtitle: nil,
                                    color: .purple
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            // Wallet Accounts Card
                            NavigationLink(destination: AccountsListView(
                                title: "Wallet Accounts",
                                accounts: viewModel.portfolioAssets.filter { 
                                    $0.accountID.hasPrefix("Assets:Wallet:") && 
                                    $0.accountID.components(separatedBy: ":").count == 3
                                }
                            )) {
                                let walletTotal = viewModel.portfolioAssets
                                    .filter { $0.accountID.hasPrefix("Assets:Wallet:") }
                                    .reduce(0) { $0 + $1.currentValueValue }
                                StatCard(
                                    icon: "wallet.pass.fill",
                                    title: "Wallet",
                                    value: CurrencyFormatter.format(String(walletTotal)),
                                    subtitle: nil,
                                    color: .orange
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        
                        // Savings Rate Card with Navigation
                        NavigationLink(destination: MOMDetailView(
                            title: "Savings Trend",
                            data: viewModel.prepareMOMData(from: viewModel.cashFlowData) { $0.netSavingsValue },
                            valueFormatter: { CurrencyFormatter.format(String($0)) },
                            color: .blue
                        )) {
                            SavingsRateCard(
                                rate: summary.savingsRate,
                                saved: summary.yearlySavings,
                                change: summary.savingsRateChange
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // KPI Metrics Grid
                        KPIGridView(
                            cashFlowRatio: summary.cashFlowRatio,
                            income: Double(summary.lastMonthIncome) ?? 0,
                            expenses: Double(summary.lastMonthExpenses) ?? 0,
                            monthlyBurnRate: summary.monthlyBurnRate,
                            expenseTrend: summary.expenseGrowth,
                            runwayDays: summary.runwayDays,
                            debtToAssetRatio: summary.debtToAssetRatio
                        )
                        
                        // Tax Information Cards with Navigation
                        if let taxAnalysis = viewModel.taxAnalysis {
                            NavigationLink(destination: TaxDetailView(taxAnalysis: taxAnalysis)) {
                                TaxCard(taxAnalysis: taxAnalysis)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        
                        if let capitalGains = viewModel.capitalGains {
                            NavigationLink(destination: CapitalGainsDetailView(capitalGains: capitalGains, history: viewModel.capitalGainsHistory)) {
                                CapitalGainsCard(capitalGains: capitalGains)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        
                        // Portfolio KPI Grid with Hierarchical Navigation (Investment accounts only)
                        if let portfolio = viewModel.portfolioMetrics, !viewModel.portfolioAssets.isEmpty {
                            NavigationLink(destination: HierarchicalPortfolioView(
                                assets: viewModel.portfolioAssets,
                                parentPath: "Assets"  // Start from children: Equity, Gold, NPS, etc.
                            )) {
                                PortfolioSummaryCard(metrics: portfolio)
                            }
                            .buttonStyle(PlainButtonStyle())
                        } else if let portfolio = viewModel.portfolioMetrics {
                            PortfolioSummaryCard(metrics: portfolio)
                        }
                        
                        // REMOVED: All chart components
                        // - MoMExpenseTrendChart
                        // - IncomeTrendChart
                        // - IncomeVsExpensesChart
                        // - SavingsTrendChart
                        // - ExpensePieChart
                        // - TagSpendingChart
                        
                        // Recent Transactions
                        if !viewModel.recentTransactions.isEmpty {
                            RecentTransactionsSection(
                                transactions: viewModel.recentTransactions
                            )
                        }

                    } else if let error = viewModel.errorMessage {
                        VStack(spacing: 16) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.largeTitle)
                                .foregroundColor(.red)
                            Text(error)
                                .foregroundColor(.secondary)
                            Button("Retry") {
                                viewModel.fetchAll()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding(.top, 100)
                    }
                }
                .padding()
            }
            .navigationTitle("Dashboard")
            .refreshable {
                // OFFLINE-FIRST: refreshable only triggers local view refresh, not blocking sync
                viewModel.fetchAll()
            }
            .onAppear {
                viewModel.setContainer(modelContext.container)
                viewModel.syncManager = syncManager
                viewModel.networkMonitor = networkMonitor
                viewModel.fetchAll()
            }
            .toolbar {
                // OFFLINE-FIRST: Show sync/network status
                ToolbarItem(placement: .navigationBarLeading) {
                    HStack(spacing: 8) {
                        if viewModel.syncManager?.isSyncing == true {
                            ProgressView()
                                .controlSize(.small)
                        } else if viewModel.networkMonitor?.isConnected == false {
                            Image(systemName: "wifi.slash")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }

                        // Backend Status & Last Sync
                        if let lastSync = viewModel.syncManager?.lastSyncDate {
                            VStack(alignment: .leading, spacing: 0) {
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(viewModel.syncManager?.backendStatus == .online ? Color.green : (viewModel.syncManager?.backendStatus == .offline ? Color.red : Color.gray))
                                        .frame(width: 8, height: 8)
                                    Text(viewModel.syncManager?.backendStatus == .online ? "Online" : "Offline")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                Text("Synced: " + lastSync.formatted(date: .omitted, time: .shortened))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        // DEBUG: Debug menu for clearing cache/queue
                        Menu {
                            Button(role: .destructive) {
                                Task {
                                    await syncManager.clearSyncQueue()
                                }
                            } label: {
                                Label("Clear Sync Queue", systemImage: "trash")
                            }
                            
                            Button(role: .destructive) {
                                Task {
                                    await syncManager.clearAllData()
                                    // Pull fresh data after clearing
                                    await syncManager.syncAll()
                                }
                            } label: {
                                Label("Clear All & Re-sync", systemImage: "arrow.clockwise")
                            }

                            Divider()

                            Menu("Sync Interval") {
                                Button("30 seconds") { syncManager.updateSyncInterval(30) }
                                Button("1 Minute") { syncManager.updateSyncInterval(60) }
                                Button("5 Minutes") { syncManager.updateSyncInterval(300) }
                                Button("15 Minutes") { syncManager.updateSyncInterval(900) }
                                Button("Manual Only") { syncManager.updateSyncInterval(0) }
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                        
                        Button(action: { AuthManager.shared.logout() }) {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                        }
                    }
                }
            }
        }
    }
}
// MARK: - Hero Card
struct NetWorthCard: View {
    let netWorth: String
    let growth: Double
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(.white.opacity(0.8))
                Text("Net Worth")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                Image(systemName: "chevron.right")
                     .font(.caption)
                     .foregroundColor(.white.opacity(0.5))
            }
            Text(CurrencyFormatter.format(netWorth))
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(.white)

            HStack(spacing: 4) {
                Image(systemName: growth >= 0 ? "arrow.up.right" : "arrow.down.right")
                Text("\(growth > 0 ? "+" : "")\(String(format: "%.1f", growth))% MoM")
            }
            .font(.caption)
            .foregroundColor(.white.opacity(0.9))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.2))
            .cornerRadius(8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(
            LinearGradient(
                colors: [Color.blue, Color.purple],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
        .shadow(color: .blue.opacity(0.4), radius: 15, x: 0, y: 8)
    }
}

// MARK: - Stat Card
struct StatCard: View {
    let icon: String
    let title: String
    let value: String
    let subtitle: String?
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(color)
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5)
    }
}

// MARK: - Savings Rate
struct SavingsRateCard: View {
    let rate: Double
    let saved: String
    let change: Double
    
    var body: some View {
        HStack {
            Image(systemName: "leaf.fill")
                .font(.title)
                .foregroundColor(.green)
            
            VStack(alignment: .leading) {
                Text("Savings Rate")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                HStack(alignment: .lastTextBaseline) {
                    Text(String(format: "%.1f%%", rate))
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("\(change > 0 ? "+" : "")\(String(format: "%.1f", change))%")
                        .font(.caption)
                        .foregroundColor(change >= 0 ? .green : .red)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing) {
                Text("YTD Saved")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(CurrencyFormatter.format(saved))
                    .font(.headline)
                    .foregroundColor(.green)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5)
    }
}

// MARK: - Portfolio KPI Grid
struct PortfolioKPIGrid: View {
    let metrics: AggregatePortfolioMetrics
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(.purple)
                Text("Portfolio Overview")
                    .font(.headline)
            }
            
            // Row 1: Invested & Current Value
            HStack(spacing: 12) {
                KPICard(
                    title: "Total Invested",
                    value: CurrencyFormatter.format(String(metrics.totalInvested)),
                    color: .blue,
                    subtitle: nil
                )
                KPICard(
                    title: "Current Value",
                    value: CurrencyFormatter.format(String(metrics.totalCurrentValue)),
                    color: .cyan,
                    subtitle: nil
                )
            }
            
            // Row 2: Return & XIRR
            HStack(spacing: 12) {
                KPICard(
                    title: "Total Return",
                    value: CurrencyFormatter.format(String(metrics.totalAbsoluteReturn)),
                    color: metrics.totalAbsoluteReturn >= 0 ? .green : .red,
                    subtitle: String(format: "%.2f%%", metrics.returnPercentage)
                )
                KPICard(
                    title: "Weighted XIRR",
                    value: String(format: "%.2f%%", metrics.weightedXIRR),
                    color: metrics.weightedXIRR >= 0 ? .green : .red,
                    subtitle: "Annualized"
                )
            }

            // Groups Breakdown
            if !metrics.groups.isEmpty {
                ForEach(metrics.groups) { group in
                    Divider()
                        .padding(.vertical, 8)

                    VStack(alignment: .leading, spacing: 8) {
                        Text(group.name)
                            .font(.headline)
                            .foregroundColor(.secondary)

                        // 2x2 Grid for Group
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            // Invested
                            VStack(alignment: .leading) {
                                Text("Invested")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(CurrencyFormatter.format(String(group.totalInvested)))
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.blue)
                            }

                            // Current
                            VStack(alignment: .leading) {
                                Text("Current")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(CurrencyFormatter.format(String(group.totalCurrentValue)))
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.cyan)
                            }

                            // Return
                            VStack(alignment: .leading) {
                                Text("Return")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                HStack(spacing: 2) {
                                    Text(CurrencyFormatter.format(String(group.totalAbsoluteReturn)))
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(group.totalAbsoluteReturn >= 0 ? .green : .red)
                                    Text("(\(String(format: "%.1f%%", group.returnPercentage)))")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }

                            // XIRR
                            VStack(alignment: .leading) {
                                Text("XIRR")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(String(format: "%.2f%%", group.weightedXIRR))
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(group.weightedXIRR >= 0 ? .green : .red)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground).opacity(0.5))
                    .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5)
    }
}

// MARK: - Recent Transactions
struct RecentTransactionsSection: View {
    let transactions: [Transaction]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundColor(.orange)
                Text("Recent Transactions")
                    .font(.headline)
            }
            
            ForEach(transactions) { tx in
                HStack {
                    // Use Transaction's determineType for color  
                    let txType = tx.determineType()
                    
                    Image(systemName: txType == .income ? "arrow.down.circle.fill" : 
                            (txType == .expense ? "arrow.up.circle.fill" : "arrow.left.arrow.right.circle.fill"))
                        .foregroundColor(txType == .income ? .green : 
                            (txType == .expense ? .red : .blue))
                    
                    VStack(alignment: .leading) {
                        Text(tx.description)
                            .font(.subheadline)
                            .lineLimit(1)
                        Text(tx.date)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Text(CurrencyFormatter.formatCheck(tx.displayAmount))
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5)
    }
}

// MARK: - Tax Card
struct TaxCard: View {
    let taxAnalysis: TaxAnalysis
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "doc.text.fill")
                    .foregroundColor(.purple)
                Text("Income Tax (Current FY)")
                    .font(.headline)
            }
            
            HStack(spacing: 12) {
                VStack(alignment: .leading) {
                    Text("Current FY Tax")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if !taxAnalysis.breakdown.isEmpty, let latest = taxAnalysis.breakdown.last {
                        Text(CurrencyFormatter.format(latest.taxPaid))
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.purple)
                    } else {
                        Text(CurrencyFormatter.format("0"))
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.purple)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("Effective Rate")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.2f%%", taxAnalysis.taxRate))
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.purple)
                }
            }
            
            Divider()

            HStack {
                Text("Total Tax Paid: \(CurrencyFormatter.format(taxAnalysis.totalTax))")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                if !taxAnalysis.breakdown.isEmpty, let latest = taxAnalysis.breakdown.last {
                     Text("FY \(latest.year)-\((latest.year + 1) % 100)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5)
    }
}

// MARK: - Capital Gains Card
struct CapitalGainsCard: View {
    let capitalGains: CapitalGainsReport
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(.orange)
                Text("Capital Gains (FY \(String(capitalGains.year))-\(String((capitalGains.year + 1) % 100)))")
                    .font(.headline)
            }
            
            // STCG and LTCG Row
            HStack(spacing: 12) {
                VStack(alignment: .leading) {
                    Text("STCG")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(CurrencyFormatter.format(capitalGains.totalSTCG))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(capitalGains.totalSTCGValue >= 0 ? .green : .red)
                }
                
                VStack(alignment: .leading) {
                    Text("LTCG")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(CurrencyFormatter.format(capitalGains.totalLTCG))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(capitalGains.totalLTCGValue >= 0 ? .green : .red)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("Total Tax")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(CurrencyFormatter.format(capitalGains.totalTax))
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5)
    }
}

// MARK: - Portfolio Summary Card (Simplified)
struct PortfolioSummaryCard: View {
    let metrics: AggregatePortfolioMetrics
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(.purple)
                Text("Portfolio")
                    .font(.headline)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Row 1: Invested & Current Value
            HStack(spacing: 12) {
                KPICard(
                    title: "Invested",
                    value: CurrencyFormatter.format(String(metrics.totalInvested)),
                    color: .blue,
                    subtitle: nil
                )
                KPICard(
                    title: "Current",
                    value: CurrencyFormatter.format(String(metrics.totalCurrentValue)),
                    color: .cyan,
                    subtitle: nil
                )
            }
            
            // Row 2: Return & XIRR
            HStack(spacing: 12) {
                KPICard(
                    title: "Return",
                    value: CurrencyFormatter.format(String(metrics.totalAbsoluteReturn)),
                    color: metrics.totalAbsoluteReturn >= 0 ? .green : .red,
                    subtitle: String(format: "%.2f%%", metrics.returnPercentage)
                )
                KPICard(
                    title: "XIRR",
                    value: String(format: "%.2f%%", metrics.weightedXIRR),
                    color: metrics.weightedXIRR >= 0 ? .green : .red,
                    subtitle: "Annualized"
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5)
    }
}

