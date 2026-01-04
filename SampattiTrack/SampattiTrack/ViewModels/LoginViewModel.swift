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
        
        // Sentinel: Prevent Denial of Service (DoS) by limiting input length
        if username.count > 100 {
            errorMessage = "Username must be 100 characters or fewer"
            return
        }

        if password.count > 100 {
            errorMessage = "Password must be 100 characters or fewer"
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
                    // Sentinel: Log actual error for debugging but show generic message to user to avoid leaking sensitive info
                    print("[LoginViewModel] Login failed with error: \(error)")
                    self.errorMessage = "Unable to connect to server. Please check your internet connection or API configuration."
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
