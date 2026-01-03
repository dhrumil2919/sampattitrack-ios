import SwiftUI
import Charts

// Capital Gains Detail View - Shows STCG/LTCG breakdown and records
struct CapitalGainsDetailView: View {
    let capitalGains: CapitalGainsReport
    var history: [CapitalGainsReport] = []

    @State private var selectedYearReport: CapitalGainsReport?

    var activeReport: CapitalGainsReport {
        selectedYearReport ?? capitalGains
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Summary Card
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("FY \(String(activeReport.year))-\(String((activeReport.year + 1) % 100))")
                            .font(.headline)

                        Spacer()

                        // Year Picker if history is available
                        if !history.isEmpty {
                            Menu {
                                ForEach(history) { report in
                                    Button("FY \(String(report.year))-\(String((report.year + 1) % 100))") {
                                        selectedYearReport = report
                                    }
                                }
                            } label: {
                                Image(systemName: "calendar")
                                    .foregroundColor(.purple)
                            }
                        }
                    }
                    
                    // STCG and LTCG Summary
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Short-Term (STCG)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(CurrencyFormatter.format(activeReport.totalSTCG))
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(activeReport.totalSTCGValue >= 0 ? .green : .red)
                            Text("Tax: \(CurrencyFormatter.format(activeReport.totalSTCGTax))")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Long-Term (LTCG)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(CurrencyFormatter.format(activeReport.totalLTCG))
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(activeReport.totalLTCGValue >= 0 ? .green : .red)
                            Text("Tax: \(CurrencyFormatter.format(activeReport.totalLTCGTax))")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    Divider()
                    
                    HStack {
                        Text("Total Tax Liability")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(CurrencyFormatter.format(activeReport.totalTax))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.orange)
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.05), radius: 5)
                
                // Gains Distribution Chart
                if #available(iOS 17.0, *) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Gains Distribution")
                            .font(.headline)
                        
                        Chart {
                            SectorMark(
                                angle: .value("Amount", abs(activeReport.totalSTCGValue)),
                                innerRadius: .ratio(0.6),
                                angularInset: 2
                            )
                            .foregroundStyle(.red)
                            .annotation(position: .overlay) {
                                Text("STCG")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                            }
                            
                            SectorMark(
                                angle: .value("Amount", abs(activeReport.totalLTCGValue)),
                                innerRadius: .ratio(0.6),
                                angularInset: 2
                            )
                            .foregroundStyle(.green)
                            .annotation(position: .overlay) {
                                Text("LTCG")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                            }
                        }
                        .frame(height: 200)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.05), radius: 5)
                }

                // Yearly Breakdown (History)
                if !history.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Yearly Breakdown")
                            .font(.headline)

                        ForEach(history) { report in
                             Button {
                                selectedYearReport = report
                             } label: {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text("FY \(String(report.year))-\(String((report.year + 1) % 100))")
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.primary)
                                        Spacer()
                                        Text(CurrencyFormatter.format(report.totalTax))
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.orange)
                                    }

                                    HStack {
                                        Text("STCG: \(CurrencyFormatter.format(report.totalSTCG))")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Spacer()
                                        Text("LTCG: \(CurrencyFormatter.format(report.totalLTCG))")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Divider()
                                }
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.05), radius: 5)
                }
                
                // Transaction Records
                if !activeReport.records.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Transaction Records (\(activeReport.records.count))")
                            .font(.headline)
                        
                        ForEach(activeReport.records) { record in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(record.symbol)
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                        Text(record.accountName)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    VStack(alignment: .trailing, spacing: 4) {
                                        Text(record.type)
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 2)
                                            .background(record.type == "STCG" ? Color.red.opacity(0.2) : Color.green.opacity(0.2))
                                            .foregroundColor(record.type == "STCG" ? .red : .green)
                                            .cornerRadius(4)
                                        Text("\(record.daysHeld) days")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                HStack {
                                    Text("Qty: \(String(format: "%.2f", record.quantityValue))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text("Gain: \(CurrencyFormatter.format(record.gain))")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(record.gainValue >= 0 ? .green : .red)
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
            }
            .padding()
        }
        .navigationTitle("Capital Gains")
        .navigationBarTitleDisplayMode(.large)
    }
}
