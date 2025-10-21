# PR#10: Real-Time Messaging & Optimistic UI

**Estimated Time:** 2-3 hours  
**Complexity:** HIGH  
**Dependencies:** PR #4 (Models), PR #5 (ChatService), PR #6 (Persistence), PR #9 (ChatView UI)

---

## Overview

### What We're Building

Real-time messaging is the **critical feature** that transforms static chat UI into a living, breathing conversation. This PR implements:
- **Optimistic UI**: Messages appear instantly when sent (no waiting for server)
- **Real-Time Sync**: Firestore snapshot listeners deliver messages within 1-2 seconds
- **Message Deduplication**: Handle same message from optimistic send + Firestore listener
- **Automatic Sync**: Offline messages queue locally, send when connection restored
- **Status Updates**: Track message journey (sending → sent → delivered → read)

Think: WhatsApp's instant message delivery, iMessage's bubble animations, Telegram's cloud sync.

### Why It Matters

This is the **make-or-break feature** for messaging apps. Users expect:
- ✅ Messages appear instantly when I tap send (0-50ms response)
- ✅ Other person receives within 2 seconds (real-time)
- ✅ Works offline (messages queue, send automatically when online)
- ✅ Never lose messages (100% reliability)
- ✅ Status updates in real-time (sent → delivered → read)

**Poor implementation** = Users think app is broken, abandon immediately.  
**Good implementation** = Users trust the app, use it daily.

### Success in One Sentence

"This PR is successful when two users can message each other in real-time, messages appear instantly for the sender, arrive within 2 seconds for the recipient, work offline with automatic sync, and never lose any messages under any circumstance."

---

## Technical Design

### Architecture Decisions

#### Decision 1: Optimistic UI Strategy

**Options Considered:**
1. **Wait for Server Confirmation** - Send to Firestore, wait for response
   - Pros: Simple, guaranteed order
   - Cons: 1-2 second delay feels laggy, poor UX

2. **Optimistic with Rollback** - Show immediately, remove if fails
   - Pros: Instant feedback
   - Cons: Jarring UX if message disappears

3. **Optimistic with Status Updates** - Show immediately, update status on confirm
   - Pros: Best UX, clear feedback
   - Cons: More complex, requires deduplication

**Chosen:** Optimistic with Status Updates (Option 3)

**Rationale:**
- WhatsApp/iMessage pattern: message appears immediately with "sending..." status
- User gets instant feedback (feels fast)
- Status updates show progress (building trust)
- If fails, message stays visible with "retry" option (no data loss)
- Industry standard for modern messaging

**Trade-offs:**
- Gain: Instant UX (0-50ms response), builds user trust
- Lose: More complex deduplication logic (acceptable with proper ID strategy)

**Implementation Pattern:**
```swift
func sendMessage(text: String) async {
    // 1. Create optimistic message with local UUID
    let tempMessage = Message(
        id: UUID().uuidString,
        conversationId: conversationId,
        senderId: currentUserId,
        text: text,
        sentAt: Date(),
        status: .sending // ← Key: starts as "sending"
    )
    
    // 2. Append to messages array (UI updates INSTANTLY)
    messages.append(tempMessage)
    
    // 3. Save to Core Data (isSynced: false)
    try await localDataManager.saveMessage(tempMessage.toEntity())
    
    // 4. Upload to Firestore (background, non-blocking)
    Task {
        do {
            let serverMessage = try await chatService.sendMessage(
                conversationId: conversationId,
                text: text
            )
            
            // 5. Update local message with server ID and status
            updateMessage(tempMessage.id, with: serverMessage)
        } catch {
            // 6. Mark as failed, show retry button
            updateMessageStatus(tempMessage.id, to: .failed)
        }
    }
}
```

---

#### Decision 2: Real-Time Listener Architecture

**Options Considered:**
1. **Poll Firestore Every N Seconds** - Periodic fetch
   - Pros: Simple, predictable load
   - Cons: High latency, wasted requests, poor UX

