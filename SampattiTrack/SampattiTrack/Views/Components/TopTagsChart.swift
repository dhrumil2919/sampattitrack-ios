import SwiftUI
import Charts

struct TopTagsChart: View {
    let data: [TopTag]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Top Tags by Expense")
                .font(.headline)
                .padding(.horizontal)
            
            if data.isEmpty {
                Text("No tag data available")
                    .foregroundColor(.secondary)
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
            } else {
                Chart {
                    ForEach(data) { tag in
                        BarMark(
                            x: .value("Amount", tag.amountValue),
                            y: .value("Tag", tag.tagName)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.orange, Color.red],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(4)
                    }
                }
                .chartXAxis {
                    AxisMarks(position: .bottom) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let doubleValue = value.as(Double.self) {
                                Text(CurrencyFormatter.formatCheck(doubleValue))
                                    .font(.caption)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisValueLabel()
                    }
                }
                .frame(height: 250)
                .padding()
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .padding()
    }
}
