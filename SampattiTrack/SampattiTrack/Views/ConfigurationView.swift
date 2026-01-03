import SwiftUI

struct ConfigurationView: View {
    @State private var apiURL: String = ""
    @State private var financialYearStartMonth: Int = 4
    @State private var validationError: String? = nil
    @State private var showInsecureWarning: Bool = false
    @Binding var isConfigured: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Setup Configuration")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Please enter the URL of your SampattiTrack backend server.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            VStack(alignment: .leading, spacing: 5) {
                TextField("e.g. https://api.sampattitrack.com/v1", text: $apiURL)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .onChange(of: apiURL) { _ in
                        validationError = nil
                        showInsecureWarning = false
                    }

                if let error = validationError {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                }

                if showInsecureWarning {
                    Text("⚠️ Using HTTP sends data in cleartext. Use HTTPS for production.")
                        .foregroundColor(.orange)
                        .font(.caption)
                }

                Picker("Financial Year Start Month", selection: $financialYearStartMonth) {
                    ForEach(1...12, id: \.self) { month in
                        Text(Calendar.current.monthSymbols[month - 1]).tag(month)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .padding(.vertical, 5)
            }
            .padding()
            
            Button(action: validateAndSave) {
                Text(showInsecureWarning ? "Confirm & Save" : "Save Configuration")
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(showInsecureWarning ? Color.orange : Color.blue)
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

            let savedMonth = UserDefaults.standard.integer(forKey: "financial_year_start_month")
            if savedMonth > 0 {
                financialYearStartMonth = savedMonth
            }

            if apiURL.isEmpty {
                // Default suggestion for simulator/local dev
                apiURL = "http://localhost:8080/api/v1"
            }
        }
    }
    
    private func validateAndSave() {
        var cleanURL = apiURL.trimmingCharacters(in: .whitespacesAndNewlines)

        // Basic URL validation
        guard let url = URL(string: cleanURL), let scheme = url.scheme, let host = url.host else {
            validationError = "Please enter a valid URL (e.g. https://example.com)"
            return
        }

        // Security Check: HTTP vs HTTPS
        if scheme.lowercased() == "http" {
            // Allow localhost/private IPs without warning, but warn for public HTTP
            let isLocal = host == "localhost" || host == "127.0.0.1" || host.hasPrefix("192.168.") || host.hasPrefix("10.")

            if !isLocal && !showInsecureWarning {
                showInsecureWarning = true
                return // Stop here, require second click to confirm
            }
        }

        if cleanURL.hasSuffix("/") {
            cleanURL = String(cleanURL.dropLast())
        }
        
        APIClient.shared.baseURL = cleanURL
        UserDefaults.standard.set(financialYearStartMonth, forKey: "financial_year_start_month")
        isConfigured = true
    }
}
