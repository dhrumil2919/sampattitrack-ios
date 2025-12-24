import SwiftUI
import Charts

// MARK: - Month-over-Month Expense Trend with Average Line
@available(iOS 16.0, *)
struct MoMExpenseTrendChart: View {
    let monthlyData: [(month: String, amount: Double)]
    
    private var average: Double {
        guard !monthlyData.isEmpty else { return 0 }
        return monthlyData.reduce(0) { $0 + $1.amount } / Double(monthlyData.count)
    }
    
    private var trend: Double {
        guard monthlyData.count >= 2 else { return 0 }
        let current = monthlyData.last?.amount ?? 0
        let previous = monthlyData[monthlyData.count - 2].amount
        guard previous > 0 else { return 0 }
        return ((current - previous) / previous) * 100
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.line.downtrend.xyaxis")
                    .foregroundColor(.red)
                Text("Expense Trend")
                    .font(.headline)
                Spacer()
                
                // Trend Badge
                HStack(spacing: 4) {
                    Image(systemName: trend <= 0 ? "arrow.down.right" : "arrow.up.right")
                    Text("\(trend > 0 ? "+" : "")\(String(format: "%.1f", trend))%")
                }
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(trend <= 0 ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
                .foregroundColor(trend <= 0 ? .green : .red)
                .cornerRadius(6)
            }
            
            if monthlyData.isEmpty {
                Text("No expense data available")
                    .foregroundColor(.secondary)
                    .frame(height: 150)
                    .frame(maxWidth: .infinity)
            } else {
                Chart {
                    // Line chart for monthly expenses (Timeline based)
                    ForEach(Array(monthlyData.enumerated()), id: \.offset) { index, item in
                        LineMark(
                            x: .value("Month", item.month),
                            y: .value("Amount", item.amount)
                        )
                        .foregroundStyle(Color.red.gradient)
                        .interpolationMethod(.catmullRom)
                        .symbol(Circle())
                    }
                    
                    // Average line
                    RuleMark(y: .value("Average", average))
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                        .foregroundStyle(.orange)
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisValueLabel {
                            if let doubleValue = value.as(Double.self) {
                                Text(CurrencyFormatter.formatCompact(doubleValue))
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .frame(height: 180)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5)
    }
}

// MARK: - Income Trend Chart with Average
@available(iOS 16.0, *)
struct IncomeTrendChart: View {
    let monthlyData: [(month: String, amount: Double)]
    
    private var average: Double {
        guard !monthlyData.isEmpty else { return 0 }
        return monthlyData.reduce(0) { $0 + $1.amount } / Double(monthlyData.count)
    }
    
    private var trend: Double {
        guard monthlyData.count >= 2 else { return 0 }
        let current = monthlyData.last?.amount ?? 0
        let previous = monthlyData[monthlyData.count - 2].amount
        guard previous > 0 else { return 0 }
        return ((current - previous) / previous) * 100
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(.green)
                Text("Income Trend")
                    .font(.headline)
                Spacer()
                
                // Trend Badge
                HStack(spacing: 4) {
                    Image(systemName: trend >= 0 ? "arrow.up.right" : "arrow.down.right")
                    Text("\(trend > 0 ? "+" : "")\(String(format: "%.1f", trend))%")
                }
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(trend >= 0 ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
                .foregroundColor(trend >= 0 ? .green : .red)
                .cornerRadius(6)
            }
            
            if monthlyData.isEmpty {
                Text("No income data available")
                    .foregroundColor(.secondary)
                    .frame(height: 150)
                    .frame(maxWidth: .infinity)
            } else {
                Chart {
                    // Line with area for income
                    ForEach(Array(monthlyData.enumerated()), id: \.offset) { index, item in
                        LineMark(
                            x: .value("Month", item.month),
                            y: .value("Amount", item.amount)
                        )
                        .foregroundStyle(Color.green.gradient)
                        .interpolationMethod(.catmullRom)
                        .symbol(Circle())
                        .symbolSize(40)
                        
                        AreaMark(
                            x: .value("Month", item.month),
                            y: .value("Amount", item.amount)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.green.opacity(0.3), Color.green.opacity(0.05)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.catmullRom)
                    }
                    
                    // Average line
                    RuleMark(y: .value("Average", average))
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                        .foregroundStyle(.blue)
                        .annotation(position: .top, alignment: .leading) {
                            Text("Avg: \(CurrencyFormatter.formatCheck(average))")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(.blue)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(4)
                        }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisValueLabel {
                            if let doubleValue = value.as(Double.self) {
                                Text(CurrencyFormatter.formatCompact(doubleValue))
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .frame(height: 180)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5)
    }
}

// MARK: - Income vs Expenses Comparison Chart
@available(iOS 16.0, *)
struct IncomeVsExpensesChart: View {
    let monthlyIncome: [(month: String, amount: Double)]
    let monthlyExpenses: [(month: String, amount: Double)]
    
    private var savingsData: [(month: String, savings: Double)] {
        // Combine income and expenses to calculate savings per month
        var result: [(month: String, savings: Double)] = []
        let incomeMap = Dictionary(uniqueKeysWithValues: monthlyIncome.map { ($0.month, $0.amount) })
        let expenseMap = Dictionary(uniqueKeysWithValues: monthlyExpenses.map { ($0.month, $0.amount) })
        
        let allMonths = Set(incomeMap.keys).union(Set(expenseMap.keys)).sorted()
        for month in allMonths {
            let income = incomeMap[month] ?? 0
            let expense = expenseMap[month] ?? 0
            result.append((month: month, savings: income - expense))
        }
        return result
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.bar.xaxis")
                    .foregroundColor(.indigo)
                Text("Income vs Expenses")
                    .font(.headline)
                Spacer()
            }
            
            if monthlyIncome.isEmpty && monthlyExpenses.isEmpty {
                Text("No data available")
                    .foregroundColor(.secondary)
                    .frame(height: 180)
                    .frame(maxWidth: .infinity)
            } else {
                Chart {
                    // Income bars
                    ForEach(Array(monthlyIncome.enumerated()), id: \.offset) { _, item in
                        BarMark(
                            x: .value("Month", item.month),
                            y: .value("Amount", item.amount)
                        )
                        .foregroundStyle(Color.green.gradient)
                        .position(by: .value("Type", "Income"))
                    }
                    
                    // Expense bars
                    ForEach(Array(monthlyExpenses.enumerated()), id: \.offset) { _, item in
                        BarMark(
                            x: .value("Month", item.month),
                            y: .value("Amount", item.amount)
                        )
                        .foregroundStyle(Color.red.gradient)
                        .position(by: .value("Type", "Expenses"))
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisValueLabel {
                            if let doubleValue = value.as(Double.self) {
                                Text(CurrencyFormatter.formatCompact(doubleValue))
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .frame(height: 180)
                
                // Legend
                HStack(spacing: 16) {
                    HStack(spacing: 4) {
                        Circle().fill(Color.green).frame(width: 8, height: 8)
                        Text("Income").font(.caption2).foregroundColor(.secondary)
                    }
                    HStack(spacing: 4) {
                        Circle().fill(Color.red).frame(width: 8, height: 8)
                        Text("Expenses").font(.caption2).foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5)
    }
}

// MARK: - Savings Trend Chart
@available(iOS 16.0, *)
struct SavingsTrendChart: View {
    let monthlyData: [(month: String, rate: Double, absolute: Double)]
    
    private var trend: Double {
        guard monthlyData.count >= 2 else { return 0 }
        let current = monthlyData.last?.absolute ?? 0
        let previous = monthlyData[monthlyData.count - 2].absolute
        guard abs(previous) > 0 else { return 0 }
        return ((current - previous) / abs(previous)) * 100
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "leaf.fill")
                    .foregroundColor(.teal)
                Text("Savings Trend")
                    .font(.headline)
                Spacer()
                
                // MoM Change Badge
                HStack(spacing: 4) {
                    Image(systemName: trend >= 0 ? "arrow.up.right" : "arrow.down.right")
                    Text("\(trend > 0 ? "+" : "")\(String(format: "%.1f", trend))%")
                }
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(trend >= 0 ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
                .foregroundColor(trend >= 0 ? .green : .red)
                .cornerRadius(6)
            }
            
            if monthlyData.isEmpty {
                Text("No savings data available")
                    .foregroundColor(.secondary)
                    .frame(height: 150)
                    .frame(maxWidth: .infinity)
            } else {
                Chart {
                    ForEach(Array(monthlyData.enumerated()), id: \.offset) { _, item in
                        // Absolute Savings Bar
                        BarMark(
                            x: .value("Month", item.month),
                            y: .value("Savings", item.absolute)
                        )
                        .foregroundStyle(item.absolute >= 0 ? Color.teal.opacity(0.5) : Color.red.opacity(0.5))
                        .cornerRadius(4)
                    }
                    
                    // Zero line
                    RuleMark(y: .value("Zero", 0))
                        .lineStyle(StrokeStyle(lineWidth: 1))
                        .foregroundStyle(.gray.opacity(0.5))
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisValueLabel {
                            if let doubleValue = value.as(Double.self) {
                                Text(CurrencyFormatter.formatCompact(doubleValue))
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .frame(height: 180)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5)
    }
}
