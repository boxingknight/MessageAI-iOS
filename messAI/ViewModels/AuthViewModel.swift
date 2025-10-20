import Foundation
import Combine
import FirebaseAuth

/// ViewModel managing authentication state and operations
@MainActor
class AuthViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Currently authenticated user
    @Published var currentUser: User?
    
    /// Whether user is authenticated
    @Published var isAuthenticated: Bool = false
    
    /// Error message to display to user
    @Published var errorMessage: String?
    
    /// Loading state for async operations
    @Published var isLoading: Bool = false
    
    // MARK: - Private Properties
    
    private let authService: AuthService
    private var authStateHandle: AuthStateDidChangeListenerHandle?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    nonisolated init(authService: AuthService = AuthService()) {
        self.authService = authService
        Task { @MainActor in
            self.setupAuthStateListener()
        }
    }
    
    deinit {
        if let handle = authStateHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }
    
    // MARK: - Auth State Listener
    
    /// Set up listener for Firebase auth state changes
    private func setupAuthStateListener() {
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                if let user = user {
                    // User is signed in - fetch their profile
                    await self?.fetchCurrentUser()
                } else {
                    // User is signed out
                    self?.currentUser = nil
                    self?.isAuthenticated = false
                }
            }
        }
    }
    
    // MARK: - Public Methods
    
    /// Sign up a new user
    func signUp(email: String, password: String, displayName: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let user = try await authService.signUp(
                email: email,
                password: password,
                displayName: displayName
            )
            
            currentUser = user
            isAuthenticated = true
            
        } catch let error as AuthError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = "An unexpected error occurred."
        }
        
        isLoading = false
    }
    
    /// Sign in existing user
    func signIn(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let user = try await authService.signIn(email: email, password: password)
            
            currentUser = user
            isAuthenticated = true
            
        } catch let error as AuthError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = "An unexpected error occurred."
        }
        
        isLoading = false
    }
    
    /// Sign out current user
    func signOut() async {
        isLoading = true
        errorMessage = nil
        
        do {
            try await authService.signOut()
            
            currentUser = nil
            isAuthenticated = false
            
        } catch {
            errorMessage = "Failed to sign out."
        }
        
        isLoading = false
    }
    
    /// Send password reset email
    func resetPassword(email: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            try await authService.resetPassword(email: email)
            errorMessage = "Password reset email sent!"
            
        } catch {
            errorMessage = "Failed to send reset email."
        }
        
        isLoading = false
    }
    
    // MARK: - Private Methods
    
    /// Fetch current user's profile from Firestore
    private func fetchCurrentUser() async {
        guard let userId = authService.currentUserId else {
            currentUser = nil
            isAuthenticated = false
            return
        }
        
        // Will implement full fetch in PR #4 when we have ChatService
        // For now, just mark as authenticated
        isAuthenticated = true
    }
    
    // MARK: - Validation
    
    /// Validate email format
    func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format:"SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    /// Validate password strength
    func isValidPassword(_ password: String) -> Bool {
        password.count >= 6
    }
    
    /// Validate display name
    func isValidDisplayName(_ name: String) -> Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && name.count >= 2
    }
}

