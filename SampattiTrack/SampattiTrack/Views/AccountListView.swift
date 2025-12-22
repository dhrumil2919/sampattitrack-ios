import SwiftUI
import SwiftData

struct AccountListView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var syncManager: SyncManager
    
    @Query(sort: \SDAccount.name) private var accounts: [SDAccount]
    
    @State private var selectedCategory: AccountCategory = .asset
    @State private var searchText = ""
    
    enum AccountCategory: String, CaseIterable, Identifiable {
        case asset = "Asset"
        case liability = "Liability"
        case income = "Income"
        case expense = "Expense"
        case equity = "Equity"
        
        var id: String { self.rawValue }
    }
    
    var filteredAccounts: [SDAccount] {
        var result = accounts.filter { $0.category == selectedCategory.rawValue }
        
        if !searchText.isEmpty {
            result = result.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        
        return result
    }
    
    var body: some View {
        NavigationView {
                VStack(spacing: 0) {
                    // Category Picker
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(AccountCategory.allCases) { category in
                            Text(category.rawValue).tag(category)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding()
                    
                    if accounts.isEmpty {
                        // Show loader or placeholder if we have no local data yet?
                        // If we have no data, we probably need to sync.
                         VStack {
                             Spacer()
                             Text("No accounts found")
                             Button("Sync Accounts") {
                                 Task {
                                     await syncManager.pullAccounts()
                                 }
                             }
                             Spacer()
                         }
                    } else if filteredAccounts.isEmpty {
                        VStack(spacing: 12) {
                            Spacer()
                            Image(systemName: "magnifyingglass")
                                .font(.largeTitle)
                                .foregroundColor(.secondary)
                            Text("No accounts found")
                                .font(.headline)
                            if !searchText.isEmpty {
                                Text("No results for \"\(searchText)\"")
                                    .foregroundColor(.secondary)
                            } else {
                                Text("You have no \(selectedCategory.rawValue.lowercased()) accounts.")
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .padding()
                    } else {
                        List {
                            ForEach(filteredAccounts) { account in
                                NavigationLink(destination: AccountDetailView(account: account.toAccount)) {
                                    AccountRowView(account: account.toAccount)
                                }
                            }
                        }
                        .listStyle(PlainListStyle())
                    }
                }
                .navigationTitle("Accounts")
                .searchable(text: $searchText, prompt: "Search accounts...")
                .refreshable {
                    await syncManager.pullAccounts()
                }
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        NavigationLink(destination: EditAccountView(account: nil, modelContext: modelContext)) {
                            Image(systemName: "plus")
                                .accessibilityLabel("Add Account")
                        }
                    }
                }
        }
    }
}

// MARK: - Account Row
struct AccountRowView: View {
    let account: Account
    
    var typeIcon: String {
        switch account.type {
        case "Cash": return "banknote"
        case "Stock": return "chart.line.uptrend.xyaxis"
        case "MutualFund": return "chart.bar.fill"
        case "CreditCard": return "creditcard"
        case "Loan": return "house"
        case "Metal": return "sparkles"
        case "NPS": return "building.columns"
        default: return "folder"
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: typeIcon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 40, height: 40)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(10)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(account.name)
                    .font(.headline)
                HStack(spacing: 4) {
                    Text(account.type)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("•")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(account.currency ?? "INR")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

