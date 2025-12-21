import SwiftUI

struct SearchableAccountPicker: View {
    let title: String
    @Binding var selection: String
    let accounts: [Account]
    @Environment(\.presentationMode) var presentationMode
    @State private var searchText = ""
    
    var filteredAccounts: [Account] {
        if searchText.isEmpty {
            return accounts
        } else {
            return accounts.filter { $0.id.localizedCaseInsensitiveContains(searchText) || $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        List {
            ForEach(filteredAccounts) { account in
                Button(action: {
                    selection = account.id
                    presentationMode.wrappedValue.dismiss()
                }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(account.name)
                                .font(.headline)
                                .foregroundColor(.primary)
                            HStack {
                                Text(account.category)
                                    .font(.caption)
                                    .padding(4)
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(4)
                                Text(account.type)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                        if account.id == selection {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .navigationTitle(title)
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
    }
}
