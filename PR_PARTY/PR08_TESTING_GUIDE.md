# PR#8: Contact Selection & New Chat - Testing Guide

**Last Updated:** October 21, 2025  
**PR Status:** Planning Complete, Ready for Implementation  
**Total Test Cases:** 26 (8 unit + 5 integration + 5 edge cases + 3 performance + 5 acceptance)

---

## Test Categories

### 1. Unit Tests (8 tests)
- Test individual methods and computed properties in isolation
- Focus: ContactsViewModel and ChatService extensions
- Environment: Xcode test suite with mocked dependencies

### 2. Integration Tests (5 tests)
- Test complete flows across multiple components
- Focus: Contact selection → Conversation creation → Sheet dismiss
- Environment: Simulator with live Firebase connection

### 3. Edge Cases (5 tests)
- Test unusual scenarios and error conditions
- Focus: Empty states, network errors, data edge cases
- Environment: Simulator with controlled conditions

### 4. Performance Tests (3 tests)
- Measure speed and resource usage
- Focus: Load time, search speed, memory usage
- Environment: Physical device with Instruments

### 5. Acceptance Tests (5 tests)
- Verify feature meets all requirements
- Focus: End-to-end user scenarios
- Environment: Physical device, two-device testing

---

## 1. Unit Tests

### Test 1.1: ContactsViewModel - Load Users

**Description:** Verify ViewModel loads users from Firestore correctly

**Setup:**
```swift
// Mock ChatService
class MockChatService: ChatService {
    var mockUsers: [User] = [
        User(id: "1", displayName: "Alice", email: "alice@test.com", photoURL: nil, isOnline: true, lastSeen: Date(), createdAt: Date()),
        User(id: "2", displayName: "Bob", email: "bob@test.com", photoURL: nil, isOnline: false, lastSeen: Date(), createdAt: Date()),
        User(id: "3", displayName: "Charlie", email: "charlie@test.com", photoURL: nil, isOnline: true, lastSeen: Date(), createdAt: Date())
    ]
    
    override func fetchAllUsers(excludingUserId: String) async throws -> [User] {
        return mockUsers.filter { $0.id != excludingUserId }
    }
}

let viewModel = ContactsViewModel(
    chatService: MockChatService(),
    currentUserId: "current-user-id"
)
```

**Action:**
```swift
await viewModel.loadUsers()
```

**Expected:**
- `viewModel.isLoading == false`
- `viewModel.allUsers.count == 3`
- `viewModel.errorMessage == nil`
- Users sorted alphabetically by displayName
- No users have id == "current-user-id"

**Actual:** ___

**Status:** [ ] Pass [ ] Fail

---

### Test 1.2: ContactsViewModel - Filtered Users (Empty Query)

**Description:** Verify filteredUsers returns all users when search is empty

**Setup:**
```swift
viewModel.allUsers = [user1, user2, user3]
viewModel.searchQuery = ""
```

**Action:**
```swift
let filtered = viewModel.filteredUsers
```

**Expected:**
- `filtered.count == 3`
- `filtered == allUsers`

**Actual:** ___

**Status:** [ ] Pass [ ] Fail

---

### Test 1.3: ContactsViewModel - Filtered Users (Name Query)

**Description:** Verify filteredUsers filters by display name

**Setup:**
```swift
viewModel.allUsers = [
    User(id: "1", displayName: "Alice Smith", email: "alice@test.com", ...),
    User(id: "2", displayName: "Bob Jones", email: "bob@test.com", ...),
    User(id: "3", displayName: "Alice Wang", email: "alice.w@test.com", ...)
]
viewModel.searchQuery = "alice"
```

**Action:**
```swift
let filtered = viewModel.filteredUsers
```

**Expected:**
- `filtered.count == 2`
- Both filtered users have "Alice" in displayName
- Case-insensitive match (lowercase query matches uppercase name)

**Actual:** ___

**Status:** [ ] Pass [ ] Fail

---

### Test 1.4: ContactsViewModel - Filtered Users (Email Query)

**Description:** Verify filteredUsers filters by email

**Setup:**
```swift
viewModel.allUsers = [
    User(id: "1", displayName: "Alice", email: "alice@gmail.com", ...),
    User(id: "2", displayName: "Bob", email: "bob@yahoo.com", ...),
    User(id: "3", displayName: "Charlie", email: "charlie@gmail.com", ...)
]
viewModel.searchQuery = "@gmail"
```

