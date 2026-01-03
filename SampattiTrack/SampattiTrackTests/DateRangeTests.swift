import XCTest
@testable import SampattiTrack

final class DateRangeTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Clear UserDefaults before each test
        UserDefaults.standard.removeObject(forKey: "financial_year_start_month")
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "financial_year_start_month")
        super.tearDown()
    }

    func testYTDDefaultStartMonth() {
        // Default should be April (4)
        // If current date is June 2025, YTD start should be April 1, 2025
        // If current date is Jan 2025, YTD start should be April 1, 2024

        // Note: Since we can't easily mock Date() in the static method without dependency injection,
        // we will test based on the actual current date logic structure.
        // Or we can rely on setting the UserDefault and checking the Month/Year components relative to "now".

        let range = DateRange.ytd()
        let calendar = Calendar.current
        let now = Date()
        let start = range.start

        let startMonth = calendar.component(.month, from: start)
        let startYear = calendar.component(.year, from: start)
        let startDay = calendar.component(.day, from: start)

        let currentMonth = calendar.component(.month, from: now)
        let currentYear = calendar.component(.year, from: now)

        // Expect default month to be April (4)
        XCTAssertEqual(startMonth, 4)
        XCTAssertEqual(startDay, 1)

        if currentMonth >= 4 {
            // Should be current year
            XCTAssertEqual(startYear, currentYear)
        } else {
            // Should be previous year
            XCTAssertEqual(startYear, currentYear - 1)
        }
    }

    func testYTDCustomStartMonth() {
        // Set custom start month to January (1)
        UserDefaults.standard.set(1, forKey: "financial_year_start_month")

        let range = DateRange.ytd()
        let calendar = Calendar.current
        let now = Date()
        let start = range.start

        let startMonth = calendar.component(.month, from: start)
        let startYear = calendar.component(.year, from: start)

        let currentYear = calendar.component(.year, from: now)

        // Expect month to be January (1)
        XCTAssertEqual(startMonth, 1)

        // Since start month is 1, and current month is >= 1, it should always be current year
        XCTAssertEqual(startYear, currentYear)
    }

    func testYTDCustomStartMonthJuly() {
        // Set custom start month to July (7)
        UserDefaults.standard.set(7, forKey: "financial_year_start_month")

        let range = DateRange.ytd()
        let calendar = Calendar.current
        let now = Date()
        let start = range.start

        let startMonth = calendar.component(.month, from: start)
        let startYear = calendar.component(.year, from: start)

        let currentMonth = calendar.component(.month, from: now)
        let currentYear = calendar.component(.year, from: now)

        // Expect month to be July (7)
        XCTAssertEqual(startMonth, 7)

        if currentMonth >= 7 {
            XCTAssertEqual(startYear, currentYear)
        } else {
            XCTAssertEqual(startYear, currentYear - 1)
        }
    }
}
