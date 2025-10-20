# PR #2: Testing Guide - Authentication Services

**Purpose**: Comprehensive testing strategy for authentication logic  
**Test Coverage**: Unit tests, integration tests, edge cases, Firebase verification  
**Estimated Testing Time**: 30-45 minutes

---

## Test Categories

### 1. Unit Tests (Manual - No XCTest Yet)

**Purpose**: Test individual components in isolation

#### Test 1.1: User Model Creation
**Component**: `User.swift`  
**What We're Testing**: User initialization works correctly

- [ ] **Test Case**: Create User with all required fields
  ```swift
  let user = User(
      id: "test123",
      email: "test@example.com",
      displayName: "Test User"
  )
  ```
  - **Expected**: User created successfully
  - **Verify**: All properties set correctly
  - **Actual**: _______________

- [ ] **Test Case**: Create User with optional fields
  ```swift
  let user = User(
      id: "test123",
      email: "test@example.com",
      displayName: "Test User",
      photoURL: "https://example.com/photo.jpg",
      fcmToken: "token123"
  )
  ```
  - **Expected**: Optional fields populated
  - **Verify**: photoURL and fcmToken not nil
  - **Actual**: _______________

---

#### Test 1.2: User Dictionary Conversion
**Component**: `User.toDictionary()`  
**What We're Testing**: Firestore format conversion

- [ ] **Test Case**: Convert User to dictionary
  ```swift
  let user = User(
      id: "test123",
      email: "test@example.com",
      displayName: "Test User"
  )
  let dict = user.toDictionary()
  print(dict)
  ```
  - **Expected Dictionary**:
    ```swift
    [
        "id": "test123",
        "email": "test@example.com",
        "displayName": "Test User",
        "isOnline": true,
        "lastSeen": Timestamp,
        "createdAt": Timestamp
    ]
    ```
  - **Verify**: All required fields present
  - **Verify**: Timestamps are Firestore Timestamp type
  - **Actual**: _______________

- [ ] **Test Case**: Dictionary includes optional fields
  ```swift
  let user = User(
      id: "test123",
      email: "test@example.com",
      displayName: "Test User",
      photoURL: "https://example.com/photo.jpg"
  )
  let dict = user.toDictionary()
  ```
  - **Expected**: "photoURL" key present in dictionary
  - **Actual**: _______________

---

#### Test 1.3: User from Dictionary
**Component**: `User.init(from:)`  
**What We're Testing**: Parsing Firestore data

- [ ] **Test Case**: Parse valid Firestore document
  ```swift
  let dict: [String: Any] = [
      "id": "test123",
      "email": "test@example.com",
      "displayName": "Test User",
      "isOnline": true,
      "lastSeen": Timestamp(date: Date()),
      "createdAt": Timestamp(date: Date())
  ]
  let user = User(from: dict)
  ```
  - **Expected**: User not nil
  - **Verify**: All properties match dictionary
  - **Actual**: _______________

- [ ] **Test Case**: Parse invalid dictionary (missing fields)
  ```swift
  let dict: [String: Any] = [
      "id": "test123"
      // Missing required fields
  ]
  let user = User(from: dict)
  ```
  - **Expected**: User is nil (failable initializer)
  - **Actual**: _______________

---

#### Test 1.4: AuthViewModel Validation Methods
**Component**: `AuthViewModel` validation

- [ ] **Test Case**: Valid email
  ```swift
  let viewModel = AuthViewModel()
  let isValid = viewModel.isValidEmail("test@example.com")
  ```
  - **Expected**: true
  - **Actual**: _______________

- [ ] **Test Case**: Invalid email formats
  ```swift
  let invalidEmails = [
      "notanemail",
      "missing@domain",
      "@nodomain.com",
      "spaces in@email.com",
      ""
  ]
  for email in invalidEmails {
      let isValid = viewModel.isValidEmail(email)
      // Expected: false for all
  }
  ```
  - **Expected**: false for all
  - **Actual**: _______________

