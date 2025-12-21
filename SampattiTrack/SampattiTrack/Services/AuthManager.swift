import Foundation
import Combine

class AuthManager: ObservableObject {
    static let shared = AuthManager()
    
    @Published var isAuthenticated: Bool = false
    @Published var token: String?
    
    private let tokenKey = "auth_token"
    
    private init() {
        self.token = UserDefaults.standard.string(forKey: tokenKey)
        self.isAuthenticated = self.token != nil
    }
    
    func login(token: String) {
        self.token = token
        self.isAuthenticated = true
        UserDefaults.standard.set(token, forKey: tokenKey)
    }
    
    func logout() {
        self.token = nil
        self.isAuthenticated = false
        UserDefaults.standard.removeObject(forKey: tokenKey)
    }
}
