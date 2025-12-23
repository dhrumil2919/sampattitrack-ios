import SwiftUI
import SwiftData
import Charts

/// VizView - OFFLINE-FIRST
/// Uses local SwiftData via VizViewModel. No API calls.
struct VizView: View {
    @StateObject private var viewModel = VizViewModel()
    @State private var selectedChart = 0 // 0: Net Worth, 1: Top Tags
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    Picker("Chart Type", selection: $selectedChart) {
                        Text("Net Worth").tag(0)
                        Text("Top Tags").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .padding()

                    if viewModel.isLoading {
                        ProgressView()
                            .frame(height: 300)
                    } else {
                        if selectedChart == 0 {
                            NetWorthChart(data: viewModel.netWorthHistory)
                        } else {
                            TopTagsChart(data: viewModel.topTags)
                        }
                    }
                }
            }
            .navigationTitle("Visualizations")
            .onAppear {
                // VizViewModel needs container for detached context
                if let container = try? modelContext.container {
                    viewModel.setContainer(container)
                }
            }
        }
    }
}

struct NetWorthChart: View {
    let data: [NetWorthDataPoint]

    var body: some View {
        VStack(alignment: .leading) {
            Text("Net Worth Trend")
                .font(.headline)
                .padding(.horizontal)

            if data.isEmpty {
                Text("No data available")
                    .foregroundColor(.secondary)
                    .frame(height: 300)
                    .frame(maxWidth: .infinity)
            } else {
                Chart {
                    ForEach(data) { point in
                        if let date = point.dateObject {
                            LineMark(
                                x: .value("Date", date),
                                y: .value("Net Worth", point.netWorthValue)
                            )
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.blue, Color.purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .symbol(Circle())
                            .symbolSize(30)

                            AreaMark(
                                x: .value("Date", date),
                                y: .value("Net Worth", point.netWorthValue)
                            )
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.1), .clear],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .interpolationMethod(.catmullRom)
                        }
                    }

                    if let avg = calculateAverage() {
                        RuleMark(y: .value("Average", avg))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [5]))
                            .foregroundStyle(.gray)
                            .annotation(position: .top, alignment: .leading) {
                                Text("Avg: \(CurrencyFormatter.formatCheck(avg))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let doubleValue = value.as(Double.self) {
                                Text(CurrencyFormatter.formatCheck(doubleValue))
                                    .font(.caption)
                            }
                        }
                    }
                }
                .frame(height: 300)
                .padding()
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .padding()
    }

    private func calculateAverage() -> Double? {
        let values = data.compactMap { Double($0.netWorth) }
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }
}