**Action:**
```swift
let filtered = viewModel.filteredUsers
```

**Expected:**
- `filtered.count == 2`
- Both filtered users have "@gmail" in email

**Actual:** ___

**Status:** [ ] Pass [ ] Fail

---

### Test 1.5: ContactsViewModel - Start Conversation (New)

**Description:** Verify starting conversation creates new when none exists

**Setup:**
```swift
// Mock ChatService with no existing conversations
class MockChatService: ChatService {
    override func findExistingConversation(participants: [String]) async throws -> Conversation? {
        return nil  // No existing conversation
    }
    
    override func createConversation(participants: [String], isGroup: Bool) async throws -> Conversation {
        return Conversation(id: "new-conv-id", participants: participants, isGroup: isGroup, ...)
    }
}

let viewModel = ContactsViewModel(
    chatService: MockChatService(),
    currentUserId: "user1"
)
let user2 = User(id: "user2", displayName: "User 2", ...)
```

**Action:**
```swift
let conversation = try await viewModel.startConversation(with: user2)
```

**Expected:**
- `conversation.id == "new-conv-id"`
- `conversation.participants == ["user1", "user2"]`
- `conversation.isGroup == false`
- `createConversation()` was called once
- `findExistingConversation()` was called first

**Actual:** ___

**Status:** [ ] Pass [ ] Fail

---

### Test 1.6: ContactsViewModel - Start Conversation (Existing)

**Description:** Verify starting conversation reuses existing

**Setup:**
```swift
// Mock ChatService with existing conversation
class MockChatService: ChatService {
    override func findExistingConversation(participants: [String]) async throws -> Conversation? {
        return Conversation(id: "existing-conv-id", participants: participants, isGroup: false, ...)
    }
    
    override func createConversation(participants: [String], isGroup: Bool) async throws -> Conversation {
        XCTFail("createConversation should not be called")
        return Conversation(...)
    }
}

let viewModel = ContactsViewModel(
    chatService: MockChatService(),
    currentUserId: "user1"
)
let user2 = User(id: "user2", displayName: "User 2", ...)
```

**Action:**
```swift
let conversation = try await viewModel.startConversation(with: user2)
```

**Expected:**
- `conversation.id == "existing-conv-id"`
- `createConversation()` was NOT called
- Returns existing conversation

**Actual:** ___

**Status:** [ ] Pass [ ] Fail

---

### Test 1.7: ChatService - Find Existing Conversation (Found)

**Description:** Verify findExistingConversation returns existing conversation

**Setup:**
```swift
// In Firestore: create conversation with participants ["user1", "user2"]
let conversation = Conversation(
    id: "test-conv-id",
    participants: ["user1", "user2"],
    isGroup: false,
    ...
)
await chatService.createConversation(participants: ["user1", "user2"], isGroup: false)
```

**Action:**
```swift
let found = try await chatService.findExistingConversation(
    participants: ["user1", "user2"]
)
```

**Expected:**
- `found != nil`
- `found?.id == "test-conv-id"`
- `found?.participants.sorted() == ["user1", "user2"]`

**Actual:** ___

**Status:** [ ] Pass [ ] Fail

---

### Test 1.8: ChatService - Find Existing Conversation (Not Found)

**Description:** Verify findExistingConversation returns nil when no conversation exists

**Setup:**
```swift
// Empty Firestore /conversations collection (no conversations)
```

**Action:**
```swift
let found = try await chatService.findExistingConversation(
    participants: ["user1", "user2"]
)
```

**Expected:**
- `found == nil`
- No error thrown
- Query completes successfully

**Actual:** ___

**Status:** [ ] Pass [ ] Fail

---

## 2. Integration Tests

### Test 2.1: Complete Contact Selection Flow

**Description:** End-to-end test of selecting contact and creating conversation

**Environment:** Simulator with live Firebase

**Setup:**
1. Sign in as User A
2. Ensure User B exists in Firestore
3. No existing conversation between A and B

**Steps:**
1. Open app to ChatListView
2. Tap "+" button in toolbar
3. Wait for ContactsListView to appear
4. Wait for users to load (spinner disappears)
5. Tap on User B in the list
6. Wait for sheet to dismiss

