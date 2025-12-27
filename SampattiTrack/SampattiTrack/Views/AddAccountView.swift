import SwiftUI
import SwiftData

struct AddAccountView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // Fetch all accounts for parent/related selection
    @Query(sort: \SDAccount.name) private var accounts: [SDAccount]
    
    // Form State
    @State private var name = ""
    @State private var selectedCategory: AccountCategory = .asset
    @State private var selectedType: AccountType = .cash
    @State private var currency = "INR"
    @State private var selectedParent: SDAccount?
    @State private var selectedRelatedAccount: SDAccount?
    
    // Credit Card Metadata
    @State private var creditLimit = ""
    @State private var network = ""
    @State private var statementDay = 1
    @State private var dueDay = 20
    @State private var lastDigits = ""
    @State private var expirationDate = Date()
    
    @State private var showError = false
    @State private var errorMessage = ""
    
    enum AccountCategory: String, CaseIterable, Identifiable {
        case asset = "Asset"
        case liability = "Liability"
        case income = "Income"
        case expense = "Expense"
        case equity = "Equity"
        
        var id: String { self.rawValue }
    }
    
    enum AccountType: String, CaseIterable, Identifiable {
        case cash = "Cash"
        case investment = "Investment"
        case creditCard = "CreditCard"
        case custom = "Custom"
        
        var id: String { self.rawValue }
    }
    
    // Filtered parent options (same category, excluding self)
    var parentOptions: [SDAccount] {
        accounts.filter { $0.category == selectedCategory.rawValue }
    }
    
    // Related account options (Asset/Liability for linking)
    var relatedAccountOptions: [SDAccount] {
        accounts.filter { acc in
            acc.category == "Asset" || acc.category == "Liability" || acc.category == "Expense"
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Basic Information") {
                    TextField("Account Name", text: $name)
                        .textContentType(.name)
                    
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(AccountCategory.allCases) { category in
                            Text(category.rawValue).tag(category)
                        }
                    }
                    .onChange(of: selectedCategory) { oldValue, newValue in
                        // Reset parent when category changes
                        selectedParent = nil
                    }
                    
                    Picker("Type", selection: $selectedType) {
                        ForEach(AccountType.allCases) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    
                    TextField("Currency", text: $currency)
                }
                
                Section("Hierarchy") {
                    Picker("Parent Account (Optional)", selection: $selectedParent) {
                        Text("No Parent (Top Level)").tag(nil as SDAccount?)
                        ForEach(parentOptions, id: \.id) { account in
                            Text(account.name).tag(account as SDAccount?)
                        }
                    }
                    .pickerStyle(.navigationLink)
                    
                    Picker("Related Account (Optional)", selection: $selectedRelatedAccount) {
                        Text("None").tag(nil as SDAccount?)
                        ForEach(relatedAccountOptions, id: \.id) { account in
                            Text("\(account.name) (\(account.category))").tag(account as SDAccount?)
                        }
                    }
                    .pickerStyle(.navigationLink)
                    
                    Text("Link Income/Expense to Asset/Liability")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if selectedType == .creditCard {
                    Section("Credit Card Details") {
                        TextField("Credit Limit", text: $creditLimit)
                            .keyboardType(.decimalPad)
                        
                        TextField("Network (e.g., Visa, MasterCard)", text: $network)
                        
                        Stepper("Statement Day: \(statementDay)", value: $statementDay, in: 1...31)
                        Text("Day of month when statement is generated")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Stepper("Due Day: \(dueDay)", value: $dueDay, in: 1...31)
                        Text("Day of month when payment is due")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        TextField("Last 4 Digits", text: $lastDigits)
                            .keyboardType(.numberPad)
                            .onChange(of: lastDigits) { oldValue, newValue in
                                // Limit to 4 characters
                                if newValue.count > 4 {
                                    lastDigits = String(newValue.prefix(4))
                                }
                            }
                        
                        DatePicker("Expiration Date", selection: $expirationDate, displayedComponents: [.date])
                    }
                }
            }
            .navigationTitle("Add Account")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveAccount()
                    }
                    .disabled(name.isEmpty)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    func saveAccount() {
        do {
            // Generate unique ID in the backend format (category:parent:name)
            let parentPath = selectedParent?.id ?? selectedCategory.rawValue
            let accountId = "\(parentPath):\(name)"
            
            // Prepare metadata if credit card
            var metadata: Data? = nil
            if selectedType == .creditCard {
                var metadataDict: [String: Any] = [:]
                
                if let limit = Double(creditLimit), limit > 0 {
                    metadataDict["credit_limit"] = limit
                }
                if !network.isEmpty {
                    metadataDict["network"] = network
                }
                metadataDict["statement_day"] = statementDay
                metadataDict["due_day"] = dueDay
                if !lastDigits.isEmpty {
                    metadataDict["last_digits"] = lastDigits
                }
                
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd"
                metadataDict["expiration_date"] = dateFormatter.string(from: expirationDate)
                
                if !metadataDict.isEmpty {
                    metadata = try JSONSerialization.data(withJSONObject: metadataDict)
                }
            }
            
            // Create local SDAccount (for immediate offline access)
            let sdAccount = SDAccount(
                id: accountId,
                name: name,
                category: selectedCategory.rawValue,
                type: selectedType.rawValue,
                currency: currency,
                icon: nil,
                parentID: selectedParent?.id,
                metadata: metadata,
                isSynced: false  // Mark as unsynced
            )
            
            modelContext.insert(sdAccount)
            try modelContext.save()
            
            // Queue for sync
            try OfflineQueueHelper.queueAccount(
                id: accountId,
                name: name,
                category: selectedCategory.rawValue,
                type: selectedType.rawValue,
                currency: currency,
                icon: nil,
                parentID: selectedParent?.id,
                relatedAccountId: selectedRelatedAccount?.id,
                metadata: metadata != nil ? try JSONSerialization.jsonObject(with: metadata!) as? [String: Any] : nil,
                context: modelContext
            )
            
            dismiss()
            
        } catch {
            errorMessage = "Failed to create account: \(error.localizedDescription)"
            showError = true
        }
    }
}
