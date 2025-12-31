import XCTest
@testable import SampattiTrack

final class SecurityUtilsTests: XCTestCase {

    // MARK: - Length Validation

    func testIsValidLength_WithinLimit() {
        XCTAssertTrue(SecurityUtils.isValidLength("test", maxLength: 10))
    }

    func testIsValidLength_ExceedsLimit() {
        XCTAssertFalse(SecurityUtils.isValidLength("test string", maxLength: 5))
    }

    func testIsValidLength_ExactLimit() {
        XCTAssertTrue(SecurityUtils.isValidLength("test", maxLength: 4))
    }

    // MARK: - Sanitization

    func testSanitizeInput_TrimsWhitespace() {
        let input = "  test  "
        XCTAssertEqual(SecurityUtils.sanitizeInput(input), "test")
    }

    func testSanitizeInput_TrimsNewlines() {
        let input = "\ntest\n"
        XCTAssertEqual(SecurityUtils.sanitizeInput(input), "test")
    }

    // MARK: - Code Validation

    func testIsValidCode_ValidAlphanumeric() {
        XCTAssertTrue(SecurityUtils.isValidCode("ABC_123"))
    }

    func testIsValidCode_InvalidCharacters() {
        XCTAssertFalse(SecurityUtils.isValidCode("ABC-123")) // Hyphen not allowed
        XCTAssertFalse(SecurityUtils.isValidCode("ABC 123")) // Space not allowed
        XCTAssertFalse(SecurityUtils.isValidCode("ABC$"))    // Special char
    }

    func testIsValidCode_Empty() {
        XCTAssertTrue(SecurityUtils.isValidCode(""))
    }
}
