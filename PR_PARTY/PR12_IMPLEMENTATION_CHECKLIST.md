# PR#12: Implementation Checklist - Presence & Typing Indicators

**Use this as your daily todo list.** Check off items as you complete them.

**Estimated Time:** 2-3 hours  
**Complexity:** MEDIUM  
**Branch:** `feature/pr12-presence-typing` (create this)

---

## Pre-Implementation Setup (10 minutes)

- [ ] Read main planning document `PR12_PRESENCE_TYPING.md` (~45 min)
- [ ] Review dependencies:
  - [ ] PR #4 (Core Models) ✅ Complete
  - [ ] PR #5 (ChatService) ✅ Complete
  - [ ] PR #7 (ChatListView) ✅ Complete
  - [ ] PR #9 (ChatView) ✅ Complete
  - [ ] PR #10 (Real-Time Messaging) ✅ Complete
- [ ] Verify current codebase builds successfully
- [ ] Create Git branch:
  ```bash
  git checkout main
  git pull
  git checkout -b feature/pr12-presence-typing
  ```
- [ ] Open Xcode project
- [ ] Verify Firebase console access (will need for rules deployment)

**Prerequisites Verified:** ✅

---

## Phase 1: Foundation - Presence Model & Service (45-60 minutes)

### 1.1: Create Presence Model (15 minutes)

#### Create Presence.swift

- [ ] Create new file: `messAI/Models/Presence.swift`
- [ ] Add file to Xcode project (messAI target)

#### Add Imports

- [ ] Add imports:
  ```swift
  import Foundation
  ```

#### Define Presence Struct

- [ ] Create Presence struct:
  ```swift
  struct Presence: Codable, Equatable, Identifiable {
      let id: String        // userId
      let userId: String
      var isOnline: Bool
      var lastSeen: Date
      var updatedAt: Date
      
      init(userId: String, isOnline: Bool, lastSeen: Date, updatedAt: Date) {
          self.id = userId
          self.userId = userId
          self.isOnline = isOnline
          self.lastSeen = lastSeen
          self.updatedAt = updatedAt
      }
  }
  ```

#### Add Computed Properties

- [ ] Add presenceText computed property:
  ```swift
  var presenceText: String {
      if isOnline {
          return "Active now"
      } else {
          return lastSeen.presenceText()
      }
  }
  ```

- [ ] Add statusColor computed property:
  ```swift
  var statusColor: String {
      isOnline ? "green" : "gray"
  }
  ```

#### Add Firestore Conversion

- [ ] Add toFirestore() method:
  ```swift
  func toFirestore() -> [String: Any] {
      return [
          "isOnline": isOnline,
          "lastSeen": lastSeen,
          "updatedAt": updatedAt
      ]
  }
  ```

- [ ] Add fromFirestore() static method:
  ```swift
  static func fromFirestore(_ data: [String: Any], userId: String) -> Presence? {
      guard let isOnline = data["isOnline"] as? Bool,
            let lastSeenTimestamp = data["lastSeen"] as? Timestamp,
            let updatedAtTimestamp = data["updatedAt"] as? Timestamp else {
          return nil
      }
      
      return Presence(
          userId: userId,
          isOnline: isOnline,
          lastSeen: lastSeenTimestamp.dateValue(),
          updatedAt: updatedAtTimestamp.dateValue()
      )
  }
  ```

- [ ] Add import for Firestore: `import FirebaseFirestore`

#### Test Compilation

- [ ] Build project: `Cmd+B`
- [ ] Verify: 0 errors related to Presence.swift
- [ ] Verify: Can create Presence instance in preview/test

**Checkpoint:** Presence model compiles ✓

**Commit:**
```bash
git add messAI/Models/Presence.swift
git commit -m "[PR #12] Add Presence model with Firestore conversion"
```

---

### 1.2: Create PresenceService (30 minutes)

#### Create PresenceService.swift

- [ ] Create new file: `messAI/Services/PresenceService.swift`
- [ ] Add file to Xcode project (messAI target)

#### Add Imports

- [ ] Add imports:
  ```swift
  import Foundation
  import FirebaseFirestore
  import Combine
  ```

#### Define Service Class

- [ ] Create PresenceService class:
  ```swift
  @MainActor
  class PresenceService: ObservableObject {
      static let shared = PresenceService()
      
      private let db = Firestore.firestore()
      private var presenceListeners: [String: ListenerRegistration] = [:]
      
      @Published var userPresence: [String: Presence] = [:]
      
      private init() {}
  }
  ```

#### Implement goOnline() Method

- [ ] Add goOnline() method:
  ```swift
  /// Set current user as online
  func goOnline(_ userId: String) async throws {
      let presence = Presence(
          userId: userId,
          isOnline: true,
          lastSeen: Date(),
          updatedAt: Date()
      )
      
      try await db.collection("presence").document(userId)
          .setData(presence.toFirestore())
      
      print("✅ Presence: User \(userId) is now online")
  }
  ```

#### Implement goOffline() Method

- [ ] Add goOffline() method:
  ```swift
  /// Set current user as offline
  func goOffline(_ userId: String) async throws {
      try await db.collection("presence").document(userId)
          .updateData([
              "isOnline": false,
              "lastSeen": FieldValue.serverTimestamp(),
              "updatedAt": FieldValue.serverTimestamp()
          ])
      
      print("✅ Presence: User \(userId) is now offline")
  }
  ```

#### Implement observePresence() Method

- [ ] Add observePresence() method:
  ```swift
  /// Observe presence for a specific user (real-time)
  func observePresence(_ userId: String) {
      // Don't create duplicate listeners
      guard presenceListeners[userId] == nil else {
          print("⚠️ Presence listener already exists for \(userId)")
          return
      }
      
      print("👀 Starting presence listener for user: \(userId)")
      
      let listener = db.collection("presence").document(userId)
          .addSnapshotListener { [weak self] snapshot, error in
              guard let self = self else { return }
              
              if let error = error {
                  print("❌ Presence listener error: \(error)")
                  return
              }
              
              guard let data = snapshot?.data() else {
                  print("⚠️ No presence data for user: \(userId)")
                  return
              }
              
              if let presence = Presence.fromFirestore(data, userId: userId) {
                  Task { @MainActor in
                      self.userPresence[userId] = presence
                      print("✅ Updated presence for \(userId): \(presence.presenceText)")
                  }
              }
          }
      
      presenceListeners[userId] = listener
  }
  ```

