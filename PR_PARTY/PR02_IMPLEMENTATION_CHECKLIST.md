# PR #2: Implementation Checklist - Authentication Services

**Use this as your daily todo list.** Check off items as you complete them.

**Branch**: `feature/auth-services`  
**Estimated Time**: 2-3 hours  
**Status**: ⏳ NOT STARTED

---

## Pre-Implementation Setup (10 minutes)

- [ ] **Read Planning Documents** (~45 min total)
  - [ ] Read `PR02_AUTH_SERVICES.md` (main spec)
  - [ ] Read `PR02_README.md` (quick start)
  - [ ] Read `PR02_TESTING_GUIDE.md` (test strategy)
  - [ ] Note any questions

- [ ] **Verify Prerequisites**
  - [ ] PR #1 complete (Firebase configured) ✅
  - [ ] Firebase SDK installed ✅
  - [ ] Firebase Authentication enabled in console ✅
  - [ ] Firestore database created ✅
  - [ ] `GoogleService-Info.plist` in project ✅

- [ ] **Create Git Branch**
  ```bash
  git checkout main
  git pull origin main
  git checkout -b feature/auth-services
  ```

- [ ] **Open Xcode Project**
  - [ ] Open `messAI.xcodeproj`
  - [ ] Verify project builds (`⌘ + B`)
  - [ ] Check simulator works (`⌘ + R`)

- [ ] **Review Folder Structure in Xcode**
  - [ ] Models/ folder exists
  - [ ] Services/ folder exists
  - [ ] ViewModels/ folder exists
  - [ ] Utilities/ folder exists (for Constants)

**Checkpoint**: ✅ Environment ready, all prerequisites met

---

## Phase 1: Create User Model (30 minutes)

### 1.1: Create User.swift File (5 minutes)

- [ ] **Create File**
  - In Xcode, right-click on `Models/` folder
  - New File → Swift File
  - Name: `User.swift`
  - Target: messAI ✓
  - Save

- [ ] **Add Import Statements**
  ```swift
  import Foundation
  import FirebaseFirestore
  ```

**Checkpoint**: User.swift created and added to project ✓

---

### 1.2: Define User Struct (10 minutes)

- [ ] **Add Struct Declaration**
  ```swift
  /// Represents a user in the MessageAI app
  struct User: Codable, Identifiable, Equatable {
  ```

- [ ] **Add Properties**
  ```swift
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
  ```

- [ ] **Verify Build** (`⌘ + B`)
  - [ ] No errors
  - [ ] No warnings

**Checkpoint**: User struct properties defined ✓

---

### 1.3: Add Initializers (10 minutes)

- [ ] **Add Main Initializer**
  ```swift
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
  ```

- [ ] **Add Firestore Dictionary Initializer**
  ```swift
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
  ```

- [ ] **Verify Build** (`⌘ + B`)

**Checkpoint**: User initializers complete ✓

---

### 1.4: Add Firestore Conversion Method (5 minutes)

- [ ] **Add toDictionary() Method**
  ```swift
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
  ```

- [ ] **Verify Build** (`⌘ + B`)
  - [ ] No errors

- [ ] **Test User Model Locally**
  - [ ] Add temporary test code to ContentView:
    ```swift
    let testUser = User(
        id: "test123",
        email: "test@example.com",
        displayName: "Test User"
    )
    print(testUser.toDictionary())
    ```
  - [ ] Run app (`⌘ + R`)
  - [ ] Check console for output
  - [ ] Remove test code

**Checkpoint**: ✅ User model complete and tested

**Commit**: 
```bash
git add messAI/Models/User.swift
git commit -m "feat(models): create User model with Firestore conversion"
```

---

## Phase 2: Create FirebaseService (20 minutes)

### 2.1: Create FirebaseService.swift File (5 minutes)

- [ ] **Create File**
  - Right-click on `Services/` folder
  - New File → Swift File
  - Name: `FirebaseService.swift`
  - Target: messAI ✓

- [ ] **Add Imports**
  ```swift
  import Foundation
  import FirebaseFirestore
  ```

**Checkpoint**: FirebaseService.swift created ✓

---

### 2.2: Define Base Service Class (15 minutes)

- [ ] **Add Class Declaration**
  ```swift
  /// Base service providing common Firebase Firestore utilities
  class FirebaseService {
      
      // MARK: - Properties
      
      /// Shared Firestore instance
      let db = Firestore.firestore()
  }
  ```

