# PR#7: Chat List View - Implementation Checklist

**Use this as your daily todo list.** Check off items as you complete them.

---

## Pre-Implementation Setup (10 minutes)

- [ ] Read main planning document (`PR07_CHAT_LIST_VIEW.md`) ~45 min
- [ ] Prerequisites verified:
  - [ ] PR #4 complete (models exist)
  - [ ] PR #5 complete (ChatService available)
  - [ ] PR #6 complete (LocalDataManager available)
  - [ ] Firebase authenticated (current user ID available)
- [ ] Git branch created
  ```bash
  git checkout main
  git pull origin main
  git checkout -b feature/chat-list-view
  ```
- [ ] Xcode project opened
- [ ] Verify app builds successfully before starting

---

## Phase 1: Date Formatting Utilities (30 minutes)

### 1.1: Create DateFormatter Extensions File (30 minutes)

#### Create File
- [ ] Create `messAI/Utilities/DateFormatter+Extensions.swift`
- [ ] Add to Xcode project (Right-click Utilities folder → Add Files)

#### Add Date Extension
- [ ] Add imports
  ```swift
  import Foundation
  ```

#### Implement relativeDateString()
- [ ] Create extension on Date
  ```swift
  extension Date {
      /// Converts date to relative string: "2m ago", "5h ago", "Yesterday", "Mon"
      func relativeDateString() -> String {
          let calendar = Calendar.current
          let now = Date()
          
          let components = calendar.dateComponents(
              [.minute, .hour, .day, .weekOfYear], 
              from: self, 
              to: now
          )
          
          // Less than 1 minute: "Just now"
          if let minute = components.minute, minute < 1 {
              return "Just now"
          }
          
          // Less than 1 hour: "Xm ago"
          if let minute = components.minute, 
             let hour = components.hour, 
             hour < 1 {
              return "\(minute)m ago"
          }
          
          // Less than 24 hours: "Xh ago"
          if let hour = components.hour, 
             let day = components.day, 
             day < 1 {
              return "\(hour)h ago"
          }
          
          // Yesterday
          if calendar.isDateInYesterday(self) {
              return "Yesterday"
          }
          
          // Less than 1 week: "Mon", "Tue"
          if let week = components.weekOfYear, week < 1 {
              let formatter = DateFormatter()
              formatter.dateFormat = "EEE" // Mon, Tue, Wed
              return formatter.string(from: self)
          }
          
          // Older: "Dec 25"
          let formatter = DateFormatter()
          formatter.dateFormat = "MMM d"
          return formatter.string(from: self)
      }
  }
  ```

#### Add DateFormatter Extensions
- [ ] Create DateFormatter extension
  ```swift
  extension DateFormatter {
      /// Shared formatter for message timestamps
      static let messageTime: DateFormatter = {
          let formatter = DateFormatter()
          formatter.dateStyle = .none
          formatter.timeStyle = .short // 3:45 PM
          return formatter
      }()
      
      /// Shared formatter for full dates
      static let fullDate: DateFormatter = {
          let formatter = DateFormatter()
          formatter.dateStyle = .medium // Dec 25, 2025
          formatter.timeStyle = .short
          return formatter
      }()
  }
  ```

#### Test Date Formatting
- [ ] Build project (Cmd+B) - verify no errors
- [ ] Test in Playground or Preview:
  - [ ] Test "Just now": Date() → "Just now"
  - [ ] Test "5m ago": Date() - 300 seconds → "5m ago"
  - [ ] Test "3h ago": Date() - 10800 seconds → "3h ago"
  - [ ] Test "Yesterday": yesterday → "Yesterday"
  - [ ] Test "Mon": 3 days ago → day of week
  - [ ] Test "Dec 25": old date → "Dec 25"

**Checkpoint:** Date formatting works correctly ✓

**Commit:**
```bash
git add messAI/Utilities/DateFormatter+Extensions.swift
git commit -m "[PR #7] Add date formatting utilities

- Implemented relativeDateString() for smart timestamps
- Added shared DateFormatter instances
- Supports: Just now, Xm ago, Xh ago, Yesterday, day names, dates
- ~80 lines of code"
```

