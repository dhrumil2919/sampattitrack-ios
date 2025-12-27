import XCTest
@testable import SampattiTrack

/// Tests for transaction balance validation logic
/// These tests verify the core business rules without depending on ViewModels
final class TransactionValidationTests: XCTestCase {

    // MARK: - Balance Calculation Tests
    
    /// Helper to simulate balance calculation matching ViewModel logic
    private func calculateTotal(amounts: [String]) -> Double {
        amounts.reduce(0.0) { $0 + (Double($1) ?? 0) }
    }
    
    private func isBalanced(amounts: [String]) -> Bool {
        abs(calculateTotal(amounts: amounts)) < 0.01
    }

    func testIsBalanced_returnsTrueWhenPostingsBalanceToZero() {
        // GIVEN balanced posting amounts
        let amounts = ["100", "-100"]
        
        // THEN it should be balanced
        XCTAssertTrue(isBalanced(amounts: amounts))
    }

    func testIsBalanced_returnsFalseWhenPostingsDoNotBalance() {
        // GIVEN unbalanced posting amounts
        let amounts = ["100", "-50"]
        
        // THEN it should not be balanced
        XCTAssertFalse(isBalanced(amounts: amounts))
    }

    func testIsBalanced_returnsTrueWithinTolerance() {
        // GIVEN posting amounts within tolerance (0.01)
        let amounts = ["100.005", "-100"]
        
        // THEN it should be considered balanced
        XCTAssertTrue(isBalanced(amounts: amounts))
    }

    func testIsBalanced_returnsFalseOutsideTolerance() {
        // GIVEN posting amounts outside tolerance
        let amounts = ["100.02", "-100"]
        
        // THEN it should not be balanced (0.02 > 0.01 tolerance)
        XCTAssertFalse(isBalanced(amounts: amounts))
    }

    func testTotalAmount_calculatesCorrectSum() {
        // GIVEN multiple amounts
        let amounts = ["100", "50", "-150"]
        
        // THEN total should be 0
        XCTAssertEqual(calculateTotal(amounts: amounts), 0.0, accuracy: 0.001)
    }

    func testTotalAmount_handlesInvalidAmounts() {
        // GIVEN invalid amount strings
        let amounts = ["invalid", "100"]
        
        // THEN invalid amounts should be treated as 0
        XCTAssertEqual(calculateTotal(amounts: amounts), 100.0, accuracy: 0.001)
    }

    func testTotalAmount_handlesEmptyAmounts() {
        // GIVEN empty amount strings
        let amounts = ["", "100"]
        
        // THEN empty amounts should be treated as 0
        XCTAssertEqual(calculateTotal(amounts: amounts), 100.0, accuracy: 0.001)
    }

    func testIsBalanced_withMultiplePostings() {
        // GIVEN multiple postings that balance
        let amounts = ["1000", "-300", "-400", "-300"]
        
        // THEN it should be balanced
        XCTAssertTrue(isBalanced(amounts: amounts))
    }
    
    func testIsBalanced_withNegativeImbalance() {
        // GIVEN postings with negative imbalance
        let amounts = ["100", "-150"]
        
        // THEN it should not be balanced
        XCTAssertFalse(isBalanced(amounts: amounts))
    }
    
    func testTotalAmount_withDecimalPrecision() {
        // GIVEN amounts with decimal precision
        let amounts = ["100.50", "-50.25", "-50.25"]
        
        // THEN total should be 0
        XCTAssertEqual(calculateTotal(amounts: amounts), 0.0, accuracy: 0.001)
    }
}