- [ ] **Add Collection References**
  ```swift
  // MARK: - Collection References
  
  /// Users collection reference
  var usersCollection: CollectionReference {
      db.collection("users")
  }
  
  /// Conversations collection reference
  var conversationsCollection: CollectionReference {
      db.collection("conversations")
  }
  ```
  
  **Note**: We'll add these strings to Constants in future PR

- [ ] **Add Helper Methods**
  ```swift
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
  ```

- [ ] **Verify Build** (`⌘ + B`)
  - [ ] No errors

**Checkpoint**: ✅ FirebaseService complete

**Commit**:
```bash
git add messAI/Services/FirebaseService.swift
git commit -m "feat(services): create FirebaseService base class"
```

---

## Phase 3: Create AuthService (60 minutes)

### 3.1: Create AuthService.swift File (5 minutes)

- [ ] **Create File**
  - Right-click on `Services/` folder
  - New File → Swift File
  - Name: `AuthService.swift`
  - Target: messAI ✓

- [ ] **Add Imports**
  ```swift
  import Foundation
  import FirebaseAuth
  import FirebaseFirestore
  ```

**Checkpoint**: AuthService.swift created ✓

---

### 3.2: Define AuthService Class & Properties (10 minutes)

- [ ] **Add Class Declaration**
  ```swift
  /// Service for handling authentication operations with Firebase
  class AuthService {
      
      // MARK: - Properties
      
      private let auth = Auth.auth()
      private let firebaseService: FirebaseService
      
      // MARK: - Initialization
      
      init(firebaseService: FirebaseService = FirebaseService()) {
          self.firebaseService = firebaseService
      }
  }
  ```

- [ ] **Add Current User Properties**
  ```swift
  // MARK: - Current User
  
  /// Current authenticated user's ID
  var currentUserId: String? {
      auth.currentUser?.uid
  }
  
  /// Current authenticated user's email
  var currentUserEmail: String? {
      auth.currentUser?.email
  }
  ```

- [ ] **Verify Build** (`⌘ + B`)

**Checkpoint**: AuthService structure created ✓

---

### 3.3: Implement Sign Up Method (20 minutes)

- [ ] **Add signUp Method Signature**
  ```swift
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
  ```

- [ ] **Implement Step 1: Create Firebase Auth User**
  ```swift
  // 1. Create Firebase Auth user
  let authResult = try await auth.createUser(withEmail: email, password: password)
  let userId = authResult.user.uid
  ```

- [ ] **Implement Step 2: Create User Object**
  ```swift
  // 2. Create User object
  let user = User(
      id: userId,
      email: email,
      displayName: displayName,
      isOnline: true,
      lastSeen: Date(),
      createdAt: Date()
  )
  ```

- [ ] **Implement Step 3: Create Firestore Document with Cleanup**
  ```swift
  // 3. Create Firestore document
  do {
      try await createUserDocument(user: user)
      return user
  } catch {
      // Cleanup: Delete auth user if Firestore creation fails
      try? await authResult.user.delete()
      throw error
  }
  ```

- [ ] **Add Helper Method: createUserDocument**
  ```swift
  // MARK: - Private Helper Methods
  
  /// Create user document in Firestore
  private func createUserDocument(user: User) async throws {
      try await firebaseService.usersCollection
          .document(user.id)
          .setData(user.toDictionary())
  }
  ```

- [ ] **Verify Build** (`⌘ + B`)

**Checkpoint**: signUp method complete ✓

---

### 3.4: Implement Sign In Method (15 minutes)

- [ ] **Add signIn Method**
  ```swift
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
  ```

- [ ] **Add Helper Method: fetchUserDocument**
  ```swift
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
  ```

- [ ] **Add Helper Method: updateUserOnlineStatus**
  ```swift
  /// Update user's online status
  private func updateUserOnlineStatus(userId: String, isOnline: Bool) async throws {
      try await firebaseService.usersCollection
          .document(userId)
          .updateData([
              "isOnline": isOnline,
              "lastSeen": Timestamp(date: Date())
          ])
  }
  ```

- [ ] **Verify Build** (`⌘ + B`)

**Checkpoint**: signIn method complete ✓

---

### 3.5: Implement Sign Out Method (5 minutes)

- [ ] **Add signOut Method**
  ```swift
  /// Sign out current user
  /// - Throws: AuthError if sign out fails
  func signOut() async throws {
      guard let userId = currentUserId else { return }
      
      // 1. Update online status in Firestore
      try? await updateUserOnlineStatus(userId: userId, isOnline: false)
      
      // 2. Sign out from Firebase Auth
      try auth.signOut()
  }
  ```

- [ ] **Verify Build** (`⌘ + B`)