**Expected:**
- Contact picker sheet appears (~200ms)
- Users load within 2 seconds
- User B visible in list
- Tapping User B:
  - Creates new conversation in Firestore
  - Sheet dismisses smoothly
  - Console logs "✅ Conversation ready: [id]"
- Check Firebase Console:
  - 1 new conversation document created
  - participants array == ["userA-id", "userB-id"]
  - isGroup == false

**Actual:** ___

**Status:** [ ] Pass [ ] Fail

---

### Test 2.2: Search Functionality End-to-End

**Description:** Test search filters contacts correctly in real UI

**Environment:** Simulator with 10+ test users in Firebase

**Setup:**
1. Sign in as User A
2. Ensure 10+ users exist with varied names:
   - "Alice Johnson"
   - "Bob Smith"
   - "John Doe"
   - "Jane Smith"
   - "Charlie Brown"
   - etc.

**Steps:**
1. Open contact picker
2. Wait for all users to load
3. Note total user count (e.g., 10)
4. Tap search bar
5. Type "john" (lowercase)
6. Observe filtered results
7. Clear search (tap X)
8. Type "smith" (lowercase)
9. Observe filtered results
10. Type "@gmail.com"
11. Observe filtered results

**Expected:**
- After typing "john": Only "Alice Johnson" and "John Doe" visible (2 users)
- After clearing: All 10 users visible again
- After typing "smith": Only "Bob Smith" and "Jane Smith" visible (2 users)
- After typing "@gmail.com": Only users with Gmail emails visible
- Search is case-insensitive
- Results update instantly (<100ms perceived)

**Actual:** ___

**Status:** [ ] Pass [ ] Fail

---

### Test 2.3: Existing Conversation Handling

**Description:** Verify reopening existing conversation doesn't create duplicate

**Environment:** Simulator with live Firebase

**Setup:**
1. Sign in as User A
2. User B exists in Firestore
3. Create conversation between A and B manually (or via previous test)
4. Note conversation ID

**Steps:**
1. Open contact picker
2. Tap on User B
3. Note the conversation ID from console
4. Go back to ChatListView
5. Open contact picker again
6. Tap on User B again
7. Note the conversation ID from console
8. Check Firebase Console /conversations collection

**Expected:**
- First selection: Finds existing conversation, logs "[existing-id]"
- Second selection: Returns SAME conversation ID
- Only 1 conversation document in Firestore
- No duplicate created

**Actual:** ___

**Status:** [ ] Pass [ ] Fail

---

### Test 2.4: Two-Device Conversation Creation

**Description:** Verify both devices create/find same conversation

**Environment:** 2 physical devices with live Firebase

**Setup:**
1. Device A: Sign in as User A
2. Device B: Sign in as User B
3. No existing conversation between A and B

**Steps:**
1. Device A: Open contact picker
2. Device A: Tap User B
3. Device A: Note conversation ID from console
4. Device A: Check Firebase Console for conversation
5. Device B: Open app (wait for sync)
6. Device B: Open contact picker
7. Device B: Tap User A
8. Device B: Note conversation ID from console

**Expected:**
- Device A creates conversation (e.g., "conv-123")
- Conversation visible in Firebase with both user IDs
- Device B finds existing conversation
- Both devices have SAME conversation ID ("conv-123")
- No duplicate conversations created

**Actual:** ___

**Status:** [ ] Pass [ ] Fail

---

### Test 2.5: Cancel Contact Picker

**Description:** Verify canceling picker doesn't create conversation

**Environment:** Simulator

**Setup:**
1. Sign in as User A
2. User B exists
3. No existing conversation

**Steps:**
1. Open contact picker
2. Wait for users to load
3. Tap "Cancel" button (top-left)
4. Check Firebase Console

**Expected:**
- Sheet dismisses immediately
- No conversation created
- ChatListView visible
- No errors in console

**Actual:** ___

**Status:** [ ] Pass [ ] Fail

---

## 3. Edge Cases

### Test 3.1: Empty Contact List

**Description:** Test behavior when no other users registered

**Environment:** Simulator with clean Firebase

**Setup:**
1. Create Firebase project with only 1 user (current user)
2. Sign in as that user
3. Verify /users collection has only 1 document

**Steps:**
1. Open contact picker
2. Wait for loading to complete

