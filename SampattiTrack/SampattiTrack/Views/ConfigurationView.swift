import SwiftUI

struct ConfigurationView: View {
    @State private var apiURL: String = ""
    @Binding var isConfigured: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Setup API Endpoint")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Please enter the URL of your SampattiTrack backend server.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            TextField("e.g. http://192.168.1.100:8080/api/v1", text: $apiURL)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .padding()
            
            Button(action: saveConfiguration) {
                Text("Save Configuration")
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding(.horizontal)
            .disabled(apiURL.isEmpty)
        }
        .padding()
        .onAppear {
            if let saved = UserDefaults.standard.string(forKey: "api_base_url") {
                apiURL = saved
            }
            if apiURL.isEmpty {
                // Default suggestion for simulator/local dev
                apiURL = "http://localhost:8080/api/v1"
            }
        }
    }
    
    private func saveConfiguration() {
        // Basic validation: ensure it looks like a URL
        var cleanURL = apiURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanURL.hasSuffix("/") {
            cleanURL = String(cleanURL.dropLast())
        }
        
        APIClient.shared.baseURL = cleanURL
        isConfigured = true
    }
}
