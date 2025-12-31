import XCTest
import SwiftData
@testable import SampattiTrack

final class SDExtensionTests: XCTestCase {

    func testDetermineType_Expense() {
        // Expense: Max is Expense (positive logic in determining type?)
        // Let's check logic:
        // Max posting category determines type usually.
        // "Expense" -> .expense

        // Scenario: Paying for food.
        // Assets:Bank  -100
        // Expenses:Food +100

        let p1 = SDPosting(accountID: "Assets:Bank", amount: "-100")
        let p2 = SDPosting(accountID: "Expenses:Food", amount: "100")

        let tx = SDTransaction(date: "2024-01-01", desc: "Food")
        tx.postings = [p1, p2]
        p1.transaction = tx
        p2.transaction = tx

        XCTAssertEqual(tx.determineType(), .expense)
    }

    func testDetermineType_Income() {
        // Income:
        // Assets:Bank +1000
        // Income:Salary -1000

        let p1 = SDPosting(accountID: "Assets:Bank", amount: "1000")
        let p2 = SDPosting(accountID: "Income:Salary", amount: "-1000")

        let tx = SDTransaction(date: "2024-01-01", desc: "Salary")
        tx.postings = [p1, p2]

        XCTAssertEqual(tx.determineType(), .income)
    }

    func testDetermineType_Transfer() {
        // Transfer:
        // Assets:Bank -500
        // Assets:Cash +500

        let p1 = SDPosting(accountID: "Assets:Bank", amount: "-500")
        let p2 = SDPosting(accountID: "Assets:Cash", amount: "500")

        let tx = SDTransaction(date: "2024-01-01", desc: "Withdrawal")
        tx.postings = [p1, p2]

        XCTAssertEqual(tx.determineType(), .transfer)
    }

    func testDetermineType_LiabilityPayment() {
        // Credit Card Payment (Transfer/Expense?)
        // Assets:Bank -100
        // Liabilities:CreditCard +100 (reducing liability, so debit/positive?)

        // Let's check existing logic:
        // Max category: Liability (if +100 is max)
        // Switch Max (Liability):
        //   Min (Asset -100): -> .expense (Wait, really?)

        // Let's verify existing behavior.
        // If I pay off CC, is it expense? Usually transfer.
        // Let's see the code:
        /*
        case "Liabilities", "Liability":
            switch minCategory {
            case "Income": return .income
            case "Assets", "Asset": return .expense // ???
            default: return .transfer
            }
        */

        let p1 = SDPosting(accountID: "Assets:Bank", amount: "-100")
        let p2 = SDPosting(accountID: "Liabilities:CreditCard", amount: "100")

        let tx = SDTransaction(date: "2024-01-01", desc: "CC Payment")
        tx.postings = [p1, p2]

        // Based on current code reading: It returns .expense
        // I should assert what the CURRENT code does, then preserve it.
        XCTAssertEqual(tx.determineType(), .expense)
    }

    func testDetermineType_SplitTransaction() {
        // Amazon purchase:
        // Assets:CreditCard -150
        // Expenses:Books +50
        // Expenses:Electronics +100

        let p1 = SDPosting(accountID: "Assets:CreditCard", amount: "-150")
        let p2 = SDPosting(accountID: "Expenses:Books", amount: "50")
        let p3 = SDPosting(accountID: "Expenses:Electronics", amount: "100")

        let tx = SDTransaction(date: "2024-01-01", desc: "Amazon")
        tx.postings = [p1, p2, p3]

        // Max is 100 (Electronics) -> Expense
        XCTAssertEqual(tx.determineType(), .expense)
    }
}
