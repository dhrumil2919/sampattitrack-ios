import SwiftUI

// Simple list view for showing accounts under a specific path
struct AccountsListView: View {
    let title: String
    let accounts: [AssetPerformance]
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Total Summary
                let totalValue = accounts.reduce(0) { $0 + $1.currentValueValue }
                VStack(alignment: .leading, spacing: 8) {
                    Text("Total Balance")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(CurrencyFormatter.format(String(totalValue)))
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.cyan)
                    Text("\(accounts.count) account\(accounts.count == 1 ? "" : "s")")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
                
                // Individual Accounts
                if !accounts.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Accounts")
                            .font(.headline)
                        
                        ForEach(accounts.sorted(by: { $0.currentValueValue > $1.currentValueValue })) { account in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(account.accountName)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    Text(account.accountID)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                                
                                Spacer()
                                
                                Text(CurrencyFormatter.format(account.currentValue))
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.green)
                            }
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(8)
                        }
                    }
                } else {
                    Text("No accounts found")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding()
                }
            }
            .padding()
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.large)
    }
}
