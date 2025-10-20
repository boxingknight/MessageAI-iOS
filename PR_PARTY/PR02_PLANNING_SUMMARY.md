# PR #2: Authentication - Models & Services - Planning Summary 🚀

**Date**: October 20, 2025  
**Status**: ✅ PLANNING READY  
**Estimated Time**: 2-3 hours  
**Complexity**: MEDIUM

---

## What We're Building

**Goal**: Implement the authentication logic layer - User model, AuthService for Firebase Auth operations, and AuthViewModel for state management. NO UI yet (that's PR #3).

**Deliverable**: Users can sign up and log in programmatically. All authentication business logic complete and testable.

---

## Key Files to Create

1. **Models/User.swift** - User data model
2. **Services/AuthService.swift** - Firebase Auth operations
3. **Services/FirebaseService.swift** - Base Firebase helpers
4. **ViewModels/AuthViewModel.swift** - Authentication state management

**Total**: 4 new files (~400 lines of code)

---

## What Gets Built

### User Model
```swift
struct User: Codable, Identifiable {
    let id: String
    let email: String
    var displayName: String
    var photoURL: String?
    var fcmToken: String?
    var isOnline: Bool
    var lastSeen: Date
    let createdAt: Date
}
```

### AuthService
- `signUp(email:password:displayName:)` → Creates Firebase user + Firestore document
- `signIn(email:password:)` → Authenticates with Firebase
- `signOut()` → Logs out user
- `resetPassword(email:)` → Sends password reset email
- `currentUser` → Returns current Firebase user

### FirebaseService
- Firestore reference helpers
- Document creation utilities
- Timestamp helpers
- Error handling

### AuthViewModel
- `@Published var currentUser: User?`
- `@Published var isAuthenticated: Bool`
- `@Published var errorMessage: String?`
- `@Published var isLoading: Bool`
- Observes Firebase auth state changes
- Handles all auth operations

---

## Key Decisions

### Decision 1: Store User Data in Firestore
**Why**: Need user profiles accessible to other users (for chat participant info)  
**Impact**: Create Firestore document on signup

### Decision 2: Observe Auth State in ViewModel
**Why**: Automatic login on app restart  
**Impact**: Use Firebase's `addStateDidChangeListener`

### Decision 3: Separate Service and ViewModel
**Why**: Testability and separation of concerns  
**Impact**: AuthService has no UI dependencies

---

## Implementation Strategy

**Phase 1**: Create Models (30 min)
- User.swift with all properties
- Helper initializers

**Phase 2**: Create Services (60 min)
- FirebaseService base class
- AuthService with all methods
- Error handling

**Phase 3**: Create ViewModel (60 min)
- Auth state observation
- Published properties
- Auth methods

**Phase 4**: Testing (30 min)
- Test signup creates user
- Test login works
- Test logout works
- Verify Firestore document created

---

## Success Criteria

- [ ] User model complete with Codable
- [ ] AuthService can create users in Firebase
- [ ] AuthService can sign in users
- [ ] Firestore document created on signup
- [ ] AuthViewModel observes auth state
- [ ] Can programmatically test signup/login (will add UI in PR #3)
- [ ] All code compiles without errors
- [ ] Firebase Console shows created users

---

## Testing (Without UI)

Test in `ContentView` temporarily:
```swift
Button("Test Signup") {
    authViewModel.signUp(email: "test@test.com", password: "password123", displayName: "Test User")
}
```

Check:
- Firebase Console → Authentication → see user
- Firestore Console → users collection → see document

---

## Next Step (PR #3)

After this PR, PR #3 will add:
- LoginView UI
- SignUpView UI
- ProfileSetupView UI
- Navigation between auth screens

But for now, we build the logic foundation!

---

**Status**: Ready to implement  
**Branch**: Will create `feature/auth-services`  
**Go**: When PR #1 is merged (✅ Done!)

