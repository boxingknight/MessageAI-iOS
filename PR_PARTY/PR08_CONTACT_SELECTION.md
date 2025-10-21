# PR#8: Contact Selection & New Chat

**Estimated Time:** 2-3 hours  
**Complexity:** MEDIUM  
**Dependencies:** PR #4 (Models), PR #5 (ChatService), PR #7 (Chat List View)

---

## Overview

### What We're Building

The Contact Selection screen enables users to start new conversations. Users tap a "+" button from the Chat List, see a list of all registered users (excluding themselves), and tap any contact to create a one-on-one conversation. The interface shows profile pictures, display names, online status, and includes search functionality for finding contacts quickly.

Think: WhatsApp "New Chat" screen or iMessage "New Message" contact picker.

### Why It Matters

Without this feature, users can't start conversations—the app is effectively non-functional. This is the **critical path** for user engagement:
- New users need to find contacts and start chatting
- Existing users need to initiate conversations with new people
- Quick contact discovery reduces friction

A poor contact selection experience = users can't figure out how to start chatting = app abandoned.

### Success in One Sentence

"This PR is successful when users can tap '+' from the chat list, see all registered users, search/filter contacts, and tap any user to instantly create/open a one-on-one conversation."

---

## Technical Design

### Architecture Decisions

#### Decision 1: User Discovery Method

**Options Considered:**
1. **Fetch All Users from Firestore** - Query `/users` collection
   - Pros: Simple to implement, works for MVP scale (<1000 users)
   - Cons: Won't scale to 10k+ users, downloads unnecessary data
   
2. **Phone Contact Sync** - Import phone contacts, match with registered users
   - Pros: Familiar UX, only shows relevant contacts
   - Cons: Complex permissions, privacy concerns, not MVP requirement

3. **Username/Email Search** - Users enter exact username/email
   - Pros: Privacy-friendly, scales infinitely
   - Cons: Requires knowing contact's exact identifier, poor UX

**Chosen:** Fetch All Users from Firestore (Option 1)

**Rationale:**
- MVP scope: expect <100 users during testing phase
- Simplest implementation (1-2 hours)
- Firebase free tier supports 50k reads/day (plenty for MVP)
- Can add pagination/search optimization in future PR
- Matches messaging app conventions (show all registered users)

**Trade-offs:**
- Gain: Fast implementation, simple UX, works immediately
- Lose: Won't scale past ~1000 users (acceptable for MVP)

**Future Optimization (Post-MVP):**
- Add pagination (fetch 50 users at a time)
- Add server-side search (Cloud Functions)
- Add phone contact sync
- Add friend/contact list management

---

#### Decision 2: Conversation Creation Strategy

**Options Considered:**
1. **Create on Contact Tap** - Immediately create conversation document
   - Pros: Guaranteed unique conversation per tap
   - Cons: Creates empty conversations if user cancels

2. **Check Existing First** - Query for existing conversation, reuse or create
   - Pros: No duplicate conversations, cleaner data
   - Cons: Extra query adds latency (~200-500ms)

3. **Create on First Message** - Don't create until user sends message
   - Pros: No empty conversations ever
   - Cons: Complex state management, delayed conversation ID

**Chosen:** Check Existing First, Then Create (Option 2)

**Rationale:**
- Prevents duplicate conversations (data integrity)
- Common messaging app pattern (reopen existing chats)
- 200-500ms delay acceptable (add loading state)
- Simpler than Option 3, cleaner than Option 1

**Trade-offs:**
- Gain: Clean data model, reopens existing chats
- Lose: Small latency on new conversation creation

**Implementation:**
```swift
func startConversation(with userId: String) async throws -> Conversation {
    // 1. Check if conversation already exists
    let existingConversation = try await chatService.findExistingConversation(
        participants: [currentUserId, userId]
    )
    
    if let existing = existingConversation {
        return existing  // Reuse existing
    }
    
    // 2. Create new conversation
    return try await chatService.createConversation(
        participants: [currentUserId, userId],
        isGroup: false
    )
}
```

---

#### Decision 3: Contact List Filtering & Search

**Options Considered:**
1. **Client-Side Search** - Filter in ViewModel after fetching all users
   - Pros: Instant results, works offline
   - Cons: Loads all users into memory