---

## Phase 2: ChatListViewModel (1 hour)

### 2.1: Create ViewModel File (5 minutes)

#### Create File
- [ ] Create `messAI/ViewModels/ChatListViewModel.swift`
- [ ] Add to Xcode project

#### Add Imports
- [ ] Add imports
  ```swift
  import Foundation
  import Combine
  import SwiftUI
  ```

#### Add Class Declaration
- [ ] Create class with @MainActor
  ```swift
  @MainActor
  class ChatListViewModel: ObservableObject {
      // Implementation next
  }
  ```

---

### 2.2: Add Properties (10 minutes)

#### Add Published Properties
- [ ] Add @Published properties
  ```swift
  // MARK: - Published Properties
  
  @Published var conversations: [Conversation] = []
  @Published var isLoading: Bool = false
  @Published var errorMessage: String?
  @Published var showError: Bool = false
  ```

#### Add Private Properties
- [ ] Add private properties
  ```swift
  // MARK: - Private Properties
  
  private let chatService: ChatService
  private let localDataManager: LocalDataManager
  private let currentUserId: String
  private var firestoreTask: Task<Void, Never>?
  ```

#### Add Computed Properties
- [ ] Add sorted conversations computed property
  ```swift
  // MARK: - Computed Properties
  
  /// Conversations sorted by most recent first
  var sortedConversations: [Conversation] {
      conversations.sorted { $0.lastMessageAt > $1.lastMessageAt }
  }
  ```

#### Add Initializer
- [ ] Add init with dependency injection
  ```swift
  // MARK: - Initialization
  
  init(
      chatService: ChatService, 
      localDataManager: LocalDataManager, 
      currentUserId: String
  ) {
      self.chatService = chatService
      self.localDataManager = localDataManager
      self.currentUserId = currentUserId
  }
  ```

**Test:** Build project - verify no errors

---

### 2.3: Implement Public Methods (10 minutes)

#### Add loadConversations()
- [ ] Implement load conversations method
  ```swift
  // MARK: - Public Methods
  
  /// Load conversations from local storage, then start real-time listener
  func loadConversations() {
      Task {
          // Step 1: Load from local (instant)
          await loadConversationsFromLocal()
          
          // Step 2: Start real-time listener
          await startRealtimeListener()
      }
  }
  ```

#### Add stopListening()
- [ ] Implement stop listening method
  ```swift
  /// Stop real-time listener when view disappears
  func stopListening() {
      firestoreTask?.cancel()
      firestoreTask = nil
      print("🛑 Stopped Firestore listener")
  }
  ```

#### Add refresh()
- [ ] Implement refresh method
  ```swift
  /// Refresh conversations manually
  func refresh() async {
      await startRealtimeListener()
  }
  ```

**Test:** Build project - verify no errors

---

### 2.4: Implement Private Methods (35 minutes)

#### Add loadConversationsFromLocal()
- [ ] Implement local loading
  ```swift
  // MARK: - Private Methods
  
  /// Load conversations from Core Data (instant display)
  private func loadConversationsFromLocal() async {
      do {
          let localConversations = try localDataManager.fetchConversations(
              userId: currentUserId
          )
          
          // Convert ConversationEntity to Conversation
          conversations = localConversations.compactMap { entity in
              guard let id = entity.id else { return nil }
              
              return Conversation(
                  id: id,
                  participants: entity.participantsArray,
                  isGroup: entity.isGroup,
                  groupName: entity.groupName,
                  lastMessage: entity.lastMessage ?? "",
                  lastMessageAt: entity.lastMessageAt ?? Date(),
                  createdBy: entity.createdBy ?? "",
                  createdAt: entity.createdAt ?? Date()
              )
          }
          
          print("✅ Loaded \(conversations.count) conversations from local storage")
      } catch {
          print("⚠️ Failed to load local conversations: \(error)")
          errorMessage = "Failed to load conversations from local storage"
          showError = true
      }
  }
  ```

