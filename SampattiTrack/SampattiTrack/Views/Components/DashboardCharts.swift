import SwiftUI
import Charts

struct DashboardCharts {

    // MARK: - Stacked Bar Chart for Tag Spending
    @available(iOS 16.0, *)
    struct TagSpendingChart: View {
        let data: [(month: String, tags: [(tag: String, amount: Double)])]

        var body: some View {
            VStack(alignment: .leading) {
                Text("Monthly Tag Spending")
                    .font(.headline)
                    .padding(.horizontal)

                if data.isEmpty {
                     Text("No data available")
                        .foregroundColor(.secondary)
                        .frame(height: 250)
                        .frame(maxWidth: .infinity)
                } else {
                    Chart {
                        ForEach(data, id: \.month) { monthData in
                            ForEach(monthData.tags, id: \.tag) { tagData in
                                BarMark(
                                    x: .value("Month", monthData.month),
                                    y: .value("Amount", tagData.amount)
                                )
                                .foregroundStyle(by: .value("Tag", tagData.tag))
                            }
                        }
                    }
                    .frame(height: 300)
                    .padding()
                }
            }
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 5)
        }
    }

    // MARK: - Pie Chart for Expenses
    @available(iOS 17.0, *)
    struct ExpensePieChart: View {
        let data: [TopTag]

        var body: some View {
            VStack(alignment: .leading) {
                Text("Expense Breakdown")
                    .font(.headline)
                    .padding(.horizontal)

                if data.isEmpty {
                    Text("No data available")
                        .foregroundColor(.secondary)
                        .frame(height: 300)
                        .frame(maxWidth: .infinity)
                } else {
                    Chart(data, id: \.tagId) { item in
                        SectorMark(
                            angle: .value("Amount", item.amountValue),
                            innerRadius: .ratio(0.5),
                            angularInset: 1.5
                        )
                        .cornerRadius(5)
                        .foregroundStyle(by: .value("Category", item.tagName))
                    }
                    .frame(height: 300)
                    .padding()

                    // Legend/List
                    VStack(spacing: 8) {
                        ForEach(data.prefix(5)) { item in
                            HStack {
                                Circle()
                                    .fill(Color.blue) // In real app, match color with chart
                                    .frame(width: 8, height: 8)
                                Text(item.tagName)
                                    .font(.caption)
                                Spacer()
                                Text(CurrencyFormatter.format(item.amount))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.bottom)
                }
            }
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 5)
        }
    }
}
