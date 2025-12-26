import SwiftUI
import SwiftData
import Combine

let CATEGORIES = ["Asset", "Liability", "Income", "Expense", "Equity"]
let TYPES = ["Cash", "Stock", "MutualFund", "Metal", "NPS", "CreditCard", "Loan", "Custom"]

/// EditAccountViewModel - OFFLINE-FIRST
/// Uses local SwiftData. Saves locally with isSynced=false.
class EditAccountViewModel: ObservableObject {
    @Published var name: String
    @Published var type: String
    @Published var category: String
    @Published var currency: String
    @Published var parentID: String?
    @Published var relatedAccountID: String?
    
    @Published var accounts: [SDAccount] = []
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    
    let accountID: String
    private var modelContext: ModelContext?
    
    init(account: Account) {
        self.accountID = account.id
        self.name = account.name
        self.type = account.type
        self.category = account.category
        self.currency = account.currency ?? "INR"
        self.parentID = account.parentID
    }
    
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
        fetchAccounts()
    }
    
    /// Fetch accounts from LOCAL SwiftData - no API call
    func fetchAccounts() {
        guard let context = modelContext else { return }
        
        isLoading = true
        do {
            let descriptor = FetchDescriptor<SDAccount>(sortBy: [SortDescriptor(\.name)])
            accounts = try context.fetch(descriptor)
            isLoading = false
        } catch {
            errorMessage = "Failed to load accounts: \(error)"
            isLoading = false
        }
    }
    
    var parentOptions: [SDAccount] {
        accounts.filter { $0.category == category && $0.id != accountID }
    }
    
    var relatedAccountOptions: [SDAccount] {
        accounts.filter { ($0.category == "Asset" || $0.category == "Liability" || $0.category == "Expense") && $0.id != accountID }
    }
    
    /// Save to LOCAL SwiftData with isSynced=false - no API call
    func save() {
        guard let context = modelContext else {
            errorMessage = "Database not available"
            return
        }
        
        isSaving = true
        errorMessage = nil
        
        let accId = accountID
        let descriptor = FetchDescriptor<SDAccount>(predicate: #Predicate { $0.id == accId })
        
        do {
            if let existing = try context.fetch(descriptor).first {
                existing.name = name
                existing.type = type
                existing.category = category
                existing.currency = currency
                existing.parentID = parentID
                existing.isSynced = false  // Mark for sync
                existing.updatedAt = Date()
                
                try context.save()
                isSaving = false
                successMessage = "Account updated!"
            } else {
                errorMessage = "Account not found locally"
                isSaving = false
            }
        } catch {
            errorMessage = "Failed to save: \(error)"
            isSaving = false
        }
    }
}

struct EditAccountView: View {
    @StateObject private var viewModel: EditAccountViewModel
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.modelContext) private var modelContext
    
    init(account: Account) {
        _viewModel = StateObject(wrappedValue: EditAccountViewModel(account: account))
    }
    
    var body: some View {
        Form {
            Section(header: Text("Account Details")) {
                TextField("Name", text: $viewModel.name)
                
                Picker("Category", selection: $viewModel.category) {
                    ForEach(CATEGORIES, id: \.self) { cat in
                        Text(cat).tag(cat)
                    }
                }
                
                Picker("Type", selection: $viewModel.type) {
                    ForEach(TYPES, id: \.self) { type in
                        Text(type).tag(type)
                    }
                }
                
                TextField("Currency", text: $viewModel.currency)
            }
            
            Section(header: Text("Hierarchy")) {
                Picker("Parent Account", selection: Binding(
                    get: { viewModel.parentID ?? "" },
                    set: { viewModel.parentID = $0.isEmpty ? nil : $0 }
                )) {
                    Text("None (Top Level)").tag("")
                    ForEach(viewModel.parentOptions, id: \.id) { acc in
                        Text(acc.name).tag(acc.id)
                    }
                }
            }
            
            if let error = viewModel.errorMessage {
                Section {
                    Text(error).foregroundColor(.red)
                }
            }
            
            Section(footer: Group {
                if viewModel.name.isEmpty {
                    Text("Account name cannot be empty.")
                        .foregroundColor(.red)
                }
            }) {
                Button(action: { viewModel.save() }) {
                    if viewModel.isSaving {
                        ProgressView()
                    } else {
                        Text("Save Changes")
                    }
                }
                .disabled(viewModel.isLoading || viewModel.isSaving || viewModel.name.isEmpty)
            }
        }
        .navigationTitle("Edit Account")
        .onChange(of: viewModel.successMessage) {
            if viewModel.successMessage != nil {
                presentationMode.wrappedValue.dismiss()
            }
        }
        .onAppear {
            viewModel.setModelContext(modelContext)
        }
    }
}
