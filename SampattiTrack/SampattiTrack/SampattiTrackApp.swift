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
    let syncManager: SyncManager
    
    init() {
        do {
            let schema = Schema([
                SDTransaction.self,
                SDAccount.self,
            ])
            let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

            container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            // Initialize SyncManager with the main context
            syncManager = SyncManager(modelContext: container.mainContext)
        } catch {
            fatalError("Failed to configure SwiftData container: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(syncManager)
        }
        .modelContainer(container)
    }
}
