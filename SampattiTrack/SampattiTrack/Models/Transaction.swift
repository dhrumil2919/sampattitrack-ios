import Foundation

struct Transaction: Codable, Identifiable {
    let id: UUID
    let date: String
    let description: String
    let note: String?
    let postings: [Posting]
    
    var displayAmount: Double {
        // Simple heuristic: Sum of positive amounts
        // Ideally we filter by account context, but for global list we just show magnitude.
        postings.reduce(0) { result, posting in
            if let amount = Double(posting.amount), amount > 0 {
                return result + amount
            }
            return result
        }
    }
    
    // Display logic for a specific account context
    func amountForAccount(_ accountID: String) -> Double {
        let accountPostings = postings.filter { $0.accountID == accountID }
        return accountPostings.reduce(0) { result, posting in
            return result + (Double(posting.amount) ?? 0.0)
        }
    }
    
    func isInflow(for accountID: String) -> Bool {
        return amountForAccount(accountID) > 0
    }
    
    func otherAccountName(for accountID: String) -> String? {
        // Simple case: 2 postings
        if postings.count == 2 {
            if let other = postings.first(where: { $0.accountID != accountID }) {
                return other.accountID // In a real app we'd map ID to Name here or need Account map
            }
        }
        return nil
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case date
        case description
        case note
        case postings
    }
}

// MARK: - Transaction Type Determination
extension Transaction {
    enum TransactionType {
        case expense    // Red
        case income     // Green
        case transfer   // Blue
    }
    
    /// Determines the transaction type based on max and min postings by value
    func determineType() -> TransactionType {
        // Find max posting (largest positive value)
        guard let maxPosting = postings.max(by: { posting1, posting2 in
            let amount1 = Double(posting1.amount) ?? 0.0
            let amount2 = Double(posting2.amount) ?? 0.0
            return amount1 < amount2
        }) else {
            return .transfer
        }
        
        // Find min posting (most negative value)
        guard let minPosting = postings.min(by: { posting1, posting2 in
            let amount1 = Double(posting1.amount) ?? 0.0
            let amount2 = Double(posting2.amount) ?? 0.0
            return amount1 < amount2
        }) else {
            return .transfer
        }
        
        let maxCategory = maxPosting.category
        let minCategory = minPosting.category
        
        // Apply rules based on max and min categories
        switch maxCategory {
        case "Expenses", "Expense":
            return .expense  // Max is Expense → RED
            
        case "Assets", "Asset":
            // Max is Asset, check min
            switch minCategory {
            case "Assets", "Asset", "Liabilities", "Liability":
                return .transfer  // Min is Asset or Liability → BLUE
            case "Income":
                return .income    // Min is Income → GREEN
            default:
                return .income    // Default → GREEN
            }
            
        case "Liabilities", "Liability":
            // Max is Liability, check min
            switch minCategory {
            case "Income":
                return .income    // Min is Income → GREEN
            case "Assets", "Asset":
                return .expense   // Min is Asset → RED
            default:
                return .transfer  // Default → BLUE
            }
            
        case "Income":
            return .income  // Max is Income → GREEN
            
        default:
            return .transfer
        }
    }
    
    /// Returns the posting with the largest absolute amount
    func dominantPosting() -> Posting? {
        // For 2-posting transactions (most common), use max without abs
        // This gives us the destination/credit side (positive amount)
        if postings.count == 2 {
            return postings.max { posting1, posting2 in
                let amount1 = Double(posting1.amount) ?? 0.0
                let amount2 = Double(posting2.amount) ?? 0.0
                return amount1 < amount2
            }
        }
        
        // For multi-posting transactions, use absolute value
        return postings.max { posting1, posting2 in
            let amount1 = abs(Double(posting1.amount) ?? 0.0)
            let amount2 = abs(Double(posting2.amount) ?? 0.0)
            return amount1 < amount2
        }
    }
}

struct Posting: Codable, Identifiable {
    let id: UUID
    let accountID: String
    let accountName: String?
    let amount: String
    let quantity: String?
    let unitCode: String?
    let tags: [Tag]?
    
    /// Extracts the category from accountID (format: "Category:Subcategory:Name")
    /// Example: "Assets:Checking:SBI" -> "Assets", "Expense:Food:Groceries" -> "Expense"
    var category: String? {
        let components = accountID.split(separator: ":", maxSplits: 1)
        return components.first.map(String.init)
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case accountID = "account_id"
        case accountName = "account_name"
        case amount
        case quantity
        case unitCode = "unit_code"
        case tags
    }
}

struct TransactionListResponse: Codable {
    let success: Bool
    let data: TransactionListData
}

struct TransactionListData: Codable {
    let data: [Transaction]
    let total: Int
}

struct SingleTransactionResponse: Codable {
    let success: Bool
    let data: Transaction
}
