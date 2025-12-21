import SwiftUI
import Charts

struct DashboardAssetChart: View {
    let assets: Double
    let liabilities: Double
    
    private var chartData: [(category: String, value: Double, color: Color)] {
        [
            ("Assets", assets, .blue),
            ("Liabilities", abs(liabilities), .orange)
        ].filter { $0.value > 0 }
    }
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "chart.pie.fill")
                    .foregroundColor(.purple)
                Text("Asset Allocation")
                    .font(.headline)
                Spacer()
            }
            
            if #available(iOS 16.0, *) {
                HStack(spacing: 20) {
                    // Donut Chart
                    Chart(chartData, id: \.category) { item in
                        SectorMark(
                            angle: .value("Value", item.value),
                            innerRadius: .ratio(0.6),
                            angularInset: 2
                        )
                        .foregroundStyle(item.color.gradient)
                    }
                    .frame(width: 120, height: 120)
                    
                    // Legend
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(chartData, id: \.category) { item in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(item.color)
                                    .frame(width: 12, height: 12)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.category)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(CurrencyFormatter.formatCheck(item.value))
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, 8)
            } else {
                // Fallback for iOS 15
                HStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.2), lineWidth: 20)
                            .frame(width: 100, height: 100)
                        
                        Circle()
                            .trim(from: 0, to: CGFloat(assets / (assets + abs(liabilities))))
                            .stroke(Color.blue, lineWidth: 20)
                            .frame(width: 100, height: 100)
                            .rotationEffect(.degrees(-90))
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(chartData, id: \.category) { item in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(item.color)
                                    .frame(width: 12, height: 12)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.category)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(CurrencyFormatter.formatCheck(item.value))
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5)
    }
}
