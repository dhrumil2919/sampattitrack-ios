import SwiftUI
import SwiftData

struct TransactionListView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var syncManager: SyncManager
    
    @State private var searchText = ""
    var accountID: String?
    
    init(accountID: String? = nil) {
        self.accountID = accountID
    }
    
    var body: some View {
        TransactionListContent(accountID: accountID, searchText: searchText)
            .navigationTitle("Transactions")
            .navigationDestination(for: SDTransaction.self) { transaction in
                EditTransactionView(transaction: transaction.toTransaction)
            }
            .searchable(text: $searchText, prompt: "Search transactions...")
            .refreshable {
                await syncManager.syncAll()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: AddTransactionView()) {
                        Image(systemName: "plus")
                    }
                }
            }
    }
}

private struct TransactionListContent: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var syncManager: SyncManager

    @Query private var transactions: [SDTransaction]
    let accountID: String?
    let searchText: String

    init(accountID: String?, searchText: String) {
        self.accountID = accountID
        self.searchText = searchText

        let predicate: Predicate<SDTransaction>
        
        if let accountID {
            if searchText.isEmpty {
                predicate = #Predicate<SDTransaction> { t in
                    // Use optional chaining + boolean check to handle optional relationship safely in Predicate
                    t.postings?.contains { $0.accountID == accountID } == true
                }
            } else {
                predicate = #Predicate<SDTransaction> { t in
                    (t.postings?.contains { $0.accountID == accountID } == true) &&
                    t.desc.localizedStandardContains(searchText)
                }
            }
        } else {
            if searchText.isEmpty {
                 predicate = #Predicate<SDTransaction> { _ in true }
            } else {
                predicate = #Predicate<SDTransaction> { t in
                    t.desc.localizedStandardContains(searchText)
                }
            }
        }
        
        _transactions = Query(filter: predicate, sort: \SDTransaction.date, order: .reverse)
    }
    
    var body: some View {
        Group {
            if transactions.isEmpty {
                if !searchText.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    ContentUnavailableView {
                        Label("No Transactions", systemImage: "tray")
                    } description: {
                        if accountID != nil {
                            Text("This account has no transactions yet.")
                        } else {
                            Text("Get started by creating your first transaction.")
                        }
                    } actions: {
                        Button("Sync Now") {
                            Task {
                                await syncManager.syncAll()
                            }
                        }
                    }
                }
            } else {
                List {
                    ForEach(transactions) { transaction in
                        // OPTIMIZATION: Use value-based navigation to defer the creation of the destination view.
                        NavigationLink(value: transaction) {
                            TransactionRowView(
                                transaction: transaction,
                                accountID: accountID
                            )
                        }
                    }
                    .onDelete(perform: deleteTransactions)
                }
                .listStyle(PlainListStyle())
            }
        }
    }
    
    private func deleteTransactions(offsets: IndexSet) {
        for index in offsets {
            let transaction = transactions[index]
            // Mark as deleted for sync
            transaction.isDeleted = true
            transaction.isSynced = false
            modelContext.delete(transaction)
        }
    }
}

// MARK: - Transaction Row
// Moved out of TransactionListView to be accessible by TransactionListContent
private struct TransactionRowView: View {
    let transaction: SDTransaction
    let accountID: String?

    var transactionType: Transaction.TransactionType {
        // If viewing from account context, use simple inflow/outflow logic
        if let accountID = accountID {
            return transaction.amountForAccount(accountID) > 0 ? .income : .expense
        }
        // Otherwise use smart category-based logic
        return transaction.determineType()
    }

    var displayAmount: String {
        if let accountID = accountID {
            let amount = transaction.amountForAccount(accountID)
            let prefix = amount > 0 ? "+" : ""
            return "\(prefix)\(CurrencyFormatter.formatCheck(abs(amount)))"
        }
        return CurrencyFormatter.formatCheck(transaction.displayAmount)
    }

    var amountColor: Color {
        switch transactionType {
        case .expense:
            return .red
        case .income:
            return .green
        case .transfer:
            return .blue
        }
    }

    var iconName: String {
        switch transactionType {
        case .expense:
            return "arrow.up.circle.fill"
        case .income:
            return "arrow.down.circle.fill"
        case .transfer:
            return "arrow.left.arrow.right.circle.fill"
        }
    }
    // Get all unique account IDs from postings
    var accountIds: String {
        let ids = transaction.postings?.compactMap { $0.accountID } ?? []
        return ids.joined(separator: " → ")
    }

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: iconName)
                .font(.title2)
                .foregroundColor(amountColor)

            VStack(alignment: .leading, spacing: 2) {
                // Description or fallback to accounts
                Text(transaction.desc.isEmpty ? accountIds : transaction.desc)
                    .font(.headline)
                    .lineLimit(1)
                
                // Show accounts on second line
                Text(accountIds)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Text(transaction.date)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    if let note = transaction.note, !note.isEmpty {
                        Text("•")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(note)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            Text(displayAmount)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(amountColor)
        }
        .padding(.vertical, 4)
    }
}
