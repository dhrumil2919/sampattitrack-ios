import Foundation
import Combine

// Symbol search result model - matches backend SearchResult
struct SymbolSearchResult: Codable, Identifiable {
    let symbol: String
    let name: String
    let exchange: String?
    let type: String?
    
    var id: String { symbol }
}

struct SymbolSearchResponse: Codable {
    let success: Bool
    let data: [SymbolSearchResult]
}

class AddUnitViewModel: ObservableObject {
    @Published var code: String = ""
    @Published var name: String = ""
    @Published var type: String = "MutualFund"
    @Published var symbol: String = ""
    @Published var provider: String = "mfapi"
    @Published var currency: String = "INR"
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    
    @Published var searchResults: [SymbolSearchResult] = []
    @Published var isSearching = false
    private var searchCancellable: AnyCancellable?
    
    let types = ["Currency", "Stock", "MutualFund", "Metal", "NPS", "Custom"]
    let providers = ["mfapi", "yahoo", "nps", "metal", "custom"]
    
    init() {
        // Setup debounced search
        searchCancellable = $name
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] query in
                self?.searchSymbols(query: query)
            }
    }
    
    func searchSymbols(query: String) {
        guard !query.isEmpty, query.count >= 3 else {
            searchResults = []
            return
        }
        
        // Only search for types that support symbol lookup
        guard ["Stock", "MutualFund", "NPS"].contains(type) else {
            searchResults = []
            return
        }
        
        isSearching = true
        
        let endpoint = "/prices/search?query=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query)&type=\(type)"
        
        APIClient.shared.request(endpoint, method: "GET") { (result: Result<SymbolSearchResponse, APIClient.APIError>) in
            DispatchQueue.main.async {
                self.isSearching = false
                switch result {
                case .success(let response):
                    if response.success {
                        self.searchResults = response.data
                    }
                case .failure:
                    self.searchResults = []
                }
            }
        }
    }
    
    func selectSymbol(_ result: SymbolSearchResult) {
        // Generate code from name (uppercase, remove spaces)
        self.code = result.name.uppercased().replacingOccurrences(of: " ", with: "_")
        self.name = result.name
        self.symbol = result.symbol
        self.searchResults = []
    }
    
    func createUnit() {
        guard !code.isEmpty, !name.isEmpty else {
            errorMessage = "Code and Name are required"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        struct CreateUnitRequest: Encodable {
            let code: String
            let name: String
            let type: String
            let symbol: String?
            let provider: String?
            let currency: String
        }
        
        let req = CreateUnitRequest(
            code: code,
            name: name,
            type: type,
            symbol: symbol.isEmpty ? nil : symbol,
            provider: provider.isEmpty ? nil : provider,
            currency: currency.isEmpty ? "INR" : currency
        )
        
        APIClient.shared.request("/units", method: "POST", body: req) { (result: Result<UnitResponse, APIClient.APIError>) in
            DispatchQueue.main.async {
                self.isLoading = false
                switch result {
                case .success(let response):
                    if response.success {
                        self.successMessage = "Unit created successfully!"
                        self.resetForm()
                    } else {
                        self.errorMessage = "Failed to create unit"
                    }
                case .failure(let error):
                    self.errorMessage = "Error: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func resetForm() {
        code = ""
        name = ""
        type = "MutualFund"
        symbol = ""
        provider = "mfapi"
        currency = "INR"
    }
}

// Wrapper for response
struct UnitResponse: Decodable {
    let success: Bool
    let data: FinancialUnit
}
