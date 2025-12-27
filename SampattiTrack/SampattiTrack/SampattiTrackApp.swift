//
//  SampattiTrackApp.swift
//  SampattiTrack
//
//  Created by Dhrumil Patel on 12/14/25.
//

import SwiftUI
import SwiftData

@main
struct SampattiTrackApp: App {
    let container: ModelContainer
    @StateObject var syncManager: SyncManager
    @StateObject var networkMonitor = NetworkMonitor()
    
    init() {
        do {
            let schema = Schema([
                SDTransaction.self,
                SDAccount.self,
                SDPosting.self,
                SDTag.self,
                SDUnit.self,
                SDPrice.self,
                SyncQueueItem.self,
            ])
            let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

            container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            
            // OFFLINE-FIRST: Initialize SyncManager with the main context
            let manager = SyncManager(modelContext: container.mainContext)
            _syncManager = StateObject(wrappedValue: manager)
        } catch {
            fatalError("Failed to configure SwiftData container: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(syncManager)
                .environmentObject(networkMonitor)
                // OFFLINE-FIRST: Setup network monitoring and sync triggers
                .onAppear {
                    // Link network monitor to sync manager
                    networkMonitor.syncManager = syncManager
                    networkMonitor.start()
                    
                    // Trigger initial sync if online
                    if AuthManager.shared.isAuthenticated && networkMonitor.isConnected {
                        Task {
                            await syncManager.syncAll()
                        }
                    }
                }
                // OFFLINE-FIRST: Sync when app returns to foreground
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                    if AuthManager.shared.isAuthenticated && networkMonitor.isConnected {
                        Task {
                            await syncManager.syncAll()
                        }
                    }
                }
        }
        .modelContainer(container)
    }
}