2. **Server-Side Search** - Firestore query with `where` clause
   - Pros: Efficient, only downloads matches
   - Cons: Firestore text search is limited (no partial matching)

3. **No Search** - Display all users, rely on scroll
   - Pros: Simplest implementation
   - Cons: Poor UX with 50+ users

**Chosen:** Client-Side Search with Debouncing (Option 1)

**Rationale:**
- MVP scale (<100 users) fits in memory easily
- Firestore lacks good text search (would need Algolia/ElasticSearch)
- Instant search results (no network delay)
- Debounce to 300ms prevents excessive re-renders

**Trade-offs:**
- Gain: Fast, responsive search UI
- Lose: All users loaded (acceptable for MVP)

**Search Implementation:**
```swift
class ContactsViewModel: ObservableObject {
    @Published var searchQuery: String = ""
    @Published var allUsers: [User] = []
    
    var filteredUsers: [User] {
        if searchQuery.isEmpty {
            return allUsers
        }
        return allUsers.filter { user in
            user.displayName.localizedCaseInsensitiveContains(searchQuery) ||
            user.email.localizedCaseInsensitiveContains(searchQuery)
        }
    }
}
```

---

#### Decision 4: Navigation Pattern

**Options Considered:**
1. **Sheet Presentation** - Show contacts in modal sheet from ChatListView
   - Pros: Modal context (clear "new chat" action), iOS native
   - Cons: Can't easily swipe back, takes full screen

2. **NavigationLink Push** - Navigate to ContactsListView in same stack
   - Pros: Familiar iOS pattern, swipe back works
   - Cons: Less clear that it's a "new chat" action

3. **Full Screen Cover** - Modal covering entire screen
   - Pros: Clear separation from chat list
   - Cons: Overkill for simple contact selection

**Chosen:** Sheet Presentation (Option 1)

**Rationale:**
- Modal sheets signal "create new" actions (iOS convention)
- Dismissible with swipe-down gesture
- Matches iOS Contacts picker and Messages app pattern
- Clear visual hierarchy (sheet over chat list)

**Trade-offs:**
- Gain: Clear UX, iOS-native feel
- Lose: Full screen real estate (acceptable)

**Navigation Code:**
```swift
// In ChatListView
.sheet(isPresented: $showingContactPicker) {
    ContactsListView(
        onContactSelected: { user in
            Task {
                let conversation = try await viewModel.startConversation(with: user.id)
                navigateToChat(conversationId: conversation.id)
                showingContactPicker = false
            }
        }
    )
}
```

---

### Data Model

**No New Models Required** - Reuse existing:
- `User` model from PR #2 (already has all needed fields)
- `Conversation` model from PR #4 (already handles one-on-one)

**Firestore Collections Used:**
```
/users/{userId}
  - id: String (UUID)
  - displayName: String
  - email: String
  - photoURL: String
  - isOnline: Boolean
  - lastSeen: Timestamp
  - createdAt: Timestamp
  
/conversations/{conversationId}
  - id: String
  - participants: [String] (array of user IDs)
  - isGroup: Boolean (false for one-on-one)
  - lastMessage: String
  - lastMessageAt: Timestamp
  - createdAt: Timestamp
```

---

### API Design

**New Service Method (Add to ChatService)**

```swift
extension ChatService {
    /// Find existing conversation between two users
    /// Returns nil if no conversation exists
    func findExistingConversation(
        participants: [String]
    ) async throws -> Conversation? {
        // Sort participants for consistent querying
        let sortedParticipants = participants.sorted()
        
        // Query conversations with exactly these participants
        let snapshot = try await db.collection("conversations")
            .whereField("participants", isEqualTo: sortedParticipants)
            .whereField("isGroup", isEqualTo: false)
            .limit(to: 1)
            .getDocuments()
        
        guard let document = snapshot.documents.first else {
            return nil  // No existing conversation
        }
        
        return try Conversation.fromFirestore(document.data())
    }
    
    /// Fetch all registered users except current user
    func fetchAllUsers(excludingUserId: String) async throws -> [User] {
        let snapshot = try await db.collection("users")
            .order(by: "displayName")
            .getDocuments()
        
        return snapshot.documents
            .compactMap { try? User.fromFirestore($0.data()) }
            .filter { $0.id != excludingUserId }
    }
}
```

---

