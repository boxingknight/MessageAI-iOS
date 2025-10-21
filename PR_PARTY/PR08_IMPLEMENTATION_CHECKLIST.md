# PR#8: Contact Selection & New Chat - Implementation Checklist

**Use this as your daily todo list.** Check off items as you complete them.

---

## Pre-Implementation Setup (10 minutes)

- [ ] Read main planning document `PR08_CONTACT_SELECTION.md` (~30 min)
- [ ] Verify PR #7 (Chat List View) is complete and merged
- [ ] Verify PR #5 (ChatService) is available
- [ ] Git branch created
  ```bash
  git checkout main
  git pull origin main
  git checkout -b feature/pr08-contact-selection
  ```
- [ ] Xcode project opens without errors
- [ ] Firebase connected and authenticated

---

## Phase 1: ChatService Extensions (30-45 minutes)

### 1.1: Add findExistingConversation Method (15-20 min)

#### Open ChatService
- [ ] Open `messAI/Services/ChatService.swift`
- [ ] Scroll to bottom of class (before closing brace)

#### Add Method
- [ ] Add new method:
  ```swift
  /// Find existing conversation between two users
  /// Returns nil if no conversation exists
  func findExistingConversation(
      participants: [String]
  ) async throws -> Conversation? {
      // Sort participants for consistent querying
      let sortedParticipants = participants.sorted()
      
      do {
          // Query conversations with exactly these participants
          let snapshot = try await db.collection("conversations")
              .whereField("participants", isEqualTo: sortedParticipants)
              .whereField("isGroup", isEqualTo: false)
              .limit(to: 1)
              .getDocuments()
          
          // Return nil if no conversation found
          guard let document = snapshot.documents.first else {
              return nil
          }
          
          // Convert Firestore document to Conversation
          return try Conversation.fromFirestore(document.data())
          
      } catch {
          print("Error finding existing conversation: \(error)")
          throw ChatError.conversationNotFound
      }
  }
  ```

#### Test Method
- [ ] Build project: `Cmd + B`
- [ ] Verify no errors
- [ ] Method signature matches Conversation model

**Checkpoint:** `findExistingConversation()` compiles ✓

**Commit:**
```bash
git add messAI/Services/ChatService.swift
git commit -m "[PR #8] Add findExistingConversation method to ChatService"
```

---

### 1.2: Add fetchAllUsers Method (15-20 min)

#### Add Method
- [ ] Add new method to `ChatService.swift`:
  ```swift
  /// Fetch all registered users except specified user
  /// Returns users sorted alphabetically by display name
  func fetchAllUsers(excludingUserId: String) async throws -> [User] {
      do {
          let snapshot = try await db.collection("users")
              .order(by: "displayName")
              .getDocuments()
          
          // Convert documents to User objects and filter out current user
          let users = snapshot.documents
              .compactMap { document -> User? in
                  try? User.fromFirestore(document.data())
              }
              .filter { $0.id != excludingUserId }
          
          return users
          
      } catch {
          print("Error fetching users: \(error)")
          throw ChatError.invalidData
      }
  }
  ```

#### Test Method
- [ ] Build project: `Cmd + B`
- [ ] Verify no errors
- [ ] Method returns `[User]` array

**Checkpoint:** `fetchAllUsers()` compiles ✓

**Commit:**
```bash
git add messAI/Services/ChatService.swift
git commit -m "[PR #8] Add fetchAllUsers method to ChatService"
```

---

## Phase 2: ContactsViewModel (45-60 minutes)

### 2.1: Create ViewModel File (30-40 min)

#### Create File
- [ ] In Xcode, right-click `ViewModels` folder
- [ ] New File → Swift File
- [ ] Name: `ContactsViewModel.swift`
- [ ] Target: messAI
- [ ] Create

#### Add Imports
- [ ] Add imports:
  ```swift
  import Foundation
  import Combine
  ```

