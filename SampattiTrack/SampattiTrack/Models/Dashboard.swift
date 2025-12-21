import Foundation

struct DashboardSummaryResponse: Codable {
    let success: Bool
    let data: DashboardData
}

struct DashboardData: Codable {
    let netWorth: String
    let totalAssets: String
    let totalLiabilities: String
    
    let lastMonthIncome: String
    let lastMonthExpenses: String
    let savingsRate: Double
    let yearlyIncome: String
    let yearlyExpenses: String
    let yearlySavings: String
    
    enum CodingKeys: String, CodingKey {
        case netWorth = "net_worth"
        case totalAssets = "total_assets"
        case totalLiabilities = "total_liabilities"
        case lastMonthIncome = "last_month_income"
        case lastMonthExpenses = "last_month_expenses"
        case savingsRate = "savings_rate"
        case yearlyIncome = "yearly_income"
        case yearlyExpenses = "yearly_expenses"
        case yearlySavings = "yearly_savings"
    }
}
