import SwiftUI

/// Extracted posting row view to prevent excessive re-renders and memory allocations
/// Updated for offline-first: uses SDAccount, SDUnit, SDTag SwiftData types
struct PostingRowView: View {
    @Binding var posting: AddTransactionViewModel.EditablePosting
    let accounts: [SDAccount]
    let units: [SDUnit]
    let availableTags: [SDTag]
    let date: Date
    let onUnitChange: (String) -> Void
    let onQuantityChange: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Account Selector
            accountSelector
            
            // Unit Picker
            unitPicker
            
            // Quantity/Price/Amount Row
            amountRow
            
            // Tags Section
            LocalTagsEditorView(
                tags: $posting.tags,
                availableTags: availableTags
            )
        }
    }
    
    @ViewBuilder
    private var accountSelector: some View {
        if let account = accounts.first(where: { $0.id == posting.accountID }) {
            NavigationLink(destination: LocalAccountPicker(
                title: "Select Account",
                selection: $posting.accountID,
                accounts: accounts
            )) {
                Text(account.name)
                    .foregroundColor(.primary)
            }
        } else {
            NavigationLink(destination: LocalAccountPicker(
                title: "Select Account",
                selection: $posting.accountID,
                accounts: accounts
            )) {
                Text("Select Account")
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var unitPicker: some View {
        Picker("Unit", selection: Binding(
            get: { posting.unitCode },
            set: { onUnitChange($0) }
        )) {
            ForEach(units, id: \.code) { unit in
                Text("\(unit.code) - \(unit.name)").tag(unit.code)
            }
        }
        .pickerStyle(.menu)
    }
    
    private var amountRow: some View {
        HStack {
            // Quantity
            TextField("Quantity", text: Binding(
                get: { posting.quantity },
                set: { onQuantityChange($0) }
            ))
            .keyboardType(.numbersAndPunctuation)
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .frame(width: 80)
            .accessibilityLabel("Quantity")
            
            // Price indicator
            Text("@ \(posting.price)")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 60, alignment: .leading)
            
            // Amount (read-only, auto-calculated)
            TextField("Amount", text: .constant(posting.amount))
                .disabled(true)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .foregroundColor((Double(posting.amount) ?? 0) < 0 ? .red : .green)
                .opacity(0.7)
                .accessibilityLabel("Amount")
                .accessibilityHint("Calculated based on quantity and price")
        }
    }
}

// MARK: - Local Account Picker (uses SDAccount)
struct LocalAccountPicker: View {
    let title: String
    @Binding var selection: String
    let accounts: [SDAccount]
    
    @State private var searchText = ""
    
    var filteredAccounts: [SDAccount] {
        if searchText.isEmpty {
            return accounts
        }
        return accounts.filter { 
            $0.id.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    // Group accounts by category for better organization
    var groupedAccounts: [String: [SDAccount]] {
        Dictionary(grouping: filteredAccounts, by: { $0.category })
    }
    
    var sortedCategories: [String] {
        ["Asset", "Liability", "Income", "Expense", "Equity"].filter { groupedAccounts[$0] != nil }
    }
    
    var body: some View {
        List {
            ForEach(sortedCategories, id: \.self) { category in
                Section(header: Text(category)) {
                    ForEach(groupedAccounts[category] ?? [], id: \.id) { account in
                        Button(action: {
                            selection = account.id
                        }) {
                            HStack {
                                // Display ID which is in category:parent:name format
                                Text(account.id)
                                    .font(.body)
                                Spacer()
                                if selection == account.id {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .foregroundColor(.primary)
                    }
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search accounts")
        .navigationTitle(title)
    }
}

// MARK: - Local Tags Editor (uses SDTag)
struct LocalTagsEditorView: View {
    @Binding var tags: [String]
    let availableTags: [SDTag]
    
    var unselectedTags: [SDTag] {
        availableTags.filter { !tags.contains($0.name) }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Tags")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if !unselectedTags.isEmpty {
                    Menu {
                        ForEach(unselectedTags, id: \.id) { tag in
                            Button(tag.name) {
                                tags.append(tag.name)
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus.circle.fill")
                            Text("Add")
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                    }
                }
            }
            
            if !tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(tags, id: \.self) { tagName in
                            LocalTagChip(
                                name: tagName,
                                color: availableTags.first(where: { $0.name == tagName })?.color,
                                onRemove: {
                                    tags.removeAll { $0 == tagName }
                                }
                            )
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Local Tag Chip
struct LocalTagChip: View {
    let name: String
    let color: String?
    let onRemove: () -> Void
    
    var chipColor: Color {
        if let hex = color {
            return Color(hex: hex) ?? .blue
        }
        return .blue
    }
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(chipColor)
                .frame(width: 6, height: 6)
            
            Text(name)
                .font(.caption)
            
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .accessibilityLabel("Remove tag \(name)")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(chipColor.opacity(0.15))
        .cornerRadius(12)
    }
}