2. **Firestore Snapshot Listeners** - Subscribe to real-time updates
   - Pros: <2 second delivery, efficient, native Firebase feature
   - Cons: Requires listener cleanup, persistent connection

3. **WebSocket + Custom Server** - Build own real-time backend
   - Pros: Full control
   - Cons: Overkill, weeks of work, Firebase already solves this

**Chosen:** Firestore Snapshot Listeners (Option 2)

**Rationale:**
- Firestore's killer feature: built-in real-time sync
- <2 second latency (meets requirement)
- Offline persistence built-in
- Automatic reconnection
- Scales to millions of users
- Zero backend code needed

**Trade-offs:**
- Gain: Real-time (<2s), reliable, scalable, zero backend
- Lose: Tied to Firebase (acceptable for MVP)

**Implementation Pattern:**
```swift
func startRealtimeListener() async throws {
    // Firestore snapshot listener for conversation messages
    let messagesStream = chatService.fetchMessagesRealtime(
        conversationId: conversationId
    )
    
    for try await firebaseMessages in messagesStream {
        // New messages from Firestore
        for firebaseMessage in firebaseMessages {
            // Deduplicate: check if already exists locally
            if let existingIndex = messages.firstIndex(where: { $0.id == firebaseMessage.id }) {
                // Update existing message (status change, etc.)
                messages[existingIndex] = firebaseMessage
            } else {
                // New message from other user
                messages.append(firebaseMessage)
                
                // Save to Core Data
                try await localDataManager.saveMessage(firebaseMessage.toEntity())
            }
        }
        
        // Sort by timestamp (Firestore doesn't guarantee order)
        messages.sort { $0.sentAt < $1.sentAt }
    }
}
```

---

#### Decision 3: Message Deduplication Strategy

**Problem:** With optimistic UI, same message can arrive twice:
1. Optimistic local message (with temp UUID)
2. Firestore confirmation (with server ID)

**Options Considered:**
1. **Replace by Index** - Track message position, replace when server confirms
   - Pros: Simple
   - Cons: Fragile if order changes

2. **Match by Temporary ID** - Store mapping of temp ID → server ID
   - Pros: Reliable
   - Cons: Extra state to manage

3. **Match by Server ID** - When Firestore returns message, update local copy
   - Pros: Clean, leverages unique IDs
   - Cons: Requires handling "sending" status properly

**Chosen:** Hybrid Approach (Option 2 + 3)

**Rationale:**
- Client generates UUID for optimistic message
- When Firestore confirms, it returns server-generated ID
- Update local message: replace temp ID with server ID
- Use `id` field as source of truth for deduplication
- Status field tracks lifecycle: sending → sent → delivered → read

**Implementation Pattern:**
```swift
// Store mapping for deduplication
private var messageIdMap: [String: String] = [:] // tempId: serverId

func sendMessage(text: String) async {
    let tempId = UUID().uuidString
    let optimisticMessage = Message(id: tempId, ...)
    
    messages.append(optimisticMessage)
    
    // Send to Firestore
    let serverMessage = try await chatService.sendMessage(...)
    
    // Map temp ID to server ID
    messageIdMap[tempId] = serverMessage.id
    
    // When Firestore listener fires with serverMessage.id
    // Check if it matches any temp ID in map
    // If yes: update existing message, don't create new one
}

func handleFirestoreMessage(_ firebaseMessage: Message) {
    // Check if this is a duplicate of an optimistic message
    if let tempId = messageIdMap.first(where: { $0.value == firebaseMessage.id })?.key {
        // Update optimistic message with server data
        if let index = messages.firstIndex(where: { $0.id == tempId }) {
            messages[index] = firebaseMessage
        }
        messageIdMap.removeValue(forKey: tempId)
    } else if !messages.contains(where: { $0.id == firebaseMessage.id }) {
        // New message from other user
        messages.append(firebaseMessage)
    }
}
```