- [ ] **Test Case**: Valid password
  ```swift
  let isValid = viewModel.isValidPassword("password123")
  ```
  - **Expected**: true (6+ characters)
  - **Actual**: _______________

- [ ] **Test Case**: Invalid password (too short)
  ```swift
  let isValid = viewModel.isValidPassword("12345")
  ```
  - **Expected**: false (<6 characters)
  - **Actual**: _______________

- [ ] **Test Case**: Valid display name
  ```swift
  let isValid = viewModel.isValidDisplayName("John Doe")
  ```
  - **Expected**: true
  - **Actual**: _______________

- [ ] **Test Case**: Invalid display names
  ```swift
  let invalidNames = ["", "   ", "A"]  // Empty, spaces, too short
  for name in invalidNames {
      let isValid = viewModel.isValidDisplayName(name)
      // Expected: false
  }
  ```
  - **Expected**: false for all
  - **Actual**: _______________

---

### 2. Integration Tests (End-to-End)

**Purpose**: Test full authentication flows with Firebase

#### Test 2.1: Sign Up New User
**Flow**: Complete user registration  
**Time**: 2 minutes

**Pre-conditions:**
- [ ] No existing user with test email
- [ ] Firebase Auth enabled
- [ ] Firestore in test mode

**Steps:**
1. [ ] Run app on simulator (`⌘ + R`)
2. [ ] Tap "Test Sign Up" button
3. [ ] Wait for loading indicator

**Expected Results:**
- [ ] Loading indicator appears briefly
- [ ] UI updates to "✅ Authenticated"
- [ ] Display name shows: "Test User"
- [ ] Email shows: "test@example.com"
- [ ] No error message

**Firebase Console Verification:**
1. [ ] Open Firebase Console → Authentication
2. [ ] Verify user exists:
   - [ ] Email: `test@example.com`
   - [ ] UID: matches Firestore document ID
   - [ ] Created date: today

3. [ ] Open Firestore Database → users collection
4. [ ] Find document with user's UID
5. [ ] Verify fields:
   - [ ] `id`: matches Auth UID
   - [ ] `email`: "test@example.com"
   - [ ] `displayName`: "Test User"
   - [ ] `isOnline`: true
   - [ ] `lastSeen`: recent timestamp
   - [ ] `createdAt`: today's timestamp
   - [ ] `photoURL`: null or not present
   - [ ] `fcmToken`: null or not present

**Actual Results:** _______________

**Status:** ✅ PASS / ❌ FAIL

---

#### Test 2.2: Sign Out User
**Flow**: User signs out  
**Time**: 1 minute

**Pre-conditions:**
- [ ] User signed in from Test 2.1

**Steps:**
1. [ ] Tap "Sign Out" button
2. [ ] Wait for state update

**Expected Results:**
- [ ] UI updates to "❌ Not Authenticated"
- [ ] User info disappears
- [ ] "Sign Up" / "Sign In" buttons appear
- [ ] No error message

**Firebase Console Verification:**
1. [ ] Refresh Firestore user document
2. [ ] Verify fields updated:
   - [ ] `isOnline`: false
   - [ ] `lastSeen`: just updated (within 1 minute)

**Actual Results:** _______________

**Status:** ✅ PASS / ❌ FAIL

---

#### Test 2.3: Sign In Existing User
**Flow**: User logs back in  
**Time**: 1 minute

**Pre-conditions:**
- [ ] User signed out from Test 2.2
- [ ] User still exists in Firebase

**Steps:**
1. [ ] Tap "Test Sign In" button
2. [ ] Wait for loading indicator

**Expected Results:**
- [ ] Loading indicator appears briefly
- [ ] UI updates to "✅ Authenticated"
- [ ] Display name shows: "Test User"
- [ ] Email shows: "test@example.com"
- [ ] No error message

**Firebase Console Verification:**
1. [ ] Refresh Firestore user document
2. [ ] Verify fields updated:
   - [ ] `isOnline`: true
   - [ ] `lastSeen`: just updated

**Actual Results:** _______________

**Status:** ✅ PASS / ❌ FAIL

---

