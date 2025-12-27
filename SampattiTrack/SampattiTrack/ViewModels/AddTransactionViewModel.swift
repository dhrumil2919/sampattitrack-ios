import Foundation
import SwiftData
import Combine

/// AddTransactionViewModel manages the state and logic for creating new transactions.
/// Uses local SwiftData for offline-first operation - no API calls required.
class AddTransactionViewModel: ObservableObject {
    @Published var description: String = ""
    @Published var note: String = ""
    @Published var date: Date = Date()
    @Published var postings: [EditablePosting] = [
        EditablePosting(accountID: "", amount: "", quantity: ""),
        EditablePosting(accountID: "", amount: "", quantity: "")
    ]
    
    @Published var accounts: [SDAccount] = []
    @Published var units: [SDUnit] = []
    @Published var availableTags: [SDTag] = []
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    
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
    
    var totalAmount: Double {
        postings.reduce(0.0) { $0 + (Double($1.amount) ?? 0) }
    }
    
    var isBalanced: Bool {
        abs(totalAmount) < 0.01
    }
    
    /// Set the model context for SwiftData operations
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }
    
    /// Fetch accounts, units, and tags from local SwiftData
    func fetchLocalData() {
        guard let context = modelContext else {
            errorMessage = "Database not available"
            return
        }
        
        isLoading = true
        
        do {
            // Fetch accounts
            let accountDescriptor = FetchDescriptor<SDAccount>(sortBy: [SortDescriptor(\.name)])
            accounts = try context.fetch(accountDescriptor)
            
            // Fetch units
            let unitDescriptor = FetchDescriptor<SDUnit>(sortBy: [SortDescriptor(\.name)])
            units = try context.fetch(unitDescriptor)
            
            // Fetch tags
            let tagDescriptor = FetchDescriptor<SDTag>(sortBy: [SortDescriptor(\.name)])
            availableTags = try context.fetch(tagDescriptor)
            
            isLoading = false
        } catch {
            errorMessage = "Failed to load data: \(error)"
            isLoading = false
        }
    }
    
    func addPosting() {
        postings.append(EditablePosting(accountID: "", amount: "", quantity: ""))
    }
    
    func removePosting(at index: Int) {
        guard postings.count > 2 else { return }
        postings.remove(at: index)
    }
    
    func fetchPriceForPosting(at index: Int, date: String) {
        let unitCode = postings[index].unitCode
        guard unitCode != "INR" else {
            postings[index].price = "1"
            recalculateAmount(at: index)
            return
        }
        
        // For non-INR units, we could lookup price from a local cache
        // For now, just set price to 1 and user can manually adjust
        postings[index].price = "1"
        recalculateAmount(at: index)
    }
    
    func recalculateAmount(at index: Int) {
        let qty = Double(postings[index].quantity) ?? 0
        let price = Double(postings[index].price) ?? 0
        postings[index].amount = String(qty * price)
    }
    
    /// OFFLINE-FIRST: Creates transaction by writing to local SwiftData FIRST
    /// Then queues backend operation separately (non-blocking)
    /// 
    /// Flow:
    /// 1. Write SDTransaction + SDPosting to SwiftData (isSynced = false)
    /// 2. Save locally - transaction appears in UI immediately
    /// 3. Queue backend sync operation
    /// 4. Background sync happens asynchronously
    func createTransaction() {
        guard isBalanced else {
            errorMessage = "Transaction does not balance. Imbalance: \(CurrencyFormatter.formatCheck(abs(totalAmount)))"
            return
        }
        
        guard postings.allSatisfy({ !$0.accountID.isEmpty }) else {
            errorMessage = "Please select an account for each posting"
            return
        }
        
        guard let context = modelContext else {
            errorMessage = "Database not available"
            return
        }
        
        isSaving = true
        errorMessage = nil
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: date)
        
        // OFFLINE-FIRST: Generate stable UUIDs
        let transactionID = UUID()
        let postingIDs = postings.map { _ in UUID() }
        
        do {
            // STEP 1: Write to SwiftData FIRST (source of truth)
            let transaction = SDTransaction(
                id: transactionID,
                date: dateString,
                desc: description,
                note: note.isEmpty ? nil : note,
                isSynced: false  // Mark as unsynced
            )
            context.insert(transaction)
            
            // Create SDPosting objects
            var sdPostings: [SDPosting] = []
            for (index, p) in postings.enumerated() {
                let posting = SDPosting(
                    id: postingIDs[index],
                    accountID: p.accountID,
                    amount: p.amount,
                    quantity: p.quantity.isEmpty ? p.amount : p.quantity,
                    unitCode: p.unitCode,
                    tags: nil  // Tags not implemented in offline create yet
                )
                posting.transaction = transaction
                context.insert(posting)
                sdPostings.append(posting)
            }
            transaction.postings = sdPostings
            
            // Save to SwiftData - transaction now visible in UI!
            try context.save()
            print("[AddTransaction] ✓ Saved locally: \(description)")
            
            // STEP 2: Queue for backend sync (non-blocking)
            let postingsJSON = postings.enumerated().map { (index, p) in
                [
                    "id": postingIDs[index].uuidString,
                    "account_id": p.accountID,
                    "amount": p.amount,
                    "quantity": p.quantity.isEmpty ? p.amount : p.quantity,
                    "unit_code": p.unitCode
                ] as [String: Any]
            }
            
            try OfflineQueueHelper.queueTransaction(
                id: transactionID,
                date: dateString,
                description: description,
                note: note.isEmpty ? nil : note,
                postings: postingsJSON,
                context: context
            )
            
            print("[AddTransaction] ⏫ Queued for backend sync")
            
            isSaving = false
            successMessage = "Transaction Created!"
            
            // Reset form
            self.description = ""
            self.note = ""
            self.date = Date()
            self.postings = [
                EditablePosting(accountID: "", amount: "", quantity: ""),
                EditablePosting(accountID: "", amount: "", quantity: "")
            ]
        } catch {
            isSaving = false
            errorMessage = "Failed to create transaction: \(error)"
            print("[AddTransaction] ✗ Error: \(error)")
        }
    }
}
