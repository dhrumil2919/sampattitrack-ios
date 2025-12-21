import SwiftUI

struct InsightCard: View {
    let title: String
    let value: String
    let primaryColor: Color
    let secondaryLabel: String?
    let secondaryValue: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(primaryColor)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            
            if let label = secondaryLabel, let secState = secondaryValue {
                HStack {
                    Text(label)
                    Spacer()
                    Text(secState)
                }
                .font(.caption)
                .foregroundColor(.secondary)
                .minimumScaleFactor(0.8)
            }
        }
        .padding()
        .frame(width: 170, height: 120) // Slightly wider and fixed height for consistency
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}
