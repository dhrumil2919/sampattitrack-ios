import Foundation
import Network
import Combine

/// OFFLINE-FIRST: Monitors network connectivity and triggers sync when connection is restored
/// Uses NWPathMonitor to detect network changes and automatically resume sync operations
class NetworkMonitor: ObservableObject {
    /// Published property indicating current network connectivity status
    @Published var isConnected: Bool = true
    
    /// Last known connection status for detecting transitions
    @Published var connectionType: NWInterface.InterfaceType?
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.sampattitrack.networkmonitor")
    
    /// Reference to SyncManager for triggering automatic sync
    weak var syncManager: SyncManager?
    
    init() {
        // Monitor will be started by calling start()
    }
    
    /// Start monitoring network connectivity
    /// Should be called once during app initialization
    func start() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                let wasConnected = self.isConnected
                let isNowConnected = path.status == .satisfied
                
                // Update connection status
                self.isConnected = isNowConnected
                
                // Determine connection type
                if isNowConnected {
                    if path.usesInterfaceType(.wifi) {
                        self.connectionType = .wifi
                    } else if path.usesInterfaceType(.cellular) {
                        self.connectionType = .cellular
                    } else if path.usesInterfaceType(.wiredEthernet) {
                        self.connectionType = .wiredEthernet
                    } else {
                        self.connectionType = nil
                    }
                } else {
                    self.connectionType = nil
                }
                
                // OFFLINE-FIRST: Auto-sync when transitioning from offline to online
                if !wasConnected && isNowConnected {
                    print("[NetworkMonitor] 🌐 Connection restored (\(self.connectionType?.name ?? "unknown")) - triggering sync")
                    Task {
                        await self.syncManager?.syncAll()
                    }
                } else if wasConnected && !isNowConnected {
                    print("[NetworkMonitor] 📴 Connection lost - app continues working offline")
                } else if isNowConnected {
                    print("[NetworkMonitor] 🌐 Connected via \(self.connectionType?.name ?? "unknown")")
                }
            }
        }
        
        monitor.start(queue: queue)
        print("[NetworkMonitor] Started monitoring network status")
    }
    
    /// Stop monitoring network connectivity
    /// Should be called during app termination
    func stop() {
        monitor.cancel()
        print("[NetworkMonitor] Stopped monitoring network status")
    }
}

// MARK: - Helper Extensions

extension NWInterface.InterfaceType {
    var name: String {
        switch self {
        case .wifi: return "WiFi"
        case .cellular: return "Cellular"
        case .wiredEthernet: return "Ethernet"
        case .loopback: return "Loopback"
        case .other: return "Other"
        @unknown default: return "Unknown"
        }
    }
}
