import Foundation

struct CurrencyFormatter {
    static func format(_ value: String, currency: String = "INR") -> String {
        // Simple formatter assuming input string is a valid decimal number
        // Convert string to double
        guard let doubleValue = Double(value) else { return value }
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        // Indian English locale handles the 1,00,000 format correctly
        formatter.locale = Locale(identifier: "en_IN") 
        
        return formatter.string(from: NSNumber(value: doubleValue)) ?? value
    }
    
    static func formatCheck(_ value: Double, currency: String = "INR") -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.locale = Locale(identifier: "en_IN")
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
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
