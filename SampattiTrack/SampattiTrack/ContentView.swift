import SwiftUI

struct ContentView: View {
    @EnvironmentObject var syncManager: SyncManager
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var authManager = AuthManager.shared
    @State private var isConfigured: Bool = false
    @State private var hasPerformedInitialSync: Bool = false
    @State private var isBackgrounded: Bool = false
    
    var body: some View {
        ZStack {
            Group {
                if !isConfigured {
                    ConfigurationView(isConfigured: $isConfigured)
                } else {
                    if authManager.isAuthenticated {
                        TabView {
                            DashboardView()
                                .tabItem {
                                    Label("Dashboard", systemImage: "chart.pie.fill")
                                }

                            AccountListView()
                                .tabItem {
                                    Label("Accounts", systemImage: "list.bullet")
                                }

                            NavigationStack {
                                 LiabilitiesView()
                            }
                            .tabItem {
                                Label("Liabilities", systemImage: "creditcard.fill")
                            }



                            NavigationStack {
                                TransactionListView()
                            }
                            .tabItem {
                                Label("Transactions", systemImage: "arrow.left.arrow.right")
                            }

                            UnitListView()
                                .tabItem {
                                    Label("Units", systemImage: "cube.box")
                                }
                        }
                        .task {
                            // First sync after login should do full cleanup
                            if !hasPerformedInitialSync {
                                await syncManager.initialSync()
                                hasPerformedInitialSync = true
                            }
                        }
                    } else {
                        VStack {
                             LoginView()
                             Button("Change Server URL") {
                                 isConfigured = false
                             }
                             .font(.caption)
                             .padding(.bottom)
                        }
                    }
                }
            }
            .onAppear {
                 let savedURL = UserDefaults.standard.string(forKey: "api_base_url")
                 if let savedURL = savedURL, !savedURL.isEmpty {
                     isConfigured = true
                 } else {
                     isConfigured = false
                 }
            }
            .onChange(of: authManager.isAuthenticated) {
                // Reset initial sync tracking when logging out
                if !authManager.isAuthenticated {
                    hasPerformedInitialSync = false
                }
            }

            // Sentinel: Privacy Shield when app is backgrounded
            if isBackgrounded {
                PrivacyOverlay()
                    .transition(.opacity)
                    .zIndex(100)
            }
        }
        .onChange(of: scenePhase) {
            // Use withAnimation to make the transition smooth
            withAnimation(.easeInOut(duration: 0.2)) {
                isBackgrounded = (scenePhase != .active)
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
