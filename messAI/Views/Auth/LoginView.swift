import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Binding var navigationPath: NavigationPath
    
    @State private var email = ""
    @State private var password = ""
    @State private var isPasswordVisible = false
    @FocusState private var focusedField: Field?
    @State private var emailTouched = false
    @State private var passwordTouched = false
    
    enum Field: Hashable {
        case email, password
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Title
                Text("Welcome Back")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .padding(.top, 20)
                
                // Email field
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        TextField("Email", text: $email)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.emailAddress)
                            .autocorrectionDisabled()
                            .focused($focusedField, equals: .email)
                        
                        if emailTouched && authViewModel.isValidEmail(email) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    
                    if emailTouched && !email.isEmpty && !authViewModel.isValidEmail(email) {
                        Text("Please enter a valid email")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                
                // Password field
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Group {
                            if isPasswordVisible {
                                TextField("Password", text: $password)
                            } else {
                                SecureField("Password", text: $password)
                            }
                        }
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .password)
                        
                        Button {
                            isPasswordVisible.toggle()
                        } label: {
                            Image(systemName: isPasswordVisible ? "eye.slash.fill" : "eye.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    
                    if passwordTouched && !password.isEmpty && !authViewModel.isValidPassword(password) {
                        Text("Password must be at least 6 characters")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                
                // Forgot password
                HStack {
                    Spacer()
                    Button("Forgot Password?") {
                        Task {
                            await authViewModel.resetPassword(email: email)
                        }
                    }
                    .font(.subheadline)
                    .foregroundColor(.blue)
                    .disabled(email.isEmpty)
                }
                
                // Sign in button
                Button {
                    emailTouched = true
                    passwordTouched = true
                    
                    if isFormValid {
                        Task {
                            await authViewModel.signIn(
                                email: email,
                                password: password
                            )
                        }
                    }
                } label: {
                    HStack {
                        if authViewModel.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        }
                        Text("Sign In")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                }
                .background(isFormValid ? Color.blue : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(12)
                .disabled(authViewModel.isLoading)
                
                // Error message
                if let error = authViewModel.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                }
                
                // Sign up link
                HStack {
                    Text("Don't have an account?")
                        .foregroundColor(.secondary)
                    Button("Sign Up") {
                        navigationPath.append(AuthRoute.signup)
                    }
                    .fontWeight(.semibold)
                }
                .font(.subheadline)
                .padding(.top, 8)
            }
            .padding(20)
        }
        .navigationTitle("Sign In")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    focusedField = nil
                }
            }
        }
        .onChange(of: focusedField) { _, newValue in
            if newValue != .email && !email.isEmpty {
                emailTouched = true
            }
            if newValue != .password && !password.isEmpty {
                passwordTouched = true
            }
        }
        .onTapGesture {
            focusedField = nil
        }
    }
    
    private var isFormValid: Bool {
        authViewModel.isValidEmail(email) &&
        authViewModel.isValidPassword(password)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        LoginView(navigationPath: .constant(NavigationPath()))
            .environmentObject(AuthViewModel())
    }
}

