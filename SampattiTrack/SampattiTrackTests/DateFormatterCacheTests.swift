import XCTest
@testable import SampattiTrack

final class DateFormatterCacheTests: XCTestCase {

    func testFormatDay() {
        let dateStr = "2023-10-27"
        let day = DateFormatterCache.formatDay(dateStr)
        XCTAssertEqual(day, "27")
    }

    func testFormatMonth() {
        let dateStr = "2023-10-27"
        let month = DateFormatterCache.formatMonth(dateStr)
        XCTAssertEqual(month, "Oct")
    }

    func testFormatMonthYear() {
        let dateStr = "2023-10-27"
        guard let date = DateFormatterCache.parseISO8601(dateStr) else {
            XCTFail("Failed to parse date")
            return
        }
        let label = DateFormatterCache.formatMonthYear(date)
        XCTAssertEqual(label, "Oct 2023")
    }

    func testParseISO8601() {
        let dateStr = "2023-10-27"
        let date = DateFormatterCache.parseISO8601(dateStr)
        XCTAssertNotNil(date)

        let components = Calendar.current.dateComponents([.year, .month, .day], from: date!)
        XCTAssertEqual(components.year, 2023)
        XCTAssertEqual(components.month, 10)
        XCTAssertEqual(components.day, 27)
    }

    func testInvalidDate() {
        let dateStr = "invalid"
        let day = DateFormatterCache.formatDay(dateStr)
        XCTAssertEqual(day, "")

        let month = DateFormatterCache.formatMonth(dateStr)
        XCTAssertEqual(month, "")
    }
}