#### Implement stopObservingPresence() Method

- [ ] Add stopObservingPresence() method:
  ```swift
  /// Stop observing presence for a user
  func stopObservingPresence(_ userId: String) {
      presenceListeners[userId]?.remove()
      presenceListeners[userId] = nil
      userPresence[userId] = nil
      print("🛑 Stopped presence listener for user: \(userId)")
  }
  ```

#### Implement stopAllListeners() Method

- [ ] Add stopAllListeners() method:
  ```swift
  /// Stop all presence listeners
  func stopAllListeners() {
      print("🛑 Stopping all presence listeners (\(presenceListeners.count) active)")
      presenceListeners.forEach { $0.value.remove() }
      presenceListeners.removeAll()
      userPresence.removeAll()
  }
  ```

#### Implement fetchPresence() Methods

- [ ] Add single user fetch:
  ```swift
  /// Fetch presence for a user (one-time, not real-time)
  func fetchPresence(_ userId: String) async throws -> Presence? {
      let snapshot = try await db.collection("presence")
          .document(userId).getDocument()
      
      guard let data = snapshot.data() else { return nil }
      return Presence.fromFirestore(data, userId: userId)
  }
  ```

- [ ] Add batch fetch method:
  ```swift
  /// Fetch presence for multiple users (batch)
  func fetchPresence(userIds: [String]) async throws -> [String: Presence] {
      var presenceMap: [String: Presence] = [:]
      
      // Firestore 'in' queries limited to 10 items
      let chunks = userIds.chunked(into: 10)
      
      for chunk in chunks {
          let snapshot = try await db.collection("presence")
              .whereField(FieldPath.documentID(), in: chunk)
              .getDocuments()
          
          for doc in snapshot.documents {
              if let presence = Presence.fromFirestore(doc.data(), userId: doc.documentID) {
                  presenceMap[doc.documentID] = presence
              }
          }
      }
      
      return presenceMap
  }
  ```

- [ ] Add Array extension for chunking:
  ```swift
  // At bottom of file
  extension Array {
      func chunked(into size: Int) -> [[Element]] {
          stride(from: 0, to: count, by: size).map {
              Array(self[$0..<Swift.min($0 + size, count)])
          }
      }
  }
  ```

#### Test Compilation

- [ ] Build project: `Cmd+B`
- [ ] Verify: 0 errors in PresenceService.swift
- [ ] Verify: goOnline/goOffline methods exist
- [ ] Verify: observePresence method exists

**Checkpoint:** PresenceService compiles ✓

**Commit:**
```bash
git add messAI/Services/PresenceService.swift
git commit -m "[PR #12] Implement PresenceService with real-time listeners"
```

---

### 1.3: Add Date Extension for Presence Text (15 minutes)

#### Open DateFormatter+Extensions.swift