#### Add ViewModel Class
- [ ] Add class structure:
  ```swift
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
          // Check for existing conversation first
          if let existing = try await chatService.findExistingConversation(
              participants: [currentUserId, user.id]
          ) {
              return existing
          }
          
          // Create new conversation if none exists
          return try await chatService.createConversation(
              participants: [currentUserId, user.id],
              isGroup: false
          )
      }
  }
  ```

#### Test ViewModel
- [ ] Build project: `Cmd + B`
- [ ] Verify no errors
- [ ] All @Published properties compile
- [ ] filteredUsers computed property works
- [ ] Methods have correct signatures

**Checkpoint:** ContactsViewModel compiles ✓

**Commit:**
```bash
git add messAI/ViewModels/ContactsViewModel.swift
git commit -m "[PR #8] Create ContactsViewModel with search and conversation logic"
```

---

## Phase 3: ContactRowView Component (30 minutes)

### 3.1: Create Contacts Folder (2 min)

- [ ] In Xcode, right-click `Views` folder
- [ ] New Group → Name: `Contacts`

### 3.2: Create ContactRowView (25 min)

#### Create File
- [ ] Right-click `Views/Contacts` folder
- [ ] New File → SwiftUI View
- [ ] Name: `ContactRowView.swift`
- [ ] Target: messAI
- [ ] Create

#### Implement View
- [ ] Replace template with:
  ```swift
  import SwiftUI

  struct ContactRowView: View {
      let user: User
      
      var body: some View {
          HStack(spacing: 12) {
              // Profile Picture
              profilePicture
              
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
      
      @ViewBuilder
      private var profilePicture: some View {
          if let photoURL = user.photoURL, !photoURL.isEmpty {
              AsyncImage(url: URL(string: photoURL)) { phase in
                  switch phase {
                  case .success(let image):
                      image
                          .resizable()
                          .scaledToFill()
                          .frame(width: 50, height: 50)
                          .clipShape(Circle())
                  case .failure, .empty:
                      placeholderImage
                  @unknown default:
                      placeholderImage
                  }
              }
          } else {
              placeholderImage
          }
      }
      
      private var placeholderImage: some View {
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
  }

  #Preview {
      VStack(spacing: 0) {
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
          .padding(.horizontal)
          
          Divider()
          
          ContactRowView(
              user: User(
                  id: "2",
                  displayName: "John Smith",
                  email: "john@example.com",
                  photoURL: nil,
                  isOnline: false,
                  lastSeen: Date(),
                  createdAt: Date()
              )
          )
          .padding(.horizontal)
      }
  }
  ```

#### Test View
- [ ] Build project: `Cmd + B`
- [ ] Open preview: `Cmd + Option + P`
- [ ] Verify row displays correctly
- [ ] Check online/offline status shows
- [ ] Verify initials show when no photo
- [ ] Test light and dark mode

**Checkpoint:** ContactRowView displays correctly ✓

**Commit:**
```bash
git add messAI/Views/Contacts/ContactRowView.swift
git commit -m "[PR #8] Create ContactRowView component with profile picture and status"
```

---

## Phase 4: ContactsListView (45-60 minutes)

### 4.1: Create Main View File (40-50 min)

#### Create File
- [ ] Right-click `Views/Contacts` folder
- [ ] New File → SwiftUI View
- [ ] Name: `ContactsListView.swift`
- [ ] Target: messAI
- [ ] Create

#### Implement View Structure
- [ ] Replace template with:
  ```swift
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
      }
  }

  #Preview {
      ContactsListView(
          chatService: ChatService(),
          currentUserId: "test-user-id"
      ) { user in
          print("Selected: \(user.displayName)")
      }
  }
  ```

#### Test View
- [ ] Build project: `Cmd + B`
- [ ] Open preview: `Cmd + Option + P`
- [ ] Verify navigation bar shows "New Chat"
- [ ] Check cancel button appears
- [ ] Verify loading view displays
- [ ] Check empty state displays
- [ ] Verify search bar appears

