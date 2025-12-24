import SwiftUI

// Hierarchical Assets View - Shows recursive asset tree with aggregated groups
struct HierarchicalAssetsView: View {
    let assets: [AssetPerformance]
    let totalAssets: String
    let totalLiabilities: String
    let parentPath: String? // nil = root level
    
    private var assetsValue: Double {
        Double(totalAssets) ?? 0
    }
    
    private var liabilitiesValue: Double {
        Double(totalLiabilities) ?? 0
    }
    
    private var netWorth: Double {
        assetsValue + liabilitiesValue
    }
    
    // Build unique account groups at current level by aggregating all child accounts
    private var currentLevelGroups: [AssetGroup] {
        let targetDepth = (parentPath?.split(separator: ":").count ?? 0) + 1
        
        var groupMap: [String: AssetGroup] = [:]
        
        for asset in assets {
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
                groupMap[groupPath] = AssetGroup(
                    id: groupPath,
                    name: groupName,
                    currentValue: 0,
                    invested: 0,
                    returns: 0,
                    type: asset.type,
                    childCount: 0
                )
            }
            
            groupMap[groupPath]?.currentValue += asset.currentValueValue
            groupMap[groupPath]?.invested += asset.investedAmountValue
            groupMap[groupPath]?.returns += asset.returnValue
            groupMap[groupPath]?.childCount += 1
        }
        
        return groupMap.values
            .map { group in
                var g = group
                g.returnPercent = g.invested > 0 ? (g.returns / g.invested) * 100 : 0
                return g
            }
            .sorted { $0.currentValue > $1.currentValue }
    }
    
    // Check if a group has children
    private func hasChildren(_ groupPath: String) -> Bool {
        let groupDepth = groupPath.split(separator: ":").count
        return assets.contains { asset in
            asset.accountID.hasPrefix(groupPath + ":") && asset.depth > groupDepth
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Balance Sheet Summary (only at root)
                if parentPath == nil {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Balance Sheet")
                            .font(.headline)
                        
                        HStack(spacing: 20) {
                            VStack(alignment: .leading) {
                                Text("Total Assets")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(CurrencyFormatter.format(totalAssets))
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.green)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing) {
                                Text("Total Liabilities")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(CurrencyFormatter.format(totalLiabilities))
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.red)
                            }
                        }
                        
                        Divider()
                        
                        HStack {
                            Text("Net Worth")
                                .font(.title3)
                                .fontWeight(.semibold)
                            Spacer()
                            Text(CurrencyFormatter.format(String(netWorth)))
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.cyan)
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.05), radius: 5)
                }
                
                // Groups List
                if !currentLevelGroups.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(parentPath == nil ? "Asset Categories" : "Accounts")
                            .font(.headline)
                        
                        ForEach(currentLevelGroups) { group in
                            let hasKids = hasChildren(group.id)
                            
                            if hasKids {
                                NavigationLink(destination: HierarchicalAssetsView(
                                    assets: assets,
                                    totalAssets: totalAssets,
                                    totalLiabilities: totalLiabilities,
                                    parentPath: group.id
                                )) {
                                    AssetGroupRow(group: group, hasChildren: true)
                                }
                                .buttonStyle(PlainButtonStyle())
                            } else {
                                AssetGroupRow(group: group, hasChildren: false)
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
        .navigationTitle(parentPath?.split(separator: ":").last.map(String.init) ?? "Assets")
        .navigationBarTitleDisplayMode(.large)
    }
}

// Asset Group for aggregation
struct AssetGroup: Identifiable {
    let id: String
    let name: String
    var currentValue: Double
    var invested: Double
    var returns: Double
    var type: String
    var returnPercent: Double = 0
    var childCount: Int
}

// Asset Group Row
struct AssetGroupRow: View {
    let group: AssetGroup
    let hasChildren: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(group.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                Text("\(group.childCount) account\(group.childCount == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(CurrencyFormatter.format(String(group.currentValue)))
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
                if group.returns != 0 {
                    Text("\(group.returnPercent >= 0 ? "+" : "")\(String(format: "%.1f%%", group.returnPercent))")
                        .font(.caption)
                        .foregroundColor(group.returnPercent >= 0 ? .green : .red)
                }
            }
            
            if hasChildren {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }
}