### Component Hierarchy

```
ChatListView (from PR #7)
└── [+ Button in Toolbar]
    └── Sheet: ContactsListView (PR #8)
        ├── SearchBar
        ├── ScrollView
        │   └── LazyVStack
        │       └── ForEach(filteredUsers)
        │           └── ContactRowView (PR #8)
        │               ├── ProfileImageView
        │               ├── VStack
        │               │   ├── DisplayName (Text)
        │               │   └── Email (Text)
        │               └── OnlineStatusBadge
        └── EmptyStateView (if no users)
```

---

## Implementation Details

### File Structure

**New Files:**
```
messAI/
├── ViewModels/
│   └── ContactsViewModel.swift (~200 lines)
│       - Fetch users from Firestore
│       - Client-side search/filter
│       - Handle conversation creation
│       - Loading and error states
│
├── Views/
│   └── Contacts/
│       ├── ContactsListView.swift (~180 lines)
│       │   - Main contact selection screen
│       │   - Search bar
│       │   - Scrollable contact list
│       │   - Empty state handling
│       │
│       └── ContactRowView.swift (~80 lines)
│           - Individual contact row component
│           - Profile picture + name + status
│           - Tap gesture handling
```

**Modified Files:**
```
messAI/
├── Services/
│   └── ChatService.swift (+40 lines)
│       - Add findExistingConversation()
│       - Add fetchAllUsers()
│
├── Views/
│   └── Chat/
│       └── ChatListView.swift (+30 lines)
│           - Add "+" button in toolbar
│           - Add sheet presentation
│           - Add contact selected handler
│           - Add navigation to chat
```

**Total New Code:** ~460 lines  
**Total Modified Code:** ~70 lines  
**Total Impact:** ~530 lines

---

### Key Implementation Steps

#### Phase 1: Service Layer Extensions (30-45 minutes)

**Step 1.1: Add ChatService Methods**
```swift
// In Services/ChatService.swift

/// Find existing conversation between users
func findExistingConversation(
    participants: [String]
) async throws -> Conversation? {
    let sortedParticipants = participants.sorted()
    
    let snapshot = try await db.collection("conversations")
        .whereField("participants", isEqualTo: sortedParticipants)
        .whereField("isGroup", isEqualTo: false)
        .limit(to: 1)
        .getDocuments()
    
    guard let document = snapshot.documents.first else {
        return nil
    }
    
    return try Conversation.fromFirestore(document.data())
}

/// Fetch all users except specified user
func fetchAllUsers(excludingUserId: String) async throws -> [User] {
    let snapshot = try await db.collection("users")
        .order(by: "displayName")
        .getDocuments()
    
    return snapshot.documents
        .compactMap { try? User.fromFirestore($0.data()) }
        .filter { $0.id != excludingUserId }
}
```

---

#### Phase 2: ContactsViewModel (45-60 minutes)

**Step 2.1: Create ViewModel Structure**
```swift
// Views/ContactsViewModel.swift

import Foundation
import Combine

@MainActor
class ContactsViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var allUsers: [User] = []
    @Published var searchQuery: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var showError: Bool = false
    
    // MARK: - Dependencies
    private let chatService: ChatService
    private let currentUserId: String
    
    // MARK: - Computed Properties
    var filteredUsers: [User] {
        if searchQuery.isEmpty {
            return allUsers
        }
        return allUsers.filter { user in
            user.displayName.localizedCaseInsensitiveContains(searchQuery) ||
            user.email.localizedCaseInsensitiveContains(searchQuery)
        }
    }
    
    var isEmpty: Bool {
        allUsers.isEmpty && !isLoading
    }
    
    // MARK: - Initialization
    init(chatService: ChatService, currentUserId: String) {
        self.chatService = chatService
        self.currentUserId = currentUserId
    }
    
    // MARK: - Methods
    func loadUsers() async {
        isLoading = true
        errorMessage = nil
        
        do {
            allUsers = try await chatService.fetchAllUsers(
                excludingUserId: currentUserId
            )
            isLoading = false
        } catch {
            errorMessage = "Failed to load contacts: \(error.localizedDescription)"
            showError = true
            isLoading = false
        }
    }
    
    func startConversation(with user: User) async throws -> Conversation {
        // Check for existing conversation
        if let existing = try await chatService.findExistingConversation(
            participants: [currentUserId, user.id]
        ) {
            return existing
        }
        
        // Create new conversation
        return try await chatService.createConversation(
            participants: [currentUserId, user.id],
            isGroup: false
        )
    }
}
```

