# PR#7: Chat List View - Main Conversation Interface

**Estimated Time:** 2-3 hours  
**Complexity:** MEDIUM  
**Dependencies:** PR #4 (Models), PR #5 (ChatService), PR #6 (Local Persistence)

---

## Overview

### What We're Building

The Chat List View is the main screen users see after logging in—a scrollable list of all their conversations (both one-on-one and group chats). Each row shows the contact/group name, profile picture, last message preview, timestamp, unread badge, and online status. This is the hub of the messaging experience.

Think: WhatsApp or iMessage conversation list.

### Why It Matters

This is the **first screen users interact with** after authentication. It sets the tone for the entire app experience. Users need to:
- Quickly scan their active conversations
- See which chats have new messages
- Identify who's online
- Jump into any conversation with one tap

A slow or confusing chat list = frustrated users who won't use the app.

### Success in One Sentence

"This PR is successful when users see a live-updating list of their conversations with accurate last messages, timestamps, unread counts, and can tap to open any chat instantly."

---

## Technical Design

### Architecture Decisions

#### Decision 1: Real-Time vs Pull-to-Refresh

**Options Considered:**
1. **Real-Time Listener** - Firestore snapshot listener on conversations
   - Pros: Instant updates when new messages arrive, always current
   - Cons: Battery drain if not managed, constant network activity
   
2. **Pull-to-Refresh** - Manual refresh on user action
   - Pros: Less battery drain, simpler implementation
   - Cons: Stale data between refreshes, poor UX

**Chosen:** Real-Time Listener

**Rationale:**
- Messaging apps demand real-time updates (core feature)
- Firestore handles connection management efficiently
- Users expect conversations to update automatically
- Competitive messaging apps all use real-time

**Trade-offs:**
- Gain: Perfect UX, always-current data
- Lose: Slightly more battery usage (acceptable for messaging)

---

#### Decision 2: Data Source (Local First vs Cloud First)

**Options Considered:**
1. **Local-First** - Load from Core Data, sync in background
   - Pros: Instant display (offline-capable), no loading spinner
   - Cons: May show stale data briefly
   
2. **Cloud-First** - Load from Firestore, cache in Core Data
   - Pros: Always fresh data from server
   - Cons: Loading delay, offline mode broken

**Chosen:** Local-First with Real-Time Sync

**Rationale:**
- Users expect instant app launch (<1 second)
- Offline functionality is a core requirement (MVP criterion)
- Real-time listener ensures data freshness after initial load
- WhatsApp model: instant display + background sync

**Trade-offs:**
- Gain: Fast app launch, offline support
- Lose: Rare edge case of briefly stale data (mitigated by real-time sync)

---

#### Decision 3: List Performance (Standard List vs Lazy Loading)

**Options Considered:**
1. **Standard List** - Load all conversations at once
   - Pros: Simple implementation
   - Cons: Slow with 100+ conversations
   
2. **LazyVStack** - Virtualized list rendering
   - Pros: Fast with any number of conversations
   - Cons: Slightly more complex

**Chosen:** LazyVStack

**Rationale:**
- SwiftUI best practice for lists
- Zero performance penalty
- Scales to power users (100+ conversations)
- Minimal complexity increase

**Trade-offs:**
- Gain: Smooth scrolling, scalable
- Lose: None (LazyVStack is standard practice)

---

### Data Model

