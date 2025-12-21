import Foundation
import Combine

class AuthManager: ObservableObject {
    static let shared = AuthManager()
    
    @Published var isAuthenticated: Bool = false
    @Published var token: String?
    
    private let tokenKey = "auth_token"
    private let service = "com.sampattitrack.auth"
    
    private init() {
        // Migration: Check UserDefaults first
        if let legacyToken = UserDefaults.standard.string(forKey: tokenKey) {
            // Save to Keychain
            if let data = legacyToken.data(using: .utf8) {
                KeychainHelper.standard.save(data, service: service, account: tokenKey)
            }
            // Remove from UserDefaults
            UserDefaults.standard.removeObject(forKey: tokenKey)
            self.token = legacyToken
        } else {
            // Load from Keychain
            if let data = KeychainHelper.standard.read(service: service, account: tokenKey),
               let token = String(data: data, encoding: .utf8) {
                self.token = token
            }
        }

        self.isAuthenticated = self.token != nil
    }
    
    func login(token: String) {
        self.token = token
        self.isAuthenticated = true
        if let data = token.data(using: .utf8) {
            KeychainHelper.standard.save(data, service: service, account: tokenKey)
        }
    }
    
    func logout() {
        self.token = nil
        self.isAuthenticated = false
        KeychainHelper.standard.delete(service: service, account: tokenKey)
    }
}
