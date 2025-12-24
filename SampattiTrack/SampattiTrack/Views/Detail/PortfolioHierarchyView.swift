import SwiftUI

// Hierarchical Portfolio View - Shows recursive account tree with aggregated groups
// Only includes Investment-type accounts for portfolio analysis
struct HierarchicalPortfolioView: View {
    let assets: [AssetPerformance]
    let parentPath: String? // nil = starts from "Assets" children, "Assets:Equity" = show MF/Stock
    
    // Filter to only Investment type accounts
    private var investmentAssets: [AssetPerformance] {
        assets.filter { $0.type == "Investment" }
    }
    
    // Build unique account groups at current level by parsing account paths
    private var currentLevelGroups: [AccountGroup] {
        let targetDepth = (parentPath?.split(separator: ":").count ?? 0) + 1
        
        var groupMap: [String: AccountGroup] = [:]
        
        for asset in investmentAssets {
            let components = asset.accountID.split(separator: ":").map(String.init)
            
            // Skip if this asset doesn't belong under current parent
            if let parent = parentPath {
                guard asset.accountID.hasPrefix(parent + ":") else { continue }
            }
            
            // Get the path at target depth
            guard components.count >= targetDepth else { continue }
            let groupPath = components.prefix(targetDepth).joined(separator: ":")
            let groupName = components[targetDepth - 1]
            
            if groupMap[groupPath] == nil {
                groupMap[groupPath] = AccountGroup(
                    id: groupPath,
                    name: groupName,
                    invested: 0,
                    currentValue: 0,
                    returns: 0,
                    xirrWeighted: 0,
                    xirrWeight: 0,
                    childCount: 0
                )
            }
            
            groupMap[groupPath]?.invested += asset.investedAmountValue
            groupMap[groupPath]?.currentValue += asset.currentValueValue
            groupMap[groupPath]?.returns += asset.returnValue
            if asset.investedAmountValue > 0 {
                groupMap[groupPath]?.xirrWeighted += asset.xirr * asset.investedAmountValue
                groupMap[groupPath]?.xirrWeight += asset.investedAmountValue
            }
            groupMap[groupPath]?.childCount += 1
        }
        
        return groupMap.values
            .map { group in
                var g = group
                g.xirr = g.xirrWeight > 0 ? g.xirrWeighted / g.xirrWeight : 0
                g.returnPercent = g.invested > 0 ? (g.returns / g.invested) * 100 : 0
                return g
            }
            .sorted { $0.currentValue > $1.currentValue }
    }
    
    // Check if a group has children (more levels below)
    private func hasChildren(_ groupPath: String) -> Bool {
        let groupDepth = groupPath.split(separator: ":").count
        return investmentAssets.contains { asset in
            asset.accountID.hasPrefix(groupPath + ":") && asset.depth > groupDepth
        }
    }
    
    private var totalSummary: (invested: Double, current: Double, returns: Double, xirr: Double) {
        let groups = currentLevelGroups
        let invested = groups.reduce(0) { $0 + $1.invested }
        let current = groups.reduce(0) { $0 + $1.currentValue }
        let returns = current - invested
        
        var totalWeight: Double = 0
        var weightedXIRR: Double = 0
        for group in groups where group.invested > 0 {
            totalWeight += group.invested
            weightedXIRR += group.xirr * group.invested
        }
        let avgXIRR = totalWeight > 0 ? weightedXIRR / totalWeight : 0
        
        return (invested, current, returns, avgXIRR)
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Summary Card
                let summary = totalSummary
                VStack(alignment: .leading, spacing: 12) {
                    Text(parentPath ?? "Total Portfolio")
                        .font(.headline)
                    
                    HStack(spacing: 16) {
                        VStack(alignment: .leading) {
                            Text("Invested")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(CurrencyFormatter.format(String(summary.invested)))
                                .font(.title3)
                                .fontWeight(.semibold)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .center) {
                            Text("Current")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(CurrencyFormatter.format(String(summary.current)))
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(.cyan)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing) {
                            Text("Return")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(CurrencyFormatter.format(String(summary.returns)))
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(summary.returns >= 0 ? .green : .red)
                        }
                    }
                    
                    Divider()
                    
                    HStack {
                        Text("Weighted XIRR")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(String(format: "%.2f%%", summary.xirr))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(summary.xirr >= 0 ? .green : .red)
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.05), radius: 5)
                
                // Groups List
                if !currentLevelGroups.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Asset Groups")
                            .font(.headline)
                        
                        ForEach(currentLevelGroups) { group in
                            let hasKids = hasChildren(group.id)
                            
                            if hasKids {
                                NavigationLink(destination: HierarchicalPortfolioView(
                                    assets: assets,
                                    parentPath: group.id
                                )) {
                                    PortfolioGroupRow(group: group, hasChildren: true)
                                }
                                .buttonStyle(PlainButtonStyle())
                            } else {
                                PortfolioGroupRow(group: group, hasChildren: false)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.05), radius: 5)
                } else {
                    Text("No accounts found at this level")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding()
                }
            }
            .padding()
        }
        .navigationTitle(parentPath?.split(separator: ":").last.map(String.init) ?? "Portfolio")
        .navigationBarTitleDisplayMode(.large)
    }
}

// Account Group for aggregation
struct AccountGroup: Identifiable {
    let id: String
    let name: String
    var invested: Double
    var currentValue: Double
    var returns: Double
    var xirrWeighted: Double
    var xirrWeight: Double
    var xirr: Double = 0
    var returnPercent: Double = 0
    var childCount: Int
}

// Portfolio Group Row
struct PortfolioGroupRow: View {
    let group: AccountGroup
    let hasChildren: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(group.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    Text("XIRR: \(String(format: "%.2f%%", group.xirr))")
                        .font(.caption)
                        .foregroundColor(group.xirr >= 0 ? .green : .red)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(CurrencyFormatter.format(String(group.currentValue)))
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.cyan)
                    Text("\(group.returnPercent >= 0 ? "+" : "")\(String(format: "%.1f%%", group.returnPercent))")
                        .font(.caption)
                        .foregroundColor(group.returnPercent >= 0 ? .green : .red)
                }
                
                if hasChildren {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.blue.opacity(0.2))
                        .frame(width: geometry.size.width, height: 6)
                        .cornerRadius(3)
                    
                    let percentage = min(group.currentValue / max(group.invested, 1), 2.0)
                    Rectangle()
                        .fill(group.currentValue >= group.invested ? Color.green : Color.red)
                        .frame(width: geometry.size.width * CGFloat(percentage / 2), height: 6)
                        .cornerRadius(3)
                }
            }
            .frame(height: 6)
            
            HStack(spacing: 16) {
                Label {
                    Text(CurrencyFormatter.format(String(group.invested)))
                        .font(.caption)
                } icon: {
                    Circle()
                        .fill(Color.blue.opacity(0.5))
                        .frame(width: 6, height: 6)
                }
                
                Label {
                    Text(CurrencyFormatter.format(String(group.returns)))
                        .font(.caption)
                        .foregroundColor(group.returns >= 0 ? .green : .red)
                } icon: {
                    Circle()
                        .fill(group.returns >= 0 ? Color.green : Color.red)
                        .frame(width: 6, height: 6)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }
}