**Checkpoint:** ContactsListView structure complete ✓

**Commit:**
```bash
git add messAI/Views/Contacts/ContactsListView.swift
git commit -m "[PR #8] Create ContactsListView with search, empty state, and loading"
```

---

## Phase 5: ChatListView Integration (30 minutes)

### 5.1: Add Navigation State (5 min)

- [ ] Open `messAI/Views/Chat/ChatListView.swift`
- [ ] Find `@StateObject` declarations at top of struct
- [ ] Add state variables:
  ```swift
  @State private var showingContactPicker: Bool = false
  ```

**Checkpoint:** State variables added ✓

---

### 5.2: Add Toolbar Button (10 min)

- [ ] Find `.navigationTitle("Chats")` in ChatListView
- [ ] After `.navigationTitle()`, add toolbar:
  ```swift
  .toolbar {
      ToolbarItem(placement: .navigationBarTrailing) {
          Button {
              showingContactPicker = true
          } label: {
              Image(systemName: "plus.circle.fill")
                  .font(.title3)
                  .foregroundColor(.blue)
          }
      }
  }
  ```

#### Test Toolbar
- [ ] Build and run: `Cmd + R`
- [ ] Verify "+" button appears in top-right
- [ ] Tap button (nothing happens yet - expected)

**Checkpoint:** Toolbar button visible ✓

**Commit:**
```bash
git add messAI/Views/Chat/ChatListView.swift
git commit -m "[PR #8] Add '+' button to ChatListView toolbar"
```

---

### 5.3: Add Sheet Presentation (10 min)

- [ ] Find the closing brace of ChatListView's body
- [ ] Before the last closing brace, add sheet modifier:
  ```swift
  .sheet(isPresented: $showingContactPicker) {
      if let currentUserId = Auth.auth().currentUser?.uid {
          ContactsListView(
              chatService: ChatService(),
              currentUserId: currentUserId
          ) { selectedUser in
              handleContactSelected(selectedUser)
          }
      }
  }
  ```

- [ ] Add Firebase Auth import at top:
  ```swift
  import FirebaseAuth
  ```

#### Test Sheet
- [ ] Build and run: `Cmd + R`
- [ ] Tap "+" button
- [ ] Verify contact picker sheet appears
- [ ] Check search bar works
- [ ] Tap "Cancel" to dismiss

**Checkpoint:** Sheet presentation working ✓

---

### 5.4: Handle Contact Selection (15 min)

- [ ] Add method to ChatListView:
  ```swift
  private func handleContactSelected(_ user: User) {
      Task {
          do {
              // Find or create conversation
              let conversation = try await viewModel.startConversation(with: user)
              
              // TODO (PR #9): Navigate to chat view
              // For now, just close the sheet
              showingContactPicker = false
              
              print("✅ Conversation ready: \(conversation.id)")
              
          } catch {
              print("❌ Error starting conversation: \(error)")
              // TODO (PR #19): Show error alert
          }
      }
  }
  ```

- [ ] Add method to ChatListViewModel:
  ```swift
  func startConversation(with user: User) async throws -> Conversation {
      let currentUserId = Auth.auth().currentUser?.uid ?? ""
      
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
  ```

- [ ] Add FirebaseAuth import to ChatListViewModel:
  ```swift
  import FirebaseAuth
  ```

#### Test Flow
- [ ] Build and run: `Cmd + R` (on simulator)
- [ ] Tap "+" button
- [ ] Wait for contacts to load
- [ ] Tap a contact
- [ ] Check console for "✅ Conversation ready: [id]"
- [ ] Verify sheet dismisses

**Checkpoint:** Contact selection flow complete ✓

**Commit:**
```bash
git add messAI/Views/Chat/ChatListView.swift
git add messAI/ViewModels/ChatListViewModel.swift
git commit -m "[PR #8] Integrate contact picker with ChatListView and handle conversation creation"
```

---

## Testing Phase (30-45 minutes)

### Manual Testing Checklist