#### Add startRealtimeListener()
- [ ] Implement Firestore listener
  ```swift
  /// Start Firestore real-time listener
  private func startRealtimeListener() async {
      // Cancel existing listener
      firestoreTask?.cancel()
      
      isLoading = true
      
      firestoreTask = Task {
          do {
              // Get async stream of conversations
              let stream = chatService.fetchConversations(userId: currentUserId)
              
              for try await firestoreConversations in stream {
                  // Update UI on main thread
                  await MainActor.run {
                      self.conversations = firestoreConversations
                      self.isLoading = false
                      print("✅ Updated \(firestoreConversations.count) conversations from Firestore")
                  }
                  
                  // Save to local storage in background
                  Task.detached { [weak self] in
                      guard let self = self else { return }
                      try? await self.saveConversationsToLocal(firestoreConversations)
                  }
              }
          } catch {
              await MainActor.run {
                  self.isLoading = false
                  self.errorMessage = "Failed to sync conversations: \(error.localizedDescription)"
                  self.showError = true
                  print("❌ Firestore listener error: \(error)")
              }
          }
      }
  }
  ```

#### Add saveConversationsToLocal()
- [ ] Implement local saving
  ```swift
  /// Save conversations to Core Data for offline access
  private func saveConversationsToLocal(_ conversations: [Conversation]) async throws {
      for conversation in conversations {
          try localDataManager.saveConversation(conversation)
      }
      print("💾 Saved \(conversations.count) conversations to local storage")
  }
  ```

#### Add Helper Methods
- [ ] Add getConversationName()
  ```swift
  /// Get display name for conversation
  func getConversationName(_ conversation: Conversation) -> String {
      if conversation.isGroup {
          return conversation.groupName ?? "Unnamed Group"
      } else {
          // Get other participant's name
          let otherUserId = conversation.participants.first { $0 != currentUserId }
          // TODO: Fetch user name from UserService (PR #8)
          return otherUserId ?? "Unknown User"
      }
  }
  ```

- [ ] Add getConversationPhotoURL()
  ```swift
  /// Get profile picture URL for conversation
  func getConversationPhotoURL(_ conversation: Conversation) -> String? {
      if conversation.isGroup {
          return nil // Group icon instead
      } else {
          // Get other participant's photo
          // TODO: Fetch user photo from UserService (PR #8)
          return nil
      }
  }
  ```

- [ ] Add getUnreadCount()
  ```swift
  /// Calculate unread count for conversation
  func getUnreadCount(_ conversation: Conversation) -> Int {
      // TODO: Implement unread count from message status (PR #11)
      return 0
  }
  ```

**Test:** 
- [ ] Build project - verify no errors
- [ ] No red underlines or warnings

**Checkpoint:** ChatListViewModel complete ✓

**Commit:**
```bash
git add messAI/ViewModels/ChatListViewModel.swift
git commit -m "[PR #7] Implement ChatListViewModel

- Published properties: conversations, isLoading, errorMessage
- Load from local storage first (instant display)
- Start Firestore real-time listener (background sync)
- Save synced conversations to local storage
- Helper methods for display name, photo URL, unread count
- Proper listener cleanup to prevent memory leaks
- ~250 lines of code"
```

---

## Phase 3: ConversationRowView Component (45 minutes)

### 3.1: Create ConversationRowView File (5 minutes)

#### Create File
- [ ] Create `messAI/Views/Chat/ConversationRowView.swift`
- [ ] Add to Xcode project
- [ ] Add import
  ```swift
  import SwiftUI
  ```

#### Add Struct Declaration
- [ ] Create struct
  ```swift
  struct ConversationRowView: View {
      // Properties
      let conversation: Conversation
      let conversationName: String
      let photoURL: String?
      let unreadCount: Int
      let isOnline: Bool
      
      var body: some View {
          // Implementation next
      }
  }
  ```

---

### 3.2: Implement Main Body (20 minutes)

