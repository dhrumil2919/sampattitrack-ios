import SwiftUI

struct TrendIndicator: View {
    let value: Double
    let showPercentage: Bool
    
    init(value: Double, showPercentage: Bool = true) {
        self.value = value
        self.showPercentage = showPercentage
    }
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: value >= 0 ? "arrow.up.right" : "arrow.down.right")
                .font(.caption)
                .foregroundColor(value >= 0 ? .green : .red)
            
            if showPercentage {
                Text(String(format: "%.1f%%", abs(value)))
                    .font(.caption)
                    .foregroundColor(value >= 0 ? .green : .red)
            }
        }
    }
}
