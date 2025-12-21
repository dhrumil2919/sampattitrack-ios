import SwiftUI

struct TopTagsSection: View {
    let tags: [TopTag]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "tag.fill")
                    .foregroundColor(.blue)
                Text("Top Expense Tags")
                    .font(.headline)
            }
            
            if tags.isEmpty {
                Text("No tag data available")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(tags) { tag in
                    HStack {
                        Circle()
                            .fill(Color.blue.opacity(0.2))
                            .frame(width: 8, height: 8)
                        
                        Text(tag.tagName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Text(CurrencyFormatter.formatCheck(tag.amountValue))
                            .font(.subheadline)
                            .foregroundColor(.red)
                            .fontWeight(.semibold)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5)
    }
}
