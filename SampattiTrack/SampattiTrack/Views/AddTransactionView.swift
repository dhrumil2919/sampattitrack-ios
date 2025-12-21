import SwiftUI

struct AddTransactionView: View {
    @StateObject private var viewModel = AddTransactionViewModel()
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        Form {
            Section(header: Text("Details")) {
                DatePicker("Date", selection: $viewModel.date, displayedComponents: .date)
                TextField("Description (Payee)", text: $viewModel.description)
                TextField("Note", text: $viewModel.note)
            }
            
            Section(header: Text("Postings (Splits)")) {
                Text("Use negative for money leaving, positive for money entering.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                ForEach(Array(viewModel.postings.enumerated()), id: \.element.id) { index, posting in
                    VStack(alignment: .leading, spacing: 8) {
                        // Account Selector
                        if let account = viewModel.accounts.first(where: { $0.id == posting.accountID }) {
                            NavigationLink(destination: SearchableAccountPicker(
                                title: "Select Account",
                                selection: Binding(
                                    get: { viewModel.postings[index].accountID },
                                    set: { viewModel.postings[index].accountID = $0 }
                                ),
                                accounts: viewModel.accounts
                            )) {
                                Text(account.name)
                                    .foregroundColor(.primary)
                            }
                        } else {
                            NavigationLink(destination: SearchableAccountPicker(
                                title: "Select Account",
                                selection: Binding(
                                    get: { viewModel.postings[index].accountID },
                                    set: { viewModel.postings[index].accountID = $0 }
                                ),
                                accounts: viewModel.accounts
                            )) {
                                Text("Select Account")
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        // Unit Picker
                        Picker("Unit", selection: Binding(
                            get: { viewModel.postings[index].unitCode },
                            set: { newValue in
                                viewModel.postings[index].unitCode = newValue
                                let formatter = DateFormatter()
                                formatter.dateFormat = "yyyy-MM-dd"
                                let dateString = formatter.string(from: viewModel.date)
                                viewModel.fetchPriceForPosting(at: index, date: dateString)
                            }
                        )) {
                            ForEach(viewModel.units) { unit in
                                Text("\(unit.code) - \(unit.name)").tag(unit.code)
                            }
                        }
                        .pickerStyle(.menu)
                        
                        HStack {
                            // Quantity
                            TextField("Quantity", text: Binding(
                                get: { viewModel.postings[index].quantity },
                                set: { newValue in
                                    viewModel.postings[index].quantity = newValue
                                    viewModel.recalculateAmount(at: index)
                                }
                            ))
                            .keyboardType(.decimalPad)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 80)
                            
                            // Price indicator
                            Text("@ \(viewModel.postings[index].price)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 60, alignment: .leading)
                            
                            // Amount (read-only, auto-calculated)
                            TextField("Amount", text: .constant(viewModel.postings[index].amount))
                                .disabled(true)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .foregroundColor(Double(posting.amount) ?? 0 < 0 ? .red : .green)
                                .opacity(0.7)
                            

                        }
                        
                        // Tags Section
                        TagsEditorView(
                            tags: $viewModel.postings[index].tags,
                            availableTags: viewModel.availableTags
                        )
                    }
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
            
            Section {
                Button(action: {
                    viewModel.createTransaction()
                }) {
                    if viewModel.isSaving {
                        ProgressView()
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
            viewModel.fetchAccounts()
        }
        .onChange(of: viewModel.successMessage) {
            if viewModel.successMessage != nil {
                presentationMode.wrappedValue.dismiss()
            }
        }
    }
}
