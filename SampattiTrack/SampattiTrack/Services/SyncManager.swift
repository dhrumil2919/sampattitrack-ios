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
    
    /// OFFLINE-FIRST: Performs full two-way sync (non-blocking)
    /// Sync failures are logged but never block the UI
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
        
        // OFFLINE-FIRST: performFullSync never throws
        await actor.performFullSync()
        
        await MainActor.run {
            lastSyncDate = Date()
            isSyncing = false
        }
    }
    
    /// Initial sync after login - same as syncAll (actor handles delete)
    func initialSync() async {
        await syncAll()
    }
    
    // MARK: - Debug Methods
    
    /// DEBUG: Clear all pending sync queue items
    func clearSyncQueue() async {
        guard let actor = syncActor else {
            print("SyncActor not initialized")
            return
        }
        
        do {
            try await actor.clearSyncQueue()
            print("[SyncManager] Sync queue cleared")
        } catch {
            print("[SyncManager] Failed to clear sync queue: \(error)")
        }
    }
    
    /// DEBUG: Clear all local data and cache
    /// WARNING: This will delete all local data!
    func clearAllData() async {
        guard let actor = syncActor else {
            print("SyncActor not initialized")
            return
        }
        
        do {
            try await actor.clearAllLocalData()
            print("[SyncManager] All data and cache cleared")
        } catch {
            print("[SyncManager] Failed to clear data: \(error)")
        }
    }
}
