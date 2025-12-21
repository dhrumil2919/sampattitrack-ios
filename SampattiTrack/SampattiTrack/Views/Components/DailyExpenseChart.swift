import SwiftUI
import Charts

struct DailyExpenseChart: View {
    let dailyData: [(day: String, amount: Double)]
    
    var totalExpense: Double {
        dailyData.reduce(0) { $0 + $1.amount }
    }
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(.red)
                Text("This Month's Daily Expenses")
                    .font(.headline)
                Spacer()
                Text(CurrencyFormatter.formatCheck(totalExpense))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.red)
            }
            
            if dailyData.isEmpty {
                Text("No expense data available")
                    .foregroundColor(.secondary)
                    .frame(height: 100)
            } else {
                if #available(iOS 16.0, *) {
                    Chart {
                        ForEach(Array(dailyData.enumerated()), id: \.offset) { index, item in
                            LineMark(
                                x: .value("Day", item.day),
                                y: .value("Amount", item.amount)
                            )
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.red, .orange],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .interpolationMethod(.catmullRom)
                            
                            AreaMark(
                                x: .value("Day", item.day),
                                y: .value("Amount", item.amount)
                            )
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.red.opacity(0.3), .clear],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .interpolationMethod(.catmullRom)
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading) { value in
                            AxisValueLabel {
                                if let doubleValue = value.as(Double.self) {
                                    Text(CurrencyFormatter.formatCheck(doubleValue))
                                        .font(.caption2)
                                }
                            }
                        }
                    }
                    .chartXAxis {
                        AxisMarks { value in
                            AxisValueLabel {
                                if let stringValue = value.as(String.self) {
                                    Text(stringValue)
                                        .font(.caption2)
                                }
                            }
                        }
                    }
                    .frame(height: 150)
                } else {
                    // iOS 15 fallback - simple bar visualization
                    HStack(alignment: .bottom, spacing: 4) {
                        ForEach(Array(dailyData.enumerated()), id: \.offset) { index, item in
                            VStack {
                                Spacer()
                                Rectangle()
                                    .fill(Color.red)
                                    .frame(width: 8, height: CGFloat(item.amount / (dailyData.map { $0.amount }.max() ?? 1)) * 100)
                            }
                        }
                    }
                    .frame(height: 100)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5)
    }
}
