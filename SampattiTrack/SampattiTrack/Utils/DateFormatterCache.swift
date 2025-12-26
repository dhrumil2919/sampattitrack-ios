import Foundation

/// A centralized cache for date formatters to improve performance.
/// DateFormatter initialization is expensive, so reusing instances is critical.
struct DateFormatterCache {

    // MARK: - Standard Formatters

    /// Cached ISO8601 Date Formatter
    /// Options: [.withFullDate, .withDashSeparatorInDate]
    /// TimeZone: Current
    /// Note: ISO8601 is a standard, so we don't usually need Locale, but POSIX is safest for parsing.
    static let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withDashSeparatorInDate]
        formatter.timeZone = Calendar.current.timeZone
        return formatter
    }()

    // MARK: - Display Formatters (Locale Aware)

    /// Cached DateFormatter for "dd" (Day)
    static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd"
        // Use autoupdatingCurrent to respect user changes while app is running
        formatter.locale = Locale.autoupdatingCurrent
        return formatter
    }()

    /// Cached DateFormatter for "MMM" (Short Month)
    static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        formatter.locale = Locale.autoupdatingCurrent
        return formatter
    }()

    /// Cached DateFormatter for "MMM yyyy" (Month Year)
    static let monthYearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        formatter.locale = Locale.autoupdatingCurrent
        return formatter
    }()

    // MARK: - Helpers

    /// Formats a date string (YYYY-MM-DD) to a day string (e.g., "27")
    static func formatDay(_ dateStr: String) -> String {
        guard let date = iso8601.date(from: dateStr) else { return "" }
        return dayFormatter.string(from: date)
    }

    /// Formats a date string (YYYY-MM-DD) to a month string (e.g., "Oct")
    static func formatMonth(_ dateStr: String) -> String {
        guard let date = iso8601.date(from: dateStr) else { return "" }
        return monthFormatter.string(from: date)
    }

    /// Formats a date object to "MMM yyyy"
    static func formatMonthYear(_ date: Date) -> String {
        return monthYearFormatter.string(from: date)
    }

    /// Parses a standard YYYY-MM-DD string into a Date
    static func parseISO8601(_ dateStr: String) -> Date? {
        return iso8601.date(from: dateStr)
    }
}