#### Test 1: Contact Loading
- [ ] Open app and sign in
- [ ] Tap "+" button in chat list
- [ ] Verify loading spinner appears briefly
- [ ] Verify contacts load within 2 seconds
- [ ] Contacts sorted alphabetically by name
- [ ] Current user NOT in list

**Expected:** Contacts load fast and correctly ✓

---

#### Test 2: Search Functionality
- [ ] Open contact picker
- [ ] Type partial name in search (e.g., "joh")
- [ ] Verify only matching users appear
- [ ] Clear search
- [ ] Verify all users reappear
- [ ] Type email domain (e.g., "@gmail")
- [ ] Verify users with matching emails appear

**Expected:** Search filters instantly and correctly ✓

---

#### Test 3: New Conversation Creation
- [ ] Open contact picker
- [ ] Select a user you haven't chatted with
- [ ] Wait for sheet to dismiss
- [ ] Check console for "✅ Conversation ready"
- [ ] Go to Firebase Console → Firestore
- [ ] Verify new conversation document created
- [ ] Check participants array contains both user IDs

**Expected:** New conversation created successfully ✓

---

#### Test 4: Existing Conversation Reopening
- [ ] Open contact picker again
- [ ] Select the SAME user from Test 3
- [ ] Check console for conversation ID
- [ ] Verify ID matches previous conversation (reused)
- [ ] Go to Firebase Console
- [ ] Verify no duplicate conversation created

**Expected:** Existing conversation reused, no duplicate ✓

---

#### Test 5: Empty State
- [ ] Sign out current user
- [ ] Create new user account (with no other users registered)
- [ ] Tap "+" button
- [ ] Verify empty state displays
- [ ] Check message says "No Contacts Found"
- [ ] Verify "Invite friends" suggestion shown

**Expected:** Empty state displays correctly ✓

---

#### Test 6: Profile Pictures
- [ ] Open contact picker
- [ ] Find user with profile picture
- [ ] Verify picture loads and displays in circle
- [ ] Find user without profile picture
- [ ] Verify initials appear in placeholder circle
- [ ] Check placeholder has colored background

**Expected:** Profile pictures display correctly ✓

---

#### Test 7: Online Status
- [ ] Open contact picker
- [ ] Find user who is online (green dot visible)
- [ ] Verify green indicator shows
- [ ] Find user who is offline (no green dot)
- [ ] Verify no indicator (or gray indicator if implemented)

**Expected:** Online status displays correctly ✓

---

#### Test 8: Two-Device Flow (Physical Devices)
- [ ] Device A: Sign in as User A
- [ ] Device B: Sign in as User B
- [ ] Device A: Tap "+", see User B in list
- [ ] Device A: Tap User B
- [ ] Device A: Check console for conversation ID
- [ ] Device B: Open app (conversation should appear in list)
- [ ] Device B: Tap "+", see User A
- [ ] Device B: Tap User A
- [ ] Device B: Check console - should be SAME conversation ID

**Expected:** Both devices create/use same conversation ✓

---

#### Test 9: Performance with Many Users
- [ ] Add 20+ test users to Firestore (manual or script)
- [ ] Open contact picker
- [ ] Measure load time (<2 seconds)
- [ ] Scroll through list (60fps, smooth)
- [ ] Search for user (instant results)
- [ ] Open Xcode Instruments → Memory
- [ ] Verify memory <50MB

**Expected:** Smooth performance with many users ✓

---

#### Test 10: Error Handling
- [ ] Enable airplane mode
- [ ] Open contact picker
- [ ] Wait for error alert to appear
- [ ] Verify error message is user-friendly
- [ ] Tap "OK" to dismiss alert
- [ ] Disable airplane mode
- [ ] Close and reopen sheet
- [ ] Verify contacts load successfully now

**Expected:** Errors handled gracefully ✓

---

### Bug Fixes

