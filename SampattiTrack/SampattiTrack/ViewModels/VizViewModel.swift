import Foundation
import SwiftData
import Combine

/// VizViewModel - OFFLINE-FIRST
/// Visualization data computed from local SwiftData. No API calls.
class VizViewModel: ObservableObject {
    @Published var netWorthHistory: [NetWorthDataPoint] = []
    @Published var portfolioData: [String: Double] = [:]
    @Published var topTags: [TopTag] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var container: ModelContainer?
    
    func setContainer(_ container: ModelContainer) {
        self.container = container
        fetchAll()
    }
    
    /// Fetch all visualization data from LOCAL SwiftData - no API calls
    func fetchAll() {
        guard let container = container else { return }
        
        isLoading = true
        
        Task.detached(priority: .userInitiated) {
            let context = ModelContext(container)
            context.autosaveEnabled = false
            
            let calculator = DashboardCalculator(modelContext: context)
            
            // Calculate net worth history from local transactions
            let history = calculator.calculateNetWorthHistory(range: .ytd())
            let tags = calculator.calculateTagBreakdown(range: .lastMonth())
            
            // Portfolio data would need account balances - simplified for now
            let portfolio: [String: Double] = [:]
            
            await MainActor.run {
                self.netWorthHistory = history
                self.topTags = tags
                self.portfolioData = portfolio
                self.isLoading = false
            }
        }
    }
}
