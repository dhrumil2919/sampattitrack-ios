import Foundation
import SwiftData

// Extensions to support efficient display without converting to Transaction struct

extension SDPosting {
    /// Extracts the category from accountID (format: "Category:Subcategory:Name")
    var category: String? {
        let components = accountID.split(separator: ":", maxSplits: 1)
        return components.first.map(String.init)
    }
}

extension SDTransaction {

    var displayAmount: Double {
        // Simple heuristic: Sum of positive amounts
        guard let postings = postings else { return 0 }

        return postings.reduce(0) { result, posting in
            if let amount = Double(posting.amount), amount > 0 {
                return result + amount
            }
            return result
        }
    }

    func amountForAccount(_ accountID: String) -> Double {
        guard let postings = postings else { return 0 }

        let accountPostings = postings.filter { $0.accountID == accountID }
        return accountPostings.reduce(0) { result, posting in
            return result + (Double(posting.amount) ?? 0.0)
        }
    }

    // Reuse Transaction.TransactionType
    func determineType() -> Transaction.TransactionType {
        guard let postings = postings, !postings.isEmpty else { return .transfer }

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
            return .expense

        case "Assets", "Asset":
            switch minCategory {
            case "Assets", "Asset", "Liabilities", "Liability":
                return .transfer
            case "Income":
                return .income
            default:
                return .income
            }

        case "Liabilities", "Liability":
            switch minCategory {
            case "Income":
                return .income
            case "Assets", "Asset":
                return .expense
            default:
                return .transfer
            }

        case "Income":
            return .income

        default:
            return .transfer
        }
    }
}