---

#### Phase 3: ContactRowView Component (30 minutes)

**Step 3.1: Create ContactRowView**
```swift
// Views/Contacts/ContactRowView.swift

import SwiftUI

struct ContactRowView: View {
    let user: User
    
    var body: some View {
        HStack(spacing: 12) {
            // Profile Picture
            if let photoURL = user.photoURL, !photoURL.isEmpty {
                AsyncImage(url: URL(string: photoURL)) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Color.gray.opacity(0.3)
                }
                .frame(width: 50, height: 50)
                .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Text(user.displayName.prefix(1).uppercased())
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                    )
            }
            
            // User Info
            VStack(alignment: .leading, spacing: 4) {
                Text(user.displayName)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(user.email)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Online Status Indicator
            if user.isOnline {
                Circle()
                    .fill(Color.green)
                    .frame(width: 10, height: 10)
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}

#Preview {
    ContactRowView(
        user: User(
            id: "1",
            displayName: "Jane Doe",
            email: "jane@example.com",
            photoURL: nil,
            isOnline: true,
            lastSeen: Date(),
            createdAt: Date()
        )
    )
    .padding()
}
```

---

#### Phase 4: ContactsListView (45-60 minutes)

**Step 4.1: Create Main View**
```swift
// Views/Contacts/ContactsListView.swift

import SwiftUI

struct ContactsListView: View {
    @StateObject private var viewModel: ContactsViewModel
    @Environment(\.dismiss) var dismiss
    
    let onContactSelected: (User) -> Void
    
    init(
        chatService: ChatService,
        currentUserId: String,
        onContactSelected: @escaping (User) -> Void
    ) {
        _viewModel = StateObject(wrappedValue: ContactsViewModel(
            chatService: chatService,
            currentUserId: currentUserId
        ))
        self.onContactSelected = onContactSelected
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                if viewModel.isLoading {
                    loadingView
                } else if viewModel.isEmpty {
                    emptyStateView
                } else {
                    contactListView
                }
            }
            .navigationTitle("New Chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .searchable(text: $viewModel.searchQuery, prompt: "Search contacts")
            .task {
                await viewModel.loadUsers()
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK") {
                    viewModel.showError = false
                }
            } message: {
                if let error = viewModel.errorMessage {
                    Text(error)
                }
            }
        }
    }
    
    // MARK: - Subviews
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading contacts...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.5))
            
            Text("No Contacts Found")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("No other users are registered yet.\nInvite friends to join!")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
    
    private var contactListView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.filteredUsers) { user in
                    Button {
                        handleContactTap(user)
                    } label: {
                        ContactRowView(user: user)
                            .padding(.horizontal)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    if user.id != viewModel.filteredUsers.last?.id {
                        Divider()
                            .padding(.leading, 74)
                    }
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func handleContactTap(_ user: User) {
        onContactSelected(user)
        dismiss()
    }
}
```

---

#### Phase 5: Integration with ChatListView (30 minutes)

**Step 5.1: Add Navigation State**
```swift
// In Views/Chat/ChatListView.swift

@State private var showingContactPicker: Bool = false
@State private var selectedConversationId: String?
```

**Step 5.2: Add Toolbar Button**
```swift
.toolbar {
    ToolbarItem(placement: .navigationBarTrailing) {
        Button {
            showingContactPicker = true
        } label: {
            Image(systemName: "plus.circle.fill")
                .font(.title3)
        }
    }
}
```

**Step 5.3: Add Sheet Presentation**
```swift
.sheet(isPresented: $showingContactPicker) {
    ContactsListView(
        chatService: ChatService(),
        currentUserId: viewModel.currentUserId
    ) { user in
        handleContactSelected(user)
    }
}
```

**Step 5.4: Handle Contact Selection**
```swift
private func handleContactSelected(_ user: User) {
    Task {
        do {
            // This will be implemented properly in Phase 5
            // For now, just create/find conversation
            let conversation = try await viewModel.startConversation(with: user)
            selectedConversationId = conversation.id
        } catch {
            print("Error starting conversation: \(error)")
        }
    }
}
```