---

#### Decision 4: Offline Message Queue Management

**Options Considered:**
1. **Disable Send Button When Offline** - Prevent sending
   - Pros: Simple
   - Cons: Poor UX, frustrating for users

2. **Show Error Toast** - Tell user to retry when online
   - Pros: Honest communication
   - Cons: Manual retry, data loss risk

3. **Automatic Queue + Sync** - Queue locally, auto-send when online
   - Pros: Seamless UX, zero data loss
   - Cons: Most complex, requires network monitoring

**Chosen:** Automatic Queue + Sync (Option 3)

**Rationale:**
- WhatsApp model: always allow sending
- Messages queue with "sending..." status
- NetworkMonitor detects connection
- SyncManager auto-sends queued messages
- User never has to think about offline/online

**Trade-offs:**
- Gain: Best UX, zero data loss, feels magical
- Lose: Complex sync logic (already built in PR #6)

**Flow:**
```
User Sends While Offline:
1. Create optimistic message (status: .sending)
2. Save to Core Data (isSynced: false)
3. Append to messages array (UI shows immediately)
4. NetworkMonitor detects offline → skip Firestore call

When Connection Restored:
1. NetworkMonitor detects online
2. SyncManager.syncQueuedMessages() runs
3. Fetch unsynced messages from Core Data
4. Send each to Firestore in order
5. Update status: .sending → .sent
6. Mark as synced in Core Data
```

---

### Data Flow Patterns

#### Flow 1: Sending a Message (Online)

```
User Taps Send
    │
    ▼
┌─────────────────────────────────────┐
│ ChatViewModel.sendMessage(text)     │
│ 1. Create optimistic message        │
│    - id: UUID()                     │
│    - status: .sending               │
│    - sentAt: Date()                 │
└─────────────────────────────────────┘
    │
    ├─ INSTANT ─────────────────────┐
    │                                │
    ▼                                ▼
┌────────────────────┐    ┌──────────────────────┐
│ Append to messages │    │ Save to Core Data    │
│ array              │    │ (isSynced: false)    │
│ ↓ UI updates       │    │                      │
│   immediately      │    └──────────────────────┘
└────────────────────┘
    │
    ▼
┌─────────────────────────────────────┐
│ ChatService.sendMessage()           │
│ - Upload to Firestore               │
│ - Returns server Message with ID    │
└─────────────────────────────────────┘
    │
    ├─ Success ───────────┬─ Failure ────────┐
    │                     │                   │
    ▼                     ▼                   ▼
┌──────────────┐    ┌─────────────┐    ┌──────────────┐
│ Update local │    │ Update Core │    │ Mark as      │
│ message:     │    │ Data:       │    │ .failed      │
│ - id: serverID│   │ - isSynced: │    │              │
│ - status:    │    │   true      │    │ Show retry   │
│   .sent      │    └─────────────┘    │ button       │
└──────────────┘                        └──────────────┘
    │
    ▼
┌─────────────────────────────────────┐
│ Firestore Snapshot Listener         │
│ - Triggers on ALL clients           │
│ - Recipient receives within 2s      │
│ - Status updates: delivered → read  │
└─────────────────────────────────────┘
```

---

#### Flow 2: Receiving a Message (Real-Time)

```
Other User Sends Message
    │
    ▼
┌─────────────────────────────────────┐
│ Firestore writes document           │
│ /conversations/{id}/messages/{mid}  │
└─────────────────────────────────────┘
    │
    ▼ (Within 1-2 seconds)
┌─────────────────────────────────────┐
│ Snapshot Listener Fires             │
│ - ChatService.messagesStream        │
│ - Yields new Message objects        │
└─────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────┐
│ ChatViewModel.handleNewMessage()    │
│                                     │
│ Check: Already exists locally?      │
│   - Yes: Update status              │
│   - No:  Append to messages array   │
└─────────────────────────────────────┘
    │
    ├─────────────────────┬─────────────────┐
    │                     │                 │
    ▼                     ▼                 ▼
┌──────────────┐    ┌─────────────┐    ┌──────────────┐
│ Sort by      │    │ Save to     │    │ Mark as      │
│ timestamp    │    │ Core Data   │    │ delivered    │
│ (ascending)  │    │ (instant    │    │ (PR #11)     │
│              │    │  cache)     │    │              │
└──────────────┘    └─────────────┘    └──────────────┘
    │
    ▼
┌─────────────────────────────────────┐
│ SwiftUI @Published triggers         │
│ - messages array changed            │
│ - View re-renders                   │
│ - New bubble appears                │
│ - Auto-scroll to bottom             │
└─────────────────────────────────────┘
```

---

#### Flow 3: Offline Send + Automatic Sync

```
User Sends While Offline
    │
    ▼
┌─────────────────────────────────────┐
│ NetworkMonitor.isConnected = false  │
└─────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────┐
│ ChatViewModel.sendMessage()         │
│ 1. Create optimistic message        │
│ 2. Append to messages (UI updates)  │
│ 3. Save to Core Data (isSynced: false)│
│ 4. Skip Firestore call (offline)   │
│ 5. Status remains: .sending         │
└─────────────────────────────────────┘
    │
    ▼ (User goes about their day)
┌─────────────────────────────────────┐
│ Later: NetworkMonitor detects       │
│ isConnected = true                  │
└─────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────┐
│ SyncManager.syncQueuedMessages()    │
│ - Fetch from Core Data:             │
│   WHERE isSynced = false            │
│ - Sort by sentAt (chronological)    │
└─────────────────────────────────────┘
    │
    ▼ (For each queued message)
┌─────────────────────────────────────┐
│ Send to Firestore                   │
│ - chatService.sendMessage()         │
│ - Max 5 retry attempts              │
│ - Exponential backoff               │
└─────────────────────────────────────┘
    │
    ├─ Success ─────────┬─ Failure After 5 Attempts ─┐
    │                   │                             │
    ▼                   ▼                             ▼
┌──────────────┐    ┌─────────────┐        ┌──────────────────┐
│ Update local │    │ Mark synced │        │ Mark as .failed  │
│ message:     │    │ in Core Data│        │ Store error      │
│ status: .sent│    │             │        │ Show retry UI    │
└──────────────┘    └─────────────┘        └──────────────────┘
```

---

## Implementation Details

### File Structure

**Modified Files:**
```
messAI/
├── ViewModels/
│   └── ChatViewModel.swift (+ ~200 lines)
│       Add:
│       - startRealtimeListener() method
│       - sendMessage() implementation (optimistic UI)
│       - handleFirestoreMessage() deduplication
│       - updateMessageStatus() helper
│       - messageIdMap for temp-to-server ID mapping
│
├── Services/
│   └── ChatService.swift (+ ~150 lines)
│       Add:
│       - fetchMessagesRealtime() with AsyncThrowingStream
│       - Optimize sendMessage() for optimistic UI
│       - Listener cleanup methods
│
└── Persistence/
    └── LocalDataManager.swift (+ ~80 lines)
        Add:
        - updateMessageStatus(id:status:)
        - replaceMessageId(tempId:serverId:)
        - markMessageAsSynced(id:)
```

**No New Files:** All changes are enhancements to existing files from PRs #5, #6, #9

**Total New Code:** ~430 lines  
**Total Modified Files:** 3 files

---

### Key Implementation Steps

#### Phase 1: ChatViewModel - Real-Time Listener (60-75 minutes)

**Step 1.1: Add Listener Lifecycle Management**
```swift
// In ViewModels/ChatViewModel.swift

import Combine

@MainActor
class ChatViewModel: ObservableObject {
    // ... existing properties ...
    
    // NEW: Listener management
    private var listenerTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    
    // NEW: Message ID mapping for deduplication
    private var messageIdMap: [String: String] = [:] // tempId: serverId
    
    // MARK: - Real-Time Sync
    
    func startRealtimeSync() {
        // Start Firestore snapshot listener
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
    
    func stopRealtimeSync() {
        // Cancel listener when view disappears
        listenerTask?.cancel()
        listenerTask = nil
    }
    
    private func handleFirestoreMessages(_ firebaseMessages: [Message]) async {
        for firebaseMessage in firebaseMessages {
            // Deduplication logic
            if let tempId = messageIdMap.first(where: { $0.value == firebaseMessage.id })?.key {
                // This is our optimistic message coming back from server
                updateOptimisticMessage(tempId: tempId, serverMessage: firebaseMessage)
            } else if let existingIndex = messages.firstIndex(where: { $0.id == firebaseMessage.id }) {
                // Message already exists, update it (status change, etc.)
                messages[existingIndex] = firebaseMessage
                
                // Update Core Data
                do {
                    try await localDataManager.updateMessage(
                        id: firebaseMessage.id,
                        updates: ["status": firebaseMessage.status.rawValue]
                    )
                } catch {
                    print("⚠️ Failed to update message in Core Data: \(error)")
                }
            } else {
                // Brand new message from other user
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
        
        // Always sort by timestamp (Firestore doesn't guarantee order)
        messages.sort { $0.sentAt < $1.sentAt }
    }
    
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
}
```

---

**Step 1.2: Update loadMessages() to Start Listener**
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
        
        // 2. Start real-time listener (background sync)
        startRealtimeSync()
        
    } catch {
        errorMessage = "Failed to load messages: \(error.localizedDescription)"
        showError = true
        isLoading = false
    }
}
```

---

#### Phase 2: ChatViewModel - Optimistic Message Sending (45-60 minutes)

**Step 2.1: Implement Full sendMessage() with Optimistic UI**
```swift
func sendMessage() {
    guard canSendMessage else { return }
    
    let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
    messageText = "" // Clear input immediately
    
    // Generate temporary ID for optimistic message
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
    
    // Save to Core Data (isSynced: false)
    Task {
        do {
            let entity = optimisticMessage.toEntity(context: localDataManager.context)
            entity.isSynced = false
            entity.syncAttempts = 0
            try await localDataManager.saveMessage(entity)
            
            // Send to Firestore
            await uploadToFirestore(tempId: tempId, text: text)
            
        } catch {
            // Core Data save failed
            updateMessageStatus(tempId, to: .failed)
            errorMessage = "Failed to save message locally"
            showError = true
        }
    }
}

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
        
        // Update local message status to .sent
        updateMessageStatus(tempId, to: .sent)
        
        // Real-time listener will handle the rest
        // (updating with server data, marking as synced)
        
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

