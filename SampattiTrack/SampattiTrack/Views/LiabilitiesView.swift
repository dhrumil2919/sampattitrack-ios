import SwiftUI
import SwiftData

struct LiabilitiesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<SDAccount> { $0.category == "Liability" && $0.type == "CreditCard" }, sort: \SDAccount.name)
    var creditCards: [SDAccount]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if creditCards.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "creditcard.fill")
                                .font(.system(size: 48))
                                .foregroundStyle(.secondary)
                            Text("No credit cards found")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                            Text("Add a credit card account to track your liabilities.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 60)
                    } else {
                        ForEach(creditCards) { card in
                            CreditCardRowView(account: card)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Liabilities")
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationDestination(for: SDAccount.self) { account in
                CreditCardDetailView(account: account)
            }
        }
    }
}

struct CreditCardRowView: View {
    let account: SDAccount
    @Query var postings: [SDPosting]
    
    init(account: SDAccount) {
        self.account = account
        let id = account.id
        _postings = Query(filter: #Predicate<SDPosting> { $0.accountID == id })
    }
    
    var balance: Decimal {
        postings.reduce(Decimal(0)) { partialResult, posting in
            partialResult + (Decimal(string: posting.amount) ?? 0)
        }
    }
    
    var displayBalance: Decimal {
        -balance
    }
    
    var utilization: Double {
        guard let limit = account.creditLimit, limit > 0 else { return 0 }
        let bal = NSDecimalNumber(decimal: displayBalance).doubleValue
        return (bal / limit) * 100
    }
    
    var utilizationColor: Color {
        if utilization > 80 { return .red }
        if utilization > 30 { return .orange }
        return .green
    }
    
    // Network-based card colors and symbols
    var networkColor: Color {
        guard let network = account.network?.lowercased() else { return .blue }
        switch network {
        case "visa": return Color(red: 0.08, green: 0.22, blue: 0.60) // Visa Blue
        case "mastercard": return Color(red: 0.92, green: 0.29, blue: 0.13) // Mastercard Orange
        case "amex", "american express": return Color(red: 0.00, green: 0.45, blue: 0.64) // Amex Blue
        case "rupay": return Color(red: 0.40, green: 0.62, blue: 0.24) // RuPay Green
        default: return .gray
        }
    }
    
    var networkIcon: String {
        guard let network = account.network?.lowercased() else { return "creditcard.fill" }
        switch network {
        case "visa": return "creditcard.fill" // SF Symbols don't have specific brand icons
        case "mastercard": return "creditcard.circle.fill"
        case "amex", "american express": return "creditcard.and.123"
        case "rupay": return "creditcard.fill"
        default: return "creditcard.fill"
        }
    }
    
    var body: some View {
        NavigationLink(value: account) {
            VStack(spacing: 0) {
                // Card Body
                VStack(alignment: .leading, spacing: 12) {
                    // Top Row: Name and Network Icon
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(account.name)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.primary)
                            
                            // Network and Last Digits
                            HStack(spacing: 4) {
                                if let network = account.network {
                                    Text(network)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundColor(.secondary)
                                }
                                if let digits = account.lastDigits {
                                    Text("••••")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(digits)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        
                        Spacer()
                        
                        // Network Icon with Brand Color
                        Image(systemName: networkIcon)
                            .font(.system(size: 28))
                            .foregroundColor(networkColor.opacity(0.3))
                    }
                    
                    // Balance Section
                    VStack(alignment: .leading, spacing: 4) {
                        Text(formatCurrency(displayBalance, code: account.currency ?? "INR"))
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(displayBalance > 0 ? .primary : .green)
                        
                        Text("Current Balance")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 4)
                    
                    // Utilization Section
                    if let limit = account.creditLimit, limit > 0 {
                        VStack(spacing: 8) {
                            HStack {
                                Text("Utilization")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(String(format: "%.1f%%", utilization))
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(utilizationColor)
                            }
                            
                            // Utilization Bar
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(Color.gray.opacity(0.15))
                                        .frame(height: 6)
                                    
                                    Capsule()
                                        .fill(utilizationColor)
                                        .frame(width: min(CGFloat(utilization / 100.0) * geo.size.width, geo.size.width), height: 6)
                                }
                            }
                            .frame(height: 6)
                            
                            HStack {
                                Spacer()
                                Text("Limit: \(formatCurrency(Decimal(limit), code: account.currency ?? "INR"))")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.top, 4)
                    }
                    
                    // Due Date
                    if let dueDay = account.dueDay {
                        let nextDue = calculateNextDueDate(day: dueDay)
                        HStack(spacing: 6) {
                            Image(systemName: "calendar")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("Due by \(nextDue.formatted(.dateTime.day().month()))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                .padding(16)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                
                // Utilization Top Border (matching React design)
                if utilization > 0 {
                    GeometryReader { geo in
                        let width = min(CGFloat(utilization / 100.0) * geo.size.width, geo.size.width)
                        Rectangle()
                            .fill(utilizationColor)
                            .frame(width: max(width, 0), height: 4)
                    }
                    .frame(height: 4)
                }
            }
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    func formatCurrency(_ value: Decimal, code: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSDecimalNumber(decimal: value)) ?? "\(value)"
    }
    
    func calculateNextDueDate(day: Int) -> Date {
        let now = Date()
        let calendar = Calendar.current
        let currentDay = calendar.component(.day, from: now)
        let currentMonth = calendar.component(.month, from: now)
        let currentYear = calendar.component(.year, from: now)
        
        var components = DateComponents(year: currentYear, month: currentMonth, day: day)
        if currentDay > day {
            components.month = currentMonth + 1
        }
        return calendar.date(from: components) ?? now
    }
}
