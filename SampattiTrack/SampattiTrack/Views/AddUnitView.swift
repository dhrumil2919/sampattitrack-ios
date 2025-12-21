import SwiftUI

struct AddUnitView: View {
    @StateObject private var viewModel = AddUnitViewModel()
    @Environment(\.presentationMode) var presentationMode
    @FocusState private var isNameFieldFocused: Bool
    
    var body: some View {
        ZStack {
            Form {
                Section(header: Text("Basic Info")) {
                    Picker("Type", selection: $viewModel.type) {
                        ForEach(viewModel.types, id: \.self) { type in
                            Text(type).tag(type)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("Search by name (e.g. Aditya Sunlife)", text: $viewModel.name)
                            .focused($isNameFieldFocused)
                        
                        if viewModel.isSearching {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Searching...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    TextField("Code (auto-filled from search)", text: $viewModel.code)
                        .autocapitalization(.allCharacters)
                        .disabled(!viewModel.searchResults.isEmpty)
                }
                
                Section(header: Text("Configuration")) {
                    Picker("Data Provider", selection: $viewModel.provider) {
                        Text("None").tag("")
                        ForEach(viewModel.providers, id: \.self) { provider in
                            Text(provider).tag(provider)
                        }
                    }
                    
                    TextField("Symbol (auto-filled from search)", text: $viewModel.symbol)
                        .disabled(!viewModel.searchResults.isEmpty)
                    
                    TextField("Base Currency", text: $viewModel.currency)
                        .autocapitalization(.allCharacters)
                }
                
                if let error = viewModel.errorMessage {
                    Section {
                        Text(error).foregroundColor(.red)
                    }
                }
                
                if let success = viewModel.successMessage {
                    Section {
                        Text(success).foregroundColor(.green)
                    }
                }
                
                Button("Create Unit") {
                    viewModel.createUnit()
                }
                .disabled(viewModel.isLoading || viewModel.code.isEmpty || viewModel.name.isEmpty)
            }
            
            // Search Results Overlay
            if !viewModel.searchResults.isEmpty {
                VStack {
                    Spacer()
                        .frame(height: 180) // Offset to position below the name field
                    
                    VStack(spacing: 0) {
                        ForEach(viewModel.searchResults.prefix(5)) { result in
                            Button(action: {
                                viewModel.selectSymbol(result)
                                isNameFieldFocused = false
                            }) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(result.name)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    HStack {
                                        Text(result.symbol)
                                            .font(.caption)
                                            .padding(4)
                                            .background(Color.blue.opacity(0.1))
                                            .cornerRadius(4)
                                        if let exchange = result.exchange {
                                            Text(exchange)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            if result.id != viewModel.searchResults.prefix(5).last?.id {
                                Divider()
                            }
                        }
                    }
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                    .padding(.horizontal)
                    
                    Spacer()
                }
            }
        }
        .navigationTitle("New Unit")
    }
}
