import Foundation

// MARK: - Tax Analysis Models

struct TaxAnalysisResponse: Codable {
    let success: Bool
    let data: TaxAnalysis
}

struct TaxAnalysis: Codable {
    let totalIncome: String
    let totalTax: String
    let netIncome: String
    let taxRate: Double
    let breakdown: [TaxBreakdown]
    
    enum CodingKeys: String, CodingKey {
        case totalIncome = "total_income"
        case totalTax = "total_tax"
        case netIncome = "net_income"
        case taxRate = "tax_rate"
        case breakdown
    }
    
    var totalIncomeValue: Double {
        Double(totalIncome) ?? 0.0
    }
    
    var totalTaxValue: Double {
        Double(totalTax) ?? 0.0
    }
    
    var netIncomeValue: Double {
        Double(netIncome) ?? 0.0
    }
}

struct TaxBreakdown: Codable, Identifiable {
    var id: Int { year }
    let year: Int
    let income: String
    let taxPaid: String
    let expectedTax: String
    let taxRate: Double
    let deduction: String
    
    enum CodingKeys: String, CodingKey {
        case year
        case income
        case taxPaid = "tax_paid"
        case expectedTax = "expected_tax"
        case taxRate = "tax_rate"
        case deduction = "standard_deduction"
    }
    
    var incomeValue: Double {
        Double(income) ?? 0.0
    }
    
    var taxPaidValue: Double {
        Double(taxPaid) ?? 0.0
    }
    
    var expectedTaxValue: Double {
        Double(expectedTax) ?? 0.0
    }
    
    var deductionValue: Double {
        Double(deduction) ?? 0.0
    }
}

// MARK: - Capital Gains Models

struct CapitalGainsResponse: Codable {
    let success: Bool
    let data: CapitalGainsReport
}

struct CapitalGainsReport: Codable, Identifiable {
    var id: Int { year }
    let year: Int
    let totalSTCG: String
    let totalLTCG: String
    let totalSTCGTax: String
    let totalLTCGTax: String
    let totalTax: String
    let records: [CapitalGainRecord]
    
    enum CodingKeys: String, CodingKey {
        case year
        case totalSTCG = "total_stcg"
        case totalLTCG = "total_ltcg"
        case totalSTCGTax = "total_stcg_tax"
        case totalLTCGTax = "total_ltcg_tax"
        case totalTax = "total_tax"
        case records
    }
    
    var totalSTCGValue: Double {
        Double(totalSTCG) ?? 0.0
    }
    
    var totalLTCGValue: Double {
        Double(totalLTCG) ?? 0.0
    }
    
    var totalSTCGTaxValue: Double {
        Double(totalSTCGTax) ?? 0.0
    }
    
    var totalLTCGTaxValue: Double {
        Double(totalLTCGTax) ?? 0.0
    }
    
    var totalTaxValue: Double {
        Double(totalTax) ?? 0.0
    }
}

struct CapitalGainRecord: Codable, Identifiable {
    let id: String
    let accountID: String
    let accountName: String
    let symbol: String
    let quantity: String
    let buyDate: String
    let sellDate: String
    let buyPrice: String
    let sellPrice: String
    let buyValue: String
    let sellValue: String
    let gain: String
    let type: String // "STCG" or "LTCG"
    let daysHeld: Int
    
    enum CodingKeys: String, CodingKey {
        case accountID = "account_id"
        case accountName = "account_name"
        case symbol
        case quantity
        case buyDate = "buy_date"
        case sellDate = "sell_date"
        case buyPrice = "buy_price"
        case sellPrice = "sell_price"
        case buyValue = "buy_value"
        case sellValue = "sell_value"
        case gain
        case type
        case daysHeld = "days_held"
    }
    
    // Generate ID from combination of fields
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        accountID = try container.decode(String.self, forKey: .accountID)
        accountName = try container.decode(String.self, forKey: .accountName)
        symbol = try container.decode(String.self, forKey: .symbol)
        quantity = try container.decode(String.self, forKey: .quantity)
        buyDate = try container.decode(String.self, forKey: .buyDate)
        sellDate = try container.decode(String.self, forKey: .sellDate)
        buyPrice = try container.decode(String.self, forKey: .buyPrice)
        sellPrice = try container.decode(String.self, forKey: .sellPrice)
        buyValue = try container.decode(String.self, forKey: .buyValue)
        sellValue = try container.decode(String.self, forKey: .sellValue)
        gain = try container.decode(String.self, forKey: .gain)
        type = try container.decode(String.self, forKey: .type)
        daysHeld = try container.decode(Int.self, forKey: .daysHeld)
        
        // Generate unique ID
        id = "\(accountID)_\(sellDate)_\(quantity)"
    }
    
    var quantityValue: Double {
        Double(quantity) ?? 0.0
    }
    
    var gainValue: Double {
        Double(gain) ?? 0.0
    }
}