#### Test 2.4: Auth State Persistence
**Flow**: User stays logged in across app restarts  
**Time**: 2 minutes

**Pre-conditions:**
- [ ] User signed in from Test 2.3

**Steps:**
1. [ ] Note current auth state (authenticated)
2. [ ] Force quit app from simulator (swipe up in app switcher)
3. [ ] Wait 5 seconds
4. [ ] Reopen app (`⌘ + R` in Xcode)
5. [ ] Wait for app to load

**Expected Results:**
- [ ] App loads directly to authenticated state
- [ ] UI shows "✅ Authenticated"
- [ ] User info displayed (name, email)
- [ ] No need to sign in again

**Debug:**
- [ ] Check console for "🔥 Auth state changed" log
- [ ] Should show user UID

**Actual Results:** _______________

**Status:** ✅ PASS / ❌ FAIL

---

### 3. Error Handling Tests

**Purpose**: Verify graceful error handling

#### Test 3.1: Duplicate Email Error
**Flow**: Attempt to sign up with existing email  
**Time**: 1 minute

**Pre-conditions:**
- [ ] User from Test 2.1 still exists
- [ ] Currently signed out

**Steps:**
1. [ ] Tap "Test Sign Up" button (same email as Test 2.1)
2. [ ] Wait for response

**Expected Results:**
- [ ] Error message appears
- [ ] Message says: "This email is already registered" (or similar)
- [ ] UI stays in "❌ Not Authenticated" state
- [ ] No user created (no duplicate)

**Firebase Console Verification:**
1. [ ] Check Authentication → Users
2. [ ] Verify only ONE user with test email
3. [ ] No duplicate entries

**Actual Results:** _______________

**Status:** ✅ PASS / ❌ FAIL

---

#### Test 3.2: Invalid Credentials Error
**Flow**: Attempt sign in with wrong password  
**Time**: 1 minute

**Pre-conditions:**
- [ ] User exists but signed out

**Steps:**
1. [ ] Modify test button temporarily:
   ```swift
   Button("Test Wrong Password") {
       Task {
           await authViewModel.signIn(
               email: "test@example.com",
               password: "wrongpassword"
           )
       }
   }
   ```
2. [ ] Run app
3. [ ] Tap button

**Expected Results:**
- [ ] Error message appears
- [ ] Message mentions invalid credentials
- [ ] UI stays in "❌ Not Authenticated" state
- [ ] User NOT signed in

**Actual Results:** _______________

**Status:** ✅ PASS / ❌ FAIL

**Cleanup:**
- [ ] Remove test button

---

#### Test 3.3: Weak Password Error
**Flow**: Attempt signup with short password  
**Time**: 1 minute

**Pre-conditions:**
- [ ] Using a new email (not test@example.com)

**Steps:**
1. [ ] Modify test button temporarily:
   ```swift
   Button("Test Weak Password") {
       Task {
           await authViewModel.signUp(
               email: "test2@example.com",
               password: "12345",  // Only 5 chars
               displayName: "Test User 2"
           )
       }
   }
   ```
2. [ ] Tap button

**Expected Results:**
- [ ] Error message appears
- [ ] Message mentions password requirements
- [ ] No user created

**Firebase Console Verification:**
- [ ] Verify `test2@example.com` NOT in Authentication

**Actual Results:** _______________

**Status:** ✅ PASS / ❌ FAIL

**Cleanup:**
- [ ] Remove test button

---

#### Test 3.4: Network Offline Error
**Flow**: Attempt auth operation with no internet  
**Time**: 2 minutes

**Pre-conditions:**
- [ ] User signed out

**Steps:**
1. [ ] Open simulator Settings
2. [ ] Turn on Airplane Mode (or disconnect Mac from internet)
3. [ ] Return to app
4. [ ] Tap "Test Sign In" button

**Expected Results:**
- [ ] Error message appears after timeout
- [ ] Message mentions network error
- [ ] UI stays in "❌ Not Authenticated" state

**Recovery:**
1. [ ] Turn off Airplane Mode
2. [ ] Tap "Test Sign In" again
3. [ ] Should work now

