import Foundation
import SwiftData
import Combine

class SyncManager: ObservableObject {
    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    
    private var syncActor: SyncActor?
    private let modelContainer: ModelContainer
    
    init(modelContext: ModelContext) {
        self.modelContainer = modelContext.container
        
        // Initialize actor on background
        Task.detached { [modelContainer] in
            let actor = SyncActor(modelContainer: modelContainer)
            await MainActor.run {
                self.syncActor = actor
            }
        }
    }
    
    /// Performs full two-way sync: push local changes, then pull remote data
    func syncAll() async {
        guard !isSyncing else { return }
        guard AuthManager.shared.isAuthenticated else {
            print("Skipping sync - not authenticated")
            return
        }
        guard let actor = syncActor else {
            print("SyncActor not initialized")
            return
        }
        
        await MainActor.run { isSyncing = true }
        
        do {
            try await actor.performFullSync()
            await MainActor.run {
                lastSyncDate = Date()
                isSyncing = false
            }
        } catch {
            print("Sync failed: \(error)")
            await MainActor.run { isSyncing = false }
        }
    }
    
    /// Initial sync after login - same as syncAll (actor handles delete)
    func initialSync() async {
        await syncAll()
    }
}
