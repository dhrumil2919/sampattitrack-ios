import SwiftUI
import Charts

// Generic MOM (Month-over-Month) Detail View
// Shows last 12 months (excluding current month) with absolute values and % change
struct MOMDetailView: View {
    let title: String
    let data: [MOMDataPoint]
    let valueFormatter: (Double) -> String
    let color: Color
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Summary Card
                if let latest = data.last {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Latest Month")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(valueFormatter(latest.value))
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(color)
                        
                        if let change = latest.changeRate {
                            HStack(spacing: 4) {
                                Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                                    .font(.caption)
                                Text(String(format: "%.1f%%", abs(change)))
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                Text("MoM")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .foregroundColor(change >= 0 ? .green : .red)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                }
                
                // Monthly Values Chart
                if #available(iOS 16.0, *) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Monthly Trend")
                            .font(.headline)
                        
                        Chart(data) { point in
                            BarMark(
                                x: .value("Month", point.monthLabel),
                                y: .value("Value", point.value)
                            )
                            .foregroundStyle(color.gradient)
                        }
                        .frame(height: 250)
                        .chartYAxis {
                            AxisMarks(position: .leading)
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.05), radius: 5)
                    
                    // MoM Change Rate Chart
                    if data.contains(where: { $0.changeRate != nil }) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Month-over-Month Change")
                                .font(.headline)
                            
                            Chart(data.filter { $0.changeRate != nil }) { point in
                                LineMark(
                                    x: .value("Month", point.monthLabel),
                                    y: .value("Change %", point.changeRate ?? 0)
                                )
                                .foregroundStyle(color)
                                .symbol(.circle)
                                
                                AreaMark(
                                    x: .value("Month", point.monthLabel),
                                    y: .value("Change %", point.changeRate ?? 0)
                                )
                                .foregroundStyle(color.opacity(0.1))
                            }
                            .frame(height: 200)
                            .chartYAxis {
                                AxisMarks(position: .leading) { value in
                                    AxisValueLabel {
                                        if let change = value.as(Double.self) {
                                            Text(String(format: "%.0f%%", change))
                                        }
                                    }
                                }
                            }
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.05), radius: 5)
                    }
                } else {
                    Text("Charts require iOS 16+")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding()
                }
                
                // Data Table
                VStack(alignment: .leading, spacing: 12) {
                    Text("Monthly Breakdown")
                        .font(.headline)
                    
                    ForEach(data.reversed()) { point in
                        HStack {
                            Text(point.monthLabel)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(valueFormatter(point.value))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            if let change = point.changeRate {
                                Text(String(format: "%+.1f%%", change))
                                    .font(.caption)
                                    .foregroundColor(change >= 0 ? .green : .red)
                                    .frame(width: 60, alignment: .trailing)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.05), radius: 5)
            }
            .padding()
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.large)
    }
}

// Data point for MOM charts
struct MOMDataPoint: Identifiable {
    let id = UUID()
    let month: String // YYYY-MM
    let value: Double
    let changeRate: Double? // % change from previous month
    
    var monthLabel: String {
        let components = month.split(separator: "-")
        guard components.count == 2,
              let monthNum = Int(components[1]) else {
            return month
        }
        let monthNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
                         "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        return monthNames[monthNum - 1]
    }
}

// Helper to prepare MOM data from cash flow
extension DashboardViewModel {
    func prepareMOMData(from cashFlow: [CashFlowDataPoint], valueExtractor: (CashFlowDataPoint) -> Double) -> [MOMDataPoint] {
        let now = Date()
        let calendar = Calendar.current
        
        // Get current month start
        let currentMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
        
        // Filter out current month and get last 12 months
        let filtered = cashFlow
            .filter { point in
                guard let date = point.date else { return false }
                return date < currentMonthStart
            }
            .sorted { ($0.date ?? Date.distantPast) < ($1.date ?? Date.distantPast) }
            .suffix(12)
        
        var result: [MOMDataPoint] = []
        var previousValue: Double?
        
        for point in filtered {
            let value = valueExtractor(point)
            let month = String(point.dateString.prefix(7)) // YYYY-MM
            
            var changeRate: Double?
            if let prev = previousValue, prev > 0 {
                changeRate = ((value - prev) / prev) * 100
            }
            
            result.append(MOMDataPoint(
                month: month,
                value: value,
                changeRate: changeRate
            ))
            
            previousValue = value
        }
        
        return result
    }
}
