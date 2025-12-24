import SwiftUI
import Charts

// Capital Gains Detail View - Shows STCG/LTCG breakdown and records
struct CapitalGainsDetailView: View {
    let capitalGains: CapitalGainsReport
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Summary Card
                VStack(alignment: .leading, spacing: 12) {
                    Text("FY \(capitalGains.year-1)-\(capitalGains.year % 100)")
                        .font(.headline)
                    
                    // STCG and LTCG Summary
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Short-Term (STCG)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(CurrencyFormatter.format(capitalGains.totalSTCG))
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(capitalGains.totalSTCGValue >= 0 ? .green : .red)
                            Text("Tax: \(CurrencyFormatter.format(capitalGains.totalSTCGTax))")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Long-Term (LTCG)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(CurrencyFormatter.format(capitalGains.totalLTCG))
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(capitalGains.totalLTCGValue >= 0 ? .green : .red)
                            Text("Tax: \(CurrencyFormatter.format(capitalGains.totalLTCGTax))")
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
                        Text(CurrencyFormatter.format(capitalGains.totalTax))
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
                                angle: .value("Amount", abs(capitalGains.totalSTCGValue)),
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
                                angle: .value("Amount", abs(capitalGains.totalLTCGValue)),
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
                
                // Transaction Records
                if !capitalGains.records.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Transaction Records (\(capitalGains.records.count))")
                            .font(.headline)
                        
                        ForEach(capitalGains.records) { record in
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
