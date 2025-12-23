import SwiftUI
import SwiftData

struct AddUnitView: View {
    @StateObject private var viewModel = AddUnitViewModel()
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.modelContext) private var modelContext
    @FocusState private var isNameFieldFocused: Bool
    
    var body: some View {
        Form {
            Section(header: Text("Basic Info")) {
                Picker("Type", selection: $viewModel.type) {
                    ForEach(viewModel.types, id: \.self) { type in
                        Text(type).tag(type)
                    }
                }
                
                TextField("Name", text: $viewModel.name)
                    .focused($isNameFieldFocused)
                
                TextField("Code", text: $viewModel.code)
                    .autocapitalization(.allCharacters)
            }
            
            Section(header: Text("Configuration")) {
                TextField("Symbol (optional)", text: $viewModel.symbol)
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
        .navigationTitle("New Unit")
        .onAppear {
            viewModel.setModelContext(modelContext)
        }
        .onChange(of: viewModel.successMessage) {
            if viewModel.successMessage != nil {
                presentationMode.wrappedValue.dismiss()
            }
        }
    }
}