**Expected:**
- Loading spinner appears briefly
- Empty state displays:
  - Icon: person.3.fill (gray)
  - Heading: "No Contacts Found"
  - Message: "No other users are registered yet.\nInvite friends to join!"
- No error messages
- Search bar still visible (but no users to search)
- Cancel button works

**Actual:** ___

**Status:** [ ] Pass [ ] Fail

---

### Test 3.2: Network Error Handling

**Description:** Test behavior when Firestore fetch fails

**Environment:** Simulator with airplane mode

**Setup:**
1. Sign in while online
2. Enable airplane mode (swipe up Control Center)
3. Force quit app (optional)

**Steps:**
1. Open contact picker
2. Wait for error to appear

**Expected:**
- Loading spinner appears
- After 5-10 seconds, error alert displays:
  - Title: "Error"
  - Message: "Failed to load contacts: [error description]"
  - Button: "OK"
- Tapping "OK" dismisses alert
- Empty state or loading state remains (not crash)
- User can tap "Cancel" to dismiss sheet
- Reopening sheet retries fetch

**Actual:** ___

**Status:** [ ] Pass [ ] Fail

---

### Test 3.3: Current User Exclusion

**Description:** Verify current user never appears in contact list

**Environment:** Simulator

**Setup:**
1. Sign in as User A (e.g., "alice@test.com")
2. Verify User A exists in Firestore /users
3. At least 2 other users exist

**Steps:**
1. Open contact picker
2. Wait for users to load
3. Search for current user's name (e.g., "Alice")
4. Search for current user's email (e.g., "alice@test.com")

**Expected:**
- Current user NEVER appears in list
- Searching for current user's name:
  - Shows other users with similar names (if any)
  - Never shows current user
- Searching for exact email returns no results
- Cannot create conversation with self

**Actual:** ___

**Status:** [ ] Pass [ ] Fail

---

### Test 3.4: Large User List Performance

**Description:** Test smooth performance with 100+ users

**Environment:** Simulator with 100+ test users in Firebase

**Setup:**
1. Add 100-150 test users to Firebase /users
2. Sign in

**Steps:**
1. Open contact picker
2. Measure load time (start: sheet appears, end: users displayed)
3. Scroll through entire list rapidly
4. Type in search bar: "test"
5. Measure search response time
6. Check FPS in Xcode (Debug → View Debugging → Show FPS)

**Expected:**
- Load time: <3 seconds
- Smooth 60fps scrolling (no jank)
- Search results: <100ms response
- Memory usage: <50MB (check Instruments)
- No lag or freezing

**Actual:** ___

**Status:** [ ] Pass [ ] Fail

---

### Test 3.5: Rapid Tap Prevention

**Description:** Verify double-tapping contact doesn't create duplicates

**Environment:** Simulator

**Setup:**
1. Sign in
2. User B exists
3. No existing conversation

**Steps:**
1. Open contact picker
2. Rapidly tap User B twice in quick succession (<500ms apart)
3. Check console for conversation IDs
4. Check Firebase Console for conversation count

**Expected:**
- Only 1 conversation created
- Console logs same ID twice (or only once)
- Sheet dismisses once (not twice)
- Firebase shows 1 conversation document
- No duplicate or error

**Actual:** ___

**Status:** [ ] Pass [ ] Fail

---

## 4. Performance Tests

### Test 4.1: Load Time Benchmark

**Description:** Measure time to load and display contacts

**Environment:** Physical device with 50 test users

**Setup:**
1. Add exactly 50 users to Firebase
2. Sign in on physical device
3. Open Xcode Instruments → Time Profiler

**Steps:**
1. Close contact picker if open
2. Note current time
3. Tap "+" button
4. Wait for users to display
5. Note time when all users visible

**Metrics:**
- **Time to Sheet Appear:** ___ ms (target: <200ms)
- **Time to Start Loading:** ___ ms (target: <100ms)
- **Time to Users Displayed:** ___ ms (target: <2000ms total)

**Expected:**
- Total load time: <2 seconds
- Sheet animation: smooth 60fps
- No perceived lag

**Actual:** ___

**Status:** [ ] Pass [ ] Fail

---

### Test 4.2: Search Performance Benchmark

**Description:** Measure search filter response time

**Environment:** Physical device with 100 test users