---

#### Phase 3: ChatService - Real-Time Stream (45-60 minutes)

**Step 3.1: Add fetchMessagesRealtime() with AsyncThrowingStream**
```swift
// In Services/ChatService.swift

import FirebaseFirestore

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
                    try? Message(from: doc.data())
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

---

**Step 3.2: Update sendMessage() to Return Server Message**
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
    
    // Return server-generated message
    return Message(
        id: messageRef.documentID, // Server-generated ID
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

---

#### Phase 4: LocalDataManager - Sync Helpers (30-40 minutes)

**Step 4.1: Add Helper Methods**
```swift
// In Persistence/LocalDataManager.swift

import CoreData

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

func incrementSyncAttempts(messageId: String) async throws {
    let fetchRequest: NSFetchRequest<MessageEntity> = MessageEntity.fetchRequest()
    fetchRequest.predicate = NSPredicate(format: "id == %@", messageId)
    
    let results = try context.fetch(fetchRequest)
    
    guard let entity = results.first else {
        throw PersistenceError.messageNotFound
    }
    
    entity.syncAttempts += 1
    
    if entity.syncAttempts >= 5 {
        // Max retries reached, mark as failed
        entity.status = MessageStatus.failed.rawValue
        entity.lastSyncError = "Max retry attempts reached"
    }
    
    try context.save()
}
```

---

#### Phase 5: Integration & Testing (30-45 minutes)

**Step 5.1: Update ChatView Lifecycle**
```swift
// In Views/Chat/ChatView.swift

