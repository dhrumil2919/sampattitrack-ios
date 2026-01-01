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
        return calculateDisplayDetails().amount
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
        return calculateDisplayDetails().type
    }

    /// OPTIMIZATION: Calculates both type and display amount in a single pass.
    /// Reduces complexity from O(2N) to O(N) for list rendering where both are needed.
    func calculateDisplayDetails() -> (type: Transaction.TransactionType, amount: Double) {
        guard let postings = postings, !postings.isEmpty else { return (.transfer, 0) }

        var maxPosting: SDPosting?
        var minPosting: SDPosting?
        var maxVal = -Double.greatestFiniteMagnitude
        var minVal = Double.greatestFiniteMagnitude
        var positiveSum: Double = 0

        // Single pass to gather all necessary data
        for posting in postings {
            let val = Double(posting.amount) ?? 0.0

            // Accumulate positive amount for display
            if val > 0 {
                positiveSum += val
            }

            // Track max/min for type determination
            if val > maxVal {
                maxVal = val
                maxPosting = posting
            }

            if val < minVal {
                minVal = val
                minPosting = posting
            }
        }

        guard let maxP = maxPosting, let minP = minPosting else { return (.transfer, positiveSum) }

        let maxCategory = maxP.category
        let minCategory = minP.category
        let type: Transaction.TransactionType

        // Apply rules based on max and min categories
        switch maxCategory {
        case "Expenses", "Expense":
            type = .expense

        case "Assets", "Asset":
            switch minCategory {
            case "Assets", "Asset", "Liabilities", "Liability":
                type = .transfer
            case "Income":
                type = .income
            default:
                type = .income
            }

        case "Liabilities", "Liability":
            switch minCategory {
            case "Income":
                type = .income
            case "Assets", "Asset":
                type = .expense
            default:
                type = .transfer
            }

        case "Income":
            type = .income

        default:
            type = .transfer
        }

        return (type, positiveSum)
    }
}
