# PR#10: Real-Time Messaging & Optimistic UI - Implementation Checklist

**Use this as your daily todo list.** Check off items as you complete them.

---

## Pre-Implementation Setup (10 minutes)

- [ ] Read main planning document `PR10_REAL_TIME_MESSAGING.md` (~45 min)
- [ ] Prerequisites verified:
  - [ ] PR #9 complete (ChatView UI working)
  - [ ] PR #6 complete (LocalDataManager available)
  - [ ] PR #5 complete (ChatService base structure)
- [ ] Git branch created:
  ```bash
  git checkout main
  git pull origin main
  git checkout -b feature/pr10-real-time-messaging
  ```
- [ ] Xcode project opens successfully
- [ ] App builds and runs (verify PR #9 works)

---

## Phase 1: ChatViewModel - Real-Time Listener (60-75 minutes)

### 1.1: Add Listener State Properties (10 minutes)

- [ ] Open `ViewModels/ChatViewModel.swift`

- [ ] Add import at top:
  ```swift
  import Combine
  ```

- [ ] Add new properties to class:
  ```swift
  // Listener management
  private var listenerTask: Task<Void, Never>?
  private var cancellables = Set<AnyCancellable>()
  
  // Message ID mapping for deduplication
  private var messageIdMap: [String: String] = [:] // tempId: serverId
  ```

**Checkpoint:** File compiles (Cmd+B)

**Commit:** `git add . && git commit -m "[PR #10] Add listener state to ChatViewModel"`

---

### 1.2: Create startRealtimeSync() Method (20 minutes)

- [ ] Add method to `ChatViewModel`:
  ```swift
  // MARK: - Real-Time Sync
  
  func startRealtimeSync() {
      listenerTask = Task {
          do {
              let messagesStream = try await chatService.fetchMessagesRealtime(
                  conversationId: conversationId
              )
              
              for try await firebaseMessages in messagesStream {
                  await handleFirestoreMessages(firebaseMessages)
              }
          } catch {
              errorMessage = "Real-time sync failed: \(error.localizedDescription)"
              showError = true
          }
      }
  }
  ```

- [ ] Add stopRealtimeSync() method:
  ```swift
  func stopRealtimeSync() {
      listenerTask?.cancel()
      listenerTask = nil
  }
  ```

**Note:** This will show compiler error until we create `fetchMessagesRealtime()` in Phase 3

**Checkpoint:** Method added, understands it's incomplete

**Commit:** `git add . && git commit -m "[PR #10] Add real-time sync lifecycle methods"`

---

### 1.3: Create handleFirestoreMessages() Deduplication Logic (30 minutes)

- [ ] Add private method to `ChatViewModel`:
  ```swift
  private func handleFirestoreMessages(_ firebaseMessages: [Message]) async {
      for firebaseMessage in firebaseMessages {
          // Check 1: Is this our optimistic message coming back?
          if let tempId = messageIdMap.first(where: { $0.value == firebaseMessage.id })?.key {
              updateOptimisticMessage(tempId: tempId, serverMessage: firebaseMessage)
          }
          // Check 2: Does message already exist locally?
          else if let existingIndex = messages.firstIndex(where: { $0.id == firebaseMessage.id }) {
              // Update existing (status change, etc.)
              messages[existingIndex] = firebaseMessage
              
              // Update Core Data
              do {
                  try await localDataManager.updateMessageStatus(
                      id: firebaseMessage.id,
                      status: firebaseMessage.status
                  )
              } catch {
                  print("⚠️ Failed to update message in Core Data: \(error)")
              }
          }
          // Check 3: Brand new message from other user
          else {
              messages.append(firebaseMessage)
              
              // Save to Core Data
              do {
                  let entity = firebaseMessage.toEntity(context: localDataManager.context)
                  entity.isSynced = true
                  try await localDataManager.saveMessage(entity)
              } catch {
                  print("⚠️ Failed to save message to Core Data: \(error)")
              }
          }
      }
      
      // Always sort by timestamp
      messages.sort { $0.sentAt < $1.sentAt }
  }
  ```

- [ ] Add updateOptimisticMessage() helper:
  ```swift
  private func updateOptimisticMessage(tempId: String, serverMessage: Message) {
      guard let index = messages.firstIndex(where: { $0.id == tempId }) else {
          return
      }
      
      // Replace optimistic message with server version
      messages[index] = serverMessage
      
      // Update Core Data: replace temp ID with server ID
      Task {
          do {
              try await localDataManager.replaceMessageId(
                  tempId: tempId,
                  serverId: serverMessage.id
              )
              try await localDataManager.markMessageAsSynced(id: serverMessage.id)
          } catch {
              print("⚠️ Failed to update message in Core Data: \(error)")
          }
      }
      
      // Clean up mapping
      messageIdMap.removeValue(forKey: tempId)
  }
  ```

**Note:** This will show compiler errors until we add LocalDataManager methods in Phase 4

**Checkpoint:** Deduplication logic complete

**Commit:** `git add . && git commit -m "[PR #10] Add message deduplication logic"`

---

### 1.4: Update loadMessages() to Start Listener (10 minutes)

- [ ] Find existing `loadMessages()` method in `ChatViewModel`

- [ ] Add listener start after local load:
  ```swift
  func loadMessages() async {
      isLoading = true
      
      do {
          // 1. Load from Core Data (instant)
          let localEntities = try localDataManager.fetchMessages(
              conversationId: conversationId
          )
          messages = localEntities.map { Message(from: $0) }
          isLoading = false
          
          // 2. Start real-time listener (NEW!)
          startRealtimeSync()
          
      } catch {
          errorMessage = "Failed to load messages: \(error.localizedDescription)"
          showError = true
          isLoading = false
      }
  }
  ```

**Checkpoint:** loadMessages() now starts listener

**Commit:** `git add . && git commit -m "[PR #10] Start listener in loadMessages()"`

---

## Phase 2: ChatViewModel - Optimistic UI Sending (45-60 minutes)

### 2.1: Implement Full sendMessage() with Optimistic UI (30 minutes)

- [ ] Find existing `sendMessage()` placeholder in `ChatViewModel`

- [ ] Replace with full implementation:
  ```swift
  func sendMessage() {
      guard canSendMessage else { return }
      
      let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
      messageText = "" // Clear input immediately
      
      // Generate temporary ID
      let tempId = UUID().uuidString
      
      // Create optimistic message
      let optimisticMessage = Message(
          id: tempId,
          conversationId: conversationId,
          senderId: currentUserId,
          text: text,
          imageURL: nil,
          sentAt: Date(),
          deliveredAt: nil,
          readAt: nil,
          status: .sending
      )
      
      // Add to messages array immediately (UI updates)
      messages.append(optimisticMessage)
      messages.sort { $0.sentAt < $1.sentAt }
      
      // Save to Core Data & upload to Firestore
      Task {
          do {
              // Save locally first
              let entity = optimisticMessage.toEntity(context: localDataManager.context)
              entity.isSynced = false
              entity.syncAttempts = 0
              try await localDataManager.saveMessage(entity)
              
              // Upload to Firestore
              await uploadToFirestore(tempId: tempId, text: text)
              
          } catch {
              // Core Data save failed
              updateMessageStatus(tempId, to: .failed)
              errorMessage = "Failed to save message locally"
              showError = true
          }
      }
  }
  ```

**Checkpoint:** sendMessage() creates optimistic message

---

### 2.2: Create uploadToFirestore() Helper (20 minutes)

- [ ] Add private method:
  ```swift
  private func uploadToFirestore(tempId: String, text: String) async {
      do {
          // Upload to Firestore
          let serverMessage = try await chatService.sendMessage(
              conversationId: conversationId,
              text: text,
              senderId: currentUserId
          )
          
          // Map temp ID to server ID (for deduplication)
          messageIdMap[tempId] = serverMessage.id
          
          // Update local message status
          updateMessageStatus(tempId, to: .sent)
          
          // Real-time listener will handle the rest
          
      } catch {
          // Firestore upload failed
          updateMessageStatus(tempId, to: .failed)
          
          // Log for sync manager to retry
          do {
              try await localDataManager.incrementSyncAttempts(messageId: tempId)
          } catch {
              print("⚠️ Failed to log sync attempt: \(error)")
          }
      }
  }
  ```

**Checkpoint:** Upload logic complete

---

### 2.3: Create updateMessageStatus() Helper (10 minutes)

- [ ] Add private method:
  ```swift
  private func updateMessageStatus(_ messageId: String, to status: MessageStatus) {
      guard let index = messages.firstIndex(where: { $0.id == messageId }) else {
          return
      }
      
      messages[index].status = status
      
      // Update Core Data
      Task {
          do {
              try await localDataManager.updateMessageStatus(
                  id: messageId,
                  status: status
              )
          } catch {
              print("⚠️ Failed to update message status in Core Data: \(error)")
          }
      }
  }
  ```

**Checkpoint:** ChatViewModel Phase 2 complete

**Commit:** `git add . && git commit -m "[PR #10] Implement optimistic UI message sending"`

---

## Phase 3: ChatService - Real-Time Stream (45-60 minutes)

### 3.1: Add fetchMessagesRealtime() Method (30 minutes)

- [ ] Open `Services/ChatService.swift`

- [ ] Add method:
  ```swift
  func fetchMessagesRealtime(
      conversationId: String
  ) -> AsyncThrowingStream<[Message], Error> {
      AsyncThrowingStream { continuation in
          let listener = db.collection("conversations")
              .document(conversationId)
              .collection("messages")
              .order(by: "sentAt", descending: false)
              .addSnapshotListener { [weak self] snapshot, error in
                  if let error = error {
                      continuation.finish(throwing: ChatError.firestoreError(error))
                      return
                  }
                  
                  guard let documents = snapshot?.documents else {
                      continuation.yield([])
                      return
                  }
                  
                  let messages = documents.compactMap { doc -> Message? in
                      var data = doc.data()
                      data["id"] = doc.documentID // Add document ID
                      return try? Message(from: data)
                  }
                  
                  continuation.yield(messages)
              }
          
          // Cleanup when stream is cancelled
          continuation.onTermination = { @Sendable _ in
              listener.remove()
          }
      }
  }
  ```

**Note:** Ensure `[weak self]` to prevent memory leaks

**Checkpoint:** Real-time stream compiles

---

### 3.2: Update sendMessage() to Return Server Message (30 minutes)

- [ ] Find existing `sendMessage()` in `ChatService`

- [ ] Update signature and implementation:
  ```swift
  func sendMessage(
      conversationId: String,
      text: String,
      senderId: String,
      imageURL: String? = nil
  ) async throws -> Message {
      let messageRef = db.collection("conversations")
          .document(conversationId)
          .collection("messages")
          .document() // Auto-generate ID
      
      let now = Timestamp(date: Date())
      
      let messageData: [String: Any] = [
          "senderId": senderId,
          "text": text,
          "imageURL": imageURL as Any,
          "sentAt": now,
          "status": MessageStatus.sent.rawValue
      ]
      
      // Write to Firestore
      try await messageRef.setData(messageData)
      
      // Update conversation's lastMessage
      try await updateConversationLastMessage(
          conversationId: conversationId,
          lastMessage: text,
          timestamp: now
      )
      
      // Return server-generated message
      return Message(
          id: messageRef.documentID, // Server ID
          conversationId: conversationId,
          senderId: senderId,
          text: text,
          imageURL: imageURL,
          sentAt: now.dateValue(),
          deliveredAt: nil,
          readAt: nil,
          status: .sent
      )
  }
  ```

- [ ] Add helper method if needed:
  ```swift
  private func updateConversationLastMessage(
      conversationId: String,
      lastMessage: String,
      timestamp: Timestamp
  ) async throws {
      try await db.collection("conversations")
          .document(conversationId)
          .updateData([
              "lastMessage": lastMessage,
              "lastMessageAt": timestamp
          ])
  }
  ```

**Checkpoint:** sendMessage() returns server Message

**Commit:** `git add . && git commit -m "[PR #10] Add real-time listener and update ChatService"`

---

## Phase 4: LocalDataManager - Sync Helpers (30-40 minutes)

### 4.1: Add updateMessageStatus() Method (10 minutes)

- [ ] Open `Persistence/LocalDataManager.swift`

- [ ] Add method:
  ```swift
  func updateMessageStatus(id: String, status: MessageStatus) async throws {
      let fetchRequest: NSFetchRequest<MessageEntity> = MessageEntity.fetchRequest()
      fetchRequest.predicate = NSPredicate(format: "id == %@", id)
      
      let results = try context.fetch(fetchRequest)
      
      guard let entity = results.first else {
          throw PersistenceError.messageNotFound
      }
      
      entity.status = status.rawValue
      
      try context.save()
  }
  ```

**Checkpoint:** Method compiles

---

### 4.2: Add replaceMessageId() Method (10 minutes)

- [ ] Add method:
  ```swift
  func replaceMessageId(tempId: String, serverId: String) async throws {
      let fetchRequest: NSFetchRequest<MessageEntity> = MessageEntity.fetchRequest()
      fetchRequest.predicate = NSPredicate(format: "id == %@", tempId)
      
      let results = try context.fetch(fetchRequest)
      
      guard let entity = results.first else {
          throw PersistenceError.messageNotFound
      }
      
      entity.id = serverId
      
      try context.save()
  }
  ```

**Checkpoint:** Method compiles

---

### 4.3: Add markMessageAsSynced() Method (10 minutes)

- [ ] Add method:
  ```swift
  func markMessageAsSynced(id: String) async throws {
      let fetchRequest: NSFetchRequest<MessageEntity> = MessageEntity.fetchRequest()
      fetchRequest.predicate = NSPredicate(format: "id == %@", id)
      
      let results = try context.fetch(fetchRequest)
      
      guard let entity = results.first else {
          throw PersistenceError.messageNotFound
      }
      
      entity.isSynced = true
      entity.syncAttempts = 0
      entity.lastSyncError = nil
      
      try context.save()
  }
  ```

**Checkpoint:** Method compiles

---

### 4.4: Add incrementSyncAttempts() Method (10 minutes)

- [ ] Add method:
  ```swift
  func incrementSyncAttempts(messageId: String) async throws {
      let fetchRequest: NSFetchRequest<MessageEntity> = MessageEntity.fetchRequest()
      fetchRequest.predicate = NSPredicate(format: "id == %@", messageId)
      
      let results = try context.fetch(fetchRequest)
      
      guard let entity = results.first else {
          throw PersistenceError.messageNotFound
      }
      
      entity.syncAttempts += 1
      
      if entity.syncAttempts >= 5 {
          // Max retries reached
          entity.status = MessageStatus.failed.rawValue
          entity.lastSyncError = "Max retry attempts reached"
      }
      
      try context.save()
  }
  ```

**Checkpoint:** All LocalDataManager helpers complete

**Commit:** `git add . && git commit -m "[PR #10] Add LocalDataManager sync helper methods"`

---

## Phase 5: Integration & UI Updates (30-45 minutes)

### 5.1: Update ChatView Lifecycle (15 minutes)

- [ ] Open `Views/Chat/ChatView.swift`

- [ ] Update `.task` modifier:
  ```swift
  .task {
      await viewModel.loadMessages() // Starts listener automatically
  }
  ```

- [ ] Add `.onDisappear` modifier:
  ```swift
  .onDisappear {
      viewModel.stopRealtimeSync() // Cleanup listener
  }
  ```

**Checkpoint:** Listener lifecycle managed

**Commit:** `git add . && git commit -m "[PR #10] Add listener lifecycle management to ChatView"`

---

### 5.2: Add Network Status Banner (15 minutes)

- [ ] In `ChatView.swift`, add banner to top of VStack:
  ```swift
  VStack(spacing: 0) {
      // Network status banner
      if !NetworkMonitor.shared.isConnected {
          HStack {
              Image(systemName: "wifi.slash")
              Text("No connection. Messages will send when online.")
          }
          .font(.caption)
          .foregroundColor(.primary)
          .padding(8)
          .background(Color.yellow.opacity(0.3))
          .cornerRadius(8)
          .padding(.horizontal)
          .transition(.move(edge: .top))
      }
      
      // Existing message list
      messageListView
      
      // Existing input bar
      MessageInputView(...)
  }
  ```

**Checkpoint:** Network banner appears when offline

---

### 5.3: Build and Test Basic Flow (15 minutes)

- [ ] Build project (Cmd+B)
  - [ ] 0 errors
  - [ ] 0 warnings (if possible)

- [ ] Run on simulator (Cmd+R)

- [ ] Basic smoke test:
  - [ ] Open ChatView
  - [ ] Type message
  - [ ] Tap send
  - [ ] Verify message appears immediately
  - [ ] Verify input clears
  - [ ] Check console for logs

**Checkpoint:** Basic flow working (no crashes)

**Commit:** `git add . && git commit -m "[PR #10] Add network status banner and complete integration"`

---

## Testing Phase (30-60 minutes)

### Unit Tests (Optional for MVP)

- [ ] Create `ChatViewModelTests.swift` (if time permits)
- [ ] Test optimistic message creation
- [ ] Test message deduplication
- [ ] Test status updates

---

### Integration Tests - Real Devices (Critical)

#### Test 1: Real-Time Messaging (15 minutes)

- [ ] Setup: 2 devices logged in as different users

- [ ] Steps:
  - [ ] Device A: Open conversation with Device B
  - [ ] Device A: Send "Hello from A"
  - [ ] Verify Device A sees message immediately
  - [ ] Wait 2 seconds
  - [ ] Device B: Check if message received
  - [ ] Device B: Send "Hello from B"
  - [ ] Device A: Verify receives within 2 seconds

- [ ] Expected:
  - [ ] <50ms instant feedback on sender
  - [ ] <2 second delivery to recipient
  - [ ] Messages appear in correct order
  - [ ] No duplicates

**Result:** ✅ PASS / ❌ FAIL (if fail, note issue)

---

#### Test 2: Optimistic UI (10 minutes)

- [ ] Setup: 1 device, conversation open

- [ ] Steps:
  - [ ] Type "Test message"
  - [ ] Tap send, start timer
  - [ ] Measure time to message appears

- [ ] Expected:
  - [ ] Message visible in <50ms
  - [ ] Input clears immediately
  - [ ] Status shows "sending..."
  - [ ] After 1-2s, status changes to "sent"

**Result:** ✅ PASS / ❌ FAIL

---

#### Test 3: Offline Message Queue (20 minutes)

- [ ] Setup: 1 device, conversation open

- [ ] Steps:
  - [ ] Enable airplane mode
  - [ ] Send 3 messages: "Message 1", "Message 2", "Message 3"
  - [ ] Verify all 3 appear locally with "sending..." status
  - [ ] Wait 10 seconds (still offline)
  - [ ] Disable airplane mode
  - [ ] Wait 5 seconds

- [ ] Expected:
  - [ ] All 3 messages visible while offline
  - [ ] Network banner appears
  - [ ] When online, all 3 send to Firestore
  - [ ] Status updates to "sent"
  - [ ] Other device receives all 3 in order

**Result:** ✅ PASS / ❌ FAIL

---

#### Test 4: Message Deduplication (10 minutes)

- [ ] Setup: 1 device, simulate slow network (Settings > Developer > Network Link Conditioner > 3G)

- [ ] Steps:
  - [ ] Send message "Dedup test"
  - [ ] Watch carefully for duplicate bubbles
  - [ ] Wait for Firestore confirmation (3-4 seconds on 3G)
  - [ ] Count message bubbles

- [ ] Expected:
  - [ ] Only 1 message bubble visible
  - [ ] No flicker or duplicate
  - [ ] Status updates smoothly

**Result:** ✅ PASS / ❌ FAIL

---

#### Test 5: App Lifecycle (10 minutes)

- [ ] Setup: Device A in conversation

- [ ] Steps:
  - [ ] Send message "Lifecycle test"
  - [ ] Background app (Home button)
  - [ ] Wait 5 seconds
  - [ ] Reopen app
  - [ ] Device B: Send message
  - [ ] Device A: Check if received

- [ ] Expected:
  - [ ] Listener reconnects automatically
  - [ ] New messages arrive
  - [ ] No crashes or hangs

**Result:** ✅ PASS / ❌ FAIL

---

### Performance Testing (Optional)

- [ ] Instruments: Check for memory leaks
  - [ ] Run Leaks instrument
  - [ ] Open/close ChatView 10 times
  - [ ] Send 20 messages
  - [ ] Verify 0 leaks

- [ ] Scroll performance:
  - [ ] Load conversation with 100+ messages
  - [ ] Scroll up and down rapidly
  - [ ] Verify 60fps (check FPS meter)

---

## Bug Fixes (As Needed)

### Bug #1: [If encountered]

- [ ] Bug description:
- [ ] Root cause:
- [ ] Fix applied:
- [ ] Test verified:

**Commit:** `git add . && git commit -m "[PR #10] Fix bug: [description]"`

---

### Bug #2: [If encountered]

- [ ] Bug description:
- [ ] Root cause:
- [ ] Fix applied:
- [ ] Test verified:

**Commit:** `git add . && git commit -m "[PR #10] Fix bug: [description]"`

---

## Completion Checklist

### Code Quality

- [ ] All compiler errors resolved
- [ ] All compiler warnings resolved (or documented)
- [ ] No console errors during normal operation
- [ ] Code commented where complex
- [ ] No force unwraps (!) except where safe
- [ ] Memory leaks verified with Instruments

---

### Functionality

- [ ] Messages send with optimistic UI (<50ms)
- [ ] Real-time delivery works (<2 seconds)
- [ ] Offline messages queue locally
- [ ] Queued messages auto-send when online
- [ ] No duplicate messages
- [ ] Message status updates correctly
- [ ] Listener cleanup works (no leaks)

---

### Testing

- [ ] Test 1: Real-time messaging ✅
- [ ] Test 2: Optimistic UI ✅
- [ ] Test 3: Offline queue ✅
- [ ] Test 4: Deduplication ✅
- [ ] Test 5: App lifecycle ✅

---

### Documentation

- [ ] Code comments added for complex logic
- [ ] Console logs added for debugging (can remove later)
- [ ] README updated (if needed)
- [ ] Memory bank updated (activeContext.md, progress.md)

---

## Final Commit & Merge

- [ ] Final commit:
  ```bash
  git add .
  git commit -m "[PR #10] Complete real-time messaging and optimistic UI

  Features implemented:
  - Optimistic UI with instant feedback (<50ms)
  - Firestore snapshot listener for real-time sync
  - Message deduplication (temp ID → server ID)
  - Offline message queueing with auto-sync
  - Status updates (sending → sent → delivered)
  - Listener lifecycle management (prevents leaks)

  Testing:
  - ✅ All 5 integration tests passing
  - ✅ Real-time delivery <2 seconds
  - ✅ No memory leaks (verified with Instruments)
  - ✅ Works offline with automatic sync

  Files modified:
  - ViewModels/ChatViewModel.swift (+200 lines)
  - Services/ChatService.swift (+150 lines)
  - Persistence/LocalDataManager.swift (+80 lines)
  - Views/Chat/ChatView.swift (+30 lines)

  Time: [X hours actual] ([2-3 hours estimated])"
  ```

- [ ] Push to GitHub:
  ```bash
  git push origin feature/pr10-real-time-messaging
  ```

- [ ] Merge to main:
  ```bash
  git checkout main
  git merge feature/pr10-real-time-messaging
  git push origin main
  ```

---

## Post-Completion

- [ ] Write complete summary (`PR10_COMPLETE_SUMMARY.md`)
- [ ] Update `PR_PARTY/README.md` (mark PR#10 complete)
- [ ] Update memory bank:
  - [ ] `activeContext.md` (latest completion)
  - [ ] `progress.md` (update percentages)
- [ ] Celebrate! 🎉 Real-time messaging works!

---

**Estimated Total Time:** 2-3 hours  
**Critical Path:** Phases 1-3 (listener + optimistic UI + service)  
**Success Metric:** Two devices can chat in real-time with <2s delivery

**Remember:** Test on real devices. Simulator is fine for building, but real-time sync needs actual network conditions.

---

*This checklist is your step-by-step guide. Follow it sequentially, check off items, commit frequently. If you encounter issues, document them in the bug section.*