.task {
    await viewModel.loadMessages() // Starts listener
}
.onDisappear {
    viewModel.stopRealtimeSync() // Cleanup listener
}
```

---

**Step 5.2: Add Network Status Banner**
```swift
// Add to ChatView body

if !NetworkMonitor.shared.isConnected {
    HStack {
        Image(systemName: "wifi.slash")
        Text("No connection. Messages will send when online.")
    }
    .font(.caption)
    .padding(8)
    .background(Color.yellow.opacity(0.3))
    .cornerRadius(8)
    .padding(.horizontal)
}
```

---

## Testing Strategy

### Unit Tests

**ChatViewModel Tests:**
```swift
func testSendMessageCreatesOptimisticMessage() async {
    // Given: ChatViewModel with empty messages
    // When: sendMessage("Hello") called
    // Then: messages.count == 1, status == .sending, id is UUID
}

func testRealtimeListenerUpdatesMessages() async {
    // Given: ChatViewModel with listener running
    // When: Firestore emits new message
    // Then: messages array contains new message
}

func testOptimisticMessageReplacedWithServerMessage() async {
    // Given: Optimistic message with tempId exists
    // When: Firestore returns message with serverId
    // Then: tempId replaced with serverId, status updated to .sent
}

func testDuplicateMessagesPrevented() async {
    // Given: Message exists with id="123"
    // When: Firestore emits message with id="123" again
    // Then: messages.count doesn't increase, existing message updated
}
```

---

### Integration Tests

**Real-Time Messaging Test (Critical):**
```
Test: Two users can message in real-time
Setup: 
- Device A logged in as User 1
- Device B logged in as User 2
- Both in same conversation

