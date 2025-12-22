import SwiftUI
import Charts

struct VizView: View {
    @StateObject private var viewModel = VizViewModel()
    @State private var selectedChart = 0 // 0: Net Worth, 1: Asset Allocation, 2: Top Tags

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    Picker("Chart Type", selection: $selectedChart) {
                        Text("Net Worth").tag(0)
                        Text("Asset Allocation").tag(1)
                        Text("Top Tags").tag(2)
                    }
                    .pickerStyle(.segmented)
                    .padding()

                    if viewModel.isLoading {
                        ProgressView()
                            .frame(height: 300)
                    } else {
                        if selectedChart == 0 {
                            NetWorthChart(data: viewModel.netWorthHistory)
                        } else if selectedChart == 1 {
                            if #available(iOS 17.0, *) {
                                AssetAllocationChart(data: viewModel.assetAllocation)
                            } else {
                                Text("Asset Allocation Chart requires iOS 17.0+")
                                    .foregroundColor(.secondary)
                                    .frame(height: 300)
                                    .frame(maxWidth: .infinity)
                                    .background(Color(.systemBackground))
                                    .cornerRadius(12)
                                    .padding()
                            }
                        } else {
                            TopTagsChart(data: viewModel.topTags)
                        }
                    }

                    // Detailed List below
                    if selectedChart == 1 && !viewModel.assetPerformance.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Asset Details")
                                .font(.headline)
                                .padding(.horizontal)

                            ForEach(viewModel.assetPerformance) { asset in
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(asset.accountName)
                                            .font(.subheadline)
                                        Text(asset.type)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    VStack(alignment: .trailing) {
                                        Text(CurrencyFormatter.formatCheck(asset.currentValueValue))
                                            .font(.subheadline)
                                        Text(String(format: "%.2f%%", asset.xirr))
                                            .font(.caption)
                                            .foregroundColor(asset.xirr >= 0 ? .green : .red)
                                    }
                                }
                                .padding(.horizontal)
                                Divider()
                            }
                        }
                        .padding(.vertical)
                    }
                }
            }
            .navigationTitle("Visualizations")
            .onAppear {
                viewModel.fetchData()
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

@available(iOS 17.0, *)
struct AssetAllocationChart: View {
    let data: [(type: String, value: Double)]

    var body: some View {
        VStack(alignment: .leading) {
            Text("Asset Allocation")
                .font(.headline)
                .padding(.horizontal)

            if data.isEmpty {
                 Text("No asset data available")
                    .foregroundColor(.secondary)
                    .frame(height: 300)
                    .frame(maxWidth: .infinity)
            } else {
                Chart(data, id: \.type) { item in
                    SectorMark(
                        angle: .value("Value", item.value),
                        innerRadius: .ratio(0.5),
                        angularInset: 1.5
                    )
                    .cornerRadius(5)
                    .foregroundStyle(by: .value("Type", item.type))
                }
                .frame(height: 300)
                .padding()
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .padding()
    }
}
