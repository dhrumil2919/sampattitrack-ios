import SwiftUI
import SwiftData

struct AddTransactionView: View {
    @StateObject private var viewModel = AddTransactionViewModel()
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.modelContext) private var modelContext
    @FocusState private var focusedField: Field?

    enum Field {
        case description
        case note
    }
    
    var body: some View {
        Form {
            Section(header: Text("Details")) {
                DatePicker("Date", selection: $viewModel.date, displayedComponents: .date)
                TextField("Description (Payee)", text: $viewModel.description)
                    .focused($focusedField, equals: .description)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .note }

                TextField("Note", text: $viewModel.note)
                    .focused($focusedField, equals: .note)
                    .textInputAutocapitalization(.sentences)
                    .submitLabel(.done)
                    .onSubmit { focusedField = nil }
            }
            
            Section(header: Text("Postings (Splits)")) {
                Text("Use negative for money leaving, positive for money entering.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                ForEach($viewModel.postings) { $posting in
                    PostingRowView(
                        posting: $posting,
                        accounts: viewModel.accounts,
                        units: viewModel.units,
                        availableTags: viewModel.availableTags,
                        date: viewModel.date,
                        onUnitChange: { newUnit in
                            posting.unitCode = newUnit
                            if let idx = viewModel.postings.firstIndex(where: { $0.id == posting.id }) {
                                let formatter = DateFormatter()
                                formatter.dateFormat = "yyyy-MM-dd"
                                let dateString = formatter.string(from: viewModel.date)
                                viewModel.fetchPriceForPosting(at: idx, date: dateString)
                            }
                        },
                        onQuantityChange: { newQty in
                            posting.quantity = newQty
                            if let idx = viewModel.postings.firstIndex(where: { $0.id == posting.id }) {
                                viewModel.recalculateAmount(at: idx)
                            }
                        }
                    )
                    .padding(.vertical, 4)
                }
                .onDelete { indexSet in
                    if viewModel.postings.count > 2 {
                        indexSet.forEach { index in
                            viewModel.removePosting(at: index)
                        }
                    }
                }
                
                // Add Posting Button
                Button(action: {
                    viewModel.addPosting()
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Posting")
                    }
                }
            }
            
            // Balance Indicator
            Section {
                HStack {
                    Text(viewModel.isBalanced ? "✓ Balanced" : "Imbalance: \(CurrencyFormatter.formatCheck(abs(viewModel.totalAmount)))")
                        .foregroundColor(viewModel.isBalanced ? .green : .red)
                        .fontWeight(.medium)
                }
            }
            
            if let error = viewModel.errorMessage {
                Section {
                    Text(error).foregroundColor(.red)
                }
            }
            
            Section(footer: Group {
                if !viewModel.isBalanced {
                    Text("Transaction must be balanced (difference is 0) to save.")
                        .foregroundColor(.secondary)
                }
            }) {
                Button(action: {
                    viewModel.createTransaction()
                }) {
                    if viewModel.isSaving {
                        ProgressView()
                            .accessibilityLabel("Saving transaction")
                    } else {
                        Text("Create Transaction")
                            .frame(maxWidth: .infinity)
                    }
                }
                .disabled(viewModel.isLoading || viewModel.isSaving || !viewModel.isBalanced)
            }
        }
        .navigationTitle("Add Transaction")
        .onAppear {
            viewModel.setModelContext(modelContext)
            viewModel.fetchLocalData()
            // Auto-focus the description field for quicker entry
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                focusedField = .description
            }
        }
        .onChange(of: viewModel.successMessage) {
            if viewModel.successMessage != nil {
                presentationMode.wrappedValue.dismiss()
            }
        }
    }
}
