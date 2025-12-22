import SwiftUI
import Charts

struct AccountDetailView: View {
    let account: Account
    @StateObject private var viewModel: AccountDetailViewModel
    @Environment(\.modelContext) private var modelContext
    
    init(account: Account) {
        self.account = account
        _viewModel = StateObject(wrappedValue: AccountDetailViewModel(accountID: account.id))
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                VStack {
                    Text(account.name)
                        .font(.title2)
                        .fontWeight(.bold)
                    Text(CurrencyFormatter.format(viewModel.balance, currency: account.currency ?? "INR"))
                        .font(.system(size: 34, weight: .bold))
                        .foregroundColor(account.category == "Liability" ? .red : .green)
                    Text(account.category.uppercased())
                        .font(.caption)
                        .padding(4)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(4)
                }
                .padding()
                
                // Chart (Requires iOS 16+)
                if #available(iOS 16.0, *) {
                    if !viewModel.history.isEmpty {
                        Chart(viewModel.history) { point in
                            LineMark(
                                x: .value("Date", point.date), // Simplification: string date might not sort correctly without parsing.
                                y: .value("Balance", Double(point.balance) ?? 0.0)
                            )
                        }
                        .frame(height: 200)
                        .padding()
                    }
                }
                
                // Transactions Link or Embedded List
                NavigationLink(destination: TransactionListView(accountID: account.id)) {
                    Text("View Transactions")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink(destination: EditAccountView(account: account, modelContext: modelContext)) {
                    Text("Edit")
                }
            }
        }
        .onAppear {
            viewModel.fetchDetails()
        }
    }
}
