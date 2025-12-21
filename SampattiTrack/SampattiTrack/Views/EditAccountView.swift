import SwiftUI
import Combine

let CATEGORIES = ["Asset", "Liability", "Income", "Expense", "Equity"]
let TYPES = ["Cash", "Stock", "MutualFund", "Metal", "NPS", "CreditCard", "Loan", "Custom"]

class EditAccountViewModel: ObservableObject {
    @Published var name: String
    @Published var type: String
    @Published var category: String
    @Published var currency: String
    @Published var parentID: String?
    @Published var relatedAccountID: String?
    
    @Published var accounts: [Account] = []
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    
    let accountID: String
    
    init(account: Account) {
        self.accountID = account.id
        self.name = account.name
        self.type = account.type
        self.category = account.category
        self.currency = account.currency ?? "INR"
        self.parentID = account.parentID
    }
    
    func fetchAccounts() {
        isLoading = true
        APIClient.shared.request("/accounts") { (result: Result<AccountListResponse, APIClient.APIError>) in
            DispatchQueue.main.async {
                self.isLoading = false
                switch result {
                case .success(let response):
                    if response.success {
                        self.accounts = response.data
                    }
                case .failure(let error):
                    self.errorMessage = "Failed to load accounts: \(error.localizedDescription)"
                }
            }
        }
    }
    
    var parentOptions: [Account] {
        // Parent must be same category and not self
        accounts.filter { $0.category == category && $0.id != accountID }
    }
    
    var relatedAccountOptions: [Account] {
        // Typically Asset/Liability/Expense, not self
        accounts.filter { ($0.category == "Asset" || $0.category == "Liability" || $0.category == "Expense") && $0.id != accountID }
    }
    
    func save() {
        isSaving = true
        errorMessage = nil
        
        struct UpdateAccountRequest: Encodable {
            let name: String
            let type: String
            let category: String
            let currency: String
            let parent_id: String?
            let related_account_id: String?
        }
        
        let req = UpdateAccountRequest(
            name: name,
            type: type,
            category: category,
            currency: currency,
            parent_id: parentID,
            related_account_id: relatedAccountID
        )
        
        APIClient.shared.request("/accounts/\(accountID)", method: "PUT", body: req) { (result: Result<AccountListResponse, APIClient.APIError>) in
            DispatchQueue.main.async {
                self.isSaving = false
                switch result {
                case .success(let response):
                    if response.success {
                        self.successMessage = "Account updated!"
                    } else {
                        self.errorMessage = "Failed to update"
                    }
                case .failure(let error):
                    self.errorMessage = "Error: \(error.localizedDescription)"
                }
            }
        }
    }
}

struct EditAccountView: View {
    @StateObject private var viewModel: EditAccountViewModel
    @Environment(\.presentationMode) var presentationMode
    
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
                        Text("Save Changes")
                    }
                }
                .disabled(viewModel.isLoading || viewModel.isSaving)
            }
        }
        .navigationTitle("Edit Account")
        .onChange(of: viewModel.successMessage) {
            if viewModel.successMessage != nil {
                presentationMode.wrappedValue.dismiss()
            }
        }
        .onAppear {
            viewModel.fetchAccounts()
        }
    }
}
