import Foundation
import Combine

class LoginViewModel: ObservableObject {
    @Published var username = ""
    @Published var password = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    func login() {
        guard !username.isEmpty, !password.isEmpty else {
            errorMessage = "Please enter both username and password"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        let loginRequest = ["username": username, "password": password]
        let body = try? JSONSerialization.data(withJSONObject: loginRequest)
        
        APIClient.shared.request("/auth/login", method: "POST", body: body) { (result: Result<LoginResponse, APIClient.APIError>) in
            DispatchQueue.main.async {
                self.isLoading = false
                switch result {
                case .success(let response):
                    if response.success, let token = response.data.token {
                        AuthManager.shared.login(token: token)
                    } else {
                        self.errorMessage = response.error?.message ?? "Login failed"
                    }
                case .failure(let error):
                    self.errorMessage = "Network error: \(error)"
                }
            }
        }
    }
}

struct LoginResponse: Codable {
    let success: Bool
    let data: LoginData
    let error: ApiError?
}

struct LoginData: Codable {
    let token: String?
    let user: User?
}

struct ApiError: Codable {
    let code: String
    let message: String
}