Steps:
1. User 1 types "Hello" and taps send
2. Verify User 1 sees message immediately with "sending..." status
3. Wait 2 seconds
4. Verify User 2 receives message on Device B
5. Verify User 1's message changes to "sent" status

Expected:
- User 1 sees message in <50ms
- User 2 receives in <2 seconds
- No duplicate messages
- Correct sender attribution
```

---

**Offline Messaging Test (Critical):**
```
Test: Messages queue offline and sync automatically
Setup:
- Device A logged in, airplane mode OFF

Steps:
1. Enable airplane mode on Device A
2. Send 3 messages: "Message 1", "Message 2", "Message 3"
3. Verify all 3 appear locally with "sending..." status
4. Disable airplane mode
5. Wait 5 seconds

Expected:
- All 3 messages send to Firestore in order
- Status changes: sending → sent
- No messages lost
- Recipient receives all 3 in correct order
```

---

**Optimistic UI Test:**
```
Test: Message appears instantly when sent
Setup: Device A in conversation

Steps:
1. Type "Test message"
2. Tap send
3. Start timer immediately

Expected:
- Message appears in UI within 50ms
- Input field clears immediately
- Keyboard remains visible
- Status shows "sending..."
```

---

**Deduplication Test:**
```
Test: No duplicate messages with optimistic UI
Setup: Device A, simulate slow network (3G)

Steps:
1. Send message "Hello"
2. Verify optimistic message appears (tempId)
3. Wait for Firestore confirmation (2-3 seconds)
4. Verify Firestore listener fires with serverId

