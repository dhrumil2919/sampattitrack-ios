import SwiftUI

struct ContentView: View {
    @EnvironmentObject var syncManager: SyncManager
    @StateObject private var authManager = AuthManager.shared
    @State private var isConfigured: Bool = false
    
    var body: some View {
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


                        NavigationView {
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
                        // Trigger initial sync if authenticated
                         if authManager.isAuthenticated {
                             await syncManager.syncAll()
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
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