#### Add HStack Layout
- [ ] Implement main layout
  ```swift
  var body: some View {
      HStack(spacing: 12) {
          // Profile Picture
          profilePicture
          
          // Conversation Info
          VStack(alignment: .leading, spacing: 4) {
              // Name
              Text(conversationName)
                  .font(.headline)
                  .lineLimit(1)
              
              // Last Message
              Text(conversation.lastMessage)
                  .font(.subheadline)
                  .foregroundColor(.secondary)
                  .lineLimit(2)
          }
          
          Spacer()
          
          // Timestamp + Badge
          VStack(alignment: .trailing, spacing: 4) {
              // Timestamp
              Text(conversation.lastMessageAt.relativeDateString())
                  .font(.caption)
                  .foregroundColor(.secondary)
              
              // Unread Badge
              if unreadCount > 0 {
                  unreadBadge
              }
          }
      }
      .padding(.vertical, 8)
      .contentShape(Rectangle()) // Make entire row tappable
  }
  ```

---

### 3.3: Implement Subviews (20 minutes)

#### Add Profile Picture View
- [ ] Create profilePicture computed property
  ```swift
  // MARK: - Subviews
  
  private var profilePicture: some View {
      ZStack(alignment: .bottomTrailing) {
          // Profile Image
          Group {
              if let photoURL = photoURL, let url = URL(string: photoURL) {
                  AsyncImage(url: url) { phase in
                      switch phase {
                      case .empty:
                          ProgressView()
                      case .success(let image):
                          image
                              .resizable()
                              .scaledToFill()
                      case .failure:
                          placeholderImage
                      @unknown default:
                          placeholderImage
                      }
                  }
              } else {
                  placeholderImage
              }
          }
          .frame(width: 56, height: 56)
          .clipShape(Circle())
          
          // Online Indicator
          if isOnline && !conversation.isGroup {
              Circle()
                  .fill(Color.green)
                  .frame(width: 16, height: 16)
                  .overlay(
                      Circle()
                          .stroke(Color(.systemBackground), lineWidth: 2)
                  )
          }
      }
  }
  ```

#### Add Placeholder Image
- [ ] Create placeholderImage computed property
  ```swift
  private var placeholderImage: some View {
      ZStack {
          Circle()
              .fill(Color.gray.opacity(0.3))
          
          Image(systemName: conversation.isGroup ? "person.3.fill" : "person.fill")
              .font(.title2)
              .foregroundColor(.gray)
      }
  }
  ```

#### Add Unread Badge
- [ ] Create unreadBadge computed property
  ```swift
  private var unreadBadge: some View {
      Text("\(unreadCount)")
          .font(.caption2)
          .fontWeight(.bold)
          .foregroundColor(.white)
          .padding(.horizontal, 6)
          .padding(.vertical, 2)
          .background(Color.blue)
          .clipShape(Capsule())
  }
  ```

---

### 3.4: Add Preview (5 minutes)

#### Add Preview Provider
- [ ] Add preview code
  ```swift
  // MARK: - Preview
  
  struct ConversationRowView_Previews: PreviewProvider {
      static var previews: some View {
          Group {
              // One-on-one chat
              ConversationRowView(
                  conversation: Conversation(
                      id: "1",
                      participants: ["user1", "user2"],
                      isGroup: false,
                      groupName: nil,
                      lastMessage: "Hey! How are you doing today?",
                      lastMessageAt: Date().addingTimeInterval(-300), // 5 min ago
                      createdBy: "user1",
                      createdAt: Date()
                  ),
                  conversationName: "Jane Doe",
                  photoURL: nil,
                  unreadCount: 3,
                  isOnline: true
              )
              .previewLayout(.sizeThatFits)
              .padding()
              .previewDisplayName("One-on-One Chat")
              
              // Group chat
              ConversationRowView(
                  conversation: Conversation(
                      id: "2",
                      participants: ["user1", "user2", "user3"],
                      isGroup: true,
                      groupName: "Weekend Plans",
                      lastMessage: "John: Sounds good!",
                      lastMessageAt: Date().addingTimeInterval(-3600), // 1 hour ago
                      createdBy: "user1",
                      createdAt: Date()
                  ),
                  conversationName: "Weekend Plans",
                  photoURL: nil,
                  unreadCount: 0,
                  isOnline: false
              )
              .previewLayout(.sizeThatFits)
              .padding()
              .previewDisplayName("Group Chat")
          }
      }
  }
  ```

