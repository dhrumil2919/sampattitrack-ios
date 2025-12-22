import SwiftUI
import Combine

class EditTransactionViewModel: ObservableObject {
    @Published var date: Date = Date()
    @Published var description: String = ""
    @Published var note: String = ""
    @Published var postings: [EditablePosting] = []
    
    @Published var accounts: [Account] = []
    @Published var units: [FinancialUnit] = []
    @Published var availableTags: [Tag] = []
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    
    let transactionID: UUID
    
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
        
        // Try multiple date formats
        let formats = ["yyyy-MM-dd", "yyyy-MM-dd'T'HH:mm:ss'Z'", "yyyy-MM-dd'T'HH:mm:ssZ", "yyyy-MM-dd'T'HH:mm:ss.SSSZ"]
        var parsedDate: Date? = nil
        
        for format in formats {
            let formatter = DateFormatter()
            formatter.dateFormat = format
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            if let d = formatter.date(from: transaction.date) {
                parsedDate = d
                break
            }
        }
        
        // Fallback: try ISO8601DateFormatter
        if parsedDate == nil {
            let isoFormatter = ISO8601DateFormatter()
            isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            parsedDate = isoFormatter.date(from: transaction.date)
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
    
    func fetchAccounts() {
        isLoading = true
        
        // Fetch accounts
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
        
        // Fetch units
        APIClient.shared.listUnits { (result: Result<UnitListResponse, APIClient.APIError>) in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    if response.success {
                        self.units = response.data
                    }
                case .failure:
                    break
                }
            }
        }
        
        // Fetch available tags
        APIClient.shared.listTags { (result: Result<TagListResponse, APIClient.APIError>) in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    if response.success {
                        self.availableTags = response.data
                    }
                case .failure:
                    break
                }
            }
        }
        
        // Fetch fresh transaction data from API to get tags (local SwiftData doesn't store tags)
        APIClient.shared.request("/transactions/\(transactionID.uuidString)") { (result: Result<SingleTransactionResponse, APIClient.APIError>) in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    if response.success {
                        // Update postings with fresh data including tags
                        self.postings = response.data.postings.map { p in
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
                case .failure:
                    // Keep local data if API fails
                    break
                }
            }
        }
    }
    
    func fetchPriceForPosting(at index: Int, date: String) {
        let unitCode = postings[index].unitCode
        guard unitCode != "INR" else {
            postings[index].price = "1"
            recalculateAmount(at: index)
            return
        }
        
        APIClient.shared.lookupPrice(unitCode: unitCode, date: date) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    if response.success {
                        self.postings[index].price = response.data.price
                        self.recalculateAmount(at: index)
                    }
                case .failure(let error):
                    self.errorMessage = "Price lookup failed: \(error)"
                }
            }
        }
    }
    
    func recalculateAmount(at index: Int) {
        let qty = Double(postings[index].quantity) ?? 0
        let price = Double(postings[index].price) ?? 0
        postings[index].amount = String(qty * price)
    }
    
    func save() {
        isSaving = true
        errorMessage = nil
        
        // Validation: Check balance?
        // Let's rely on backend validation or add simple check here if needed.
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateStr = formatter.string(from: date)
        
        struct UpdatePostingRequest: Encodable {
            let account_id: String
            let amount: String
            let quantity: String
            let unit_code: String?
            let tags: [String]?
        }

        struct UpdateTransactionRequest: Encodable {
            let date: String
            let description: String
            let note: String
            let postings: [UpdatePostingRequest]
        }
        
        let postingRequests = postings.map { p in
            UpdatePostingRequest(
                account_id: p.accountID,
                amount: p.amount,
                quantity: p.quantity.isEmpty ? "0" : p.quantity,
                unit_code: p.unitCode,
                tags: p.tags.isEmpty ? nil : p.tags
            )
        }
        
        let req = UpdateTransactionRequest(date: dateStr, description: description, note: note, postings: postingRequests)
        
        APIClient.shared.request("/transactions/\(transactionID.uuidString)", method: "PUT", body: req) { (result: Result<TransactionResponse, APIClient.APIError>) in
             DispatchQueue.main.async {
                self.isSaving = false
                switch result {
                case .success(let response):
                    if response.success {
                        self.successMessage = "Transaction updated!"
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

struct EditTransactionView: View {
    @StateObject private var viewModel: EditTransactionViewModel
    @Environment(\.presentationMode) var presentationMode
    
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
                        // Account Selector - DEBUG: Show ID only
                        NavigationLink(destination: SearchableAccountPicker(
                            title: "Select Account",
                            selection: $posting.accountID,
                            accounts: viewModel.accounts
                        )) {
                            Text(posting.accountID)
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                        
                        // Unit Picker
                        Picker("Unit", selection: Binding(
                            get: { posting.unitCode },
                            set: { newValue in
                                if let index = viewModel.postings.firstIndex(where: { $0.id == posting.id }) {
                                    viewModel.postings[index].unitCode = newValue
                                    let formatter = DateFormatter()
                                    formatter.dateFormat = "yyyy-MM-dd"
                                    let dateString = formatter.string(from: viewModel.date)
                                    viewModel.fetchPriceForPosting(at: index, date: dateString)
                                }
                            }
                        )) {
                            ForEach(viewModel.units) { unit in
                                Text("\(unit.code) - \(unit.name)").tag(unit.code)
                            }
                        }
                        .pickerStyle(.menu)
                        
                        HStack {
                            // Quantity
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
                            
                            // Price indicator
                            Text("@ \(posting.price)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 60, alignment: .leading)
                            
                            // Amount (read-only, auto-calculated)
                            TextField("Amount", text: .constant(posting.amount))
                                .disabled(true)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .foregroundColor(Double(posting.amount) ?? 0 < 0 ? .red : .green)
                                .opacity(0.7)
                            

                        }
                        
                        // Tags Section
                        TagsEditorView(
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
                
                // Add Posting Button
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
            viewModel.fetchAccounts()
        }
    }
}

// MARK: - Tags Editor View
struct TagsEditorView: View {
    @Binding var tags: [String]
    let availableTags: [Tag]
    
    @State private var selectedTag: String = ""
    
    var unselectedTags: [Tag] {
        availableTags.filter { !tags.contains($0.name) }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Tags")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                // Tag Picker
                if !unselectedTags.isEmpty {
                    Menu {
                        ForEach(unselectedTags) { tag in
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
                    .accessibilityLabel("Add tag")
                }
            }
            
            // Selected Tags as Chips
            if !tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(tags, id: \.self) { tagName in
                            TagChip(
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

// MARK: - Tag Chip
struct TagChip: View {
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
            .accessibilityLabel("Remove \(name) tag")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(chipColor.opacity(0.15))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(chipColor.opacity(0.3), lineWidth: 1)
        )
    }
}
