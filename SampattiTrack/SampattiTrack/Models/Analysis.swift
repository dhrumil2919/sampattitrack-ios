import Foundation

struct NetWorthDataPoint: Codable, Identifiable {
    var id: String { date }
    let date: String
    let assets: String
    let liabilities: String
    let netWorth: String

    enum CodingKeys: String, CodingKey {
        case date
        case assets
        case liabilities
        case netWorth = "net_worth"
    }

    // Helper to get Date object
    var dateObject: Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: date) ?? ISO8601DateFormatter().date(from: date)
    }

    var netWorthValue: Double {
        return Double(netWorth) ?? 0.0
    }

    var assetsValue: Double {
        return Double(assets) ?? 0.0
    }

    var liabilitiesValue: Double {
        return Double(liabilities) ?? 0.0
    }
}

struct AssetPerformance: Codable, Identifiable {
    var id: String { accountID }
    let accountID: String
    let accountName: String
    let type: String
    let category: String
    let currency: String
    let symbol: String?
    let quantity: String
    let investedAmount: String
    let currentValue: String
    let absoluteReturn: String
    let xirr: Double

    enum CodingKeys: String, CodingKey {
        case accountID = "account_id"
        case accountName = "account_name"
        case type
        case category
        case currency
        case symbol
        case quantity
        case investedAmount = "invested_amount"
        case currentValue = "current_value"
        case absoluteReturn = "absolute_return"
        case xirr
    }

    var currentValueValue: Double {
        return Double(currentValue) ?? 0.0
    }

    var investedAmountValue: Double {
        return Double(investedAmount) ?? 0.0
    }
    
    // Hierarchical navigation helpers
    var accountPath: [String] {
        accountID.split(separator: ":").map(String.init)
    }
    
    var parentAccountID: String? {
        let components = accountPath
        guard components.count > 1 else { return nil }
        return components.dropLast().joined(separator: ":")
    }
    
    var depth: Int {
        accountPath.count
    }
    
    var returnValue: Double {
        Double(absoluteReturn) ?? 0
   }
    
    var returnPercentage: Double {
        guard investedAmountValue > 0 else { return 0 }
        return (returnValue / investedAmountValue) * 100
    }
}

struct NetWorthHistoryResponse: Codable {
    let success: Bool
    let data: [NetWorthDataPoint]
}

struct PortfolioAnalysisResponse: Codable {
    let success: Bool
    let data: [AssetPerformance]
}
