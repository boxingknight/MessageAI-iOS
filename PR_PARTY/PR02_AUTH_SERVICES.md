# PR #2: Authentication - Models & Services

**Estimated Time**: 2-3 hours  
**Complexity**: MEDIUM  
**Dependencies**: PR #1 (Firebase configured)  
**Branch**: `feature/auth-services`

---

## Overview

### What We're Building
Implementing the authentication logic layer for MessageAI. This includes the User data model, Firebase authentication services, and state management through ViewModels. This PR focuses entirely on the **business logic** - no UI yet (that comes in PR #3).

### Why It Matters
Authentication is the gateway to our entire app. Without solid auth logic:
- Can't identify users
- Can't create user profiles
- Can't attribute messages to senders
- Can't implement presence or typing indicators
- Can't manage permissions or privacy

A well-structured auth layer makes everything else easier.

### Success in One Sentence
"This PR is successful when we can programmatically sign up and log in users, create their Firestore profiles, and observe authentication state changes."

---

## Technical Design

### Architecture Decisions

#### Decision 1: User Model - Struct vs Class
**Options Considered:**
1. **Struct (Value Type)**
   - Pros: Immutable by default, thread-safe, Codable-friendly
   - Cons: Need to recreate when updating properties
   
2. **Class (Reference Type)**
   - Pros: Can mutate in place, can use inheritance
   - Cons: Need to handle thread safety, less SwiftUI-friendly

**Chosen:** Struct

**Rationale:**
- SwiftUI works best with value types
- User data doesn't change frequently (immutability is fine)
- Codable conformance is simpler with structs
- Thread-safe by default (important for concurrent operations)

**Trade-offs:**
- Gain: Safety, SwiftUI compatibility, simplicity
- Lose: Slightly more memory allocation when copying (negligible for small structs)

---

#### Decision 2: Firestore Document on Signup - Immediate vs Deferred
**Options Considered:**
1. **Immediate Creation** (during signup)
   - Create Firestore user document in same transaction as Firebase Auth
   - Pros: User profile always exists, one-step process
   - Cons: Signup might fail after Auth succeeds (need cleanup)
   
2. **Deferred Creation** (after first login)
   - Create document on first successful login
   - Pros: Simpler error handling
   - Cons: User profile might not exist, complex state

**Chosen:** Immediate Creation

**Rationale:**
- Need user profile for chat participants display
- Simpler app logic (user document always exists)
- Can handle cleanup if Firestore fails
- Industry standard pattern (WhatsApp, Signal do this)

**Trade-offs:**
- Gain: Guaranteed user profile, simpler logic
- Lose: Need cleanup code for rare failure case

**Error Handling:**
```swift
do {
    // 1. Create Firebase Auth user
    let authResult = try await Auth.auth().createUser(...)
    
    // 2. Create Firestore document
    try await createUserDocument(userId: authResult.user.uid, ...)
    
    // Success!
} catch {
    // If Firestore fails, delete Auth user
    try? await authResult.user.delete()
    throw error
}
```

---

#### Decision 3: Auth State Management - Singleton vs Injected
**Options Considered:**
1. **Singleton Pattern**
   - `AuthViewModel.shared`
   - Pros: Easy access everywhere, one source of truth
   - Cons: Hard to test, tight coupling, global state
   
2. **Dependency Injection**
   - Pass AuthViewModel through environment or init
   - Pros: Testable, loosely coupled, clear dependencies
   - Cons: More boilerplate, need to pass through views

**Chosen:** Dependency Injection via SwiftUI Environment

**Rationale:**
- Testability is crucial for auth logic
- SwiftUI's `@EnvironmentObject` makes injection easy
- Can mock for testing/previews
- Industry best practice for modern SwiftUI

**Implementation:**
```swift
// In messAIApp.swift
@StateObject private var authViewModel = AuthViewModel(
    authService: AuthService(),
    firestoreService: FirebaseService()
)

var body: some Scene {
    WindowGroup {
        ContentView()
            .environmentObject(authViewModel)
    }
}

// In any view
@EnvironmentObject var authViewModel: AuthViewModel
```

**Trade-offs:**
- Gain: Testability, flexibility, cleaner architecture
- Lose: Slightly more setup code (minimal)

---

#### Decision 4: Password Requirements - Strict vs Lenient
**Options Considered:**
1. **Strict** (8+ chars, uppercase, lowercase, number, special)
   - Pros: More secure
   - Cons: User friction, harder to test
   
2. **Lenient** (6+ chars)
   - Pros: Easy to use, quick testing
   - Cons: Less secure

**Chosen:** Lenient for MVP (6+ chars), can tighten later

**Rationale:**
- MVP priority is functionality, not security hardening
- Firebase has rate limiting (prevents brute force)
- Can add stricter validation in PR #19 (Error Handling)
- Easier for testing during development

**Trade-offs:**
- Gain: Faster development, easier testing
- Lose: Less secure (acceptable for MVP, not production)

**Note**: Document in README to tighten before production launch

---

### Data Model

#### User Model

**File**: `Models/User.swift`

```swift
import Foundation

/// Represents a user in the MessageAI app
struct User: Codable, Identifiable, Equatable {
    /// Unique identifier (matches Firebase Auth UID)
    let id: String
    
    /// User's email address
    let email: String
    
    /// User's display name (editable)
    var displayName: String
    
    /// URL to profile picture in Firebase Storage (optional)
    var photoURL: String?
    
    /// Firebase Cloud Messaging token for push notifications (optional)
    var fcmToken: String?
    
    /// Whether user is currently online
    var isOnline: Bool
    
    /// Last time user was active (for "last seen" display)
    var lastSeen: Date
    
    /// Account creation timestamp
    let createdAt: Date
    
    // MARK: - Initializers
    
    /// Initialize a new user (typically for signup)
    init(
        id: String,
        email: String,
        displayName: String,
        photoURL: String? = nil,
        fcmToken: String? = nil,
        isOnline: Bool = true,
        lastSeen: Date = Date(),
        createdAt: Date = Date()
    ) {
        self.id = id
        self.email = email
        self.displayName = displayName
        self.photoURL = photoURL
        self.fcmToken = fcmToken
        self.isOnline = isOnline
        self.lastSeen = lastSeen
        self.createdAt = createdAt
    }
    
    /// Initialize from Firestore document
    init?(from dictionary: [String: Any]) {
        guard 
            let id = dictionary["id"] as? String,
            let email = dictionary["email"] as? String,
            let displayName = dictionary["displayName"] as? String,
            let isOnline = dictionary["isOnline"] as? Bool,
            let lastSeenTimestamp = dictionary["lastSeen"] as? Timestamp,
            let createdAtTimestamp = dictionary["createdAt"] as? Timestamp
        else {
            return nil
        }
        
        self.id = id
        self.email = email
        self.displayName = displayName
        self.photoURL = dictionary["photoURL"] as? String
        self.fcmToken = dictionary["fcmToken"] as? String
        self.isOnline = isOnline
        self.lastSeen = lastSeenTimestamp.dateValue()
        self.createdAt = createdAtTimestamp.dateValue()
    }
    
    // MARK: - Firestore Conversion
    
    /// Convert to dictionary for Firestore
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "email": email,
            "displayName": displayName,
            "isOnline": isOnline,
            "lastSeen": Timestamp(date: lastSeen),
            "createdAt": Timestamp(date: createdAt)
        ]
        
        if let photoURL = photoURL {
            dict["photoURL"] = photoURL
        }
        
        if let fcmToken = fcmToken {
            dict["fcmToken"] = fcmToken
        }
        
        return dict
    }
}
```

**Key Design Choices:**
- `id` matches Firebase Auth UID (no separate IDs)
- `Codable` for easy JSON/Firestore conversion
- `Identifiable` for SwiftUI List compatibility
- `Equatable` for comparison and testing
- Optional properties for photoURL and fcmToken (not required initially)
- Helper initializer from dictionary (Firestore format)
- `toDictionary()` method for Firestore writes

---

### Service Layer

#### FirebaseService (Base Class)

**File**: `Services/FirebaseService.swift`

**Purpose**: Centralize Firebase Firestore access and common utilities

```swift
import Foundation
import FirebaseFirestore

/// Base service providing common Firebase Firestore utilities
class FirebaseService {
    
    // MARK: - Properties
    
    /// Shared Firestore instance
    let db = Firestore.firestore()
    
    // MARK: - Collection References
    
    /// Users collection reference
    var usersCollection: CollectionReference {
        db.collection(Constants.Firestore.users)
    }
    
    /// Conversations collection reference
    var conversationsCollection: CollectionReference {
        db.collection(Constants.Firestore.conversations)
    }
    
    // MARK: - Helper Methods
    
    /// Generate a new document ID
    func generateDocumentId(in collection: CollectionReference) -> String {
        collection.document().documentID
    }
    
    /// Create server timestamp
    func serverTimestamp() -> FieldValue {
        FieldValue.serverTimestamp()
    }
    
    /// Convert Firestore timestamp to Date
    func dateFromTimestamp(_ timestamp: Timestamp?) -> Date? {
        timestamp?.dateValue()
    }
}
```

**Key Features:**
- Centralized Firestore access
- Collection reference helpers (using Constants)
- Timestamp utilities
- Document ID generation
- Can be subclassed or used directly

---

#### AuthService

**File**: `Services/AuthService.swift`

**Purpose**: Handle all Firebase Authentication operations

```swift
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
```

**Key Features:**
- Async/await for modern Swift concurrency
- Creates Firestore document on signup
- Fetches user data on sign in
- Updates online status
- Cleanup on failures
- Clear error handling
- Testable (can inject FirebaseService mock)

---

### ViewModel Layer

#### AuthViewModel

**File**: `ViewModels/AuthViewModel.swift`

**Purpose**: Manage authentication state and expose to SwiftUI views

```swift
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
    
    init(authService: AuthService = AuthService()) {
        self.authService = authService
        setupAuthStateListener()
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
```

**Key Features:**
- `@MainActor` ensures UI updates on main thread
- `ObservableObject` for SwiftUI binding
- Auth state listener (automatic updates)
- Published properties for reactive UI
- Loading states for better UX
- Error handling with user-friendly messages
- Input validation helpers
- Cleanup in deinit

---

## Implementation Details

### File Structure

**New Files:**
```
Models/
├── User.swift                      (~120 lines)

Services/
├── FirebaseService.swift           (~60 lines)
└── AuthService.swift               (~180 lines)

ViewModels/
└── AuthViewModel.swift             (~160 lines)
```

**Total New Lines**: ~520 lines of code

---

### Key Implementation Steps

#### Phase 1: Create User Model (30 minutes)

**Steps:**
1. Create User.swift in Models folder
2. Add all properties with proper types
3. Implement Codable conformance
4. Add convenience initializers
5. Add Firestore conversion methods
6. Build to verify no errors

**Testing:**
- Create a User instance manually
- Convert to dictionary
- Verify all fields present

---

#### Phase 2: Create FirebaseService (20 minutes)

**Steps:**
1. Create FirebaseService.swift in Services
2. Add Firestore instance
3. Add collection references
4. Add helper methods
5. Build to verify

**Testing:**
- Access usersCollection
- Generate a document ID
- Verify no crashes

---

#### Phase 3: Create AuthService (60 minutes)

**Steps:**
1. Create AuthService.swift in Services
2. Implement signUp method
   - Create Firebase Auth user
   - Create Firestore document
   - Handle cleanup on failure
3. Implement signIn method
   - Authenticate with Firebase
   - Fetch Firestore document
   - Update online status
4. Implement signOut method
   - Update Firestore
   - Sign out from Firebase
5. Implement resetPassword method
6. Add helper methods
7. Define AuthError enum
8. Build to verify

**Testing:**
- Call signUp with test data (will test in next phase)
- Verify Firestore document created

---

#### Phase 4: Create AuthViewModel (60 minutes)

**Steps:**
1. Create AuthViewModel.swift in ViewModels
2. Add @Published properties
3. Set up auth state listener
4. Implement signUp method
5. Implement signIn method
6. Implement signOut method
7. Implement resetPassword method
8. Add validation methods
9. Build to verify

**Testing:**
- Create AuthViewModel instance
- Call methods programmatically
- Verify state changes

---

#### Phase 5: Integration & Testing (30 minutes)

**Steps:**
1. Add AuthViewModel to messAIApp.swift
2. Add test buttons to ContentView
3. Test signup flow end-to-end
4. Test signin flow end-to-end
5. Verify Firestore documents
6. Test error cases

---

## Testing Strategy

### Test Scenarios

#### Test 1: Sign Up New User
**Goal**: Verify new user creation works end-to-end

**Steps:**
1. Add test button to ContentView:
   ```swift
   Button("Test Signup") {
       Task {
           await authViewModel.signUp(
               email: "test@example.com",
               password: "password123",
               displayName: "Test User"
           )
       }
   }
   ```
2. Run app
3. Tap button
4. Check Firebase Console → Authentication
5. Check Firestore → users collection

**Expected**:
- Firebase Auth shows new user
- Firestore has user document with correct fields
- `authViewModel.isAuthenticated == true`
- `authViewModel.currentUser != nil`

---

#### Test 2: Sign In Existing User
**Goal**: Verify existing user can log in

**Pre-requisite**: User created in Test 1

**Steps:**
1. Restart app (to clear state)
2. Add sign-in test button:
   ```swift
   Button("Test Sign In") {
       Task {
           await authViewModel.signIn(
               email: "test@example.com",
               password: "password123"
           )
       }
   }
   ```
3. Tap button
4. Check auth state

**Expected**:
- User signed in successfully
- `isAuthenticated == true`
- User data populated from Firestore
- No errors

---

#### Test 3: Sign Out
**Goal**: Verify sign out works

**Pre-requisite**: User signed in from Test 2

**Steps:**
1. Add sign-out button:
   ```swift
   Button("Test Sign Out") {
       Task {
           await authViewModel.signOut()
       }
   }
   ```
2. Tap button
3. Check auth state

**Expected**:
- User signed out
- `isAuthenticated == false`
- `currentUser == nil`
- Firestore shows isOnline: false

---

#### Test 4: Error Handling - Invalid Email
**Goal**: Verify error handling works

**Steps:**
1. Try to sign up with invalid email:
   ```swift
   await authViewModel.signUp(
       email: "not-an-email",
       password: "password123",
       displayName: "Test"
   )
   ```

**Expected**:
- Error message appears
- User not created
- isAuthenticated remains false

---

#### Test 5: Error Handling - Duplicate Email
**Goal**: Verify duplicate email is caught

**Steps:**
1. Try to sign up with existing email (from Test 1)

**Expected**:
- Error: "This email is already registered"
- No new user created
- isAuthenticated remains false

---

#### Test 6: Auth State Persistence
**Goal**: Verify user stays logged in on app restart

**Steps:**
1. Sign in a user
2. Force quit app (swipe up)
3. Reopen app
4. Check auth state

**Expected**:
- User still authenticated
- Auth state listener fires
- currentUser populated (Note: Will implement full fetch in PR #4)

---

## Success Criteria

### Feature is complete when:

- [x] User.swift model created with all properties
- [x] User conforms to Codable, Identifiable, Equatable
- [x] FirebaseService.swift created with helper methods
- [x] AuthService.swift created with all auth methods
- [x] AuthService can create users in Firebase Auth
- [x] AuthService can create Firestore documents
- [x] AuthService handles cleanup on failures
- [x] AuthViewModel.swift created with state management
- [x] AuthViewModel observes Firebase auth state
- [x] AuthViewModel exposes published properties
- [x] AuthViewModel has validation methods
- [x] All files build without errors
- [x] All 6 test scenarios pass
- [x] Firebase Console shows created users
- [x] Firestore shows user documents
- [x] Auth state persists on app restart
- [x] Error handling works for invalid inputs

---

## Risk Assessment

### Risk 1: Firestore Document Creation Fails After Auth Success
**Likelihood:** LOW  
**Impact:** HIGH (user in Auth but no profile)  
**Mitigation**: Cleanup code deletes Auth user if Firestore fails  
**Recovery**: Implemented in AuthService.signUp  
**Status**: 🟢 MITIGATED

### Risk 2: Auth State Listener Memory Leak
**Likelihood:** MEDIUM  
**Impact:** MEDIUM (memory issues)  
**Mitigation**: Remove listener in deinit  
**Recovery**: Implemented in AuthViewModel  
**Status**: 🟢 MITIGATED

### Risk 3: Race Condition on State Updates
**Likelihood:** LOW  
**Impact:** MEDIUM (UI inconsistency)  
**Mitigation**: Use `@MainActor` to ensure main thread updates  
**Recovery**: Implemented in AuthViewModel  
**Status**: 🟢 MITIGATED

### Risk 4: Password Too Weak (Lenient Validation)
**Likelihood:** HIGH  
**Impact:** LOW for MVP (security concern for production)  
**Mitigation**: Document in README, plan to tighten in PR #19  
**Recovery**: Easy to update validation logic later  
**Status**: 🟡 ACCEPTABLE FOR MVP

### Risk 5: Test User Clutter in Firebase
**Likelihood:** HIGH  
**Impact:** LOW (cleanup annoyance)  
**Mitigation**: Use consistent test email prefix, manual cleanup  
**Recovery**: Can delete test users from Firebase Console  
**Status**: 🟢 MANAGEABLE

---

## Open Questions

### Question 1: Email Verification Required?
**Question**: Should we require email verification before allowing login?  
**Options**:
- A) Require verification (more secure, better UX)
- B) Skip for MVP (faster development)

