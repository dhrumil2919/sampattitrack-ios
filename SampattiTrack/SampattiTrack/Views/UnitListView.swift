import SwiftUI
import Combine

struct UnitListView: View {
    @StateObject private var viewModel = UnitListViewModel()
    
    var body: some View {
        NavigationView {
            Group {
                if viewModel.isLoading {
                    ProgressView()
                } else if let error = viewModel.errorMessage {
                    Text(error).foregroundColor(.red)
                } else {
                    List(viewModel.units) { unit in
                        VStack(alignment: .leading) {
                            Text(unit.name)
                                .font(.headline)
                            HStack {
                                Text(unit.code)
                                    .font(.caption)
                                    .padding(4)
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(4)
                                Spacer()
                                Text(unit.type)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Units")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                     NavigationLink(destination: AddUnitView()) {
                         Image(systemName: "plus")
                     }
                }
            }
            .onAppear {
                viewModel.fetchUnits()
            }
        }
    }
}

class UnitListViewModel: ObservableObject {
    @Published var units: [FinancialUnit] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    func fetchUnits() {
        isLoading = true
        APIClient.shared.listUnits { result in
             DispatchQueue.main.async {
                 self.isLoading = false
                 switch result {
                 case .success(let response):
                     if response.success {
                         self.units = response.data
                     }
                 case .failure(let error):
                     self.errorMessage = "\(error)"
                 }
             }
        }
    }
}