- [ ] Open `messAI/Utilities/DateFormatter+Extensions.swift`
- [ ] Verify file exists (created in PR #7)

#### Add presenceText() Method

- [ ] Add new extension method at bottom of file:
  ```swift
  // MARK: - Presence Formatting
  
  extension Date {
      /// Format date as presence text: "Active now", "5m ago", "Last seen recently"
      func presenceText() -> String {
          let now = Date()
          let seconds = now.timeIntervalSince(self)
          
          switch seconds {
          case 0..<60:
              // Less than 1 minute
              return "Active now"
              
          case 60..<300:
              // 1-5 minutes
              let minutes = Int(seconds / 60)
              return "\(minutes)m ago"
              
          case 300..<3600:
              // 5-60 minutes
              return "Active recently"
              
          case 3600..<86400:
              // 1-24 hours
              return "Last seen today"
              
          default:
              // More than 24 hours
              return "Last seen recently"
          }
      }
  }
  ```

#### Test Logic

- [ ] Test in playground or preview:
  ```swift
  let now = Date()
  let oneMinuteAgo = now.addingTimeInterval(-60)
  let fiveMinutesAgo = now.addingTimeInterval(-300)
  let oneDayAgo = now.addingTimeInterval(-86400)
  
  print(now.presenceText())          // "Active now"
  print(oneMinuteAgo.presenceText())  // "1m ago"
  print(fiveMinutesAgo.presenceText()) // "Active recently"
  print(oneDayAgo.presenceText())     // "Last seen recently"
  ```

#### Build & Verify

- [ ] Build project: `Cmd+B`
- [ ] Verify: 0 errors
- [ ] Verify: presenceText() method available on Date

**Checkpoint:** Presence text formatting works ✓

**Commit:**
```bash
git add messAI/Utilities/DateFormatter+Extensions.swift
git commit -m "[PR #12] Add presenceText() formatter for last seen display"
```

---

**Phase 1 Complete!** ✅ (Presence model, service, and formatting)

**Time Check:** Should be ~45-60 minutes into PR

---

## Phase 2: App Lifecycle Integration (30 minutes)

### 2.1: Add Scene Phase Observer (20 minutes)

#### Open messAIApp.swift

- [ ] Open `messAI/messAIApp.swift`

#### Import ScenePhase

- [ ] Add to imports (if not already present):
  ```swift
  import SwiftUI
  ```

#### Add ScenePhase Environment

- [ ] Add after existing @StateObject properties:
  ```swift
  @Environment(\.scenePhase) var scenePhase
  ```

#### Add onChange Modifier

- [ ] Add to WindowGroup:
  ```swift
  var body: some Scene {
      WindowGroup {
          ContentView()
              .environmentObject(authViewModel)
      }
      .onChange(of: scenePhase) { oldPhase, newPhase in
          handleScenePhaseChange(newPhase)
      }
  }
  ```

#### Implement handleScenePhaseChange()

- [ ] Add method to messAIApp struct:
  ```swift
  /// Handle app lifecycle changes and update presence
  func handleScenePhaseChange(_ phase: ScenePhase) {
      // Only update presence if user is logged in
      guard let userId = authViewModel.currentUser?.id else {
          print("⚠️ No user logged in, skipping presence update")
          return
      }
      
      switch phase {
      case .active:
          // App entered foreground - mark online
          print("🟢 App active - marking user online")
          Task {
              do {
                  try await PresenceService.shared.goOnline(userId)
              } catch {
                  print("❌ Failed to go online: \(error)")
              }
          }
          
      case .inactive:
          // Brief transition (e.g., notification center pulled down)
          // Don't change presence - user might come right back
          print("🟡 App inactive - no presence change")
          break
          
      case .background:
          // App backgrounded - mark offline
          print("🔴 App background - marking user offline")
          Task {
              do {
                  try await PresenceService.shared.goOffline(userId)
              } catch {
                  print("❌ Failed to go offline: \(error)")
              }
          }
          
      @unknown default:
          print("⚠️ Unknown scene phase: \(phase)")
          break
      }
  }
  ```

#### Build & Test

- [ ] Build project: `Cmd+B`
- [ ] Verify: 0 errors
- [ ] Run on simulator
- [ ] Check console: Should see "App active" message on launch
- [ ] Press Home button (Cmd+Shift+H)
- [ ] Check console: Should see "App background" message
- [ ] Reopen app
- [ ] Check console: Should see "App active" again

**Checkpoint:** App lifecycle updates presence ✓

**Commit:**
```bash
git add messAI/messAIApp.swift
git commit -m "[PR #12] Integrate presence updates with app lifecycle"
```

---

### 2.2: Handle Sign In/Out (10 minutes)

#### Open AuthViewModel.swift

- [ ] Open `messAI/ViewModels/AuthViewModel.swift`

#### Update signIn() Method

- [ ] Find the `signIn()` method
- [ ] After successful authentication, add:
  ```swift
  // Inside signIn() after user is set
  if let userId = currentUser?.id {
      Task {
          try? await PresenceService.shared.goOnline(userId)
          print("✅ Set presence online after sign in")
      }
  }
  ```

#### Update signOut() Method

- [ ] Find the `signOut()` method
- [ ] Before calling Firebase sign out, add:
  ```swift
  // Inside signOut() before Auth.auth().signOut()
  if let userId = currentUser?.id {
      Task {
          try? await PresenceService.shared.goOffline(userId)
          print("✅ Set presence offline before sign out")
      }
  }
  ```

#### Build & Test

- [ ] Build project: `Cmd+B`
- [ ] Verify: 0 errors
- [ ] Run app, sign in
- [ ] Check Firestore console: `presence/{userId}` should have `isOnline: true`
- [ ] Sign out
- [ ] Check Firestore: `isOnline: false`, `lastSeen` updated

**Checkpoint:** Authentication updates presence ✓

**Commit:**
```bash
git add messAI/ViewModels/AuthViewModel.swift
git commit -m "[PR #12] Update presence on authentication state changes"
```

---

**Phase 2 Complete!** ✅ (App lifecycle integration)

**Time Check:** Should be ~1.5 hours into PR

---

## Phase 3: ChatListView Presence (30-45 minutes)

### 3.1: Update ChatListViewModel (20 minutes)

#### Open ChatListViewModel.swift

- [ ] Open `messAI/ViewModels/ChatListViewModel.swift`

#### Add Presence Property

- [ ] Add after existing @Published properties:
  ```swift
  @Published var presenceMap: [String: Presence] = [:]
  ```

#### Add Presence Subscription

- [ ] In `init()` or after setting up other subscriptions:
  ```swift
  // Subscribe to presence updates
  PresenceService.shared.$userPresence
      .receive(on: DispatchQueue.main)
      .sink { [weak self] presenceMap in
          self?.presenceMap = presenceMap
      }
      .store(in: &cancellables)
  ```

#### Observe Presence for Participants

- [ ] Add method to start observing:
  ```swift
  /// Start observing presence for all conversation participants
  func observePresenceForConversations() {
      // Extract all unique participant IDs
      var allParticipants = Set<String>()
      
      for conversation in conversations {
          allParticipants.formUnion(conversation.participantIds)
      }
      
      // Remove current user (don't need to observe self)
      if let currentUserId = AuthService.shared.currentUserId {
          allParticipants.remove(currentUserId)
      }
      
      // Start observing each participant
      for userId in allParticipants {
          PresenceService.shared.observePresence(userId)
      }
      
      print("👀 Observing presence for \(allParticipants.count) users")
  }
  ```

- [ ] Call this method after conversations load:
  ```swift
  // In loadConversations() after conversations are fetched
  observePresenceForConversations()
  ```

#### Add Cleanup Method

- [ ] Update existing cleanup/stopListener method (or create if doesn't exist):
  ```swift
  func cleanup() {
      stopRealtimeSync()
      PresenceService.shared.stopAllListeners()
      print("🧹 ChatListViewModel cleanup complete")
  }
  ```

- [ ] Ensure cleanup is called on deinit:
  ```swift
  deinit {
      cleanup()
  }
  ```

#### Build & Verify

- [ ] Build project: `Cmd+B`
- [ ] Verify: 0 errors
- [ ] Verify: presenceMap property exists
- [ ] Verify: observePresenceForConversations() method exists

**Checkpoint:** ChatListViewModel observes presence ✓

**Commit:**
```bash
git add messAI/ViewModels/ChatListViewModel.swift
git commit -m "[PR #12] ChatListViewModel observes presence for participants"
```

---

### 3.2: Update ConversationRowView (25 minutes)

#### Open ConversationRowView.swift

- [ ] Open `messAI/Views/Chat/ConversationRowView.swift`

#### Add Presence Parameter

- [ ] Add to struct properties:
  ```swift
  let presence: Presence?
  ```

#### Add Presence Dot to Avatar

- [ ] Find the AsyncImage or profile picture view
- [ ] Wrap in ZStack and add overlay:
  ```swift
  ZStack(alignment: .bottomTrailing) {
      // Existing AsyncImage or Circle
      AsyncImage(url: URL(string: conversation.photoURL ?? "")) { image in
          image
              .resizable()
              .scaledToFill()
      } placeholder: {
          Circle()
              .fill(Color.gray.opacity(0.3))
              .overlay(
                  Text(conversationName.prefix(1))
                      .font(.title2)
                      .foregroundColor(.white)
              )
      }
      .frame(width: 56, height: 56)
      .clipShape(Circle())
      
      // Presence dot (only for 1-on-1 chats)
      if !conversation.isGroup, let presence = presence {
          Circle()
              .fill(presence.isOnline ? Color.green : Color.gray)
              .frame(width: 12, height: 12)
              .overlay(
                  Circle()
                      .stroke(Color.white, lineWidth: 2)
              )
              .offset(x: -2, y: -2)
      }
  }
  ```

#### Add Presence Text Below Name

- [ ] Find the VStack with conversation name and last message
- [ ] Add presence text:
  ```swift
  VStack(alignment: .leading, spacing: 4) {
      Text(conversationName)
          .font(.headline)
      
      // Presence text (only for 1-on-1)
      if !conversation.isGroup, let presence = presence {
          Text(presence.presenceText)
              .font(.caption)
              .foregroundColor(.secondary)
      }
      
      Text(conversation.lastMessage)
          .font(.subheadline)
          .foregroundColor(.secondary)
          .lineLimit(1)
  }
  ```

#### Update Preview

- [ ] Update preview provider with sample presence:
  ```swift
  #Preview {
      let sampleConversation = Conversation(
          // ... existing sample data
      )
      
      let samplePresence = Presence(
          userId: "user123",
          isOnline: true,
          lastSeen: Date(),
          updatedAt: Date()
      )
      
      return ConversationRowView(
          conversation: sampleConversation,
          presence: samplePresence
      )
      .padding()
  }
  ```

#### Build & Test Preview

- [ ] Build project: `Cmd+B`
- [ ] Verify: 0 errors
- [ ] Open preview: Cmd+Opt+Return
- [ ] Verify: Green dot appears on avatar
- [ ] Verify: "Active now" appears below name
- [ ] Change presence to offline in preview, verify gray dot

**Checkpoint:** Presence displays in conversation row ✓

**Commit:**
```bash
git add messAI/Views/Chat/ConversationRowView.swift
git commit -m "[PR #12] Display presence indicator in ConversationRowView"
```

---

### 3.3: Wire Up in ChatListView (10 minutes)

#### Open ChatListView.swift

- [ ] Open `messAI/Views/Chat/ChatListView.swift`

#### Pass Presence to ConversationRow

- [ ] Find where ConversationRowView is created in LazyVStack
- [ ] Calculate other user ID (for 1-on-1):
  ```swift
  ForEach(viewModel.conversations) { conversation in
      let otherUserId = conversation.participantIds.first { $0 != viewModel.currentUserId } ?? ""
      let presence = viewModel.presenceMap[otherUserId]
      
      NavigationLink(value: conversation.id) {
          ConversationRowView(
              conversation: conversation,
              presence: presence
          )
      }
  }
  ```

- [ ] Ensure currentUserId is available in ChatListViewModel (should be from AuthService)

#### Build & Test

- [ ] Build project: `Cmd+B`
- [ ] Verify: 0 errors
- [ ] Run app on simulator
- [ ] Navigate to chat list
- [ ] Create a test conversation (if none exist)
- [ ] Verify: Presence dot appears (may need 2 devices to see online/offline)

**Checkpoint:** Presence integrated in ChatListView ✓

**Commit:**
```bash
git add messAI/Views/Chat/ChatListView.swift
git commit -m "[PR #12] Integrate presence display in ChatListView"
```

---

**Phase 3 Complete!** ✅ (ChatListView presence)

**Time Check:** Should be ~2-2.5 hours into PR

---

## Phase 4: ChatView Presence (20-30 minutes)

### 4.1: Update ChatViewModel (15 minutes)

#### Open ChatViewModel.swift

- [ ] Open `messAI/ViewModels/ChatViewModel.swift`

#### Add Presence Property

- [ ] Add after existing @Published properties:
  ```swift
  @Published var otherUserPresence: Presence?
  ```

#### Calculate Other User ID

- [ ] Add helper computed property:
  ```swift
  private var otherUserId: String? {
      // For 1-on-1 chat, find the other user
      if !conversation.isGroup {
          return conversation.participantIds.first { $0 != currentUserId }
      }
      return nil
  }
  ```

#### Start Observing Presence

- [ ] In `init()` or `onAppear()` equivalent:
  ```swift
  func startObservingPresence() {
      guard let otherUserId = otherUserId else {
          print("⚠️ No other user to observe (group chat or error)")
          return
      }
      
      print("👀 Starting presence observation for: \(otherUserId)")
      PresenceService.shared.observePresence(otherUserId)
      
      // Subscribe to presence updates
      PresenceService.shared.$userPresence
          .map { $0[otherUserId] }
          .receive(on: DispatchQueue.main)
          .assign(to: &$otherUserPresence)
  }
  ```

- [ ] Call from appropriate lifecycle:
  ```swift
  // If using init
  init(conversationId: String, chatService: ChatService) {
      // ... existing init code
      startObservingPresence()
  }
  ```

#### Stop Observing on Cleanup

- [ ] Update cleanup/deinit:
  ```swift
  func cleanup() {
      stopRealtimeSync()
      if let otherUserId = otherUserId {
          PresenceService.shared.stopObservingPresence(otherUserId)
      }
      print("🧹 ChatViewModel cleanup complete")
  }
  
  deinit {
      cleanup()
  }
  ```

#### Build & Verify

- [ ] Build project: `Cmd+B`
- [ ] Verify: 0 errors
- [ ] Verify: otherUserPresence property exists

**Checkpoint:** ChatViewModel observes other user presence ✓

**Commit:**
```bash
git add messAI/ViewModels/ChatViewModel.swift
git commit -m "[PR #12] ChatViewModel observes other user's presence"
```

---

### 4.2: Update ChatView Navigation Title (15 minutes)

#### Open ChatView.swift

- [ ] Open `messAI/Views/Chat/ChatView.swift`

#### Find Navigation Title

- [ ] Locate existing `.navigationTitle()` or `.toolbar()` modifier

#### Replace with Custom Toolbar

- [ ] Replace/update to show presence subtitle:
  ```swift
  .toolbar {
      ToolbarItem(placement: .principal) {
          VStack(spacing: 2) {
              // Conversation name
              Text(conversationName)
                  .font(.headline)
                  .fontWeight(.semibold)
              
              // Presence subtitle (only for 1-on-1)
              if !viewModel.conversation.isGroup, let presence = viewModel.otherUserPresence {
                  Text(presence.presenceText)
                      .font(.caption)
                      .foregroundColor(.secondary)
              }
          }
      }
  }
  ```

#### Update Preview

- [ ] Update preview with sample presence:
  ```swift
  #Preview {
      let samplePresence = Presence(
          userId: "user123",
          isOnline: true,
          lastSeen: Date(),
          updatedAt: Date()
      )
      
      // Inject into ChatViewModel somehow, or just verify compilation
      return NavigationStack {
          ChatView(conversationId: "conv123")
      }
  }
  ```

#### Build & Test

- [ ] Build project: `Cmd+B`
- [ ] Verify: 0 errors
- [ ] Run app
- [ ] Open a conversation
- [ ] Verify: Title shows name + presence subtitle
- [ ] Test with 2 devices: background one, see "Last seen" update on other

**Checkpoint:** Presence displays in ChatView title ✓

**Commit:**
```bash
git add messAI/Views/Chat/ChatView.swift
git commit -m "[PR #12] Display presence in ChatView navigation title"
```

---

**Phase 4 Complete!** ✅ (ChatView presence)

**Time Check:** Should be ~2.5-3 hours into PR

---

## Phase 5: Typing Indicators (60-75 minutes)

### 5.1: Add Typing Methods to ChatService (25 minutes)

#### Open ChatService.swift

- [ ] Open `messAI/Services/ChatService.swift`

#### Add Typing Listener Property

- [ ] Add after existing listener properties:
  ```swift
  private var typingListeners: [String: ListenerRegistration] = [:]
  ```

#### Implement updateTypingStatus() Method

- [ ] Add typing update method:
  ```swift
  // MARK: - Typing Status
  
  /// Update typing status for current user in conversation
  func updateTypingStatus(_ conversationId: String, userId: String, isTyping: Bool) async throws {
      if isTyping {
          // User started typing - write current timestamp
          try await db.collection("typingStatus").document(conversationId)
              .setData([userId: FieldValue.serverTimestamp()], merge: true)
          print("⌨️ Updated typing status: \(userId) is typing in \(conversationId)")
      } else {
          // User stopped typing - remove their entry
          try await db.collection("typingStatus").document(conversationId)
              .updateData([userId: FieldValue.delete()])
          print("⌨️ Cleared typing status: \(userId) stopped typing")
      }
  }
  ```

#### Implement observeTypingStatus() Method

- [ ] Add typing observer:
  ```swift
  /// Observe typing status for a conversation (real-time)
  func observeTypingStatus(_ conversationId: String) -> AsyncThrowingStream<[String: Date], Error> {
      AsyncThrowingStream { continuation in
          print("👀 Starting typing status listener for: \(conversationId)")
          
          let listener = db.collection("typingStatus").document(conversationId)
              .addSnapshotListener { snapshot, error in
                  if let error = error {
                      print("❌ Typing listener error: \(error)")
                      continuation.finish(throwing: error)
                      return
                  }
                  
                  guard let data = snapshot?.data() else {
                      // No one typing
                      continuation.yield([:])
                      return
                  }
                  
                  // Convert Firestore timestamps to Date
                  var typingMap: [String: Date] = [:]
                  for (userId, value) in data {
                      if let timestamp = value as? Timestamp {
                          typingMap[userId] = timestamp.dateValue()
                      }
                  }
                  
                  continuation.yield(typingMap)
              }
          
          // Store listener for cleanup
          typingListeners[conversationId] = listener
          
          continuation.onTermination = { @Sendable _ in
              listener.remove()
              print("🛑 Typing listener terminated for: \(conversationId)")
          }
      }
  }
  ```

#### Implement stopObservingTyping() Method

- [ ] Add cleanup method:
  ```swift
  /// Stop observing typing status
  func stopObservingTyping(_ conversationId: String) {
      typingListeners[conversationId]?.remove()
      typingListeners[conversationId] = nil
      print("🛑 Stopped typing listener for: \(conversationId)")
  }
  ```

#### Build & Verify

- [ ] Build project: `Cmd+B`
- [ ] Verify: 0 errors
- [ ] Verify: updateTypingStatus() exists
- [ ] Verify: observeTypingStatus() exists

**Checkpoint:** ChatService has typing methods ✓

**Commit:**
```bash
git add messAI/Services/ChatService.swift
git commit -m "[PR #12] Add typing status methods to ChatService"
```

---

### 5.2: Update ChatViewModel with Typing Logic (25 minutes)

#### Open ChatViewModel.swift

- [ ] Open `messAI/ViewModels/ChatViewModel.swift`

#### Add Typing Properties

- [ ] Add after existing @Published properties:
  ```swift
  @Published var typingUserIds: [String] = []
  private var typingDebounceTask: Task<Void, Never>?
  private var typingListenerTask: Task<Void, Never>?
  ```

#### Add Typing User Names Computed Property

- [ ] Add computed property for display:
  ```swift
  var typingUserNames: [String] {
      // For MVP: return generic names (would fetch from UserService in production)
      // Filter out current user
      let otherUsers = typingUserIds.filter { $0 != currentUserId }
      return otherUsers.map { _ in "Someone" }  // Placeholder
  }
  ```

#### Implement startObservingTyping() Method

- [ ] Add typing observer:
  ```swift
  /// Start observing typing status for this conversation
  func startObservingTyping() {
      typingListenerTask = Task {
          do {
              for try await typingMap in chatService.observeTypingStatus(conversationId) {
                  let now = Date()
                  
                  // Filter out stale entries (>3 seconds old)
                  let activeTyping = typingMap.filter { _, timestamp in
                      now.timeIntervalSince(timestamp) < 3.0
                  }
                  
                  // Exclude current user
                  let otherUsers = activeTyping.keys.filter { $0 != currentUserId }
                  
                  await MainActor.run {
                      self.typingUserIds = Array(otherUsers)
                      if !otherUsers.isEmpty {
                          print("⌨️ Users typing: \(otherUsers.joined(separator: ", "))")
                      }
                  }
              }
          } catch {
              print("❌ Typing listener error: \(error)")
          }
      }
  }
  ```

#### Implement userStartedTyping() Method

- [ ] Add debounced typing update:
  ```swift
  /// User started typing (debounced)
  func userStartedTyping() {
      // Cancel previous task if still pending
      typingDebounceTask?.cancel()
      
      // Create new debounced task
      typingDebounceTask = Task {
          do {
              // Wait 500ms
              try await Task.sleep(for: .milliseconds(500))
              
              // Check if cancelled
              guard !Task.isCancelled else { return }
              
              // Send typing update
              try await chatService.updateTypingStatus(conversationId, userId: currentUserId, isTyping: true)
          } catch {
              print("❌ Failed to update typing status: \(error)")
          }
      }
  }
  ```

#### Implement userStoppedTyping() Method

- [ ] Add stopped typing method:
  ```swift
  /// User stopped typing
  func userStoppedTyping() {
      // Cancel pending debounce
      typingDebounceTask?.cancel()
      
      // Immediately clear typing status
      Task {
          do {
              try await chatService.updateTypingStatus(conversationId, userId: currentUserId, isTyping: false)
          } catch {
              print("❌ Failed to clear typing status: \(error)")
          }
      }
  }
  ```

#### Call startObservingTyping() in Init

- [ ] Add to init or onAppear:
  ```swift
  // In init() after other setup
  startObservingTyping()
  ```

#### Update Cleanup

- [ ] Update cleanup method:
  ```swift
  func cleanup() {
      stopRealtimeSync()
      
      // Stop typing observer
      typingListenerTask?.cancel()
      chatService.stopObservingTyping(conversationId)
      
      // Clear typing status (user left conversation)
      Task {
          try? await chatService.updateTypingStatus(conversationId, userId: currentUserId, isTyping: false)
      }
      
      // Stop presence observer
      if let otherUserId = otherUserId {
          PresenceService.shared.stopObservingPresence(otherUserId)
      }
      
      print("🧹 ChatViewModel cleanup complete")
  }
  ```

#### Build & Verify

- [ ] Build project: `Cmd+B`
- [ ] Verify: 0 errors
- [ ] Verify: typingUserIds property exists
- [ ] Verify: userStartedTyping() and userStoppedTyping() exist

**Checkpoint:** ChatViewModel has typing logic ✓

**Commit:**
```bash
git add messAI/ViewModels/ChatViewModel.swift
git commit -m "[PR #12] Implement typing detection with debouncing in ChatViewModel"
```

---

### 5.3: Create TypingIndicatorView (15 minutes)

#### Create TypingIndicatorView.swift

- [ ] Create new file: `messAI/Views/Chat/TypingIndicatorView.swift`
- [ ] Add file to Xcode project (messAI target)

#### Add Imports

- [ ] Add imports:
  ```swift
  import SwiftUI
  ```

#### Define TypingIndicatorView

- [ ] Create view:
  ```swift
  struct TypingIndicatorView: View {
      let userName: String
      @State private var dotCount = 1
      @State private var timer: Timer?
      
      var body: some View {
          HStack(spacing: 8) {
              // Small avatar (24x24)
              Circle()
                  .fill(Color.gray.opacity(0.3))
                  .frame(width: 24, height: 24)
                  .overlay(
                      Text(userName.prefix(1).uppercased())
                          .font(.caption2)
                          .foregroundColor(.white)
                  )
              
              // Animated dots
              Text("\(userName) is typing\(String(repeating: ".", count: dotCount))")
                  .font(.caption)
                  .foregroundColor(.secondary)
          }
          .padding(.horizontal, 12)
          .padding(.vertical, 6)
          .background(Color(.systemGray6))
          .cornerRadius(16)
          .onAppear {
              startAnimation()
          }
          .onDisappear {
              stopAnimation()
          }
      }
      
      private func startAnimation() {
          timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
              withAnimation(.easeInOut(duration: 0.3)) {
                  dotCount = (dotCount % 3) + 1
              }
          }
      }
      
      private func stopAnimation() {
          timer?.invalidate()
          timer = nil
      }
  }
  ```

#### Add Preview

- [ ] Add preview:
  ```swift
  #Preview {
      VStack(spacing: 20) {
          TypingIndicatorView(userName: "Alice")
          TypingIndicatorView(userName: "Bob Thompson")
      }
      .padding()
  }
  ```

#### Build & Test Preview

- [ ] Build project: `Cmd+B`
- [ ] Verify: 0 errors
- [ ] Open preview: Cmd+Opt+Return
- [ ] Verify: Dots animate 1 → 2 → 3 → 1
- [ ] Verify: Avatar shows first letter of name

**Checkpoint:** TypingIndicatorView animates ✓

**Commit:**
```bash
git add messAI/Views/Chat/TypingIndicatorView.swift
git commit -m "[PR #12] Create animated TypingIndicatorView component"
```

---

### 5.4: Integrate Typing in ChatView (10 minutes)

#### Open ChatView.swift

- [ ] Open `messAI/Views/Chat/ChatView.swift`

#### Add Typing Indicator Above Input

- [ ] Find MessageInputView location
- [ ] Add typing indicator above it:
  ```swift
  // Above MessageInputView
  if !viewModel.typingUserIds.isEmpty {
      TypingIndicatorView(userName: viewModel.typingUserNames.first ?? "Someone")
          .padding(.horizontal)
          .transition(.opacity.combined(with: .move(edge: .bottom)))
  }
  ```

#### Build & Test

- [ ] Build project: `Cmd+B`
- [ ] Verify: 0 errors
- [ ] Run app (need 2 devices for full test)
- [ ] Note: Will see typing indicator when implemented in next step

**Checkpoint:** Typing indicator displays in UI ✓

**Commit:**
```bash
git add messAI/Views/Chat/ChatView.swift
git commit -m "[PR #12] Display typing indicator in ChatView"
```

---

### 5.5: Update MessageInputView to Trigger Typing (10 minutes)

#### Open MessageInputView.swift

- [ ] Open `messAI/Views/Chat/MessageInputView.swift`

#### Add Typing Callbacks

- [ ] Add to struct properties:
  ```swift
  var onTyping: (() -> Void)?
  var onStoppedTyping: (() -> Void)?
  ```

#### Add onChange Modifier

- [ ] Add to TextField or messageText binding:
  ```swift
  .onChange(of: messageText) { oldValue, newValue in
      if newValue.isEmpty && !oldValue.isEmpty {
          // User cleared text - stopped typing
          onStoppedTyping?()
      } else if !newValue.isEmpty && oldValue.isEmpty {
          // User just started typing
          onTyping?()
      }
      // Don't call onTyping for every character (debounced in ViewModel)
  }
  ```

#### Update ChatView Integration

- [ ] Go back to ChatView.swift
- [ ] Update MessageInputView call:
  ```swift
  MessageInputView(
      messageText: $viewModel.messageText,
      onSend: {
          viewModel.sendMessage()
          viewModel.userStoppedTyping()  // Clear typing on send
      },
      onTyping: {
          viewModel.userStartedTyping()
      },
      onStoppedTyping: {
          viewModel.userStoppedTyping()
      }
  )
  ```

#### Build & Test

- [ ] Build project: `Cmd+B`
- [ ] Verify: 0 errors
- [ ] Test typing detection:
  - Type in input → should trigger userStartedTyping()
  - Clear text → should trigger userStoppedTyping()
  - Send message → should clear typing

**Checkpoint:** Typing triggers from input field ✓

**Commit:**
```bash
git add messAI/Views/Chat/MessageInputView.swift messAI/Views/Chat/ChatView.swift
git commit -m "[PR #12] Trigger typing updates from MessageInputView"
```

---

**Phase 5 Complete!** ✅ (Typing indicators)

**Time Check:** Should be ~3-4 hours into PR (allow extra time for debugging)

---

## Phase 6: Firestore Security Rules (15 minutes)

### 6.1: Update firestore.rules (10 minutes)

#### Open firestore.rules

- [ ] Open `firebase/firestore.rules`

#### Add Presence Rules

- [ ] Add after existing rules (before closing braces):
  ```javascript
  // Presence: anyone can read, users can only write their own
  match /presence/{userId} {
    allow read: if request.auth != null;
    allow write: if request.auth != null && request.auth.uid == userId;
  }
  ```

#### Add Typing Status Rules

- [ ] Add typing status rules:
  ```javascript
  // Typing Status: users can read/write for their conversations only
  match /typingStatus/{conversationId} {
    allow read: if request.auth != null 
                && request.auth.uid in get(/databases/$(database)/documents/conversations/$(conversationId)).data.participants;
    
    allow write: if request.auth != null
                 && request.auth.uid in get(/databases/$(database)/documents/conversations/$(conversationId)).data.participants;
  }
  ```

#### Verify Full Rules File

- [ ] Verify complete rules structure:
  ```javascript
  rules_version = '2';
  service cloud.firestore {
    match /databases/{database}/documents {
      
      // ... existing rules (users, conversations, messages)
      
      // Presence rules (NEW)
      match /presence/{userId} {
        allow read: if request.auth != null;
        allow write: if request.auth != null && request.auth.uid == userId;
      }
      
      // Typing status rules (NEW)
      match /typingStatus/{conversationId} {
        allow read: if request.auth != null 
                    && request.auth.uid in get(/databases/$(database)/documents/conversations/$(conversationId)).data.participants;
        
        allow write: if request.auth != null
                     && request.auth.uid in get(/databases/$(database)/documents/conversations/$(conversationId)).data.participants;
      }
    }
  }
  ```

**Commit:**
```bash
git add firebase/firestore.rules
git commit -m "[PR #12] Add Firestore security rules for presence and typing"
```

---

### 6.2: Deploy Rules to Firebase (5 minutes)

#### Deploy via Firebase CLI

- [ ] Open Terminal in project root
- [ ] Deploy rules:
  ```bash
  firebase deploy --only firestore:rules
  ```

- [ ] Expected output:
  ```
  === Deploying to 'messageai-xxxxx'...
  
  i  firestore: checking firestore.rules for compilation errors...
  ✔  firestore: rules file firestore.rules compiled successfully
  i  firestore: uploading rules firestore.rules...
  ✔  firestore: released rules firestore.rules to cloud.firestore
  
  ✔  Deploy complete!
  ```

#### Verify in Firebase Console

- [ ] Open Firebase Console: https://console.firebase.google.com
- [ ] Navigate to: Firestore Database → Rules tab
- [ ] Verify: presence and typingStatus rules visible
- [ ] Verify: Published timestamp shows recent time

**Checkpoint:** Firestore rules deployed ✓

**Commit:**
```bash
# Rules already committed above, just note deployment
# Add deployment confirmation to PR notes
```

---

**Phase 6 Complete!** ✅ (Firestore security rules)

---

## Final Testing & Verification (30 minutes)

### Build & Run Tests

#### Clean Build

- [ ] Clean build folder: Cmd+Shift+K
- [ ] Build project: Cmd+B
- [ ] Expected: 0 errors, 0 warnings (except existing unrelated warnings)
- [ ] Run on simulator: Cmd+R
- [ ] Expected: App launches successfully

#### Presence Testing (10 minutes)

- [ ] Test app lifecycle:
  - [ ] Launch app → online
  - [ ] Check Firestore: presence/{userId} isOnline = true ✓
  - [ ] Background app (Cmd+Shift+H)
  - [ ] Check Firestore: isOnline = false, lastSeen updated ✓
  - [ ] Foreground app
  - [ ] Check Firestore: isOnline = true again ✓

- [ ] Test chat list:
  - [ ] Open chat list
  - [ ] Verify: Green/gray dots on avatars (if test users exist)
  - [ ] Verify: "Active now" or "Last seen X ago" text

- [ ] Test chat view:
  - [ ] Open conversation
  - [ ] Verify: Navigation subtitle shows presence
  - [ ] Changes when other user backgrounds/foregrounds (need 2 devices)

#### Typing Testing (10 minutes)

- [ ] Test typing indicator (requires 2 devices or simulator + device):
  - [ ] Device A: Open conversation with Device B
  - [ ] Device B: Start typing in message input
  - [ ] Device A: Within 1 second, see "User is typing..." ✓
  - [ ] Device A: Verify dots animate (1 → 2 → 3 → 1) ✓
  - [ ] Device B: Stop typing for 3 seconds
  - [ ] Device A: Typing indicator disappears ✓
  - [ ] Device B: Send message
  - [ ] Device A: Typing indicator clears immediately ✓

#### Edge Case Testing (10 minutes)

- [ ] Test offline:
  - [ ] Enable airplane mode
  - [ ] Try typing
  - [ ] Expected: No errors, typing queued
  - [ ] Disable airplane mode
  - [ ] Expected: Typing updates resume

- [ ] Test force quit:
  - [ ] Force quit app (swipe up)
  - [ ] Other device checks presence
  - [ ] Expected: Shows "Last seen" (not "Active now")

- [ ] Test multiple typing:
  - [ ] 3+ users in group (if available)
  - [ ] Multiple users type simultaneously
  - [ ] Expected: All shown in typing indicator

---

## Documentation & Cleanup (15 minutes)

### Update Memory Bank

- [ ] Open `memory-bank/activeContext.md`
- [ ] Update "What We're Working On Right Now" section:
  - [ ] Mark PR #12 as COMPLETE
  - [ ] Update status
  - [ ] Note completion date and time

- [ ] Open `memory-bank/progress.md`
- [ ] Check off PR #12 tasks
- [ ] Update progress percentage
- [ ] Note "What Works" additions:
  - [ ] Online/offline presence indicators
  - [ ] Typing indicators with animation
  - [ ] Real-time presence updates

### Update PR_PARTY README

- [ ] Open `PR_PARTY/README.md`
- [ ] Mark PR #12 as COMPLETE:
  - [ ] Update status from 📋 PLANNED to ✅ COMPLETE
  - [ ] Add completion date
  - [ ] Add actual time taken
  - [ ] Update "Current PRs" section

### Code Review Checklist

- [ ] All files compile without errors
- [ ] No force unwraps (!) except in safe contexts
- [ ] All listeners properly cleaned up (no memory leaks)
- [ ] Print statements helpful for debugging (can remove in PR #20)
- [ ] All methods have clear purpose
- [ ] Presence updates on all lifecycle events
- [ ] Typing debounce working (max 2 writes/second)
- [ ] Security rules deployed

---

## Final Commit & Push (5 minutes)

### Commit Any Remaining Changes

```bash
git status
git add .
git commit -m "[PR #12] Final cleanup and documentation"
```

### Push to GitHub

```bash
git push origin feature/pr12-presence-typing
```

### Create Merge Notes

- [ ] Document changes made:
  ```
  PR #12: Presence & Typing Indicators - COMPLETE ✅
  
  Files Created (3):
  - Models/Presence.swift (~150 lines)
  - Services/PresenceService.swift (~250 lines)
  - Views/Chat/TypingIndicatorView.swift (~80 lines)
  
  Files Modified (7):
  - messAI/messAIApp.swift (+30 lines)
  - Services/ChatService.swift (+100 lines)
  - ViewModels/ChatListViewModel.swift (+50 lines)
  - ViewModels/ChatViewModel.swift (+80 lines)
  - Views/Chat/ChatListView.swift (+10 lines)
  - Views/Chat/ConversationRowView.swift (+30 lines)
  - Views/Chat/ChatView.swift (+40 lines)
  - Views/Chat/MessageInputView.swift (+20 lines)
  - Utilities/DateFormatter+Extensions.swift (+30 lines)
  - firebase/firestore.rules (+20 lines)
  
  Total: ~770 lines across 13 files
  
  Features Implemented:
  ✅ Online/offline presence with green/gray dot
  ✅ Last seen timestamps ("Active now", "5m ago")
  ✅ App lifecycle updates presence automatically
  ✅ Typing indicators with animated dots
  ✅ Debounced typing updates (max 2/sec)
  ✅ Real-time presence and typing (<1-2s latency)
  ✅ Firestore security rules deployed
  
  Tested:
  ✅ Presence updates on app lifecycle
  ✅ Typing indicators appear/disappear
  ✅ Works offline (no crashes)
  ✅ Memory leaks checked with Instruments
  ✅ Performance: <1s typing latency, <2s presence latency
  ```

---

## Optional: Merge to Main (5 minutes)

### If Ready to Merge

```bash
git checkout main
git merge feature/pr12-presence-typing
git push origin main
```

### If Keeping Branch for Testing

```bash
# Leave branch unmerged, can test with 2 devices
# Merge later after comprehensive testing
```

---

## Celebration! 🎉

- [ ] Take a break (you deserve it!)
- [ ] Test with friends/colleagues (2+ devices)
- [ ] Document any issues found
- [ ] Move on to PR #13 planning

---

**PR #12 COMPLETE!** ✅

**Key Achievements:**
- ✅ Real-time presence system working
- ✅ Typing indicators with smooth animation
- ✅ <1 second latency for both features
- ✅ Automatic lifecycle integration
- ✅ Debounced updates for efficiency
- ✅ Security rules properly enforced

**What This Enables:**
- Users see who's online before messaging
- Typing indicators reduce "double send" anxiety
- App feels more alive and connected
- Foundation for future social features

---

**Next Up:** PR #13 - Group Chat Functionality

**Estimated Time for PR #12:** 2-3 hours actual  
**Your Actual Time:** _______ hours (record this!)

**Did Planning Help?** Rate 1-10: _______  
**Would You Skip Planning Next Time?** Yes / No  
**Most Helpful Part of Docs:** _______________________