**Actual Results:** _______________

**Status:** ✅ PASS / ❌ FAIL

---

### 4. Edge Cases

**Purpose**: Test unusual but valid scenarios

#### Test 4.1: Very Long Display Name
**Flow**: Sign up with maximum length name  
**Time**: 1 minute

**Steps:**
1. [ ] Use new email: `longname@example.com`
2. [ ] Use 100-character display name:
   ```swift
   let longName = String(repeating: "A", count: 100)
   await authViewModel.signUp(
       email: "longname@example.com",
       password: "password123",
       displayName: longName
   )
   ```

**Expected Results:**
- [ ] Signup succeeds
- [ ] Name stored in Firestore (might be truncated by Firebase)
- [ ] UI displays name (might wrap)

**Actual Results:** _______________

**Status:** ✅ PASS / ❌ FAIL

**Cleanup:**
- [ ] Delete `longname@example.com` from Firebase

---

#### Test 4.2: Special Characters in Display Name
**Flow**: Sign up with Unicode characters  
**Time**: 1 minute

**Steps:**
1. [ ] Use new email: `special@example.com`
2. [ ] Use special characters:
   ```swift
   await authViewModel.signUp(
       email: "special@example.com",
       password: "password123",
       displayName: "Test 🔥 用户 Ñoño"
   )
   ```

**Expected Results:**
- [ ] Signup succeeds
- [ ] Firestore stores Unicode correctly
- [ ] UI displays characters correctly

**Actual Results:** _______________

**Status:** ✅ PASS / ❌ FAIL

**Cleanup:**
- [ ] Delete `special@example.com` from Firebase

---

#### Test 4.3: Rapid Successive Auth Operations
**Flow**: Multiple auth calls quickly  
**Time**: 1 minute

**Pre-conditions:**
- [ ] User signed out

**Steps:**
1. [ ] Tap "Test Sign In" button
2. [ ] **Immediately** tap "Test Sign In" again (before first completes)
3. [ ] Tap 2-3 more times rapidly

**Expected Results:**
- [ ] No crashes
- [ ] Eventually signs in successfully
- [ ] Only one auth state (not multiple)
- [ ] Error messages handled gracefully

**Actual Results:** _______________

**Status:** ✅ PASS / ❌ FAIL

---

#### Test 4.4: Auth During Low Memory
**Flow**: Auth while device under stress  
**Time**: 2 minutes (optional)

**Steps:**
1. [ ] Open multiple apps in simulator
2. [ ] Navigate to messAI
3. [ ] Attempt sign in

**Expected Results:**
- [ ] Auth succeeds or fails gracefully
- [ ] No crashes
- [ ] Error message if failure

**Actual Results:** _______________

**Status:** ✅ PASS / ❌ FAIL / ⏭️ SKIP

---

### 5. Performance Tests

**Purpose**: Verify acceptable performance

#### Test 5.1: Sign Up Speed
**Flow**: Measure signup time  
**Time**: 2 minutes

**Steps:**
1. [ ] Add timing code:
   ```swift
   let startTime = Date()
   await authViewModel.signUp(...)
   let endTime = Date()
   let duration = endTime.timeIntervalSince(startTime)
   print("⏱️ Signup took: \(duration) seconds")
   ```
2. [ ] Run test 3 times
3. [ ] Record times

**Expected Performance:**
- [ ] Signup < 3 seconds on good network
- [ ] Signup < 10 seconds on slow network

**Actual Times:**
- Test 1: _______ seconds
- Test 2: _______ seconds
- Test 3: _______ seconds
- Average: _______ seconds

**Status:** ✅ PASS / ❌ FAIL

---

#### Test 5.2: Sign In Speed
**Flow**: Measure signin time  
**Time**: 2 minutes

**Steps:**
1. [ ] Similar to Test 5.1 but for signIn
2. [ ] Run 3 times
3. [ ] Record times

**Expected Performance:**
- [ ] Sign in < 2 seconds on good network
- [ ] Sign in < 8 seconds on slow network