**Test:** 
- [ ] Build project - verify no errors
- [ ] Run preview (Cmd+Option+Enter) - verify UI looks correct
- [ ] Test both preview variants (1-on-1 and group)
- [ ] Verify online indicator shows for 1-on-1 only
- [ ] Verify unread badge shows correctly
- [ ] Verify timestamp displays correctly

**Checkpoint:** ConversationRowView complete and looks good ✓

**Commit:**
```bash
git add messAI/Views/Chat/ConversationRowView.swift
git commit -m "[PR #7] Create ConversationRowView component

- Profile picture with AsyncImage and placeholder
- Online indicator (green dot) for 1-on-1 chats
- Conversation name and last message
- Smart timestamp (using relativeDateString)
- Unread count badge
- Group vs 1-on-1 distinction (different icons)
- SwiftUI preview for testing
- ~120 lines of code"
```

---

## Phase 4: ChatListView (45 minutes)

### 4.1: Create ChatListView File (5 minutes)

#### Create File
- [ ] Create `messAI/Views/Chat/ChatListView.swift`
- [ ] Add to Xcode project
- [ ] Add import
  ```swift
  import SwiftUI
  ```

#### Add Struct Declaration
- [ ] Create struct with ViewModel
  ```swift
  struct ChatListView: View {
      @StateObject var viewModel: ChatListViewModel
      @State private var showingNewChat = false
      
      var body: some View {
          // Implementation next
      }
  }
  ```

---

### 4.2: Implement Main Body (15 minutes)

#### Add NavigationStack and ZStack
- [ ] Implement main structure
  ```swift
  var body: some View {
      NavigationStack {
          ZStack {
              // Main Content
              content
              
              // Loading Overlay (first load only)
              if viewModel.isLoading && viewModel.conversations.isEmpty {
                  ProgressView("Loading conversations...")
              }
          }
          .navigationTitle("Messages")
          .toolbar {
              ToolbarItem(placement: .navigationBarTrailing) {
                  Button {
                      showingNewChat = true
                  } label: {
                      Image(systemName: "square.and.pencil")
                          .font(.title3)
                  }
              }
          }
          .sheet(isPresented: $showingNewChat) {
              // TODO: ContactsListView (PR #8)
              Text("New Chat - Coming in PR #8")
                  .font(.title)
                  .padding()
          }
          .alert("Error", isPresented: $viewModel.showError) {
              Button("OK") {
                  viewModel.showError = false
              }
          } message: {
              if let errorMessage = viewModel.errorMessage {
                  Text(errorMessage)
              }
          }
          .onAppear {
              viewModel.loadConversations()
          }
          .onDisappear {
              viewModel.stopListening()
          }
      }
  }
  ```

---

### 4.3: Implement Content Views (25 minutes)

#### Add Content Switcher
- [ ] Create content computed property
  ```swift
  // MARK: - Content
  
  @ViewBuilder
  private var content: some View {
      if viewModel.sortedConversations.isEmpty && !viewModel.isLoading {
          emptyState
      } else {
          conversationList
      }
  }
  ```

#### Add Conversation List
- [ ] Create conversationList computed property
  ```swift
  private var conversationList: some View {
      ScrollView {
          LazyVStack(spacing: 0) {
              ForEach(viewModel.sortedConversations) { conversation in
                  NavigationLink(value: conversation) {
                      ConversationRowView(
                          conversation: conversation,
                          conversationName: viewModel.getConversationName(conversation),
                          photoURL: viewModel.getConversationPhotoURL(conversation),
                          unreadCount: viewModel.getUnreadCount(conversation),
                          isOnline: false // TODO: PresenceService (PR #12)
                      )
                      .padding(.horizontal)
                  }
                  .buttonStyle(PlainButtonStyle())
                  
                  Divider()
                      .padding(.leading, 80)
              }
          }
      }
      .navigationDestination(for: Conversation.self) { conversation in
          // TODO: ChatView (PR #9)
          Text("Chat: \(conversation.id)")
              .navigationTitle(viewModel.getConversationName(conversation))
              .navigationBarTitleDisplayMode(.inline)
      }
      .refreshable {
          await viewModel.refresh()
      }
  }
  ```

