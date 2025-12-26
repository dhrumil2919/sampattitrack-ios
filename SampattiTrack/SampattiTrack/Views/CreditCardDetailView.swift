import SwiftUI
import SwiftData

struct CreditCardDetailView: View {
    let account: SDAccount
    @Environment(\.modelContext) private var modelContext
    
    // Fetch all postings for this account
    @Query var postings: [SDPosting]
    
    // State for selected cycle
    @State private var selectedPeriodIndex: Int = 0
    // Periods (calculated)
    @State private var periods: [StatementPeriod] = []
    
    init(account: SDAccount) {
        self.account = account
        let id = account.id
        // Filter postings for this account
        _postings = Query(filter: #Predicate<SDPosting> { $0.accountID == id })
    }
    
    // Network-based styling (matching LiabilitiesView)
    var networkColor: Color {
        guard let network = account.network?.lowercased() else { return .blue }
        switch network {
        case "visa": return Color(red: 0.08, green: 0.22, blue: 0.60)
        case "mastercard": return Color(red: 0.92, green: 0.29, blue: 0.13)
        case "amex", "american express": return Color(red: 0.00, green: 0.45, blue: 0.64)
        case "rupay": return Color(red: 0.40, green: 0.62, blue: 0.24)
        default: return .gray
        }
    }
    
    var networkIcon: String {
        guard let network = account.network?.lowercased() else { return "creditcard.fill" }
        switch network {
        case "visa": return "creditcard.fill"
        case "mastercard": return "creditcard.circle.fill"
        case "amex", "american express": return "creditcard.and.123"
        case "rupay": return "creditcard.fill"
        default: return "creditcard.fill"
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header Card with Network Branding
                if !periods.isEmpty {
                    VStack(spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(account.name)
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(.primary)
                                
                                if let network = account.network, let digits = account.lastDigits {
                                    HStack(spacing: 4) {
                                        Text(network)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundColor(.secondary)
                                        Text("••••")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                        Text(digits)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            
                            Spacer()
                            
                            Image(systemName: networkIcon)
                                .font(.system(size: 32))
                                .foregroundColor(networkColor.opacity(0.3))
                        }
                    }
                    .padding()
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .cornerRadius(12)
                }
                
                if periods.isEmpty {
                    VStack(spacing: 12) {
                         Image(systemName: "calendar.badge.exclamationmark")
                             .font(.system(size: 48))
                             .foregroundColor(.secondary)
                         Text("No statement periods generated.")
                             .font(.headline)
                             .foregroundColor(.primary)
                         Text("Update account settings with Statement Day to view cycles.")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 40)
                } else {
                    // Cycle Selector
                    HStack {
                        Text("Billing Cycle")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        Spacer()
                        Picker("Billing Cycle", selection: $selectedPeriodIndex) {
                            ForEach(periods.indices, id: \.self) { index in
                                Text(periodLabel(periods[index]))
                                    .tag(index)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .labelsHidden()
                    }
                    .padding()
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .cornerRadius(10)
                    
                    if periods.indices.contains(selectedPeriodIndex) {
                        let period = periods[selectedPeriodIndex]
                        let stats = calculateStats(for: period)
                        
                        // Summary Card
                        StatementSummaryCard(account: account, period: period, stats: stats)
                        
                        // Transactions List
                        TransactionHistoryList(postings: stats.transactions, account: account)
                    }
                }
            }
            .padding()
        }
        .navigationTitle(account.name)
        .background(Color(uiColor: .systemGroupedBackground))
        .onAppear {
            generatePeriods()
        }
    }
    
    func periodLabel(_ period: StatementPeriod) -> String {
        let label = DateFormatterCache.formatMonthYear(period.endDate)
        if period.status == .open {
            return "\(label) (Current)"
        }
        return label
    }
    
    func generatePeriods() {
        // Logic to generate periods based on account.statementDay
        // Same logic as React app or Backend
        guard let statementDay = account.statementDay else { return }
        
        let now = Date()
        var generated: [StatementPeriod] = []
        
        let calendar = Calendar.current
        
        // Generate last 12 months
        for i in 0..<12 {
            // End Date: statementDay of (Current Month - i)
            // Start Date: (End Date - 1 Month) + 1 Day
            
            var components = calendar.dateComponents([.year, .month], from: now)
            components.month = (components.month ?? 1) - i
            components.day = statementDay
            
            guard let endDate = calendar.date(from: components) else { continue }
            guard let startDate = calendar.date(byAdding: .month, value: -1, to: endDate)?.addingTimeInterval(86400) else { continue }
            
            // Due Date: 20 days after endDate (approx) or use metadata dueDay
            var dueDate: Date
            if let dueDay = account.dueDay {
                // Find next occurrence of dueDay after endDate
                var dueComps = calendar.dateComponents([.year, .month], from: endDate)
                dueComps.day = dueDay
                if let d = calendar.date(from: dueComps), d > endDate {
                    dueDate = d
                } else {
                     dueDate = calendar.date(byAdding: .month, value: 1, to: calendar.date(from: dueComps)!)!
                }
            } else {
                 dueDate = calendar.date(byAdding: .day, value: 20, to: endDate)!
            }
            
            // Status
            var status: StatementStatus = .closed
            if now >= startDate && now <= endDate {
                status = .open // Current cycle
            } else if now > endDate && now > dueDate {
                 // Check if paid? For now just mark closed or overdue logic separate
                 status = .closed
            }
            
            generated.append(StatementPeriod(startDate: startDate, endDate: endDate, dueDate: dueDate, status: status))
        }
        
        self.periods = generated
        // Default to current (first one usually if loop 0 is current)
        self.selectedPeriodIndex = 0
    }
    
     func calculateStats(for period: StatementPeriod) -> StatementStats {
         // Filter postings within range [startDate, endDate]
         // Note: transactionDate is typically just Date (YY-MM-DD). We need to be careful with time.
         // SDPosting doesn't have `date`. SDTransaction has `date`.
         // Wait, SDPosting does not have date. SDTransaction does.
         // And `_postings` sort uses `\SDPosting.transactionDate`. Does SDPosting have it?
         // Let's check `SDPosting` model. Usually it links to transaction.
         
         // Since I query `SDPosting`, I need the date from its transaction relationship.
         // `SDPosting` has `transaction: SDTransaction?`
         let relevantPostings = postings.filter { p in
             guard let txn = p.transaction else { return false }
             let dateStr = txn.date
             // Parse date string "2023-10-27"
             // Using cached ISO8601 formatter
             guard let date = DateFormatterCache.parseISO8601(dateStr) else { return false }
             
             return date >= period.startDate && date <= period.endDate
         }
         
         var credits: Decimal = 0
         var debits: Decimal = 0
         
         for p in relevantPostings {
             let amt = Decimal(string: p.amount) ?? 0
             if amt < 0 {
                 debits += abs(amt)
             } else {
                 credits += amt
             }
         }
         
         // Opening balance calculation is HARD locally because we need sum of ALL previous transactions.
         // Or we fetch balance at start date calculated from all previous.
         // Optimization: Calculate total balance, then subtract transactions after start date?
         // No, calculate total balance of all postings BEFORE startDate.
         
         // This is expensive. But feasible for local DB.
         let previousPostings = postings.filter { p in
             guard let txn = p.transaction else { return false }
             let dateStr = txn.date
             guard let date = DateFormatterCache.parseISO8601(dateStr) else { return false }
             return date < period.startDate
         }
         
         let openingBalance = previousPostings.reduce(Decimal(0)) { $0 + (Decimal(string: $1.amount) ?? 0) }
         
         // Amount Due logic
         // Opening Balance (Debt) + Debits - Credits
         // Inverted because Liability is negative.
         // Opening Balance: -1000 (Owe 1000). Display: 1000.
         // Debits: -500. Display: +500.
         // Credits: +200. Display: -200.
         // New Balance: -1300. Display: 1300.
         
         let openingDisplay = -openingBalance
         // Debits are already abs()
         // Credits are pos
         
         let due = openingDisplay + debits - credits
         
         return StatementStats(
             openingBalance: openingDisplay,
             totalDebits: debits,
             totalCredits: credits,
             amountDue: due,
             transactions: relevantPostings
         )
     }
}

struct StatementPeriod {
    let startDate: Date
    let endDate: Date
    let dueDate: Date
    let status: StatementStatus
}

enum StatementStatus {
    case open, closed
}

struct StatementStats {
    let openingBalance: Decimal
    let totalDebits: Decimal
    let totalCredits: Decimal
    let amountDue: Decimal
    let transactions: [SDPosting]
}

struct StatementSummaryCard: View {
    let account: SDAccount
    let period: StatementPeriod
    let stats: StatementStats
    
    var body: some View {
        VStack(spacing: 16) {
            // Statement Period Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Statement Period")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(period.endDate.formatted(date: .abbreviated, time: .omitted))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                Spacer()
                if period.status == .open {
                    Text("CURRENT")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green)
                        .cornerRadius(4)
                }
            }
            
            Divider()
            
            // Transaction Summary
            VStack(spacing: 10) {
                SummaryRow(label: "Opening Balance", value: formatCurrency(stats.openingBalance), color: .primary)
                SummaryRow(label: "Debits (+)", value: formatCurrency(stats.totalDebits), color: .red)
                SummaryRow(label: "Credits (-)", value: formatCurrency(stats.totalCredits), color: .green)
            }
            
            Divider()
            
            // Due Information (Prominent)
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Due Date")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.caption)
                        Text(period.dueDate.formatted(date: .abbreviated, time: .omitted))
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Amount Due")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatCurrency(stats.amountDue))
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(stats.amountDue > 0 ? .red : .green)
                }
            }
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 2)
    }
    
    func formatCurrency(_ val: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = account.currency ?? "INR"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSDecimalNumber(decimal: val)) ?? "\(val)"
    }
}

