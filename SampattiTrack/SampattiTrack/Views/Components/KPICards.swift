import SwiftUI

// MARK: - KPI Card Base Style
struct KPICardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 5)
    }
}

extension View {
    func kpiCardStyle() -> some View {
        modifier(KPICardStyle())
    }
}

// MARK: - Cash Flow KPI Card
struct CashFlowKPICard: View {
    let ratio: Double
    let income: Double
    let expenses: Double
    
    private var displayRatio: String {
        if ratio.isInfinite { return "∞" }
        return String(format: "%.2fx", ratio)
    }
    
    private var progressValue: Double {
        if ratio.isInfinite { return 1.0 }
        return min(max(ratio / 2.0, 0), 1.0) // Normalize to 0-1 range
    }
    
    private var statusColor: Color {
        if ratio >= 1.5 { return .green }
        if ratio >= 1.0 { return .orange }
        return .red
    }
    
    private var statusText: String {
        if ratio >= 1.5 { return "Excellent" }
        if ratio >= 1.0 { return "Positive" }
        return "Negative"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "arrow.left.arrow.right.circle.fill")
                    .foregroundColor(.blue)
                Text("Cash Flow")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text(statusText)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(statusColor.opacity(0.2))
                    .foregroundColor(statusColor)
                    .cornerRadius(4)
            }
            
            Text(displayRatio)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(statusColor)
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 4)
                        .cornerRadius(2)
                    
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [statusColor.opacity(0.7), statusColor],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * progressValue, height: 4)
                        .cornerRadius(2)
                }
            }
            .frame(height: 4)
            
            Text("Income ÷ Expenses")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .kpiCardStyle()
    }
}

// MARK: - Burn Rate KPI Card
struct BurnRateKPICard: View {
    let monthlyBurnRate: Double
    let trend: Double // Percentage change from previous period
    
    private var trendColor: Color {
        // Lower burn rate is better, so negative trend is good
        return trend <= 0 ? .green : .red
    }
    
    private var trendIcon: String {
        return trend <= 0 ? "arrow.down.right" : "arrow.up.right"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "flame.fill")
                    .foregroundColor(.orange)
                Text("Burn Rate")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(CurrencyFormatter.formatCheck(monthlyBurnRate))
                .font(.title3)
                .fontWeight(.bold)
            
            HStack(spacing: 4) {
                Image(systemName: trendIcon)
                    .font(.caption2)
                Text("\(trend > 0 ? "+" : "")\(String(format: "%.1f", trend))%")
                    .font(.caption2)
            }
            .foregroundColor(trendColor)
            
            Text("Monthly average spending")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .kpiCardStyle()
    }
}

// MARK: - Runway Days KPI Card
struct RunwayKPICard: View {
    let runwayDays: Int
    
    private var statusColor: Color {
        if runwayDays >= 365 { return .green }
        if runwayDays >= 180 { return .blue }
        if runwayDays >= 90 { return .orange }
        return .red
    }
    
    private var statusIcon: String {
        if runwayDays >= 365 { return "shield.checkered" }
        if runwayDays >= 180 { return "shield.lefthalf.filled" }
        if runwayDays >= 90 { return "exclamationmark.shield" }
        return "exclamationmark.triangle"
    }
    
    private var displayDays: String {
        if runwayDays >= 9999 { return "∞" }
        if runwayDays >= 365 {
            let years = runwayDays / 365
            return "\(years)y+"
        }
        return "\(runwayDays)d"
    }
    
    private var statusText: String {
        if runwayDays >= 365 { return "Secure" }
        if runwayDays >= 180 { return "Healthy" }
        if runwayDays >= 90 { return "Caution" }
        return "At Risk"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: statusIcon)
                    .foregroundColor(statusColor)
                Text("Runway")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text(statusText)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(statusColor.opacity(0.2))
                    .foregroundColor(statusColor)
                    .cornerRadius(4)
            }
            
            Text(displayDays)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(statusColor)
            
            Text("Days of financial runway")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .kpiCardStyle()
    }
}

// MARK: - Debt Ratio KPI Card
struct DebtRatioKPICard: View {
    let ratio: Double // As percentage
    
    private var statusColor: Color {
        if ratio <= 20 { return .green }
        if ratio <= 50 { return .blue }
        if ratio <= 80 { return .orange }
        return .red
    }
    
    private var statusText: String {
        if ratio <= 20 { return "Low" }
        if ratio <= 50 { return "Moderate" }
        if ratio <= 80 { return "High" }
        return "Critical"
    }
    
    private var progressValue: Double {
        return min(ratio / 100.0, 1.0)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "percent")
                    .foregroundColor(.purple)
                Text("Debt Ratio")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text(statusText)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(statusColor.opacity(0.2))
                    .foregroundColor(statusColor)
                    .cornerRadius(4)
            }
            
            Text(String(format: "%.1f%%", ratio))
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(statusColor)
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 4)
                        .cornerRadius(2)
                    
                    Rectangle()
                        .fill(statusColor)
                        .frame(width: geometry.size.width * progressValue, height: 4)
                        .cornerRadius(2)
                }
            }
            .frame(height: 4)
            
            Text("Liabilities ÷ Assets")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .kpiCardStyle()
    }
}

// MARK: - KPI Grid View
struct KPIGridView: View {
    let cashFlowRatio: Double
    let income: Double
    let expenses: Double
    let monthlyBurnRate: Double
    let expenseTrend: Double
    let runwayDays: Int
    let debtToAssetRatio: Double
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "chart.bar.doc.horizontal")
                    .foregroundColor(.indigo)
                Text("Financial KPIs")
                    .font(.headline)
                Spacer()
            }
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                CashFlowKPICard(ratio: cashFlowRatio, income: income, expenses: expenses)
                BurnRateKPICard(monthlyBurnRate: monthlyBurnRate, trend: expenseTrend)
                RunwayKPICard(runwayDays: runwayDays)
                DebtRatioKPICard(ratio: debtToAssetRatio)
            }
        }
    }
}