Expected:
- Only 1 message bubble visible
- TempId replaced with serverId
- Status updated to "sent"
- No flash/flicker in UI
```

---

## Success Criteria

### Feature Complete When:

- [ ] User can send messages with instant optimistic UI (<50ms)
- [ ] Messages upload to Firestore successfully
- [ ] Real-time listener delivers messages within 2 seconds
- [ ] Optimistic messages deduplicated (no duplicates)
- [ ] Message status updates correctly (sending → sent)
- [ ] Offline messages queue locally
- [ ] Queued messages auto-send when connection restored
- [ ] Two devices can chat in real-time (tested)
- [ ] No memory leaks (listener cleanup verified)
- [ ] Works on poor network (3G, high latency)
- [ ] App force quit doesn't lose unsent messages
- [ ] Messages appear in chronological order always
- [ ] All unit tests passing
- [ ] All integration tests passing

---

### Performance Targets

| Metric | Target | Measurement Method |
|--------|--------|-------------------|
| Optimistic UI response | <50ms | Tap to message visible |
| Real-time delivery | <2 seconds | Send to recipient receives |
| Offline queue capacity | 1000+ messages | Stress test |
| Listener memory leak | 0 leaks | Instruments |
| Scroll performance | 60fps | With real-time updates |

---

## Risk Assessment

### Risk 1: Firestore Listener Memory Leaks 🔴 HIGH
**Issue:** Snapshot listener not properly cleaned up  
**Impact:** App crashes, battery drain, performance degradation  
**Mitigation:**
- Store listener in `listenerTask`
- Cancel in `onDisappear` lifecycle
- Use `[weak self]` in closures
- Test with Instruments (Leaks, Allocations)
- Verify listener count doesn't grow over time

---

### Risk 2: Message Deduplication Failures 🟡 MEDIUM
**Issue:** Same message appears twice (optimistic + Firestore)  
**Impact:** Confusing UI, looks broken  
**Mitigation:**
- Maintain `messageIdMap` dictionary
- Check both tempId and serverId
- Log all deduplication events
- Test extensively with logs
- Add assertions in debug builds

---

### Risk 3: Offline Sync Race Conditions 🟡 MEDIUM
**Issue:** Connection flapping causes duplicate sends  
**Impact:** Same message sent multiple times  
**Mitigation:**
- Use `isSynced` flag in Core Data
- Check sync status before sending
- Implement idempotency on server (Firestore)
- Test with airplane mode on/off rapidly

---

### Risk 4: Firestore Query Costs 🟢 LOW
**Issue:** Real-time listeners cost reads per document change  
**Impact:** Firebase bill could grow  
**Mitigation:**
- Limit initial query to 50 messages
- Implement pagination in future PR
- Monitor Firebase usage dashboard
- For MVP: acceptable cost (<$10/month)

---

## Timeline

**Total Estimate:** 2-3 hours

| Phase | Task | Time |
|-------|------|------|
| 1 | ChatViewModel real-time listener | 60-75 min |
| 2 | Optimistic message sending | 45-60 min |
| 3 | ChatService real-time stream | 45-60 min |
| 4 | LocalDataManager helpers | 30-40 min |
| 5 | Integration & testing | 30-45 min |

---

## Dependencies

### Requires:
- [x] PR #4: Core Models (Message, MessageStatus)
- [x] PR #5: ChatService (basic structure)
- [x] PR #6: LocalDataManager (CRUD, sync metadata)
- [ ] PR #9: ChatView UI (display messages, input)

### Blocks:
- PR #11: Message Status Indicators (needs real-time status updates)
- PR #14: Image Sharing (needs optimistic UI pattern)

---

## Open Questions

1. **Message Pagination:** Should we limit initial load to 50 messages?
   - **Decision:** Yes, but defer to future PR (out of scope for MVP)
   - **Reason:** Performance optimization, can add later

2. **Retry Strategy:** How many attempts before marking as permanently failed?
   - **Decision:** 5 attempts with exponential backoff
   - **Reason:** Balances persistence with avoiding infinite loops

3. **Network Banner:** Always show connection status?
   - **Decision:** Only show when offline
   - **Reason:** Reduces UI clutter, user only needs to know when problem exists

---

*This specification provides complete technical design for PR #10. Implementation should follow phases in order, testing at each checkpoint. Real-time messaging is critical—prioritize reliability over speed.*