// Helper view for summary rows
struct SummaryRow: View {
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(color)
        }
    }
}

struct TransactionHistoryList: View {
    let postings: [SDPosting]
    let account: SDAccount
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Transactions")
                .font(.headline)
                .padding(.bottom, 4)
            
            if postings.isEmpty {
                Text("No transactions in this period.")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(postings) { posting in
                     TransactionRowSimple(posting: posting, currency: account.currency ?? "INR")
                }
            }
        }
        .padding(.top)
    }
}

struct TransactionRowSimple: View {
    let posting: SDPosting
    let currency: String
    
    var body: some View {
        HStack(spacing: 12) {
            // Date Circle
            if let date = posting.transaction?.date {
                VStack(spacing: 2) {
                    Text(formatDay(date))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    Text(formatMonth(date))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                }
                .frame(width: 44)
            }
            
            // Transaction Details
            VStack(alignment: .leading, spacing: 2) {
                Text(posting.transaction?.desc ?? "Unknown")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                if let note = posting.transaction?.note, !note.isEmpty {
                    Text(note)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Amount
            let amount = Decimal(string: posting.amount) ?? 0
            let isDebit = amount < 0
            Text(formatCurrency(abs(amount)))
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(isDebit ? .red : .green)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(Color(uiColor: .tertiarySystemGroupedBackground))
        .cornerRadius(10)
    }
    
    func formatDay(_ dateStr: String) -> String {
        return DateFormatterCache.formatDay(dateStr)
    }
    
    func formatMonth(_ dateStr: String) -> String {
        return DateFormatterCache.formatMonth(dateStr)
    }
    
    func formatCurrency(_ val: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSDecimalNumber(decimal: val)) ?? "\(val)"
    }
}
