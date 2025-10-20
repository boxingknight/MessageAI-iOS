import SwiftUI

struct SignUpView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Binding var navigationPath: NavigationPath
    
    @State private var displayName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isPasswordVisible = false
    @State private var isConfirmPasswordVisible = false
    @FocusState private var focusedField: Field?
    @State private var displayNameTouched = false
    @State private var emailTouched = false
    @State private var passwordTouched = false
    @State private var confirmPasswordTouched = false
    
    enum Field: Hashable {
        case displayName, email, password, confirmPassword
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Title
                Text("Create Account")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .padding(.top, 20)
                
                // Display name field
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        TextField("Display Name", text: $displayName)
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()
                            .focused($focusedField, equals: .displayName)
                        
                        if displayNameTouched && authViewModel.isValidDisplayName(displayName) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    
                    if displayNameTouched && !displayName.isEmpty && !authViewModel.isValidDisplayName(displayName) {
                        Text("Name must be at least 2 characters")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                
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
                
                // Confirm password field
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Group {
                            if isConfirmPasswordVisible {
                                TextField("Confirm Password", text: $confirmPassword)
                            } else {
                                SecureField("Confirm Password", text: $confirmPassword)
                            }
                        }
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .confirmPassword)
                        
                        Button {
                            isConfirmPasswordVisible.toggle()
                        } label: {
                            Image(systemName: isConfirmPasswordVisible ? "eye.slash.fill" : "eye.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    
                    if confirmPasswordTouched && !confirmPassword.isEmpty && password != confirmPassword {
                        Text("Passwords do not match")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                
                // Sign up button
                Button {
                    displayNameTouched = true
                    emailTouched = true
                    passwordTouched = true
                    confirmPasswordTouched = true
                    
                    if isFormValid {
                        Task {
                            await authViewModel.signUp(
                                email: email,
                                password: password,
                                displayName: displayName
                            )
                        }
                    }
                } label: {
                    HStack {
                        if authViewModel.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        }
                        Text("Sign Up")
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
                
                // Login link
                HStack {
                    Text("Already have an account?")
                        .foregroundColor(.secondary)
                    Button("Sign In") {
                        navigationPath.removeLast()
                    }
                    .fontWeight(.semibold)
                }
                .font(.subheadline)
                .padding(.top, 8)
            }
            .padding(20)
        }
        .navigationTitle("Sign Up")
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
            if newValue != .displayName && !displayName.isEmpty {
                displayNameTouched = true
            }
            if newValue != .email && !email.isEmpty {
                emailTouched = true
            }
            if newValue != .password && !password.isEmpty {
                passwordTouched = true
            }
            if newValue != .confirmPassword && !confirmPassword.isEmpty {
                confirmPasswordTouched = true
            }
        }
        .onTapGesture {
            focusedField = nil
        }
    }
    
    private var isFormValid: Bool {
        authViewModel.isValidDisplayName(displayName) &&
        authViewModel.isValidEmail(email) &&
        authViewModel.isValidPassword(password) &&
        password == confirmPassword
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        SignUpView(navigationPath: .constant(NavigationPath()))
            .environmentObject(AuthViewModel())
    }
}