**Actual Times:**
- Test 1: _______ seconds
- Test 2: _______ seconds
- Test 3: _______ seconds
- Average: _______ seconds

**Status:** ✅ PASS / ❌ FAIL

---

#### Test 5.3: Auth State Listener Response Time
**Flow**: Measure how fast UI updates after auth change  
**Time**: 2 minutes

**Steps:**
1. [ ] Add timing logs:
   ```swift
   // In setupAuthStateListener
   authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
       let listenerTime = Date()
       print("⏱️ Listener fired at: \(listenerTime)")
       Task { @MainActor in
           let uiUpdateTime = Date()
           print("⏱️ UI updated at: \(uiUpdateTime)")
           // ... rest of code
       }
   }
   ```
2. [ ] Sign in
3. [ ] Check console logs

**Expected Performance:**
- [ ] Listener fires within 100ms of auth change
- [ ] UI updates within 50ms of listener

**Actual Time:** _______ ms

**Status:** ✅ PASS / ❌ FAIL

**Cleanup:**
- [ ] Remove timing logs

---

### 6. Acceptance Criteria

**All must pass for PR #2 to be complete:**

#### Functional Requirements
- [ ] User can sign up with email, password, display name
- [ ] User can sign in with email and password
- [ ] User can sign out
- [ ] Auth state persists across app restarts
- [ ] User document created in Firestore on signup
- [ ] User online status updates on sign in/out

#### Error Handling
- [ ] Duplicate email shows error message
- [ ] Invalid credentials show error message
- [ ] Weak password shows error message
- [ ] Network errors handled gracefully
- [ ] No crashes on any error case

#### Data Integrity
- [ ] Firebase Auth and Firestore stay in sync
- [ ] User ID matches between Auth and Firestore
- [ ] All required fields present in Firestore
- [ ] Timestamps use Firestore Timestamp type
- [ ] Auth cleanup works if Firestore fails

#### UI/UX
- [ ] Loading states work
- [ ] Error messages displayed clearly
- [ ] Auth state reflected in UI immediately
- [ ] No lag or jank on state changes

#### Performance
- [ ] Signup < 5 seconds
- [ ] Sign in < 3 seconds
- [ ] Auth state updates < 200ms
- [ ] No memory leaks

#### Code Quality
- [ ] All files build without errors
- [ ] No compiler warnings
- [ ] Code properly commented
- [ ] Follows Swift conventions

---

## Test Summary Template

**Date Tested:** _______________  
**Tester:** _______________  
**Total Tests:** 21  
**Tests Passed:** _____ / 21  
**Tests Failed:** _____ / 21  
**Tests Skipped:** _____ / 21

### Critical Failures (Must Fix)
1. _______________
2. _______________

### Minor Issues (Can Defer)
1. _______________
2. _______________

### Performance Notes
- Signup average: _______ seconds
- Sign in average: _______ seconds
- UI responsiveness: ⭐⭐⭐⭐⭐

### Overall Assessment
[ ] ✅ READY TO MERGE  
[ ] ⚠️ NEEDS FIXES  
[ ] ❌ SIGNIFICANT ISSUES

---

## Quick Test Checklist (Minimum Tests)

**If time is limited, run AT LEAST these 6 core tests:**

- [ ] Test 2.1: Sign up new user
- [ ] Test 2.2: Sign out
- [ ] Test 2.3: Sign in existing user
- [ ] Test 2.4: Auth persistence on restart
- [ ] Test 3.1: Duplicate email error
- [ ] Test 3.2: Invalid credentials error

**Time Required:** ~10 minutes  
**Coverage:** ~80% of critical paths

---

## Cleanup After Testing

**Before marking PR complete:**

- [ ] Delete all test users from Firebase Authentication
- [ ] Delete all test user documents from Firestore
- [ ] Remove test buttons from ContentView (will add proper UI in PR #3)
- [ ] Remove debug print statements
- [ ] Remove timing code
- [ ] Commit clean code

---

**Testing Complete!** 🎉

If all tests pass, PR #2 is ready to merge (after PR #3 UI is added).

