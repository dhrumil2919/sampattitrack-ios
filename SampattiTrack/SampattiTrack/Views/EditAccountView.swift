import SwiftUI
import Combine
import SwiftData

let CATEGORIES = ["Asset", "Liability", "Income", "Expense", "Equity"]
let TYPES = ["Cash", "Stock", "MutualFund", "Metal", "NPS", "CreditCard", "Loan", "Custom"]

class EditAccountViewModel: ObservableObject {
    @Published var name: String
    @Published var type: String
    @Published var category: String
    @Published var currency: String
    @Published var parentID: String?
    @Published var relatedAccountID: String?
    
    @Published var parentOptions: [Account] = []
    @Published var relatedAccountOptions: [Account] = []
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    
    private let modelContext: ModelContext
    let accountID: String?
    let isNewAccount: Bool
    
    init(account: Account?, modelContext: ModelContext) {
        self.modelContext = modelContext
        if let account = account {
            self.accountID = account.id
            self.name = account.name
            self.type = account.type
            self.category = account.category
            self.currency = account.currency ?? "INR"
            self.parentID = account.parentID
            // Attempt to load relatedAccountID if available in Account struct, otherwise nil for now or fetch?
            // Since Account struct doesn't have relatedAccountID, we might miss it unless we fetch SDAccount.
            // But usually we pass Account from UI.
            // IMPROVEMENT: If we have SDAccount, we should use it. But for compatibility with existing views...
            // Let's assume for now existing accounts might not show related ID unless we fetch SDAccount.
            self.relatedAccountID = nil
            self.isNewAccount = false

            // Try to fetch existing SDAccount to get relatedAccountID
            let id = account.id
            let descriptor = FetchDescriptor<SDAccount>(predicate: #Predicate { $0.id == id })
            if let existing = try? modelContext.fetch(descriptor).first {
                self.relatedAccountID = existing.relatedAccountID
            }

        } else {
            self.accountID = nil
            self.name = ""
            self.type = "Cash"
            self.category = "Asset"
            self.currency = "INR"
            self.parentID = nil
            self.relatedAccountID = nil
            self.isNewAccount = true
        }
    }
    
    @MainActor
    func fetchAccounts() {
        isLoading = true
        do {
            let descriptor = FetchDescriptor<SDAccount>(sortBy: [SortDescriptor(\.name)])
            let accounts = try modelContext.fetch(descriptor).map { $0.toAccount }

            // Filter logic
            self.parentOptions = accounts.filter {
                $0.category == self.category && $0.id != (self.accountID ?? "")
            }

            self.relatedAccountOptions = accounts.filter {
                ($0.category == "Asset" || $0.category == "Liability" || $0.category == "Expense") && $0.id != (self.accountID ?? "")
            }

            self.isLoading = false
        } catch {
            self.errorMessage = "Failed to load accounts: \(error.localizedDescription)"
            self.isLoading = false
        }
    }
    
    @MainActor
    func save() {
        isSaving = true
        errorMessage = nil
        
        // Validation
        if name.isEmpty {
            errorMessage = "Name is required"
            isSaving = false
            return
        }
        
        do {
            if isNewAccount {
                // Create
                let newID = UUID().uuidString
                let newAccount = SDAccount(
                    id: newID,
                    name: name,
                    category: category,
                    type: type,
                    currency: currency,
                    icon: nil,
                    parentID: parentID,
                    relatedAccountID: relatedAccountID
                )
                // Mark as unsynced so SyncManager picks it up
                newAccount.isSynced = false
                newAccount.isNew = true
                modelContext.insert(newAccount)

            } else {
                // Update
                guard let id = accountID else {
                    errorMessage = "Internal Error: Missing ID for update"
                    isSaving = false
                    return
                }

                let descriptor = FetchDescriptor<SDAccount>(predicate: #Predicate { $0.id == id })
                if let existing = try modelContext.fetch(descriptor).first {
                    existing.name = name
                    existing.category = category
                    existing.type = type
                    existing.currency = currency
                    existing.parentID = parentID
                    existing.relatedAccountID = relatedAccountID
                    existing.isSynced = false
                    existing.updatedAt = Date()
                } else {
                    errorMessage = "Account not found locally"
                    isSaving = false
                    return
                }
            }

            try modelContext.save()

            // Trigger sync (optimistic)
            Task {
                await SyncManager(modelContext: modelContext).pushAccounts()
            }

            self.successMessage = isNewAccount ? "Account created!" : "Account updated!"
            self.isSaving = false

        } catch {
            errorMessage = "Save failed: \(error.localizedDescription)"
            isSaving = false
        }
    }
}

struct EditAccountView: View {
    @StateObject private var viewModel: EditAccountViewModel
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.modelContext) private var modelContext
    
    init(account: Account?, modelContext: ModelContext) {
        _viewModel = StateObject(wrappedValue: EditAccountViewModel(account: account, modelContext: modelContext))
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
                .onChange(of: viewModel.category) { _, _ in
                     viewModel.fetchAccounts() // Refresh parent options when category changes
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
                

                Picker("Related Account", selection: Binding(
                    get: { viewModel.relatedAccountID ?? "" },
                    set: { viewModel.relatedAccountID = $0.isEmpty ? nil : $0 }
                )) {
                    Text("None").tag("")
                    ForEach(viewModel.relatedAccountOptions, id: \.id) { acc in
                        Text("\(acc.name) (\(acc.category))").tag(acc.id)
                    }
                }

            }
            
            if let error = viewModel.errorMessage {
                Section {
                    Text(error).foregroundColor(.red)
                }
            }
            
            Section {
                Button(action: { viewModel.save() }) {
                    if viewModel.isSaving {
                        ProgressView()
                    } else {
                        Text(viewModel.isNewAccount ? "Create Account" : "Save Changes")
                    }
                }
                .disabled(viewModel.isLoading || viewModel.isSaving)
            }
        }
        .navigationTitle(viewModel.isNewAccount ? "Add Account" : "Edit Account")
        .onChange(of: viewModel.successMessage) { _, newVal in
            if newVal != nil {
                presentationMode.wrappedValue.dismiss()
            }
        }
        .onAppear {
            viewModel.fetchAccounts()
        }
    }
}