**Setup:**
1. Add 100 users to Firebase
2. Sign in
3. Open contact picker
4. Wait for all users to load
5. Open Xcode Debug Console

**Steps:**
1. Add timing code to ViewModel:
```swift
var filteredUsers: [User] {
    let start = Date()
    defer {
        let duration = Date().timeIntervalSince(start) * 1000
        print("🔍 Search took: \(duration)ms")
    }
    
    if searchQuery.isEmpty { return allUsers }
    return allUsers.filter { /* ... */ }
}
```
2. Type "test" in search bar
3. Note time from console
4. Repeat 5 times with different queries
5. Calculate average

**Metrics:**
- **Search 1:** ___ ms
- **Search 2:** ___ ms
- **Search 3:** ___ ms
- **Search 4:** ___ ms
- **Search 5:** ___ ms
- **Average:** ___ ms (target: <100ms)

**Expected:**
- Average search time: <100ms
- Instant perceived response
- No typing lag

**Actual:** ___

**Status:** [ ] Pass [ ] Fail

---

### Test 4.3: Memory Usage Benchmark

**Description:** Measure memory footprint with large user list

**Environment:** Physical device with Instruments

**Setup:**
1. Add 200 users to Firebase
2. Connect device to Xcode
3. Open Instruments → Allocations

**Steps:**
1. Launch app (note baseline memory)
2. Sign in (note memory)
3. Open contact picker (note memory)
4. Wait for 200 users to load (note peak memory)
5. Close picker (note memory after)
6. Reopen picker (note memory on second open)

**Metrics:**
- **Baseline (app launch):** ___ MB
- **After sign in:** ___ MB
- **Picker opened:** ___ MB
- **200 users loaded:** ___ MB (target: <50MB total)
- **After close:** ___ MB (should return to baseline)
- **Second open:** ___ MB (reused memory)

**Expected:**
- Peak memory with 200 users: <50MB
- Memory released after closing sheet
- No memory leaks
- Second open doesn't double memory

**Actual:** ___

**Status:** [ ] Pass [ ] Fail

---

## 5. Acceptance Tests

### Test 5.1: MVP Requirement - Start New Conversation

**Description:** Core MVP requirement verification

**Scenario:** As a user, I can start a new one-on-one conversation with any registered user

