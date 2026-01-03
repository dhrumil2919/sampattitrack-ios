import SwiftUI
import Charts

// Tax Detail View - Shows yearly tax breakdown
struct TaxDetailView: View {
    let taxAnalysis: TaxAnalysis
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Summary Card
                VStack(alignment: .leading, spacing: 12) {
                    Text("Total Tax Summary")
                        .font(.headline)
                    
                    HStack(spacing: 20) {
                        VStack(alignment: .leading) {
                            Text("Total Tax Paid")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(CurrencyFormatter.format(taxAnalysis.totalTax))
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.purple)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing) {
                            Text("Effective Rate")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(String(format: "%.2f%%", taxAnalysis.taxRate))
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.purple)
                        }
                    }
                    
                    Divider()
                    
                    HStack(spacing: 20) {
                        VStack(alignment: .leading) {
                            Text("Total Income")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(CurrencyFormatter.format(taxAnalysis.totalIncome))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing) {
                            Text("Net Income")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(CurrencyFormatter.format(taxAnalysis.netIncome))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.green)
                        }
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.05), radius: 5)
                
                // Tax Rate Trend Chart
                if #available(iOS 16.0, *), !taxAnalysis.breakdown.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Tax Rate Trend")
                            .font(.headline)
                        
                        Chart(taxAnalysis.breakdown) { item in
                            LineMark(
                                x: .value("Year", "FY \(String((item.year + 1) % 100))"),
                                y: .value("Rate", item.taxRate)
                            )
                            .foregroundStyle(.purple)
                            .symbol(.circle)
                            
                            PointMark(
                                x: .value("Year", "FY \(String((item.year + 1) % 100))"),
                                y: .value("Rate", item.taxRate)
                            )
                            .foregroundStyle(.purple)
                        }
                        .frame(height: 200)
                        .chartYAxis {
                            AxisMarks(position: .leading) { value in
                                AxisValueLabel {
                                    if let rate = value.as(Double.self) {
                                        Text(String(format: "%.1f%%", rate))
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
                
                // Yearly Breakdown
                VStack(alignment: .leading, spacing: 12) {
                    Text("Yearly Breakdown")
                        .font(.headline)
                    
                    ForEach(taxAnalysis.breakdown.reversed()) { item in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("FY \(String(item.year))-\(String((item.year + 1) % 100))")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Spacer()
                                Text(String(format: "%.2f%%", item.taxRate))
                                    .font(.subheadline)
                                    .foregroundColor(.purple)
                                    .fontWeight(.semibold)
                            }
                            
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Income")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(CurrencyFormatter.format(item.income))
                                        .font(.caption)
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .center, spacing: 4) {
                                    Text("Tax Paid")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(CurrencyFormatter.format(item.taxPaid))
                                        .font(.caption)
                                        .foregroundColor(.purple)
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text("Deduction")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(CurrencyFormatter.format(item.deduction))
                                        .font(.caption)
                                        .foregroundColor(.green)
                                }
                            }
                            
                            Divider()
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
        .navigationTitle("Income Tax Analysis")
        .navigationBarTitleDisplayMode(.large)
    }
}
