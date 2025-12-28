import Foundation

// MARK: - Cash Flow Analysis Models

struct CashFlowResponse: Codable {
    let success: Bool
    let data: [CashFlowDataPoint]
}

struct CashFlowDataPoint: Codable, Identifiable {
    var id: String { dateString }
    let dateString: String
    let income: String
    let expense: String
    let netSavings: String
    
    enum CodingKeys: String, CodingKey {
        case dateString = "date"
        case income
        case expense
        case netSavings = "net_savings"
    }
    
    var date: Date? {
        return DateFormatterCache.iso8601Default.date(from: dateString)
    }
    
    var incomeValue: Double {
        Double(income) ?? 0.0
    }
    
    var expenseValue: Double {
        Double(expense) ?? 0.0
    }
    
    var netSavingsValue: Double {
        Double(netSavings) ?? 0.0
    }
    
    // Month-over-Month change calculation helper
    func momChangeRate(previous: CashFlowDataPoint?) -> Double? {
        guard let prev = previous else { return nil }
        let prevValue = prev.expenseValue
        guard prevValue > 0 else { return nil }
        return ((expenseValue - prevValue) / prevValue) * 100
    }
}
