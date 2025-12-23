import Foundation
import SwiftData
import Combine

// Symbol search result model - kept for future use when online
struct SymbolSearchResult: Codable, Identifiable {
    let symbol: String
    let name: String
    let exchange: String?
    let type: String?
    
    var id: String { symbol }
}

/// AddUnitViewModel - OFFLINE-FIRST
/// Saves units to local SwiftData with isSynced=false. No API calls.
/// Symbol search is disabled in offline mode.
class AddUnitViewModel: ObservableObject {
    @Published var code: String = ""
    @Published var name: String = ""
    @Published var type: String = "MutualFund"
    @Published var symbol: String = ""
    @Published var currency: String = "INR"
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    
    @Published var searchResults: [SymbolSearchResult] = []
    @Published var isSearching = false
    
    private var modelContext: ModelContext?
    
    let types = ["Currency", "Stock", "MutualFund", "Metal", "NPS", "Custom"]
    
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }
    
    /// Symbol search disabled in offline mode
    func searchSymbols(query: String) {
        // Symbol search requires API - disabled in offline-first mode
        // Users must manually enter code and name
        searchResults = []
    }
    
    func selectSymbol(_ result: SymbolSearchResult) {
        self.code = result.name.uppercased().replacingOccurrences(of: " ", with: "_")
        self.name = result.name
        self.symbol = result.symbol
        self.searchResults = []
    }
    
    /// Create unit in LOCAL SwiftData - no API call
    func createUnit() {
        guard !code.isEmpty, !name.isEmpty else {
            errorMessage = "Code and Name are required"
            return
        }
        
        guard let context = modelContext else {
            errorMessage = "Database not available"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        // Check if unit already exists
        let unitCode = code
        let descriptor = FetchDescriptor<SDUnit>(predicate: #Predicate { $0.code == unitCode })
        
        do {
            let existing = try context.fetch(descriptor)
            if !existing.isEmpty {
                errorMessage = "Unit with code '\(code)' already exists"
                isLoading = false
                return
            }
            
            let newUnit = SDUnit(
                code: code,
                name: name,
                symbol: symbol.isEmpty ? nil : symbol,
                type: type,
                isSynced: false  // Will be synced later
            )
            context.insert(newUnit)
            try context.save()
            
            isLoading = false
            successMessage = "Unit created successfully!"
            resetForm()
        } catch {
            errorMessage = "Failed to create unit: \(error)"
            isLoading = false
        }
    }
    
    private func resetForm() {
        code = ""
        name = ""
        type = "MutualFund"
        symbol = ""
        currency = "INR"
    }
}
