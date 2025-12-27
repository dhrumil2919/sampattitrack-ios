import SwiftUI

struct LoginView: View {
    @StateObject private var viewModel = LoginViewModel()
    
    var body: some View {
        NavigationView {
            VStack {
                Text("SampattiTrack")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.top, 40)
                    .padding(.bottom, 20)
                
                List {
                    Section {
                        TextField("Username", text: $viewModel.username)
                            .autocapitalization(.none)
                            .textContentType(.username)
                            .keyboardType(.emailAddress)
                            .submitLabel(.next)
                        
                        SecureField("Password", text: $viewModel.password)
                            .textContentType(.password)
                            .submitLabel(.go)
                            .onSubmit { viewModel.login() }
                    }
                }
                .listStyle(InsetGroupedListStyle())
                .frame(maxHeight: 150) // Restrict height so it doesn't take up the whole screen if we want buttons below
                .scrollDisabled(true)
                
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding(.top, 10)
                }
                
                Button(action: viewModel.login) {
                    if viewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .accessibilityLabel("Logging in...")
                    } else {
                        Text("Login")
                            .fontWeight(.bold)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.top, 20)
                .disabled(viewModel.isLoading)
                .opacity(viewModel.isLoading ? 0.7 : 1.0)
                
                Spacer()
            }
            .navigationBarHidden(true)
            .background(Color(UIColor.systemGroupedBackground)) // Match List background if desired, or keep white

        }
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
    }
}