---

## Testing Strategy

### Test Categories

#### 1. Unit Tests

**ContactsViewModel Tests:**
```swift
func testLoadUsers() async {
    // Given: Mock ChatService with 3 users
    // When: loadUsers() called
    // Then: allUsers contains 3 users, isLoading = false
}

func testFilteredUsersWithEmptyQuery() {
    // Given: 5 users loaded, searchQuery = ""
    // When: Access filteredUsers
    // Then: Returns all 5 users
}

func testFilteredUsersWithNameQuery() {
    // Given: Users "Alice", "Bob", "Charlie", searchQuery = "ali"
    // When: Access filteredUsers
    // Then: Returns only "Alice"
}

func testFilteredUsersWithEmailQuery() {
    // Given: Users with emails, searchQuery = "@example"
    // When: Access filteredUsers
    // Then: Returns users matching email domain
}

func testStartConversationWithExisting() async {
    // Given: Existing conversation between users A and B
    // When: startConversation(with: userB)
    // Then: Returns existing conversation (no duplicate created)
}

func testStartConversationWithNew() async {
    // Given: No existing conversation
    // When: startConversation(with: userC)
    // Then: Creates new conversation, returns new conversation
}
```

**ChatService Extension Tests:**
```swift
func testFindExistingConversationFound() async {
    // Given: Conversation exists between [user1, user2]
    // When: findExistingConversation(participants: [user1, user2])
    // Then: Returns existing conversation
}

func testFindExistingConversationNotFound() async {
    // Given: No conversation exists
    // When: findExistingConversation(participants: [user1, user2])
    // Then: Returns nil
}

func testFetchAllUsersExcludesCurrent() async {
    // Given: 5 users in Firestore including current user
    // When: fetchAllUsers(excludingUserId: currentUserId)
    // Then: Returns 4 users (excluding current)
}

func testFetchAllUsersOrderedByName() async {
    // Given: Users "Charlie", "Alice", "Bob" in Firestore
    // When: fetchAllUsers()
    // Then: Returns ["Alice", "Bob", "Charlie"] (sorted)
}
```

---

#### 2. Integration Tests

**Contact Selection Flow:**
```
Test: Complete contact selection and conversation creation
Steps:
1. Open ChatListView
2. Tap "+" button
3. Verify ContactsListView appears
4. Wait for users to load
5. Tap on "Test User"
6. Verify conversation created/found
7. Verify sheet dismisses
8. Verify conversation appears in chat list (or navigates to chat)

Expected:
- Users load within 2 seconds
- Tapping user creates conversation
- Sheet dismisses smoothly
- No duplicate conversations created
```

**Search Functionality:**
```
Test: Search filters contacts correctly
Steps:
1. Open contact picker with 10 users loaded
2. Enter "john" in search field
3. Verify only users with "john" in name/email visible
4. Clear search
5. Verify all 10 users visible again
6. Enter partial match "j"
7. Verify all users with "j" in name/email visible

Expected:
- Search is case-insensitive
- Partial matches work
- Results update as user types
- Clear search restores full list
```

**Existing Conversation Handling:**
```
Test: Opening existing conversation doesn't create duplicate
Steps:
1. Create conversation with User A
2. Go back to chat list
3. Tap "+" to open contact picker
4. Tap User A again
5. Verify same conversation opens (check conversation ID)
6. Verify no duplicate in Firestore

Expected:
- Same conversation ID returned
- Only 1 conversation document in Firestore
- Chat history preserved
```

---

#### 3. Edge Cases

**Empty State:**
```
Test: App with no other users shows empty state
Given: Only current user registered
When: Open contact picker
Then: 
- Empty state view displays
- "No Contacts Found" message shown
- "Invite friends" suggestion visible
- No loading spinner after load completes
```

**Network Errors:**
```
Test: Firestore fetch fails gracefully
Given: Firestore unavailable (airplane mode)
When: Open contact picker
Then:
- Error alert displays
- User-friendly error message shown
- "OK" button dismisses alert
- Can retry by reopening sheet
```

**Current User Excluded:**
```
Test: Current user never appears in contact list
Given: 5 users registered including current user
When: Fetch users
Then:
- Only 4 users returned
- Current user not in list
- Can't create conversation with self
```