#### Add Empty State
- [ ] Create emptyState computed property
  ```swift
  private var emptyState: some View {
      VStack(spacing: 16) {
          Image(systemName: "message.fill")
              .font(.system(size: 64))
              .foregroundColor(.gray)
          
          Text("No Conversations Yet")
              .font(.title2)
              .fontWeight(.semibold)
          
          Text("Tap the compose button to start a new chat")
              .font(.body)
              .foregroundColor(.secondary)
              .multilineTextAlignment(.center)
              .padding(.horizontal)
          
          Button {
              showingNewChat = true
          } label: {
              Label("New Chat", systemImage: "square.and.pencil")
                  .font(.headline)
                  .foregroundColor(.white)
                  .padding()
                  .background(Color.blue)
                  .cornerRadius(12)
          }
      }
      .padding()
  }
  ```

---

### 4.4: Add Preview (5 minutes)

#### Add Preview (Mock ViewModel)
- [ ] Add preview code (note: this won't compile until PR #6 is done)
  ```swift
  // MARK: - Preview
  
  struct ChatListView_Previews: PreviewProvider {
      static var previews: some View {
          // Note: This preview requires PR #6 dependencies
          // Will compile after LocalDataManager is available
          
          ChatListView(viewModel: ChatListViewModel(
              chatService: ChatService(),
              localDataManager: LocalDataManager(modelContext: .preview),
              currentUserId: "preview-user"
          ))
      }
  }
  ```

**Test:** 
- [ ] Build project - verify no errors
- [ ] Preview may not work yet (dependencies), but code should compile

**Checkpoint:** ChatListView complete ✓

**Commit:**
```bash
git add messAI/Views/Chat/ChatListView.swift
git commit -m "[PR #7] Create ChatListView

- NavigationStack with toolbar (New Chat button)
- LazyVStack for conversation list (virtualized)
- ConversationRowView integration
- Empty state when no conversations
- Pull-to-refresh support
- Error alert display
- Lifecycle management (onAppear/onDisappear)
- Navigation to ChatView (placeholder for PR #9)
- ~180 lines of code"
```

---

## Phase 5: Integration & Testing (30 minutes)

### 5.1: Update ContentView (10 minutes)

#### Integrate ChatListView
- [ ] Open `messAI/ContentView.swift`
- [ ] Replace placeholder content with ChatListView
  ```swift
  import SwiftUI
  
  struct ContentView: View {
      @EnvironmentObject var authViewModel: AuthViewModel
      
      var body: some View {
          if authViewModel.isAuthenticated, let currentUser = authViewModel.currentUser {
              ChatListView(
                  viewModel: ChatListViewModel(
                      chatService: ChatService(),
                      localDataManager: LocalDataManager.shared,
                      currentUserId: currentUser.id
                  )
              )
          } else {
              Text("Not authenticated")
          }
      }
  }
  ```

**Test:**
- [ ] Build project - verify no errors
- [ ] Run app in simulator
- [ ] Log in with test account
- [ ] Verify ChatListView appears

---

### 5.2: Manual Testing (20 minutes)

#### Test Empty State
- [ ] Launch app with no conversations
- [ ] Expected: Empty state displays with icon and message
- [ ] Tap "New Chat" button
- [ ] Expected: Shows placeholder sheet

#### Test Conversation List
- [ ] Create test conversation in Firestore Console (optional, or wait for PR #8)
- [ ] Add conversation document:
  ```json
  {
    "participants": ["user1", "user2"],
    "isGroup": false,
    "lastMessage": "Test message",
    "lastMessageAt": Timestamp.now(),
    "createdBy": "user1",
    "createdAt": Timestamp.now()
  }
  ```
- [ ] Pull to refresh
- [ ] Expected: Conversation appears in list
- [ ] Verify: Name displays (will be user ID for now)
- [ ] Verify: Last message displays
- [ ] Verify: Timestamp displays correctly
- [ ] Verify: Profile picture placeholder shows

#### Test Navigation
- [ ] Tap conversation row
- [ ] Expected: Navigate to placeholder chat screen
- [ ] Verify: Navigation title shows conversation name
- [ ] Tap back button
- [ ] Expected: Return to list

#### Test Offline Mode
- [ ] Enable airplane mode
- [ ] Force quit app
- [ ] Relaunch app
- [ ] Expected: Conversations load from local storage
- [ ] Expected: No errors or crashes

#### Test Real-Time Updates
- [ ] Open app on device
- [ ] Add new conversation in Firestore Console
- [ ] Expected: New conversation appears in list within 2 seconds
- [ ] Update lastMessage field in Firestore
- [ ] Expected: Message updates in list automatically

#### Test Performance
- [ ] Scroll through conversation list
- [ ] Expected: Smooth 60fps scrolling
- [ ] No lag or stuttering

#### Test Memory Leaks
- [ ] Open ChatListView
- [ ] Navigate away (background app)
- [ ] Check Xcode debug navigator
- [ ] Expected: Memory stable, no constant increase

**Checkpoint:** All tests passing ✓

---

## Testing Checklist

### Unit Tests (Optional for MVP)
- [ ] DateFormatter+Extensions tests
- [ ] ChatListViewModel tests
- [ ] ConversationRowView snapshot tests

### Integration Tests
- [ ] Full load flow (local → Firestore)
- [ ] Empty state display
- [ ] Navigation to ChatView
- [ ] Pull-to-refresh
- [ ] Real-time update
- [ ] Offline mode
- [ ] Zero conversations (no crash)
- [ ] 100+ conversations (performance)
- [ ] Very long last message (truncation)
- [ ] Missing group name (fallback)
- [ ] Rapid navigation (no crash)
- [ ] Listener cleanup (no memory leak)

### Performance Benchmarks
- [ ] Initial load: <1 second (local) - Actual: _____
- [ ] Firestore sync: <2 seconds - Actual: _____
- [ ] Scroll performance: 60fps - Actual: _____
- [ ] Real-time latency: <2 seconds - Actual: _____

---

## Deployment Checklist

### Pre-Deploy
- [ ] All code committed
- [ ] No compiler warnings
- [ ] No console errors
- [ ] All tests passed
- [ ] Memory leaks checked
- [ ] Performance verified

### Final Commit
```bash
git add .
git commit -m "[PR #7] Chat List View - Complete!

Summary:
- DateFormatter+Extensions: Smart timestamp formatting (~80 lines)
- ChatListViewModel: State management with real-time sync (~250 lines)
- ConversationRowView: Reusable row component (~120 lines)
- ChatListView: Main conversation list (~180 lines)
- Integration with ContentView
- All tests passing

Total: ~630 lines of new code
Status: Ready for PR #8 (Contact Selection)
"
```

### Merge to Main
```bash
git checkout main
git merge feature/chat-list-view
git push origin main
```

---

## Post-Merge Tasks

### Documentation
- [ ] Update `PR_PARTY/README.md`:
  - [ ] Mark PR #7 as ✅ COMPLETE
  - [ ] Add actual time taken
  - [ ] Update project status
- [ ] Update `memory-bank/activeContext.md`:
  - [ ] Move PR #7 to "Recent Changes"
  - [ ] Update current work to PR #8
- [ ] Update `memory-bank/progress.md`:
  - [ ] Check off PR #7 tasks
  - [ ] Update completion percentage
  - [ ] Update "What Works" section

### Celebrate! 🎉
- [ ] Take a break
- [ ] Review what you built
- [ ] Share progress if desired

---

## Completion Checklist

**All tasks complete when:**
- [ ] All phases completed
- [ ] All tests passing
- [ ] Performance targets met
- [ ] No critical bugs
- [ ] Code committed and merged
- [ ] Documentation updated
- [ ] Ready for PR #8

**Time Tracking:**
- Estimated: 2-3 hours
- Actual: _____ hours
- Difference: _____ hours

---

## Known Issues / Notes

**Record any issues encountered:**

1. Issue: _____________________________
   - Solution: _____________________________

2. Issue: _____________________________
   - Solution: _____________________________

---

**Status:** Ready to implement after PR #6 ✓  
**Next PR:** PR #8 - Contact Selection & New Chat

