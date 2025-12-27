import XCTest
@testable import SampattiTrack

final class CurrencyFormatterTests: XCTestCase {

    // MARK: - format(_:currency:)

    func testFormatValidPositiveNumber() {
        // GIVEN a positive number string
        let value = "12345.67"
        
        // WHEN formatted as INR
        let result = CurrencyFormatter.format(value)
        
        // THEN it should contain the value (locale-specific formatting)
        XCTAssertTrue(result.contains("12,345") || result.contains("12345"))
    }
    
    func testFormatValidNegativeNumber() {
        // GIVEN a negative number string
        let value = "-5000"
        
        // WHEN formatted
        let result = CurrencyFormatter.format(value)
        
        // THEN it should contain the negative indicator
        XCTAssertTrue(result.contains("-") || result.contains("("))
    }
    
    func testFormatInvalidString() {
        // GIVEN an invalid number string
        let value = "not-a-number"
        
        // WHEN formatted
        let result = CurrencyFormatter.format(value)
        
        // THEN it should return the original value unchanged
        XCTAssertEqual(result, "not-a-number")
    }
    
    func testFormatEmptyString() {
        // GIVEN an empty string
        let value = ""
        
        // WHEN formatted
        let result = CurrencyFormatter.format(value)
        
        // THEN it should return empty string
        XCTAssertEqual(result, "")
    }

    // MARK: - formatCompact(_:)
    
    func testFormatCompactCrore() {
        // GIVEN a value >= 1 crore (10 million)
        let value = 15_000_000.0
        
        // WHEN formatted compact
        let result = CurrencyFormatter.formatCompact(value)
        
        // THEN it should show in Crores
        XCTAssertEqual(result, "1.5Cr")
    }
    
    func testFormatCompactLakh() {
        // GIVEN a value in lakhs range
        let value = 250_000.0
        
        // WHEN formatted compact
        let result = CurrencyFormatter.formatCompact(value)
        
        // THEN it should show in Lakhs
        XCTAssertEqual(result, "2.5L")
    }
    
    func testFormatCompactThousand() {
        // GIVEN a value in thousands
        let value = 5_500.0
        
        // WHEN formatted compact
        let result = CurrencyFormatter.formatCompact(value)
        
        // THEN it should show in K
        XCTAssertEqual(result, "6K") // Rounds to nearest
    }
    
    func testFormatCompactSmall() {
        // GIVEN a small value
        let value = 999.0
        
        // WHEN formatted compact
        let result = CurrencyFormatter.formatCompact(value)
        
        // THEN it should show the raw number
        XCTAssertEqual(result, "999")
    }
    
    func testFormatCompactNegative() {
        // GIVEN a negative value
        let value = -500_000.0
        
        // WHEN formatted compact
        let result = CurrencyFormatter.formatCompact(value)
        
        // THEN it should include negative sign
        XCTAssertEqual(result, "-5.0L")
    }
    
    func testFormatCompactZero() {
        // GIVEN zero
        let value = 0.0
        
        // WHEN formatted compact
        let result = CurrencyFormatter.formatCompact(value)
        
        // THEN it should show 0
        XCTAssertEqual(result, "0")
    }

    // MARK: - formatInverted(_:currency:)
    
    func testFormatInvertedPositive() {
        // GIVEN a positive value
        let value = "1000"
        
        // WHEN inverted
        let result = CurrencyFormatter.formatInverted(value)
        
        // THEN it should be negative
        XCTAssertTrue(result.contains("-") || result.contains("("))
    }
    
    func testFormatInvertedInvalid() {
        // GIVEN an invalid value
        let value = "abc"
        
        // WHEN inverted
        let result = CurrencyFormatter.formatInverted(value)
        
        // THEN it should return original
        XCTAssertEqual(result, "abc")
    }
}