**Conversation Model** (from PR #4):
```swift
struct Conversation: Identifiable, Codable, Equatable {
    let id: String
    let participants: [String]
    let isGroup: Bool
    let groupName: String?
    var lastMessage: String
    var lastMessageAt: Date
    let createdBy: String
    let createdAt: Date
    
    // Computed properties
    var lastMessageTimestamp: String // "2m ago", "Yesterday", etc.
}
```

**ViewModel State**:
```swift
class ChatListViewModel: ObservableObject {
    @Published var conversations: [Conversation] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var currentUserId: String
    
    // For display
    var sortedConversations: [Conversation] {
        conversations.sorted { $0.lastMessageAt > $1.lastMessageAt }
    }
}
```

---

### Component Hierarchy

```
ChatListView
├── NavigationStack
│   ├── Toolbar (Title + New Chat button)
│   ├── Connection Status Banner (if offline)
│   └── Content
│       ├── Loading State (ProgressView)
│       ├── Empty State (No conversations yet)
│       └── LazyVStack
│           └── ConversationRowView (repeated)
│               ├── Profile Picture (AsyncImage)
│               ├── VStack (Name + Last Message)
│               ├── VStack (Timestamp + Unread Badge)
│               └── Online Indicator (green dot)
```

---

## Implementation Details

### File Structure

**New Files:**
```
messAI/
├── ViewModels/
│   └── ChatListViewModel.swift       (~250 lines)
├── Views/
│   └── Chat/
│       ├── ChatListView.swift         (~180 lines)
│       └── ConversationRowView.swift  (~120 lines)
└── Utilities/
    └── DateFormatter+Extensions.swift  (~80 lines)
```

**Modified Files:**
- `messAI/ContentView.swift` (+20/-10 lines) - Add ChatListView as main content
- `messAI/messAIApp.swift` (+5/-0 lines) - Inject ChatListViewModel into environment

**Total New Code:** ~630 lines

---

### Key Implementation Steps

#### Phase 1: Date Formatting Utilities (30 minutes)

**Goal:** Create smart timestamp formatting ("2m ago", "Yesterday", "Mon")

**File:** `Utilities/DateFormatter+Extensions.swift`

```swift
import Foundation

extension Date {
    /// Converts date to relative string: "2m ago", "5h ago", "Yesterday", "Mon"
    func relativeDateString() -> String {
        let calendar = Calendar.current
        let now = Date()
        
        let components = calendar.dateComponents([.minute, .hour, .day, .weekOfYear], from: self, to: now)
        
        // Less than 1 minute: "Just now"
        if let minute = components.minute, minute < 1 {
            return "Just now"
        }
        
        // Less than 1 hour: "Xm ago"
        if let minute = components.minute, let hour = components.hour, hour < 1 {
            return "\(minute)m ago"
        }
        
        // Less than 24 hours: "Xh ago"
        if let hour = components.hour, let day = components.day, day < 1 {
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

---

#### Phase 2: ChatListViewModel (1 hour)

**Goal:** Manage conversation list state, fetch from local + Firestore, handle real-time updates

**File:** `ViewModels/ChatListViewModel.swift`

```swift
import Foundation
import Combine
import SwiftUI

@MainActor
class ChatListViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var conversations: [Conversation] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var showError: Bool = false
    
    // MARK: - Private Properties
    
    private let chatService: ChatService
    private let localDataManager: LocalDataManager
    private let currentUserId: String
    private var firestoreTask: Task<Void, Never>?
    
    // MARK: - Computed Properties
    
    /// Conversations sorted by most recent first
    var sortedConversations: [Conversation] {
        conversations.sorted { $0.lastMessageAt > $1.lastMessageAt }
    }
    
    // MARK: - Initialization
    
    init(chatService: ChatService, localDataManager: LocalDataManager, currentUserId: String) {
        self.chatService = chatService
        self.localDataManager = localDataManager
        self.currentUserId = currentUserId
    }
    
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
    
    /// Stop real-time listener when view disappears
    func stopListening() {
        firestoreTask?.cancel()
        firestoreTask = nil
    }
    
    /// Refresh conversations manually
    func refresh() async {
        await startRealtimeListener()
    }
    
    // MARK: - Private Methods
    
    /// Load conversations from Core Data (instant display)
    private func loadConversationsFromLocal() async {
        do {
            let localConversations = try localDataManager.fetchConversations(userId: currentUserId)
            
            // Convert ConversationEntity to Conversation
            conversations = localConversations.compactMap { entity in
                Conversation(
                    id: entity.id ?? UUID().uuidString,
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
    
    /// Start Firestore real-time listener
    private func startRealtimeListener() async {
        // Cancel existing listener
        firestoreTask?.cancel()
        
        isLoading = true
        
        firestoreTask = Task {
            do {
                // Get async stream of conversations
                for try await firestoreConversations in chatService.fetchConversations(userId: currentUserId) {
                    // Update UI on main thread
                    await MainActor.run {
                        self.conversations = firestoreConversations
                        self.isLoading = false
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
                }
            }
        }
    }
    
    /// Save conversations to Core Data for offline access
    private func saveConversationsToLocal(_ conversations: [Conversation]) async throws {
        for conversation in conversations {
            try localDataManager.saveConversation(conversation)
        }
    }
    
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
    
    /// Get profile picture URL for conversation
    func getConversationPhotoURL(_ conversation: Conversation) -> String? {
        if conversation.isGroup {
            return nil // Group icon instead
        } else {
            // Get other participant's photo
            let otherUserId = conversation.participants.first { $0 != currentUserId }
            // TODO: Fetch user photo from UserService (PR #8)
            return nil
        }
    }
    
    /// Calculate unread count for conversation
    func getUnreadCount(_ conversation: Conversation) -> Int {
        // TODO: Implement unread count from message status (PR #11)
        return 0
    }
}
```

---

#### Phase 3: ConversationRowView Component (45 minutes)

**Goal:** Reusable row component for each conversation

**File:** `Views/Chat/ConversationRowView.swift`

```swift
import SwiftUI

struct ConversationRowView: View {
    let conversation: Conversation
    let conversationName: String
    let photoURL: String?
    let unreadCount: Int
    let isOnline: Bool
    
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
    
    private var placeholderImage: some View {
        ZStack {
            Circle()
                .fill(Color.gray.opacity(0.3))
            
            Image(systemName: conversation.isGroup ? "person.3.fill" : "person.fill")
                .font(.title2)
                .foregroundColor(.gray)
        }
    }
    
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
}

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
        }
    }
}
```

---

#### Phase 4: ChatListView (45 minutes)

**Goal:** Main view with list, toolbar, empty state, loading state

**File:** `Views/Chat/ChatListView.swift`

```swift
import SwiftUI

struct ChatListView: View {
    @StateObject var viewModel: ChatListViewModel
    @State private var showingNewChat = false
    
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
                Text("New Chat")
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
    
    // MARK: - Content
    
    @ViewBuilder
    private var content: some View {
        if viewModel.sortedConversations.isEmpty && !viewModel.isLoading {
            emptyState
        } else {
            conversationList
        }
    }
    
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
}

// MARK: - Preview

struct ChatListView_Previews: PreviewProvider {
    static var previews: some View {
        // Mock dependencies
        let chatService = ChatService()
        let localDataManager = LocalDataManager(modelContext: /* mock context */)
        let viewModel = ChatListViewModel(
            chatService: chatService,
            localDataManager: localDataManager,
            currentUserId: "user123"
        )
        
        ChatListView(viewModel: viewModel)
    }
}
```

---

### Code Examples

**Example 1: Real-Time Listener Pattern**

```swift
// In ChatListViewModel
private func startRealtimeListener() async {
    firestoreTask = Task {
        do {
            // AsyncThrowingStream from ChatService
            for try await conversations in chatService.fetchConversations(userId: currentUserId) {
                await MainActor.run {
                    self.conversations = conversations
                }
            }
        } catch {
            // Handle error
        }
    }
}
```

**Example 2: Local-First Loading**

```swift
// In ChatListViewModel.loadConversations()
// Step 1: Instant display from Core Data
await loadConversationsFromLocal()

// Step 2: Background sync from Firestore
await startRealtimeListener()
```

**Example 3: Smart Timestamp Formatting**

```swift
// In ConversationRowView
Text(conversation.lastMessageAt.relativeDateString())
    .font(.caption)
    .foregroundColor(.secondary)

// Output examples:
// "Just now", "2m ago", "5h ago", "Yesterday", "Mon", "Dec 25"
```

---

## Testing Strategy

### Test Categories

**Unit Tests: DateFormatter+Extensions**

- [ ] **Test 1: Just now**
  - Input: Date() - 30 seconds
  - Expected: "Just now"
  
- [ ] **Test 2: Minutes ago**
  - Input: Date() - 5 minutes
  - Expected: "5m ago"
  
- [ ] **Test 3: Hours ago**
  - Input: Date() - 3 hours
  - Expected: "3h ago"
  
- [ ] **Test 4: Yesterday**
  - Input: Yesterday 10 AM
  - Expected: "Yesterday"
  
- [ ] **Test 5: Day of week**
  - Input: Monday (3 days ago)
  - Expected: "Mon"
  
- [ ] **Test 6: Older date**
  - Input: December 25
  - Expected: "Dec 25"

**Unit Tests: ChatListViewModel**

- [ ] **Test 7: Load from local**
  - Action: Call loadConversations()
  - Expected: conversations populated from Core Data
  
- [ ] **Test 8: Sort by recent**
  - Given: 3 conversations with different lastMessageAt
  - Expected: sortedConversations in descending order
  
- [ ] **Test 9: Start real-time listener**
  - Action: startRealtimeListener()
  - Expected: firestoreTask created, isLoading = true
  
- [ ] **Test 10: Stop listening**
  - Given: Active listener
  - Action: stopListening()
  - Expected: firestoreTask cancelled
  
- [ ] **Test 11: Get conversation name (1-on-1)**
  - Given: Conversation with 2 participants
  - Expected: Other participant's name
  
- [ ] **Test 12: Get conversation name (group)**
  - Given: Group conversation
  - Expected: Group name or "Unnamed Group"

**Integration Tests**

- [ ] **Test 13: Full load flow**
  - Step 1: Open ChatListView
  - Step 2: Verify local conversations load instantly
  - Step 3: Verify Firestore listener starts
  - Step 4: Verify UI updates with Firestore data
  
- [ ] **Test 14: Empty state**
  - Given: User with no conversations
  - Expected: Empty state view shown
  
- [ ] **Test 15: Navigation to chat**
  - Action: Tap conversation row
  - Expected: Navigate to ChatView (placeholder for PR #9)
  
- [ ] **Test 16: Pull to refresh**
  - Action: Pull down on list
  - Expected: Refresh conversations from Firestore
  
- [ ] **Test 17: Real-time update**
  - Given: ChatListView open
  - Action: New message arrives in Firestore
  - Expected: Conversation moves to top, last message updates
  
- [ ] **Test 18: Offline mode**
  - Given: Device offline
  - Expected: Load from Core Data, show conversations
  - Expected: No error, graceful degradation

**Edge Cases**

- [ ] **Test 19: Zero conversations**
  - Expected: Empty state, no crashes
  
- [ ] **Test 20: 100+ conversations**
  - Expected: Smooth scrolling, no lag
  
- [ ] **Test 21: Very long last message**
  - Expected: Text truncated with ellipsis
  
- [ ] **Test 22: Missing group name**
  - Expected: "Unnamed Group" displayed
  
- [ ] **Test 23: Rapid navigation**
  - Action: Tap multiple rows quickly
  - Expected: No crashes, correct navigation
  
- [ ] **Test 24: Listener cleanup**
  - Action: Navigate away from ChatListView
  - Expected: Listener stopped, no memory leak

**Performance Tests**

- [ ] **Benchmark 1: Initial load**
  - Target: <1 second to show local conversations
  - Actual: _____
  
- [ ] **Benchmark 2: Firestore sync**
  - Target: <2 seconds to sync from Firestore
  - Actual: _____
  
- [ ] **Benchmark 3: Scroll performance**
  - Target: 60fps with 100+ conversations
  - Actual: _____
  
- [ ] **Benchmark 4: Real-time latency**
  - Target: <2 seconds for new message to update list
  - Actual: _____

---

## Success Criteria

**Feature is complete when:**
- [ ] ChatListView displays all user's conversations
- [ ] Conversations load instantly from local storage
- [ ] Real-time updates work (new messages appear automatically)
- [ ] List sorted by most recent conversation first
- [ ] Each row shows: name, last message, timestamp, profile picture
- [ ] Empty state displayed when no conversations
- [ ] Tap conversation navigates to ChatView (placeholder OK)
- [ ] Pull-to-refresh works
- [ ] Offline mode works (shows local conversations)
- [ ] All tests passing
- [ ] Performance targets met
- [ ] Documentation complete
- [ ] No memory leaks (listeners cleaned up)

**Performance Targets:**
- Initial load: <1 second (local)
- Firestore sync: <2 seconds
- Real-time update latency: <2 seconds
- Scroll performance: 60fps with 100+ conversations
- Memory: <30MB for 100 conversations

**Quality Gates:**
- Zero crashes during testing
- No console errors or warnings
- Smooth animations (60fps)
- Works offline
- Real-time updates reliable

---

## Risk Assessment

### Risk 1: Real-Time Listener Memory Leaks
**Likelihood:** MEDIUM  
**Impact:** HIGH  
**Issue:** Firestore listeners not detached cause memory leaks and crashes  
**Mitigation:** 
- Proper cleanup in `stopListening()` and `onDisappear`
- Test with Xcode Instruments (Leaks tool)
- Cancel Task when view disappears
**Prevention:**
- Always pair listener start with cleanup
- Use `Task` cancellation properly
**Status:** 🟡 Mitigated (needs testing)

---

### Risk 2: Slow Initial Load
**Likelihood:** LOW  
**Impact:** MEDIUM  
**Issue:** Core Data fetch could be slow with many conversations  
**Mitigation:**
- LazyVStack (virtualized rendering)
- Limit Core Data fetch to 100 recent conversations
- Index on lastMessageAt field
**Prevention:**
- Performance testing with 100+ conversations
- Profile with Instruments (Time Profiler)
**Status:** 🟢 Low risk

---

### Risk 3: Stale Data Displayed
**Likelihood:** LOW  
**Impact:** LOW  
**Issue:** Brief moment where local data is outdated  
**Mitigation:**
- Real-time listener updates within 2 seconds
- Pull-to-refresh available
- Acceptable UX trade-off for instant display
**Prevention:**
- Clear communication in UI (optional "syncing" indicator)
**Status:** 🟢 Acceptable trade-off

---

### Risk 4: Navigation Not Working Yet
**Likelihood:** NONE  
**Impact:** NONE  
**Issue:** ChatView doesn't exist yet (PR #9)  
**Mitigation:**
- Use placeholder view for navigation
- Test navigation structure works
- Will integrate ChatView in PR #9
**Prevention:**
- Document navigation structure clearly
**Status:** 🟢 Expected (not a risk)

---

## Open Questions

1. **User Names/Photos: Where to fetch from?**
   - Option A: Add UserService in PR #7
   - Option B: Defer to PR #8 (Contact Selection)
   - **Decision needed by:** Before implementation
   - **Recommendation:** Option B (defer to PR #8, use placeholder/userID for now)

2. **Unread Count: Where to calculate?**
   - Option A: Count unread messages in ChatService
   - Option B: Store unread count in Conversation model
   - **Decision needed by:** Before implementation
   - **Recommendation:** Option B (cleaner, already part of model)

3. **Presence Status: Where to get online/offline?**
   - Option A: Add PresenceService in PR #7
   - Option B: Defer to PR #12 (Presence & Typing)
   - **Decision needed by:** Before implementation
   - **Recommendation:** Option B (defer, show placeholder indicator)

---

## Timeline

**Total Estimate:** 2-3 hours

| Phase | Task | Time | Status |
|-------|------|------|--------|
| 1 | Date Formatter Extension | 30 min | ⏳ |
| 2 | ChatListViewModel | 1 hour | ⏳ |
| 3 | ConversationRowView | 45 min | ⏳ |
| 4 | ChatListView | 45 min | ⏳ |
| 5 | Integration & Testing | 30 min | ⏳ |

---

## Dependencies

**Requires:**
- [x] PR #4 complete (Conversation model)
- [x] PR #5 complete (ChatService.fetchConversations)
- [x] PR #6 complete (LocalDataManager.fetchConversations)
- [x] Firebase Auth (current user ID)

**Blocks:**
- PR #8 (Contact Selection - needs ChatListView for navigation)
- PR #9 (ChatView - needs ChatListView to navigate from)

**Integration Points:**
- PR #8: Will add user name/photo fetching
- PR #9: Will replace navigation placeholder with real ChatView
- PR #12: Will add real presence status indicators

---

## References

- Similar Implementation: WhatsApp conversation list
- Design Reference: iOS Messages app
- Firestore Docs: [Real-time updates](https://firebase.google.com/docs/firestore/query-data/listen)
- SwiftUI Docs: [LazyVStack](https://developer.apple.com/documentation/swiftui/lazyvstack)
- Date Formatting: [RelativeDateTimeFormatter](https://developer.apple.com/documentation/foundation/relativedatetimeformatter)

---

**Status:** 📋 PLANNED - Ready to implement after PR #6  
**Complexity:** MEDIUM  
**Priority:** HIGH (critical path to MVP)

*Documentation created: October 20, 2025*