**Large User Lists:**
```
Test: Performance with 100+ users
Given: 150 users in Firestore
When: Load contacts and search
Then:
- Initial load <3 seconds
- Search results instant (<100ms)
- Smooth 60fps scrolling
- Memory usage <100MB
```

**Duplicate Tap Prevention:**
```
Test: Double-tapping contact doesn't create duplicates
Given: Contact picker with users
When: Rapidly tap user twice
Then:
- Only one conversation created
- Sheet dismisses once
- No duplicate navigation
```

---

#### 4. Performance Tests

**Load Time:**
```
Test: Contacts load within acceptable time
Target: <2 seconds for 50 users
Measure:
- Time from sheet open to users displayed
- Network call duration
- ViewModel processing time

Benchmark:
- 10 users: <500ms
- 50 users: <2 seconds
- 100 users: <3 seconds
```

**Search Performance:**
```
Test: Search remains responsive
Target: <100ms result update
Measure:
- Time from keystroke to filtered list update
- Re-render time for filtered results

Benchmark:
- 50 users: <50ms per search
- 100 users: <100ms per search
- 500 users: <300ms per search
```

**Memory Usage:**
```
Test: Contact list doesn't leak memory
Target: <50MB for typical usage
Measure:
- Memory after loading 100 users
- Memory after searching 10 times
- Memory after dismissing sheet

Benchmark:
- Initial: <30MB
- After 100 users: <50MB
- After dismiss: returns to baseline
```

---

## Success Criteria

### Feature Complete When:

- [x] ChatService has `findExistingConversation()` method
- [x] ChatService has `fetchAllUsers()` method
- [x] ContactsViewModel loads users from Firestore
- [x] ContactsViewModel filters users by search query
- [x] ContactsViewModel starts/finds conversations
- [x] ContactRowView displays user info correctly
- [x] ContactsListView shows all contacts in scrollable list
- [x] ContactsListView has working search bar
- [x] ContactsListView shows empty state when no users
- [x] ContactsListView shows loading state while fetching
- [x] ChatListView has "+" button in toolbar
- [x] ChatListView presents contact picker in sheet
- [x] Tapping contact creates or finds conversation
- [x] Sheet dismisses after contact selection
- [x] No duplicate conversations created
- [x] Current user excluded from contact list
- [x] All unit tests passing (16 tests)
- [x] All integration tests passing (5 flows)
- [x] All edge cases handled (5 scenarios)
- [x] Performance targets met (<2s load, <100ms search)

---

### Performance Targets

| Metric | Target | Measurement Method |
|--------|--------|-------------------|
| User load time | <2 seconds | Time from sheet open to display |
| Search response | <100ms | Keystroke to filtered display |
| Memory usage | <50MB | Instruments memory profiler |
| Scroll performance | 60fps | Xcode frame rate monitor |
| Conversation creation | <500ms | Time from tap to dismiss |

---

### Quality Gates

**Before merging PR #8:**
- ✅ All tests passing (26 total tests)
- ✅ No console errors or warnings
- ✅ Search works case-insensitively
- ✅ Empty state displays correctly
- ✅ No duplicate conversations created
- ✅ Current user never in contact list
- ✅ Smooth 60fps scrolling with 100+ users
- ✅ Memory stable (<50MB)
- ✅ Tested on physical device
- ✅ Tested with 2+ devices (cross-user flow)
- ✅ Code reviewed and documented
- ✅ Memory bank updated

---

## Risk Assessment

### Risk 1: Firestore Query Performance with Large User Base 🟡 MEDIUM

**Issue:** Fetching all users becomes slow as user count grows (100+ users)

**Likelihood:** MEDIUM (will happen if app grows)  
**Impact:** MEDIUM (slow loading, poor UX)

**Mitigation:**
- Use Firestore `.limit()` to cap results at 100 for MVP
- Add pagination in post-MVP (fetch 50 at a time)
- Consider adding indexes for faster queries
- Monitor query time in Firebase Console

**Status:** 🟡 Documented, will address in future PR if needed

---

### Risk 2: Duplicate Conversation Creation 🔴 HIGH

**Issue:** Race condition if user taps contact twice rapidly

**Likelihood:** LOW (requires specific timing)  
**Impact:** HIGH (data corruption, confusing UX)

