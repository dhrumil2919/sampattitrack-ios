import SwiftUI

struct QuickActionsCard: View {
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "bolt.fill")
                    .foregroundColor(.orange)
                Text("Quick Actions")
                    .font(.headline)
                Spacer()
            }
            
            HStack(spacing: 12) {
                // Add Transaction Button
                NavigationLink(destination: AddTransactionView()) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Add")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Text("Transaction")
                                .font(.caption)
                        }
                        Spacer()
                    }
                    .foregroundColor(.white)
                    .padding()
                    .background(
                        LinearGradient(
                            colors: [Color.blue, Color.blue.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(12)
                }
                
                // Add Account Button
                NavigationLink(destination: AccountListView()) {
                    HStack {
                        Image(systemName: "folder.fill.badge.plus")
                            .font(.title2)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("View")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Text("Accounts")
                                .font(.caption)
                        }
                        Spacer()
                    }
                    .foregroundColor(.white)
                    .padding()
                    .background(
                        LinearGradient(
                            colors: [Color.purple, Color.purple.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(12)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5)
    }
}
