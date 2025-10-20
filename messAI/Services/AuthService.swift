import Foundation
import FirebaseAuth
import FirebaseFirestore

/// Service for handling authentication operations with Firebase
class AuthService {
    
    // MARK: - Properties
    
    private let auth = Auth.auth()
    private let firebaseService: FirebaseService
    
    // MARK: - Initialization
    
    init(firebaseService: FirebaseService = FirebaseService()) {
        self.firebaseService = firebaseService
    }
    
    // MARK: - Authentication Methods
    
    /// Sign up a new user with email and password
    /// - Parameters:
    ///   - email: User's email address
    ///   - password: User's password (min 6 characters)
    ///   - displayName: User's display name
    /// - Returns: Created User object
    /// - Throws: AuthError if signup fails
    func signUp(
        email: String,
        password: String,
        displayName: String
    ) async throws -> User {
        // 1. Create Firebase Auth user
        let authResult = try await auth.createUser(withEmail: email, password: password)
        let userId = authResult.user.uid
        
        // 2. Create User object
        let user = User(
            id: userId,
            email: email,
            displayName: displayName,
            isOnline: true,
            lastSeen: Date(),
            createdAt: Date()
        )
        
        // 3. Create Firestore document
        do {
            try await createUserDocument(user: user)
            return user
        } catch {
            // Cleanup: Delete auth user if Firestore creation fails
            try? await authResult.user.delete()
            throw error
        }
    }
    
    /// Sign in existing user with email and password
    /// - Parameters:
    ///   - email: User's email
    ///   - password: User's password
    /// - Returns: User object from Firestore
    /// - Throws: AuthError if sign in fails
    func signIn(email: String, password: String) async throws -> User {
        // 1. Sign in with Firebase Auth
        let authResult = try await auth.signIn(withEmail: email, password: password)
        let userId = authResult.user.uid
        
        // 2. Fetch user document from Firestore
        let user = try await fetchUserDocument(userId: userId)
        
        // 3. Update online status
        try await updateUserOnlineStatus(userId: userId, isOnline: true)
        
        return user
    }
    
    /// Sign out current user
    /// - Throws: AuthError if sign out fails
    func signOut() async throws {
        guard let userId = currentUserId else { return }
        
        // 1. Update online status in Firestore
        try? await updateUserOnlineStatus(userId: userId, isOnline: false)
        
        // 2. Sign out from Firebase Auth
        try auth.signOut()
    }
    
    /// Send password reset email
    /// - Parameter email: User's email address
    /// - Throws: AuthError if reset fails
    func resetPassword(email: String) async throws {
        try await auth.sendPasswordReset(withEmail: email)
    }
    
    // MARK: - Current User
    
    /// Current authenticated user's ID
    var currentUserId: String? {
        auth.currentUser?.uid
    }
    
    /// Current authenticated user's email
    var currentUserEmail: String? {
        auth.currentUser?.email
    }
    
    // MARK: - Private Helper Methods
    
    /// Create user document in Firestore
    private func createUserDocument(user: User) async throws {
        try await firebaseService.usersCollection
            .document(user.id)
            .setData(user.toDictionary())
    }
    
    /// Fetch user document from Firestore
    private func fetchUserDocument(userId: String) async throws -> User {
        let document = try await firebaseService.usersCollection
            .document(userId)
            .getDocument()
        
        guard let data = document.data(),
              let user = User(from: data) else {
            throw AuthError.userNotFound
        }
        
        return user
    }
    
    /// Update user's online status
    private func updateUserOnlineStatus(userId: String, isOnline: Bool) async throws {
        try await firebaseService.usersCollection
            .document(userId)
            .updateData([
                "isOnline": isOnline,
                "lastSeen": Timestamp(date: Date())
            ])
    }
}

// MARK: - Auth Errors

enum AuthError: LocalizedError {
    case userNotFound
    case invalidCredentials
    case emailAlreadyInUse
    case weakPassword
    case networkError
    case unknown(Error)
    
    var errorDescription: String? {
        switch self {
        case .userNotFound:
            return "User not found. Please sign up first."
        case .invalidCredentials:
            return "Invalid email or password."
        case .emailAlreadyInUse:
            return "This email is already registered."
        case .weakPassword:
            return "Password must be at least 6 characters."
        case .networkError:
            return "Network error. Please check your connection."
        case .unknown(let error):
            return "An error occurred: \(error.localizedDescription)"
        }
    }
}

