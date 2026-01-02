import Foundation

struct CurrencyFormatter {
    // Thread-safety note: NumberFormatter is not thread-safe.
    // We use a lock to protect both the cache and the formatting operation itself.
    private static let lock = NSLock()
    private static var cache: [String: NumberFormatter] = [:]

    private static let inrFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "INR"
        formatter.locale = Locale(identifier: "en_IN")
        return formatter
    }()

    /// Thread-safe helper to format a number
    private static func string(from number: NSNumber, currency: String) -> String? {
        lock.lock()
        defer { lock.unlock() }

        let formatter: NumberFormatter
        if currency == "INR" {
            formatter = inrFormatter
        } else if let cached = cache[currency] {
            formatter = cached
        } else {
            let newFormatter = NumberFormatter()
            newFormatter.numberStyle = .currency
            newFormatter.currencyCode = currency
            // Indian English locale handles the 1,00,000 format correctly
            newFormatter.locale = Locale(identifier: "en_IN")
            cache[currency] = newFormatter
            formatter = newFormatter
        }

        return formatter.string(from: number)
    }

    static func format(_ value: String, currency: String = "INR") -> String {
        // Simple formatter assuming input string is a valid decimal number
        // Convert string to double
        guard let doubleValue = Double(value) else { return value }
        
        return string(from: NSNumber(value: doubleValue), currency: currency) ?? value
    }
    
    static func formatCheck(_ value: Double, currency: String = "INR") -> String {
        return string(from: NSNumber(value: value), currency: currency) ?? "\(value)"
    }
    
    static func formatInverted(_ value: String, currency: String = "INR") -> String {
        guard let doubleValue = Double(value) else { return value }
        return formatCheck(-doubleValue, currency: currency)
    }
    
    /// Compact format for chart axes (e.g., 1.2L, 50K)
    static func formatCompact(_ value: Double) -> String {
        let absValue = abs(value)
        let sign = value < 0 ? "-" : ""
        
        if absValue >= 10_000_000 {
            return "\(sign)\(String(format: "%.1f", absValue / 10_000_000))Cr"
        } else if absValue >= 100_000 {
            return "\(sign)\(String(format: "%.1f", absValue / 100_000))L"
        } else if absValue >= 1_000 {
            return "\(sign)\(String(format: "%.0f", absValue / 1_000))K"
        } else {
            return "\(sign)\(String(format: "%.0f", absValue))"
        }
    }
}