**Checkpoint**: signOut method complete ✓

---

### 3.6: Implement Password Reset Method (5 minutes)

- [ ] **Add resetPassword Method**
  ```swift
  /// Send password reset email
  /// - Parameter email: User's email address
  /// - Throws: AuthError if reset fails
  func resetPassword(email: String) async throws {
      try await auth.sendPasswordReset(withEmail: email)
  }
  ```

- [ ] **Verify Build** (`⌘ + B`)

**Checkpoint**: resetPassword method complete ✓

---

### 3.7: Define AuthError Enum (5 minutes)

- [ ] **Add AuthError Definition** (at bottom of file)
  ```swift
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

- [ ] **Verify Build** (`⌘ + B`)
  - [ ] No errors
  - [ ] No warnings

**Checkpoint**: ✅ AuthService complete with all methods

**Commit**:
```bash
git add messAI/Services/AuthService.swift
git commit -m "feat(services): implement AuthService with signup, signin, signout"
```

---

## Phase 4: Create AuthViewModel (60 minutes)

### 4.1: Create AuthViewModel.swift File (5 minutes)

- [ ] **Create File**
  - Right-click on `ViewModels/` folder
  - New File → Swift File
  - Name: `AuthViewModel.swift`
  - Target: messAI ✓

- [ ] **Add Imports**
  ```swift
  import Foundation
  import Combine
  import FirebaseAuth
  ```

**Checkpoint**: AuthViewModel.swift created ✓

---

### 4.2: Define AuthViewModel Class & Properties (10 minutes)

- [ ] **Add Class Declaration with @MainActor**
  ```swift
  /// ViewModel managing authentication state and operations
  @MainActor
  class AuthViewModel: ObservableObject {
  ```

- [ ] **Add Published Properties**
  ```swift
  // MARK: - Published Properties
  
  /// Currently authenticated user
  @Published var currentUser: User?
  
  /// Whether user is authenticated
  @Published var isAuthenticated: Bool = false
  
  /// Error message to display to user
  @Published var errorMessage: String?
  
  /// Loading state for async operations
  @Published var isLoading: Bool = false
  ```

- [ ] **Add Private Properties**
  ```swift
  // MARK: - Private Properties
  
  private let authService: AuthService
  private var authStateHandle: AuthStateDidChangeListenerHandle?
  private var cancellables = Set<AnyCancellable>()
  ```

- [ ] **Add Initializer**
  ```swift
  // MARK: - Initialization
  
  init(authService: AuthService = AuthService()) {
      self.authService = authService
      setupAuthStateListener()
  }
  ```

- [ ] **Add Deinit**
  ```swift
  deinit {
      if let handle = authStateHandle {
          Auth.auth().removeStateDidChangeListener(handle)
      }
  }
  ```

- [ ] **Verify Build** (`⌘ + B`)

**Checkpoint**: AuthViewModel structure created ✓

---

### 4.3: Implement Auth State Listener (10 minutes)

- [ ] **Add setupAuthStateListener Method**
  ```swift
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
  ```

- [ ] **Add fetchCurrentUser Stub** (will implement fully in PR #4)
  ```swift
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
  ```

- [ ] **Verify Build** (`⌘ + B`)

**Checkpoint**: Auth state listener implemented ✓

---

### 4.4: Implement Sign Up Method (10 minutes)

- [ ] **Add signUp Method**
  ```swift
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
  ```

- [ ] **Verify Build** (`⌘ + B`)

**Checkpoint**: signUp method implemented ✓

---

### 4.5: Implement Sign In Method (5 minutes)

- [ ] **Add signIn Method**
  ```swift
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
  ```

- [ ] **Verify Build** (`⌘ + B`)

**Checkpoint**: signIn method implemented ✓

---

### 4.6: Implement Sign Out Method (5 minutes)

- [ ] **Add signOut Method**
  ```swift
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
  ```

- [ ] **Verify Build** (`⌘ + B`)

**Checkpoint**: signOut method implemented ✓

---

### 4.7: Implement Password Reset Method (5 minutes)

- [ ] **Add resetPassword Method**
  ```swift
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
  ```

- [ ] **Verify Build** (`⌘ + B`)

**Checkpoint**: resetPassword method implemented ✓

---

### 4.8: Add Validation Methods (10 minutes)

- [ ] **Add Validation Section**
  ```swift
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
  ```

- [ ] **Verify Build** (`⌘ + B`)
  - [ ] No errors
  - [ ] No warnings

**Checkpoint**: ✅ AuthViewModel complete with all methods

**Commit**:
```bash
git add messAI/ViewModels/AuthViewModel.swift
git commit -m "feat(viewmodels): implement AuthViewModel with state management"
```

---

## Phase 5: Integration & Testing (30 minutes)

### 5.1: Add AuthViewModel to App (10 minutes)

- [ ] **Open `messAI/messAIApp.swift`**

- [ ] **Add Import**
  ```swift
  import FirebaseAuth
  ```

- [ ] **Add AuthViewModel as StateObject**
  ```swift
  @main
  struct messAIApp: App {
      // Initialize Firebase
      init() {
          FirebaseApp.configure()
      }
      
      // Create AuthViewModel
      @StateObject private var authViewModel = AuthViewModel()
      
      var body: some Scene {
          WindowGroup {
              ContentView()
                  .environmentObject(authViewModel)
          }
      }
  }
  ```

- [ ] **Verify Build** (`⌘ + B`)

**Checkpoint**: AuthViewModel added to app ✓

**Commit**:
```bash
git add messAI/messAIApp.swift
git commit -m "feat(app): integrate AuthViewModel into app lifecycle"
```

---

### 5.2: Create Test UI in ContentView (10 minutes)

- [ ] **Open `messAI/ContentView.swift`**

- [ ] **Add EnvironmentObject**
  ```swift
  struct ContentView: View {
      @EnvironmentObject var authViewModel: AuthViewModel
  ```

- [ ] **Replace Body with Test UI**
  ```swift
  var body: some View {
      VStack(spacing: 20) {
          Text("Auth Testing")
              .font(.largeTitle)
          
          // Display auth status
          if authViewModel.isAuthenticated {
              Text("✅ Authenticated")
                  .foregroundColor(.green)
              
              if let user = authViewModel.currentUser {
                  Text("User: \(user.displayName)")
                  Text("Email: \(user.email)")
              }
              
              Button("Sign Out") {
                  Task {
                      await authViewModel.signOut()
                  }
              }
              .buttonStyle(.borderedProminent)
              .tint(.red)
          } else {
              Text("❌ Not Authenticated")
                  .foregroundColor(.red)
              
              Button("Test Sign Up") {
                  Task {
                      await authViewModel.signUp(
                          email: "test@example.com",
                          password: "password123",
                          displayName: "Test User"
                      )
                  }
              }
              .buttonStyle(.borderedProminent)
              
              Button("Test Sign In") {
                  Task {
                      await authViewModel.signIn(
                          email: "test@example.com",
                          password: "password123"
                      )
                  }
              }
              .buttonStyle(.bordered)
          }
          
          // Display errors
          if let error = authViewModel.errorMessage {
              Text("Error: \(error)")
                  .foregroundColor(.red)
                  .multilineTextAlignment(.center)
                  .padding()
          }
          
          // Loading indicator
          if authViewModel.isLoading {
              ProgressView()
          }
      }
      .padding()
  }
  ```

- [ ] **Verify Build** (`⌘ + B`)

**Checkpoint**: Test UI created ✓

---

### 5.3: Run All Tests (10 minutes)

**Test 1: Sign Up New User**

- [ ] **Run App** (`⌘ + R`)
- [ ] **Tap "Test Sign Up" button**
- [ ] **Check UI Updates**:
  - [ ] Loading indicator appears briefly
  - [ ] Status changes to "✅ Authenticated"
  - [ ] Display name and email show correctly
- [ ] **Check Firebase Console**:
  - [ ] Go to Firebase Console → Authentication
  - [ ] Verify `test@example.com` exists
  - [ ] Go to Firestore Database
  - [ ] Verify `users` collection exists
  - [ ] Verify user document with correct fields:
    - [ ] id
    - [ ] email
    - [ ] displayName
    - [ ] isOnline: true
    - [ ] lastSeen (timestamp)
    - [ ] createdAt (timestamp)

**Expected**: ✅ User created in both Auth and Firestore

---

**Test 2: Sign Out**

- [ ] **Tap "Sign Out" button**
- [ ] **Check UI Updates**:
  - [ ] Status changes to "❌ Not Authenticated"
  - [ ] User info disappears
- [ ] **Check Firestore**:
  - [ ] Refresh user document
  - [ ] Verify `isOnline: false`
  - [ ] Verify `lastSeen` updated

**Expected**: ✅ User signed out, Firestore updated

---

**Test 3: Sign In Existing User**

- [ ] **Tap "Test Sign In" button**
- [ ] **Check UI Updates**:
  - [ ] Status changes to "✅ Authenticated"
  - [ ] User info appears
- [ ] **Check Firestore**:
  - [ ] Verify `isOnline: true`
  - [ ] Verify `lastSeen` updated

**Expected**: ✅ User signed in, Firestore updated

---

**Test 4: Auth State Persistence**

- [ ] **Force Quit App** (from simulator)
- [ ] **Reopen App** (`⌘ + R`)
- [ ] **Check UI**:
  - [ ] Status shows "✅ Authenticated"
  - [ ] User info appears automatically

**Expected**: ✅ User stays logged in across app restarts

---

**Test 5: Error Handling - Duplicate Email**

- [ ] **Sign Out** (if signed in)
- [ ] **Tap "Test Sign Up" button** (same email)
- [ ] **Check UI**:
  - [ ] Error message appears
  - [ ] Message says "This email is already registered"
  - [ ] User not authenticated

**Expected**: ✅ Duplicate email error handled

---

**Test 6: Sign Out and Clean Up**

- [ ] **Sign In** (if needed)
- [ ] **Sign Out**
- [ ] **Go to Firebase Console**
- [ ] **Delete test user** (from Authentication)
- [ ] **Delete test user document** (from Firestore)

**Expected**: ✅ Clean state for next development

---

**Checkpoint**: ✅ All tests passing!

---

## Final Checks (10 minutes)

### Code Quality

- [ ] **No Errors** (`⌘ + B`)
- [ ] **No Warnings**
- [ ] **Code Formatting**:
  - [ ] Consistent indentation
  - [ ] Proper spacing
  - [ ] Comments for complex logic

### Documentation

- [ ] **All functions have doc comments**
- [ ] **README updated** (if needed)
- [ ] **Code is self-explanatory**

### Git Status

- [ ] **Check Status**:
  ```bash
  git status
  ```
- [ ] **Verify All Changes Committed**:
  - [ ] User.swift ✓
  - [ ] FirebaseService.swift ✓
  - [ ] AuthService.swift ✓
  - [ ] AuthViewModel.swift ✓
  - [ ] messAIApp.swift ✓
  - [ ] ContentView.swift ✓ (will revert later)

**Checkpoint**: ✅ All code committed

---

## Completion (5 minutes)

### Create Final Commit

- [ ] **Add ContentView Test Changes** (temporary, will revert in PR #3)
  ```bash
  git add messAI/ContentView.swift
  git commit -m "test(auth): add temporary test UI for auth verification"
  ```

### Push Branch

- [ ] **Push to GitHub**
  ```bash
  git push origin feature/auth-services
  ```

### Update Documentation

- [ ] **Update `PR_PARTY/README.md`**
  - [ ] Mark PR #2 as "✅ COMPLETE"
  - [ ] Add actual time taken

- [ ] **Update `memory-bank/activeContext.md`**
  - [ ] Move PR #2 to "Recent Changes"
  - [ ] Update "What We're Working On" to PR #3

- [ ] **Update `memory-bank/progress.md`**
  - [ ] Mark all PR #2 tasks complete ✅
  - [ ] Update completion percentage

- [ ] **Commit Documentation Updates**
  ```bash
  git add PR_PARTY/README.md memory-bank/activeContext.md memory-bank/progress.md
  git commit -m "docs: mark PR #2 as complete, update memory bank"
  git push origin feature/auth-services
  ```

---

## Success Criteria ✅

**All items must be checked:**

- [ ] User.swift model created with all properties
- [ ] User conforms to Codable, Identifiable, Equatable
- [ ] FirebaseService.swift created with helper methods
- [ ] AuthService.swift created with all auth methods
- [ ] AuthService can create users in Firebase Auth
- [ ] AuthService can create Firestore documents
- [ ] AuthService handles cleanup on failures
- [ ] AuthViewModel.swift created with state management
- [ ] AuthViewModel observes Firebase auth state
- [ ] AuthViewModel exposes published properties
- [ ] AuthViewModel has validation methods
- [ ] All files build without errors
- [ ] All 6 test scenarios pass
- [ ] Firebase Console shows created users
- [ ] Firestore shows user documents
- [ ] Auth state persists on app restart
- [ ] Error handling works for invalid inputs
- [ ] All commits pushed to GitHub
- [ ] Documentation updated

---

## Merge to Main (After PR #3)

**Note**: We'll merge this after creating PR #3 (Auth UI), so we have both logic and UI together.

---

**Status**: ⏳ → 🚧 → ✅  
**Branch**: `feature/auth-services`  
**Total Time**: ~3.5 hours estimated  
**Next**: PR #3 - Authentication UI Views

