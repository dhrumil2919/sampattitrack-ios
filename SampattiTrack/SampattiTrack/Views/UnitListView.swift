import SwiftUI
import SwiftData

/// UnitListView - OFFLINE-FIRST
/// Uses @Query on SDUnit. No API calls.
struct UnitListView: View {
    @Query(sort: \SDUnit.name) private var units: [SDUnit]
    @EnvironmentObject var syncManager: SyncManager
    
    var body: some View {
        NavigationView {
            Group {
                if units.isEmpty {
                    VStack {
                        Text("No units found")
                        Button("Sync Now") {
                            Task {
                                await syncManager.syncAll()
                            }
                        }
                    }
                } else {
                    List(units, id: \.code) { unit in
                        VStack(alignment: .leading) {
                            Text(unit.name)
                                .font(.headline)
                            HStack {
                                Text(unit.code)
                                    .font(.caption)
                                    .padding(4)
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(4)
                                Spacer()
                                Text(unit.type)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Units")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                     NavigationLink(destination: AddUnitView()) {
                         Image(systemName: "plus")
                     }
                }
            }
            .refreshable {
                await syncManager.syncAll()
            }
        }
    }
}
