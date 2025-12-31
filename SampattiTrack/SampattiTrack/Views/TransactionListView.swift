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
                await syncManager.syncTransactions()
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
            
            // OFFLINE-FIRST: Queue DELETE operation for backend sync
            do {
                try OfflineQueueHelper.queueTransactionDelete(
                    id: transaction.id,
                    context: modelContext
                )
                print("[TransactionList] ✓ Queued deletion: \(transaction.desc)")
            } catch {
                print("[TransactionList] ✗ Failed to queue deletion: \(error)")
                // Continue with local deletion even if queue fails
            }
            
            // Delete from local SwiftData (includes cascade delete to postings)
            modelContext.delete(transaction)
        }
        
        // Save local changes
        do {
            try modelContext.save()
            print("[TransactionList] ✓ Local deletion saved")
        } catch {
            print("[TransactionList] ✗ Failed to save deletion: \(error)")
        }
    }
}

// MARK: - Transaction Row
// Moved out of TransactionListView to be accessible by TransactionListContent
private struct TransactionRowView: View {
    let transaction: SDTransaction
    let accountID: String?

    // Helpers for display
    private func color(for type: Transaction.TransactionType) -> Color {
        switch type {
        case .expense: return .red
        case .income: return .green
        case .transfer: return .blue
        }
    }

    private func icon(for type: Transaction.TransactionType) -> String {
        switch type {
        case .expense: return "arrow.up.circle.fill"
        case .income: return "arrow.down.circle.fill"
        case .transfer: return "arrow.left.arrow.right.circle.fill"
        }
    }

    var body: some View {
        // OPTIMIZATION: Calculate expensive values once per render
        // 1. Determine type and amount string (avoids redundant amountForAccount calls)
        let type: Transaction.TransactionType
        let amountString: String

        if let accountID = accountID {
            // In account context, we check amount once
            let amount = transaction.amountForAccount(accountID)
            type = amount > 0 ? .income : .expense
            let prefix = amount > 0 ? "+" : ""
            amountString = "\(prefix)\(CurrencyFormatter.formatCheck(abs(amount)))"
        } else {
            // In global context
            type = transaction.determineType()
            amountString = CurrencyFormatter.formatCheck(transaction.displayAmount)
        }

        // 2. Compute account IDs string (avoids relationship traversal and string joining)
        let ids = transaction.postings?.compactMap { $0.accountID } ?? []
        let accountIdsText = ids.joined(separator: " → ")

        return HStack(spacing: 12) {
            // Icon
            Image(systemName: icon(for: type))
                .font(.title2)
                .foregroundColor(color(for: type))

            VStack(alignment: .leading, spacing: 2) {
                // Description or fallback to accounts
                HStack(spacing: 4) {
                    Text(transaction.desc.isEmpty ? accountIdsText : transaction.desc)
                        .font(.headline)
                        .lineLimit(1)
                    
                    // OFFLINE-FIRST: Show sync status indicator
                    if !transaction.isSynced {
                        Image(systemName: "icloud.and.arrow.up")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
                
                // Show accounts on second line
                Text(accountIdsText)
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

            Text(amountString)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(color(for: type))
        }
        .padding(.vertical, 4)
    }
}