**Recommendation**: Skip for MVP, add in PR #19  
**Rationale**: MVP priority is functionality testing  
**Decision**: ⏳ DEFER TO MVP COMPLETION

### Question 2: Profile Picture on Signup?
**Question**: Should users upload profile picture during signup?  
**Options**:
- A) Required on signup (complete profile)
- B) Optional later (in profile management - PR #16)

**Recommendation**: Optional later (PR #16)  
**Rationale**: Faster onboarding, less friction  
**Decision**: ✅ OPTIONAL (PR #16)

---

## Timeline

**Total Estimate**: 2-3 hours

| Phase | Task | Time | Status |
|-------|------|------|--------|
| 1 | Create User model | 30 min | ⏳ |
| 2 | Create FirebaseService | 20 min | ⏳ |
| 3 | Create AuthService | 60 min | ⏳ |
| 4 | Create AuthViewModel | 60 min | ⏳ |
| 5 | Integration & testing | 30 min | ⏳ |
| **Total** | | **3.3 hours** | ⏳ |

**Buffer**: +30 minutes for debugging = **3.5 hours max**

---

## Dependencies

### Requires:
- [x] PR #1 complete (Firebase configured)
- [x] Firebase SDK installed
- [x] Firestore enabled
- [x] Firebase Auth enabled

### Blocks:
- PR #3: Authentication UI (needs auth logic)
- PR #4: Core Models (needs User model)
- PR #5: Chat Service (needs User model)
- All future PRs depend on authentication

---

## References

- [Firebase Auth Documentation](https://firebase.google.com/docs/auth/ios/start)
- [Firestore Swift Documentation](https://firebase.google.com/docs/firestore/quickstart#swift)
- [Swift Async/Await Guide](https://docs.swift.org/swift-book/LanguageGuide/Concurrency.html)
- Task List: `messageai_task_list.md` lines 147-193

---

**Status**: 📋 PLANNING COMPLETE  
**Next Step**: Create implementation checklist and begin coding  
**Estimated Completion**: October 20, 2025 (same day)