**Steps:**
1. Sign in as User A
2. Ensure User B is registered
3. No existing conversation between A and B
4. From ChatListView, tap "+"
5. Contact picker appears
6. Tap User B
7. Sheet dismisses
8. (PR #9 will navigate to chat - for now, verify conversation created)

**Acceptance Criteria:**
- [ ] "+" button visible and accessible in ChatListView
- [ ] Tapping "+" opens contact picker in <200ms
- [ ] All registered users visible (except self)
- [ ] Tapping user creates conversation in <500ms
- [ ] Conversation has correct participants [A, B]
- [ ] Sheet dismisses automatically
- [ ] No errors during flow
- [ ] Conversation persists in Firebase

**Actual:** ___

**Status:** [ ] Pass [ ] Fail

---

### Test 5.2: MVP Requirement - Search Contacts

**Description:** User can find contacts quickly via search

**Scenario:** As a user with many contacts, I can search to find specific people quickly

**Steps:**
1. Sign in with 20+ test users registered
2. Open contact picker
3. Note user "John Doe" is in list
4. Type "john" in search
5. Verify "John Doe" appears
6. Clear search
7. Type email domain "@gmail.com"
8. Verify only Gmail users appear

**Acceptance Criteria:**
- [ ] Search bar visible and accessible
- [ ] Typing filters list instantly (<100ms)
- [ ] Search is case-insensitive
- [ ] Matches both name and email
- [ ] Clearing search restores full list
- [ ] Partial matches work (e.g., "joh" matches "John")

**Actual:** ___

**Status:** [ ] Pass [ ] Fail

---

### Test 5.3: MVP Requirement - No Duplicate Conversations

**Description:** System prevents duplicate conversations

**Scenario:** As a user, reopening conversation with same person reuses existing chat

**Steps:**
1. Create conversation with User B (via contact picker)
2. Note conversation ID: ___
3. Go back to ChatListView
4. Open contact picker again
5. Tap User B again
6. Note conversation ID: ___
7. Verify IDs match

**Acceptance Criteria:**
- [ ] First tap creates new conversation
- [ ] Second tap returns SAME conversation ID
- [ ] Only 1 conversation in Firebase
- [ ] Conversation has lastMessageAt updated (if modified)
- [ ] No error or duplicate conversation

**Actual:** ___

**Status:** [ ] Pass [ ] Fail

---

### Test 5.4: MVP Requirement - Handle Empty State

**Description:** Graceful handling when no contacts available

**Scenario:** As a new user with no contacts, I see helpful empty state

**Steps:**
1. Create new user (only user in system)
2. Sign in
3. Open contact picker
4. Observe empty state

**Acceptance Criteria:**
- [ ] Empty state displays (not blank screen)
- [ ] Helpful icon shown (person.3.fill)
- [ ] Clear message: "No Contacts Found"
- [ ] Suggestion: "Invite friends to join!"
- [ ] Can dismiss sheet with Cancel
- [ ] No console errors

**Actual:** ___

**Status:** [ ] Fail

---

### Test 5.5: MVP Requirement - Cross-Device Sync

**Description:** Conversations sync across multiple devices

**Scenario:** As a user logged in on 2 devices, creating conversation on one device makes it available on the other

**Steps:**
1. Device A (iPhone): Sign in as User A
2. Device B (iPad): Sign in as User A
3. Device A: Create conversation with User C
4. Wait 5 seconds
5. Device B: Check ChatListView

**Acceptance Criteria:**
- [ ] Device A successfully creates conversation
- [ ] Device B automatically receives conversation
- [ ] Conversation appears in both ChatListViews
- [ ] Participants correct on both devices
- [ ] No manual refresh needed
- [ ] Sync happens within 5 seconds

**Actual:** ___

**Status:** [ ] Pass [ ] Fail

---

## Test Execution Summary

### Completion Tracking

**Unit Tests:** ___ / 8 passing  
**Integration Tests:** ___ / 5 passing  
**Edge Cases:** ___ / 5 passing  
**Performance Tests:** ___ / 3 passing  
**Acceptance Tests:** ___ / 5 passing

**Total:** ___ / 26 tests passing

---

### Critical Failures (Must Fix Before Merge)

| Test | Issue | Severity | Fix Required |
|------|-------|----------|--------------|
| ___ | ___ | CRITICAL | ___ |

---

### Known Issues (Can Address Post-Merge)

| Test | Issue | Severity | Planned Fix |
|------|-------|----------|-------------|
| ___ | ___ | LOW | ___ |

---

### Performance Metrics Summary

| Metric | Target | Actual | Status |
|--------|--------|--------|--------|
| Load time (50 users) | <2s | ___ | [ ] |
| Search response | <100ms | ___ | [ ] |
| Memory usage (200 users) | <50MB | ___ | [ ] |
| Scroll FPS | 60fps | ___ | [ ] |

---

## Final Acceptance Checklist

Before marking PR #8 as complete, verify:

### Functional Requirements
- [ ] All 5 acceptance tests passing
- [ ] Contact picker accessible from ChatListView
- [ ] Search functionality works correctly
- [ ] Conversation creation succeeds
- [ ] No duplicate conversations created
- [ ] Empty state handles gracefully

### Technical Requirements
- [ ] All 8 unit tests passing
- [ ] All 5 integration tests passing
- [ ] All 5 edge cases handled
- [ ] All 3 performance benchmarks met
- [ ] No console errors or warnings
- [ ] No memory leaks detected

### Quality Requirements
- [ ] Smooth 60fps scrolling
- [ ] Fast load time (<2 seconds)
- [ ] Instant search (<100ms)
- [ ] Clean code (no TODOs or commented code)
- [ ] Documented (JSDoc on public methods)

### User Experience
- [ ] Intuitive UI (no user confusion in testing)
- [ ] Fast and responsive
- [ ] Error messages clear and helpful
- [ ] Animations smooth
- [ ] Works on physical device
- [ ] Accessible (VoiceOver compatible - bonus)

---

## Testing Sign-Off

**Tested By:** ___  
**Date:** ___  
**Result:** [ ] PASS [ ] FAIL  
**Notes:** ___

**Ready for Merge:** [ ] YES [ ] NO

---

*Complete all 26 tests before marking PR #8 as complete. This ensures production-quality contact selection functionality.*