#### If contacts don't load:
- [ ] Check Firebase Console → Firestore → /users collection exists
- [ ] Verify users have displayName field
- [ ] Check console for error messages
- [ ] Verify currentUserId is valid
- [ ] Test with debugger breakpoint in `loadUsers()`

#### If search doesn't work:
- [ ] Check searchQuery is binding correctly
- [ ] Verify filteredUsers computed property is called
- [ ] Test with print statements in filter logic
- [ ] Ensure @Published searchQuery triggers updates

#### If duplicates are created:
- [ ] Check findExistingConversation is called first
- [ ] Verify participants array is sorted before query
- [ ] Check Firestore query returns correct results
- [ ] Add logging to track conversation creation flow

---

## Post-Testing (15 minutes)

### Code Cleanup
- [ ] Remove all print statements (except errors)
- [ ] Remove test comments
- [ ] Verify no TODOs left unaddressed
- [ ] Check indentation and formatting
- [ ] Remove unused imports

### Documentation
- [ ] Add JSDoc comments to ContactsViewModel methods
- [ ] Add comments to complex logic sections
- [ ] Update inline documentation if needed

### Final Build
- [ ] Build project: `Cmd + B`
- [ ] Verify 0 errors, 0 warnings
- [ ] Run on simulator: `Cmd + R`
- [ ] Test critical path one more time

**Checkpoint:** All tests passing, code clean ✓

---

## Final Commit & Documentation (10 minutes)

### Update Memory Bank
- [ ] Open `memory-bank/activeContext.md`
- [ ] Update "What Just Happened" section with PR #8
- [ ] Update "What's Next" to PR #9
- [ ] Update code statistics

### Update PR_PARTY README
- [ ] Open `PR_PARTY/README.md`
- [ ] Mark PR #8 as ✅ COMPLETE
- [ ] Update time taken (estimated vs actual)
- [ ] Update "Next Focus" section

### Final Commit
```bash
git add .
git commit -m "[PR #8] Complete contact selection and new chat functionality

Features:
- Contact list with search functionality
- Profile pictures and online status
- Conversation creation/reuse logic
- Empty state handling
- Integration with ChatListView

Files:
- Services/ChatService.swift (+40 lines)
- ViewModels/ContactsViewModel.swift (200 lines)
- Views/Contacts/ContactRowView.swift (80 lines)
- Views/Contacts/ContactsListView.swift (180 lines)
- Views/Chat/ChatListView.swift (+30 lines)
- ViewModels/ChatListViewModel.swift (+20 lines)

Tests: All 10 manual tests passing ✅
Performance: <2s load, <100ms search ✅
Memory: <50MB stable ✅
"
```

### Push to GitHub
```bash
git push origin feature/pr08-contact-selection
```

---

## Completion Checklist

**Feature Complete:**
- [x] ChatService extensions (findExisting, fetchAllUsers)
- [x] ContactsViewModel with search logic
- [x] ContactRowView component
- [x] ContactsListView with all states
- [x] ChatListView integration (button + sheet)
- [x] Contact selection handler
- [x] Conversation creation/reuse working

**Quality Gates:**
- [x] All tests passing (10 manual tests)
- [x] No console errors
- [x] Search works case-insensitively
- [x] Empty state displays correctly
- [x] No duplicate conversations created
- [x] Current user excluded from list
- [x] Performance targets met (<2s, 60fps)
- [x] Memory stable (<50MB)

**Documentation:**
- [x] Memory bank updated
- [x] PR_PARTY README updated
- [x] Code commented where needed
- [x] All commits pushed to GitHub

---

## 🎉 PR #8 Complete!

**Time Taken:** ___ hours (estimated: 2-3 hours)

**What We Built:**
- Complete contact selection interface
- Search functionality for finding users
- Conversation creation with duplicate prevention
- Beautiful UI with profile pictures and status
- Integration with chat list

**Next PR:** PR #9 - Chat View UI Components

**Celebrate!** 🚀 Users can now start conversations!

---

*Use this checklist to track your progress. Check off each item as you complete it. This is your daily todo list!*