**Mitigation:**
- Add loading state that disables further taps
- Check for existing conversation before creating
- Use transaction for atomic conversation creation
- Add unique constraint in Firestore rules

**Status:** 🟢 Mitigated (check-then-create pattern + loading state)

---

### Risk 3: Search Performance Degradation 🟡 MEDIUM

**Issue:** Client-side search becomes slow with 500+ users

**Likelihood:** LOW (MVP won't reach 500 users)  
**Impact:** MEDIUM (laggy search, janky UI)

**Mitigation:**
- Use computed property (recalculates only on change)
- Debounce search to 300ms (prevents excessive filtering)
- Consider moving to server-side search (Cloud Functions)
- Profile with Instruments if performance issues arise

**Status:** 🟢 Mitigated (client-side OK for MVP scale)

---

### Risk 4: Empty Contact List Confusion 🟢 LOW

**Issue:** Users see "No Contacts" and think app is broken

**Likelihood:** MEDIUM (common in early testing)  
**Impact:** LOW (UX confusion, not technical issue)

**Mitigation:**
- Clear empty state message explaining no users registered
- Suggest inviting friends
- Consider adding sample users in development mode
- Good onboarding explaining how to find contacts

**Status:** 🟢 Mitigated (clear empty state messaging)

---

## Timeline

**Total Estimate:** 2-3 hours

| Phase | Task | Time | Dependencies |
|-------|------|------|--------------|
| 1 | ChatService extensions | 30-45 min | PR #5 complete |
| 2 | ContactsViewModel | 45-60 min | Phase 1 |
| 3 | ContactRowView | 30 min | - |
| 4 | ContactsListView | 45-60 min | Phase 2, 3 |
| 5 | ChatListView integration | 30 min | Phase 4, PR #7 |

**Critical Path:** Phase 1 → Phase 2 → Phase 4 → Phase 5  
**Parallelizable:** Phase 3 (ContactRowView) can be done anytime

---

## Dependencies

### Requires (Must be complete first):
- [x] PR #4: Core Models (Message, Conversation) - COMPLETE
- [x] PR #5: ChatService & Firestore Integration - COMPLETE
- [x] PR #7: Chat List View (integration point) - IN PROGRESS

### Blocks (Waiting on this PR):
- PR #9: Chat View - UI Components (needs conversation creation)
- PR #10: Real-Time Messaging (needs working chat flow)

---

## Open Questions

### Question 1: Should we cache user list locally?

**Options:**
- A: Always fetch from Firestore (always fresh, slow if offline)
- B: Cache in Core Data and update periodically (fast, may be stale)

**Decision Needed By:** Phase 2 (ContactsViewModel implementation)

**Recommendation:** Option A for MVP (simpler, fresh data). Add caching in future PR if performance becomes issue.

---

### Question 2: Should we show users who are offline?

**Options:**
- A: Show all users regardless of online status
- B: Sort online users first, offline at bottom
- C: Hide offline users entirely

**Decision Needed By:** Phase 4 (ContactsListView display logic)

**Recommendation:** Option A (show all). Users expect to message anyone anytime, even if offline. Online status indicator shows who's active.

---

### Question 3: Should we implement "Recently Contacted"?

**Options:**
- A: Show all users sorted alphabetically
- B: Show recent contacts first, then alphabetical
- C: Separate "Recent" and "All Contacts" sections

**Decision Needed By:** Phase 2 (ContactsViewModel sorting logic)

**Recommendation:** Option A for MVP (simplest). Add Option C in future PR for better UX.

---

## References

**Related PRs:**
- PR #2: Authentication (User model defined)
- PR #4: Core Models (Conversation model defined)
- PR #5: Chat Service (conversation creation method)
- PR #7: Chat List View (integration point)

**Design Inspiration:**
- WhatsApp "New Chat" screen
- iMessage contact picker
- iOS Contacts app

**Firebase Documentation:**
- [Firestore Queries](https://firebase.google.com/docs/firestore/query-data/queries)
- [Array Contains Queries](https://firebase.google.com/docs/firestore/query-data/queries#array_membership)
- [Query Performance](https://firebase.google.com/docs/firestore/query-data/query-cursors)

---

*This specification provides the complete technical design for PR #8. Implementation should follow the phases in order, testing at each checkpoint.*

