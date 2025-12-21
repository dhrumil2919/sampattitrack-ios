import SwiftUI
import Charts

struct MonthlyExpenseTrendChart: View {
    let monthlyData: [(month: String, amount: Double)]
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "chart.line.downtrend.xyaxis")
                    .foregroundColor(.red)
                Text("Monthly Expenses")
                    .font(.headline)
                Spacer()
                if let latest = monthlyData.last {
                    Text(CurrencyFormatter.formatCheck(latest.amount))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.red)
                }
            }
            
            if monthlyData.isEmpty {
                Text("No expense data available")
                    .foregroundColor(.secondary)
                    .frame(height: 100)
            } else {
                if #available(iOS 16.0, *) {
                    Chart {
                        ForEach(Array(monthlyData.enumerated()), id: \.offset) { index, item in
                            LineMark(
                                x: .value("Month", item.month),
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
                                x: .value("Month", item.month),
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
                    .frame(height: 120)
                } else {
                    // iOS 15 fallback - simple sparkline
                    GeometryReader { geometry in
                        Path { path in
                            guard !monthlyData.isEmpty else { return }
                            let maxValue = monthlyData.map { $0.amount }.max() ?? 1
                            let width = geometry.size.width
                            let height = geometry.size.height
                            let stepX = width / CGFloat(monthlyData.count - 1)
                            
                            for (index, item) in monthlyData.enumerated() {
                                let x = CGFloat(index) * stepX
                                let y = height - (CGFloat(item.amount / maxValue) * height)
                                
                                if index == 0 {
                                    path.move(to: CGPoint(x: x, y: y))
                                } else {
                                    path.addLine(to: CGPoint(x: x, y: y))
                                }
                            }
                        }
                        .stroke(Color.red, lineWidth: 2)
                    }
                    .frame(height: 60)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5)
    }
}
