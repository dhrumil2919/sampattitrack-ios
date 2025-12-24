import SwiftUI

// Net Worth Growth View - Reuses MOMDetailView for consistent UI
struct NetWorthGrowthView: View {
    let netWorthHistory: [NetWorthDataPoint]
    let currentNetWorth: String
    let growth: Double
    
    // Convert net worth history to MOM data format (last 12 months excluding current)
    private var momData: [MOMDataPoint] {
        let now = Date()
        let calendar = Calendar.current
        let currentMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
        
        // Group by month and take last value of each month
        let grouped = Dictionary(grouping: netWorthHistory) { point in
            String(point.date.prefix(7)) // YYYY-MM
        }
        
        // Get current month string to exclude
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        let currentMonthStr = formatter.string(from: now)
        
        // Filter, sort, and get last 12 months excluding current
        let sortedMonths = grouped.keys
            .filter { $0 != currentMonthStr }
            .sorted()
            .suffix(12)
        
        var result: [MOMDataPoint] = []
        var previousValue: Double?
        
        for month in sortedMonths {
            guard let points = grouped[month],
                  let lastPoint = points.max(by: { $0.date < $1.date }) else {
                continue
            }
            
            let value = lastPoint.netWorthValue
            var changeRate: Double?
            
            if let prev = previousValue, prev != 0 {
                changeRate = ((value - prev) / abs(prev)) * 100
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
    
    var body: some View {
        MOMDetailView(
            title: "Net Worth Growth",
            data: momData,
            valueFormatter: { value in CurrencyFormatter.format(String(value)) },
            color: .cyan
        )
    }
}
