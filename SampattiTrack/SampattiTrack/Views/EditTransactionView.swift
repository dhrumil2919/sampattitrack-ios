import SwiftUI
import SwiftData
import Combine

/// EditTransactionViewModel - OFFLINE-FIRST
/// Uses local SwiftData, saves changes locally with isSynced=false
class EditTransactionViewModel: ObservableObject {
    @Published var date: Date = Date()
    @Published var description: String = ""
    @Published var note: String = ""
    @Published var postings: [EditablePosting] = []
    
    @Published var accounts: [SDAccount] = []
    @Published var units: [SDUnit] = []
    @Published var availableTags: [SDTag] = []
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    
    let transactionID: UUID
    private var modelContext: ModelContext?
    
    struct EditablePosting: Identifiable {
        let id = UUID()
        var accountID: String
        var amount: String
        var quantity: String
        var unitCode: String = "INR"
        var price: String = "1"
        var tags: [String] = []
    }
    
    init(transaction: Transaction) {
        self.transactionID = transaction.id
        self.description = transaction.description
        self.note = transaction.note ?? ""
        
        // Parse date
        let formats = ["yyyy-MM-dd", "yyyy-MM-dd'T'HH:mm:ss'Z'", "yyyy-MM-dd'T'HH:mm:ssZ"]
        var parsedDate: Date? = nil
        for format in formats {
            let formatter = DateFormatter()
            formatter.dateFormat = format
            formatter.locale = Locale(identifier: "en_US_POSIX")
            if let d = formatter.date(from: transaction.date) {
                parsedDate = d
                break
            }
        }
        self.date = parsedDate ?? Date()
        
        self.postings = transaction.postings.map { p in
            let qty = p.quantity ?? p.amount
            let price = p.unitCode == "INR" || p.unitCode == nil ? "1" : 
                (abs(Double(p.amount) ?? 0) / abs(Double(qty) ?? 1)).description
            return EditablePosting(
                accountID: p.accountID,
                amount: p.amount,
                quantity: qty,
                unitCode: p.unitCode ?? "INR",
                price: price,
                tags: p.tags?.map { $0.name } ?? []
            )
        }
    }
    
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }
    
    /// Fetch accounts, units, tags from LOCAL SwiftData - no API calls
    func fetchLocalData() {
        guard let context = modelContext else {
            errorMessage = "Database not available"
            return
        }
        isLoading = true
        
        do {
            let accountDescriptor = FetchDescriptor<SDAccount>(sortBy: [SortDescriptor(\.name)])
            accounts = try context.fetch(accountDescriptor)
            
            let unitDescriptor = FetchDescriptor<SDUnit>(sortBy: [SortDescriptor(\.name)])
            units = try context.fetch(unitDescriptor)
            
            let tagDescriptor = FetchDescriptor<SDTag>(sortBy: [SortDescriptor(\.name)])
            availableTags = try context.fetch(tagDescriptor)
            
            isLoading = false
        } catch {
            errorMessage = "Failed to load data: \(error)"
            isLoading = false
        }
    }
    
    func recalculateAmount(at index: Int) {
        let qty = Double(postings[index].quantity) ?? 0
        let price = Double(postings[index].price) ?? 0
        postings[index].amount = String(qty * price)
    }
    
    /// Save changes to LOCAL SwiftData - no API call
    func save() {
        guard let context = modelContext else {
            errorMessage = "Database not available"
            return
        }
        
        isSaving = true
        errorMessage = nil
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateStr = formatter.string(from: date)
        
        // Find existing transaction
        let txId = transactionID
        let descriptor = FetchDescriptor<SDTransaction>(predicate: #Predicate { $0.id == txId })
        
        do {
            if let existing = try context.fetch(descriptor).first {
                // Update existing transaction
                existing.date = dateStr
                existing.desc = description
                existing.note = note.isEmpty ? nil : note
                existing.isSynced = false  // Mark for sync
                existing.updatedAt = Date()
                
                // Fetch tags for linking
                let tagDescriptor = FetchDescriptor<SDTag>()
                let allTags = try context.fetch(tagDescriptor)
                let tagMap = Dictionary(uniqueKeysWithValues: allTags.map { ($0.name, $0) })
                
                // Recreate postings
                var newPostings: [SDPosting] = []
                for p in postings {
                    let postingTags = p.tags.compactMap { tagMap[$0] }
                    let posting = SDPosting(
                        id: UUID(),
                        accountID: p.accountID,
                        amount: p.amount,
                        quantity: p.quantity.isEmpty ? p.amount : p.quantity,
                        unitCode: p.unitCode,
                        tags: postingTags.isEmpty ? nil : postingTags
                    )
                    newPostings.append(posting)
                }
                existing.postings = newPostings
                
                try context.save()
                isSaving = false
                successMessage = "Transaction updated!"
            } else {
                errorMessage = "Transaction not found locally"
                isSaving = false
            }
        } catch {
            errorMessage = "Failed to save: \(error)"
            isSaving = false
        }
    }
}

