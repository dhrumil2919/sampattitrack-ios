import SwiftUI
import SwiftData

struct DashboardView: View {
    @StateObject private var viewModel = DashboardViewModel()
    @Environment(\.modelContext) private var modelContext

    // Navigation States
    @State private var showingTagsView = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Time Range Picker
                    TimeRangePicker(selection: $viewModel.selectedRange)
                        .padding(.horizontal, -16) // Edge-to-edge

                    if viewModel.isLoading && viewModel.summary == nil {
                        ProgressView()
                            .padding(.top, 100)
                    } else if let summary = viewModel.summary {
                        
                        // Net Worth Hero Card
                        NetWorthCard(netWorth: summary.netWorth, growth: summary.netWorthGrowth)
                            .onTapGesture {
                                // Visualization removed
                            }
                        
                        // Quick Stats Grid
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                            StatCard(
                                icon: "arrow.up.circle.fill",
                                title: "Income",
                                value: CurrencyFormatter.format(summary.lastMonthIncome),
                                subtitle: "Avg Growth: \(String(format: "%.1f", summary.averageGrowthRate))%",
                                color: .green
                            )
                            
                            StatCard(
                                icon: "arrow.down.circle.fill",
                                title: "Expenses",
                                value: CurrencyFormatter.format(summary.lastMonthExpenses),
                                subtitle: "MoM: \(summary.expenseGrowth > 0 ? "+" : "")\(String(format: "%.1f", summary.expenseGrowth))%",
                                color: .red
                            )
                            
                            StatCard(
                                icon: "banknote.fill",
                                title: "Assets",
                                value: CurrencyFormatter.format(summary.totalAssets),
                                subtitle: nil,
                                color: .blue
                            )
                            
                            StatCard(
                                icon: "creditcard.fill",
                                title: "Liabilities",
                                value: CurrencyFormatter.formatInverted(summary.totalLiabilities),
                                subtitle: nil,
                                color: .orange
                            )
                        }
                        
                        // Savings Rate Card
                        SavingsRateCard(
                            rate: summary.savingsRate,
                            saved: summary.yearlySavings,
                            change: summary.savingsRateChange
                        )
                        
                        // NEW: KPI Metrics Grid
                        KPIGridView(
                            cashFlowRatio: summary.cashFlowRatio,
                            income: Double(summary.lastMonthIncome) ?? 0,
                            expenses: Double(summary.lastMonthExpenses) ?? 0,
                            monthlyBurnRate: summary.monthlyBurnRate,
                            expenseTrend: summary.expenseGrowth,
                            runwayDays: summary.runwayDays,
                            debtToAssetRatio: summary.debtToAssetRatio
                        )
                        
                        // Net Worth Trend (Chart component removed)
                        // if !viewModel.netWorthHistory.isEmpty {
                        //     NetWorthChart(data: viewModel.netWorthHistory)
                        //         .onTapGesture {
                        //             // Visualization removed
                        //         }
                        // }
                        
                        // TEMPORARILY DISABLED: New trend charts causing memory spike
                        // TODO: Investigate SwiftUI Charts memory usage with tuple data
                        /*
                        // NEW: MoM Expense Trend Chart with Average Line
                        if !viewModel.monthlyExpenses.isEmpty {
                            if #available(iOS 16.0, *) {
                                MoMExpenseTrendChart(monthlyData: viewModel.monthlyExpenses)
                            }
                        }
                        
                        // NEW: Income Trend Chart with Average Line
                        if !viewModel.monthlyIncome.isEmpty {
                            if #available(iOS 16.0, *) {
                                IncomeTrendChart(monthlyData: viewModel.monthlyIncome)
                            }
                        }
                        
                        // NEW: Income vs Expenses Comparison
                        if !viewModel.monthlyIncome.isEmpty || !viewModel.monthlyExpenses.isEmpty {
                            if #available(iOS 16.0, *) {
                                IncomeVsExpensesChart(
                                    monthlyIncome: viewModel.monthlyIncome,
                                    monthlyExpenses: viewModel.monthlyExpenses
                                )
                            }
                        }
                        
                        // NEW: Savings Trend Chart
                        if !viewModel.monthlySavings.isEmpty {
                            if #available(iOS 16.0, *) {
                                SavingsTrendChart(monthlyData: viewModel.monthlySavings)
                            }
                        }
                        */
                        
                        // Expense Pie Chart
                        if !viewModel.topTags.isEmpty {
                            if #available(iOS 17.0, *) {
                                DashboardCharts.ExpensePieChart(data: viewModel.topTags)
                                    .onTapGesture {
                                        showingTagsView = true
                                    }
                            }
                        }
                        
                        // Tag Spending Stacked Bar
                        if !viewModel.monthlyTagSpending.isEmpty {
                            if #available(iOS 16.0, *) {
                                DashboardCharts.TagSpendingChart(data: viewModel.monthlyTagSpending)
                            }
                        }
                        
                        // Portfolio KPI Grid  
                        if let portfolio = viewModel.portfolioMetrics {
                            PortfolioKPIGrid(metrics: portfolio)
                        }
                        
                        // Recent Transactions
                        if !viewModel.recentTransactions.isEmpty {
                            RecentTransactionsSection(
                                transactions: viewModel.recentTransactions
                            )
                        }
                        
                        // Hidden Links
                        NavigationLink(isActive: $showingTagsView) {
                            TagListView()
                        } label: { EmptyView() }

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
                viewModel.fetchAll()
            }
            .onAppear {
                viewModel.setContainer(modelContext.container)
                viewModel.fetchAll()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { AuthManager.shared.logout() }) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
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
