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
    
    /// Search symbols using API
    func searchSymbols(query: String) {
        guard !query.isEmpty else {
            searchResults = []
            return
        }

        isSearching = true

        // Use existing listUnits API and filter locally
        // This is a workaround since we don't have a dedicated search endpoint yet
        APIClient.shared.listUnits { [weak self] result in
            DispatchQueue.main.async {
                self?.isSearching = false

                switch result {
                case .success(let response):
                    let filtered = response.data.filter { unit in
                        unit.code.localizedCaseInsensitiveContains(query) ||
                        unit.name.localizedCaseInsensitiveContains(query) ||
                        (unit.symbol?.localizedCaseInsensitiveContains(query) ?? false)
                    }

                    self?.searchResults = filtered.map { unit in
                        SymbolSearchResult(
                            symbol: unit.symbol ?? "",
                            name: unit.name,
                            exchange: nil,
                            type: unit.type
                        )
                    }

                case .failure(let error):
                    print("Symbol search failed: \(error)")
                    self?.searchResults = []
                }
            }
        }
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

            // Queue for sync
            try OfflineQueueHelper.queueUnit(
                code: code,
                name: name,
                symbol: symbol.isEmpty ? nil : symbol,
                type: type,
                context: context
            )

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
