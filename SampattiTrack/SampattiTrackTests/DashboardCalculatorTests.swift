import XCTest
import SwiftData
@testable import SampattiTrack

@MainActor
final class DashboardCalculatorTests: XCTestCase {
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    var calculator: DashboardCalculator!

    override func setUpWithError() throws {
        // Use in-memory configuration.
        // Note: The previous "CoreData: error: Failed to stat path" was likely due to incomplete schema definition
        // causing SwiftData to fallback or fail internal validations.
        // We now include all relevant models (SDTransaction, SDPosting, SDAccount, SDTag, SDUnit) to ensure a complete schema graph.
        let config = ModelConfiguration(isStoredInMemoryOnly: true)

        // Include all related models to ensure schema consistency
        modelContainer = try ModelContainer(for: SDTransaction.self, SDPosting.self, SDAccount.self, SDTag.self, SDUnit.self, configurations: config)
        modelContext = modelContainer.mainContext
        calculator = DashboardCalculator(modelContext: modelContext)
    }

    override func tearDownWithError() throws {
        modelContainer = nil
        modelContext = nil
        calculator = nil
    }

    func testCachedTransactionMonthKeyOptimization() throws {
        // Create sample transactions
        let tx1 = SDTransaction(date: "2023-01-15", desc: "Expense 1")
        let p1 = SDPosting(accountID: "Expenses:Food", amount: "100.0")
        p1.transaction = tx1
        tx1.postings = [p1]

        let tx2 = SDTransaction(date: "2023-01-20", desc: "Income 1")
        let p2 = SDPosting(accountID: "Income:Salary", amount: "1000.0")
        p2.transaction = tx2
        tx2.postings = [p2]

        let tx3 = SDTransaction(date: "2023-02-10", desc: "Expense 2")
        let p3 = SDPosting(accountID: "Expenses:Rent", amount: "500.0")
        p3.transaction = tx3
        tx3.postings = [p3]

        modelContext.insert(tx1)
        modelContext.insert(tx2)
        modelContext.insert(tx3)

        // Populate Cache
        _ = calculator.calculateSummary(range: .all())

        // Verify Monthly Expenses Grouping
        let expenses = calculator.calculateMonthlyExpenses(range: .all())
        XCTAssertEqual(expenses.count, 2)

        let janExpenses = expenses.first(where: { $0.month == "2023-01" })
        XCTAssertEqual(janExpenses?.amount, 100.0)

        let febExpenses = expenses.first(where: { $0.month == "2023-02" })
        XCTAssertEqual(febExpenses?.amount, 500.0)

        // Verify Monthly Income Grouping
        let income = calculator.calculateMonthlyIncome(range: .all())
        XCTAssertEqual(income.count, 1)

        let janIncome = income.first(where: { $0.month == "2023-01" })
        XCTAssertEqual(janIncome?.amount, 1000.0)
    }
}