struct EditTransactionView: View {
    @StateObject private var viewModel: EditTransactionViewModel
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.modelContext) private var modelContext
    
    init(transaction: Transaction) {
        _viewModel = StateObject(wrappedValue: EditTransactionViewModel(transaction: transaction))
    }
    
    var body: some View {
        Form {
            Section(header: Text("Details")) {
                DatePicker("Date", selection: $viewModel.date, displayedComponents: .date)
                TextField("Description", text: $viewModel.description)
                TextField("Note", text: $viewModel.note)
            }
            
            Section(header: Text("Postings (Splits)")) {
                ForEach($viewModel.postings) { $posting in
                    VStack(alignment: .leading, spacing: 8) {
                        // Account Selector
                        if let account = viewModel.accounts.first(where: { $0.id == posting.accountID }) {
                            NavigationLink(destination: LocalAccountPicker(
                                title: "Select Account",
                                selection: $posting.accountID,
                                accounts: viewModel.accounts
                            )) {
                                Text(account.name)
                                    .foregroundColor(.primary)
                            }
                        } else {
                            NavigationLink(destination: LocalAccountPicker(
                                title: "Select Account",
                                selection: $posting.accountID,
                                accounts: viewModel.accounts
                            )) {
                                Text("Select Account")
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        // Unit Picker
                        Picker("Unit", selection: Binding(
                            get: { posting.unitCode },
                            set: { newValue in
                                if let index = viewModel.postings.firstIndex(where: { $0.id == posting.id }) {
                                    viewModel.postings[index].unitCode = newValue
                                    viewModel.postings[index].price = "1"
                                    viewModel.recalculateAmount(at: index)
                                }
                            }
                        )) {
                            ForEach(viewModel.units, id: \.code) { unit in
                                Text("\(unit.code) - \(unit.name)").tag(unit.code)
                            }
                        }
                        .pickerStyle(.menu)
                        
                        HStack {
                            TextField("Quantity", text: Binding(
                                get: { posting.quantity },
                                set: { newValue in
                                    if let index = viewModel.postings.firstIndex(where: { $0.id == posting.id }) {
                                        viewModel.postings[index].quantity = newValue
                                        viewModel.recalculateAmount(at: index)
                                    }
                                }
                            ))
                            .keyboardType(.decimalPad)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 80)
                            
                            Text("@ \(posting.price)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 60, alignment: .leading)
                            
                            TextField("Amount", text: .constant(posting.amount))
                                .disabled(true)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .foregroundColor(Double(posting.amount) ?? 0 < 0 ? .red : .green)
                                .opacity(0.7)
                        }
                        
                        // Tags Section
                        LocalTagsEditorView(
                            tags: Binding(
                                get: { posting.tags },
                                set: { newTags in
                                    if let index = viewModel.postings.firstIndex(where: { $0.id == posting.id }) {
                                        viewModel.postings[index].tags = newTags
                                    }
                                }
                            ),
                            availableTags: viewModel.availableTags
                        )
                    }
                    .padding(.vertical, 4)
                }
                .onDelete { indexSet in
                    if viewModel.postings.count > 2 {
                        viewModel.postings.remove(atOffsets: indexSet)
                    }
                }
                
                Button(action: {
                    viewModel.postings.append(EditTransactionViewModel.EditablePosting(accountID: "", amount: "", quantity: ""))
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Posting")
                    }
                }
            }
            
            // Balance Indicator
            let total = viewModel.postings.reduce(0.0) { $0 + (Double($1.amount) ?? 0) }
            let isBalanced = abs(total) < 0.01
            Section {
                HStack {
                    Text(isBalanced ? "Balanced" : "Imbalance: \(CurrencyFormatter.formatCheck(abs(total)))")
                        .foregroundColor(isBalanced ? .green : .red)
                }
            }
            
            if let error = viewModel.errorMessage {
                Text(error).foregroundColor(.red)
            }
            
            Button("Save Changes") {
                viewModel.save()
            }
            .disabled(viewModel.isLoading || viewModel.isSaving)
        }
        .navigationTitle("Edit Transaction")
        .onChange(of: viewModel.successMessage) {
            if viewModel.successMessage != nil {
                presentationMode.wrappedValue.dismiss()
            }
        }
        .onAppear {
            viewModel.setModelContext(modelContext)
            viewModel.fetchLocalData()
        }
    }
}
