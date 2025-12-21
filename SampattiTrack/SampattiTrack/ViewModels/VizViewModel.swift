import Foundation
import Combine

class VizViewModel: ObservableObject {
    @Published var netWorthHistory: [NetWorthDataPoint] = []
    @Published var assetPerformance: [AssetPerformance] = []
    @Published var topTags: [TopTag] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    func fetchData() {
        isLoading = true
        errorMessage = nil

        let group = DispatchGroup()

        group.enter()
        APIClient.shared.request("/analysis/net-worth?interval=monthly") { (result: Result<NetWorthHistoryResponse, APIClient.APIError>) in
            defer { group.leave() }
            switch result {
            case .success(let response):
                if response.success {
                    DispatchQueue.main.async {
                        self.netWorthHistory = response.data.sorted(by: { $0.date < $1.date })
                    }
                }
            case .failure(let error):
                print("Net Worth Error: \(error)")
                // Don't fail everything if one fails
            }
        }

        group.enter()
        APIClient.shared.request("/analysis/portfolio") { (result: Result<PortfolioAnalysisResponse, APIClient.APIError>) in
            defer { group.leave() }
            switch result {
            case .success(let response):
                if response.success {
                    DispatchQueue.main.async {
                        self.assetPerformance = response.data
                    }
                }
            case .failure(let error):
                print("Portfolio Error: \(error)")
            }
        }
        
        group.enter()
        APIClient.shared.fetchTopTags { result in
            defer { group.leave() }
            switch result {
            case .success(let response):
                if response.success {
                    DispatchQueue.main.async {
                        self.topTags = response.data
                    }
                }
            case .failure(let error):
                print("Top Tags Error: \(error)")
            }
        }

        group.notify(queue: .main) {
            self.isLoading = false
        }
    }

    // Processed data for Asset Allocation Chart
    var assetAllocation: [(type: String, value: Double)] {
        let grouped = Dictionary(grouping: assetPerformance) { $0.type }
        return grouped.map { (key, values) in
            (type: key, value: values.reduce(0) { $0 + $1.currentValueValue })
        }.sorted { $0.value > $1.value }
    }
}
