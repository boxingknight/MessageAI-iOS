# PR#6: Local Persistence with SwiftData - Testing Guide

**Comprehensive test strategy for offline-first messaging persistence**

---

## Testing Overview

### Test Categories

| Category | Tests | Time | Purpose |
|----------|-------|------|---------|
| Unit Tests | 16 | 10 min | Test individual components |
| Integration Tests | 3 | 15 min | Test component interactions |
| Edge Cases | 6 | 10 min | Test boundary conditions |
| Performance Tests | 4 | 10 min | Verify speed targets |
| Acceptance Tests | 3 | 15 min | Validate MVP requirements |
| **Total** | **32** | **60 min** | **Comprehensive coverage** |

---

## Unit Tests (16 tests)

### LocalDataManager Tests (9 tests)

#### Test 1: Save New Message

**Purpose:** Verify messages can be created and saved

**Setup:**
```swift
let manager = LocalDataManager(context: testContext)
let message = Message(
    id: UUID().uuidString,
    conversationId: "test-conversation",
    senderId: "user-1",
    text: "Test message",
    sentAt: Date(),
    status: .sending
)
```

**Action:**
```swift
try manager.saveMessage(message, isSynced: false)
```

**Expected:**
- No error thrown
- Message saved to Core Data
- `isSynced` = false
- `needsSync` = true
- `syncAttempts` = 0

**Verification:**
```swift
let fetchRequest: NSFetchRequest<MessageEntity> = MessageEntity.fetchRequest()
fetchRequest.predicate = NSPredicate(format: "id == %@", message.id)
let results = try testContext.fetch(fetchRequest)

XCTAssertEqual(results.count, 1)
XCTAssertEqual(results.first?.text, "Test message")
XCTAssertEqual(results.first?.isSynced, false)
```

---

#### Test 2: Fetch Messages by Conversation

**Purpose:** Verify messages can be queried by conversation ID

**Setup:**
```swift
// Save 5 messages for conversation "conv-1"
for i in 0..<5 {
    let message = Message(id: UUID().uuidString, conversationId: "conv-1", ...)
    try manager.saveMessage(message)
}

// Save 3 messages for conversation "conv-2"
for i in 0..<3 {
    let message = Message(id: UUID().uuidString, conversationId: "conv-2", ...)
    try manager.saveMessage(message)
}
```

**Action:**
```swift
let messages = try manager.fetchMessages(conversationId: "conv-1")
```

**Expected:**
- Returns exactly 5 messages
- All have `conversationId == "conv-1"`
- Sorted by `sentAt` (ascending)
- None from "conv-2"

**Verification:**
```swift
XCTAssertEqual(messages.count, 5)
XCTAssertTrue(messages.allSatisfy { $0.conversationId == "conv-1" })

// Verify sorted
for i in 0..<messages.count-1 {
    XCTAssertLessThanOrEqual(messages[i].sentAt, messages[i+1].sentAt)
}
```

---

#### Test 3: Update Message Status

**Purpose:** Verify message status can be updated

**Setup:**
```swift
let message = Message(id: "msg-1", ..., status: .sending)
try manager.saveMessage(message)
```

**Action:**
```swift
try manager.updateMessageStatus(id: "msg-1", status: .delivered)
```

**Expected:**
- Status updated to `.delivered`
- `deliveredAt` timestamp set to current time
- Other fields unchanged

**Verification:**
```swift
let updated = try manager.fetchMessages(conversationId: message.conversationId)
let msg = updated.first(where: { $0.id == "msg-1" })

XCTAssertEqual(msg?.status, .delivered)
XCTAssertNotNil(msg?.deliveredAt)
XCTAssertEqual(msg?.text, "Test message") // Unchanged
```

---

#### Test 4: Delete Message

**Purpose:** Verify messages can be deleted

**Setup:**
```swift
let message = Message(id: "msg-to-delete", ...)
try manager.saveMessage(message)
```

**Action:**
```swift
try manager.deleteMessage(id: "msg-to-delete")
```

**Expected:**
- Message removed from Core Data
- Fetch returns empty array

**Verification:**
```swift
let messages = try manager.fetchMessages(conversationId: message.conversationId)
XCTAssertTrue(messages.isEmpty)
```

---

#### Test 5: Fetch Unsynced Messages

**Purpose:** Verify can query messages that need syncing

**Setup:**
```swift
// Save 3 synced messages
for i in 0..<3 {
    let msg = Message(id: "synced-\(i)", ...)
    try manager.saveMessage(msg, isSynced: true)
}

// Save 2 unsynced messages
for i in 0..<2 {
    let msg = Message(id: "unsynced-\(i)", ...)
    try manager.saveMessage(msg, isSynced: false)
}
```

**Action:**
```swift
let unsynced = try manager.fetchUnsyncedMessages()
```

**Expected:**
- Returns exactly 2 messages
- All have `isSynced == false`
- Sorted by `sentAt` (oldest first)

**Verification:**
```swift
XCTAssertEqual(unsynced.count, 2)
XCTAssertTrue(unsynced.allSatisfy { !$0.isSynced })
```

---

#### Test 6: Mark as Synced

**Purpose:** Verify can mark message as successfully synced

**Setup:**
```swift
let message = Message(id: "msg-1", ...)
try manager.saveMessage(message, isSynced: false)
```

**Action:**
```swift
try manager.markAsSynced(messageId: "msg-1")
```

**Expected:**
- `isSynced` = true
- `needsSync` = false
- `syncAttempts` = 0
- `lastSyncError` = nil

**Verification:**
```swift
let fetchRequest: NSFetchRequest<MessageEntity> = MessageEntity.fetchRequest()
fetchRequest.predicate = NSPredicate(format: "id == %@", "msg-1")
let entity = try testContext.fetch(fetchRequest).first

XCTAssertEqual(entity?.isSynced, true)
XCTAssertEqual(entity?.needsSync, false)
XCTAssertEqual(entity?.syncAttempts, 0)
XCTAssertNil(entity?.lastSyncError)
```

---

#### Test 7: Save Conversation

**Purpose:** Verify conversations can be saved

**Setup:**
```swift
let conversation = Conversation(
    id: "conv-1",
    participantIds: ["user-1", "user-2"],
    isGroup: false,
    lastMessage: "Hello",
    lastMessageAt: Date(),
    createdBy: "user-1",
    createdAt: Date()
)
```

**Action:**
```swift
try manager.saveConversation(conversation)
```

**Expected:**
- Conversation saved to Core Data
- All fields match

**Verification:**
```swift
let fetchRequest: NSFetchRequest<ConversationEntity> = ConversationEntity.fetchRequest()
fetchRequest.predicate = NSPredicate(format: "id == %@", "conv-1")
let entity = try testContext.fetch(fetchRequest).first

XCTAssertNotNil(entity)
XCTAssertEqual(entity?.participantIds, ["user-1", "user-2"])
XCTAssertEqual(entity?.isGroup, false)
```

---

#### Test 8: Fetch Conversations

**Purpose:** Verify conversations can be queried and sorted

**Setup:**
```swift
// Create 3 conversations with different lastMessageAt times
let now = Date()
let conv1 = Conversation(id: "conv-1", ..., lastMessageAt: now.addingTimeInterval(-3600)) // 1 hour ago
let conv2 = Conversation(id: "conv-2", ..., lastMessageAt: now) // Now
let conv3 = Conversation(id: "conv-3", ..., lastMessageAt: now.addingTimeInterval(-7200)) // 2 hours ago

try manager.saveConversation(conv1)
try manager.saveConversation(conv2)
try manager.saveConversation(conv3)
```

**Action:**
```swift
let conversations = try manager.fetchConversations()
```

**Expected:**
- Returns 3 conversations
- Sorted by `lastMessageAt` (most recent first)
- Order: conv2, conv1, conv3

**Verification:**
```swift
XCTAssertEqual(conversations.count, 3)
XCTAssertEqual(conversations[0].id, "conv-2") // Most recent
XCTAssertEqual(conversations[1].id, "conv-1")
XCTAssertEqual(conversations[2].id, "conv-3") // Oldest
```

---

#### Test 9: Batch Save Messages

**Purpose:** Verify can save multiple messages efficiently

**Setup:**
```swift
let messages = (0..<100).map { i in
    Message(id: UUID().uuidString, conversationId: "conv-1", text: "Message \(i)", ...)
}
```

**Action:**
```swift
let start = Date()
try manager.batchSaveMessages(messages)
let duration = Date().timeIntervalSince(start)
```

**Expected:**
- All 100 messages saved
- Duration < 500ms
- All fetchable

**Verification:**
```swift
XCTAssertLessThan(duration, 0.5) // < 500ms
let fetched = try manager.fetchMessages(conversationId: "conv-1")
XCTAssertEqual(fetched.count, 100)
```

---

### SyncManager Tests (5 tests)

#### Test 10: Queue Message for Sync

**Purpose:** Verify messages can be queued when offline

**Setup:**
```swift
let syncManager = SyncManager(
    localDataManager: manager,
    networkMonitor: mockNetworkMonitor
)
mockNetworkMonitor.isConnected = false

let message = Message(id: "msg-1", ...)
```

**Action:**
```swift
try syncManager.queueMessageForSync(message)
```

**Expected:**
- Message saved locally with `isSynced: false`
- `pendingMessageCount` increases by 1
- No sync attempted (offline)

**Verification:**
```swift
XCTAssertEqual(syncManager.pendingMessageCount, 1)

let unsynced = try manager.fetchUnsyncedMessages()
XCTAssertEqual(unsynced.count, 1)
XCTAssertEqual(unsynced.first?.id, "msg-1")
```

---

#### Test 11: Sync When Online

**Purpose:** Verify sync triggers when connection available

**Setup:**
```swift
// Queue 3 messages while offline
mockNetworkMonitor.isConnected = false
for i in 0..<3 {
    try syncManager.queueMessageForSync(Message(id: "msg-\(i)", ...))
}
```

**Action:**
```swift
mockNetworkMonitor.isConnected = true
await syncManager.syncPendingMessages()
```

**Expected:**
- All 3 messages synced (or attempted)
- `isSyncing` = false after completion
- `pendingMessageCount` = 0 (if successful)

**Verification:**
```swift
XCTAssertEqual(syncManager.isSyncing, false)
XCTAssertEqual(syncManager.pendingMessageCount, 0)

let unsynced = try manager.fetchUnsyncedMessages()
XCTAssertTrue(unsynced.isEmpty)
```

---

#### Test 12: Pause Sync When Offline

**Purpose:** Verify sync doesn't run when offline

**Setup:**
```swift
mockNetworkMonitor.isConnected = false
try syncManager.queueMessageForSync(Message(id: "msg-1", ...))
```

**Action:**
```swift
await syncManager.syncPendingMessages()
```

**Expected:**
- Sync skipped (logs "⏸️ Sync skipped: No network connection")
- `isSyncing` = false
- Messages still in queue

**Verification:**
```swift
XCTAssertEqual(syncManager.isSyncing, false)
XCTAssertEqual(syncManager.pendingMessageCount, 1)
```

---

#### Test 13: Increment Sync Attempts on Failure

**Purpose:** Verify retry counter increments on failure

**Setup:**
```swift
let message = Message(id: "msg-1", ...)
try manager.saveMessage(message, isSynced: false)
```

**Action:**
```swift
try manager.incrementSyncAttempts(messageId: "msg-1", error: "Network timeout")
```

**Expected:**
- `syncAttempts` incremented (0 → 1)
- `lastSyncError` set to "Network timeout"
- Still in unsynced queue

**Verification:**
```swift
let fetchRequest: NSFetchRequest<MessageEntity> = MessageEntity.fetchRequest()
fetchRequest.predicate = NSPredicate(format: "id == %@", "msg-1")
let entity = try testContext.fetch(fetchRequest).first

XCTAssertEqual(entity?.syncAttempts, 1)
XCTAssertEqual(entity?.lastSyncError, "Network timeout")
```

---

#### Test 14: Stop Retry After Max Attempts

**Purpose:** Verify retry stops after 5 attempts

**Setup:**
```swift
let message = Message(id: "msg-1", ...)
try manager.saveMessage(message, isSynced: false)
```

**Action:**
```swift
// Increment 5 times
for i in 0..<5 {
    try manager.incrementSyncAttempts(messageId: "msg-1", error: "Retry \(i)")
}
```

**Expected:**
- `syncAttempts` = 5
- `needsSync` = false (stops trying)
- Still `isSynced` = false (never succeeded)

**Verification:**
```swift
let entity = ... // Fetch entity
XCTAssertEqual(entity?.syncAttempts, 5)
XCTAssertEqual(entity?.needsSync, false)
XCTAssertEqual(entity?.isSynced, false)
```

---

### NetworkMonitor Tests (3 tests)

#### Test 15: Detect Online State

**Purpose:** Verify monitors connected state

**Setup:**
```swift
let monitor = NetworkMonitor()
```

**Action:**
- Run on device/simulator with network enabled

**Expected:**
- `isConnected` = true
- Console shows "🟢 Network: Online"
- `connectionType` = .wifi or .cellular

**Verification:**
```swift
XCTAssertTrue(monitor.isConnected)
XCTAssertNotNil(monitor.connectionType)
```

---

#### Test 16: Detect Offline State

**Purpose:** Verify detects disconnected state

**Setup:**
```swift
let monitor = NetworkMonitor()
```

**Action:**
- Enable airplane mode
- Or use Network Link Conditioner (100% Loss)

**Expected:**
- `isConnected` = false
- Console shows "🔴 Network: Offline"
- `connectionType` = nil

**Verification:**
```swift
XCTAssertFalse(monitor.isConnected)
XCTAssertNil(monitor.connectionType)
```

---

#### Test 17: Detect Connection Type

**Purpose:** Verify identifies WiFi vs cellular

**Setup:**
```swift
let monitor = NetworkMonitor()
```

**Action:**
- Test on WiFi

**Expected:**
- `connectionType` = .wifi
- Console shows "📶 Connection: WiFi"

**Action:**
- Test on cellular (physical device)

**Expected:**
- `connectionType` = .cellular
- Console shows "📱 Connection: Cellular"

**Verification:**
```swift
// On WiFi
XCTAssertEqual(monitor.connectionType, .wifi)

// On cellular
XCTAssertEqual(monitor.connectionType, .cellular)
```

---

## Integration Tests (3 scenarios)

### Test 18: Save & Retrieve (Lossless Round-Trip)

**Purpose:** Verify data integrity through save/fetch cycle

**Scenario:**
1. Create message with all fields populated
2. Save to Core Data
3. Fetch from Core Data
4. Verify all fields match exactly

**Setup:**
```swift
let original = Message(
    id: "msg-1",
    conversationId: "conv-1",
    senderId: "user-1",
    text: "Test message with emoji 🎉",
    imageURL: "https://example.com/image.jpg",
    sentAt: Date(),
    deliveredAt: Date().addingTimeInterval(1),
    readAt: Date().addingTimeInterval(2),
    status: .read
)
```

**Actions:**
```swift
try manager.saveMessage(original)
let fetched = try manager.fetchMessages(conversationId: "conv-1")
let retrieved = fetched.first!
```

**Expected:**
- All fields match exactly
- No data loss
- Timestamps preserved (within 1ms)
- Optional fields preserved

**Verification:**
```swift
XCTAssertEqual(retrieved.id, original.id)
XCTAssertEqual(retrieved.text, original.text)
XCTAssertEqual(retrieved.imageURL, original.imageURL)
XCTAssertEqual(retrieved.status, original.status)
XCTAssertEqual(retrieved.sentAt.timeIntervalSince1970,
               original.sentAt.timeIntervalSince1970, accuracy: 0.001)
```

**Result:** ✅ PASS if all fields match

---

### Test 19: Offline Queue → Online Sync

**Purpose:** Verify full offline-to-online workflow

**Scenario:**
1. Go offline
2. Send 3 messages (queued locally)
3. Verify messages saved with `isSynced: false`
4. Go online
5. Verify sync triggered automatically
6. Verify all messages marked as synced

**Setup:**
```swift
let mockNetwork = MockNetworkMonitor()
mockNetwork.isConnected = false

let syncManager = SyncManager(
    localDataManager: manager,
    networkMonitor: mockNetwork
)
```

**Actions:**
```swift
// 1. Queue messages while offline
for i in 0..<3 {
    let message = Message(id: "msg-\(i)", conversationId: "conv-1", text: "Message \(i)", ...)
    try syncManager.queueMessageForSync(message)
}

// 2. Verify queued
var unsynced = try manager.fetchUnsyncedMessages()
XCTAssertEqual(unsynced.count, 3)

// 3. Go online
mockNetwork.isConnected = true
mockNetwork.triggerConnectionChange() // Simulate network state change

// 4. Wait for sync
await syncManager.syncPendingMessages()

// 5. Verify synced
unsynced = try manager.fetchUnsyncedMessages()
```

**Expected:**
- Before online: 3 unsynced messages
- After online: 0 unsynced messages
- Sync triggered automatically
- All messages marked `isSynced: true`

**Verification:**
```swift
XCTAssertEqual(unsynced.count, 0)
XCTAssertEqual(syncManager.pendingMessageCount, 0)
```

**Result:** ✅ PASS if all messages synced

---

### Test 20: App Restart Persistence

**Purpose:** Verify messages survive app termination

**Scenario:**
1. Save 10 messages
2. Save context explicitly
3. Destroy PersistenceController
4. Create new PersistenceController
5. Fetch messages with new instance
6. Verify all 10 messages still exist

**Setup:**
```swift
// Phase 1: Save messages
var controller: PersistenceController? = PersistenceController()
var manager: LocalDataManager? = LocalDataManager(context: controller!.container.viewContext)

for i in 0..<10 {
    let message = Message(id: "msg-\(i)", ...)
    try manager!.saveMessage(message)
}

controller!.save()
```

**Actions:**
```swift
// Phase 2: Destroy and recreate
controller = nil
manager = nil

// Simulate app restart
controller = PersistenceController()
manager = LocalDataManager(context: controller!.container.viewContext)

// Fetch messages
let messages = try manager!.fetchMessages(conversationId: "conv-1")
```

**Expected:**
- All 10 messages retrieved
- Data intact
- Order preserved

**Verification:**
```swift
XCTAssertEqual(messages.count, 10)

for i in 0..<10 {
    XCTAssertTrue(messages.contains(where: { $0.id == "msg-\(i)" }))
}
```

**Result:** ✅ PASS if all messages persist

---

## Edge Cases (6 tests)

### Test 21: Empty Database Query

**Purpose:** Verify graceful handling of empty result

**Setup:**
```swift
// Empty database
let manager = LocalDataManager(context: emptyContext)
```

**Action:**
```swift
let messages = try manager.fetchMessages(conversationId: "nonexistent")
```

**Expected:**
- Returns empty array (not nil)
- No crash
- No error thrown

**Verification:**
```swift
XCTAssertNotNil(messages)
XCTAssertTrue(messages.isEmpty)
```

---

### Test 22: Duplicate ID Handling

**Purpose:** Verify update (not create) when ID exists

**Setup:**
```swift
let message1 = Message(id: "duplicate-id", text: "First version", ...)
try manager.saveMessage(message1)
```

**Action:**
```swift
let message2 = Message(id: "duplicate-id", text: "Second version", ...)
try manager.saveMessage(message2)
```

**Expected:**
- Only one message with that ID
- Text updated to "Second version"
- No duplicate entries

**Verification:**
```swift
let fetchRequest: NSFetchRequest<MessageEntity> = MessageEntity.fetchRequest()
fetchRequest.predicate = NSPredicate(format: "id == %@", "duplicate-id")
let results = try testContext.fetch(fetchRequest)

XCTAssertEqual(results.count, 1)
XCTAssertEqual(results.first?.text, "Second version")
```

---

### Test 23: Sync Conflict Resolution

**Purpose:** Verify server data overwrites local

**Setup:**
```swift
// Local message (offline)
let localMessage = Message(id: "msg-1", text: "Local version", sentAt: Date())
try manager.saveMessage(localMessage, isSynced: false)
```

**Action:**
```swift
// Server message (newer timestamp)
let serverMessage = Message(id: "msg-1", text: "Server version", sentAt: Date().addingTimeInterval(10))
try manager.saveMessage(serverMessage, isSynced: true)
```

**Expected:**
- Text = "Server version" (server wins)
- Timestamp = server timestamp
- `isSynced` = true

**Verification:**
```swift
let messages = try manager.fetchMessages(conversationId: "conv-1")
let msg = messages.first(where: { $0.id == "msg-1" })

XCTAssertEqual(msg?.text, "Server version")
XCTAssertTrue(msg!.isSynced)
```

---

### Test 24: Network Flapping

**Purpose:** Verify handles rapid online/offline changes

**Setup:**
```swift
let monitor = NetworkMonitor()
let syncManager = SyncManager(localDataManager: manager, networkMonitor: monitor)
```

**Action:**
```swift
// Rapid network changes
for _ in 0..<10 {
    mockMonitor.isConnected = false
    mockMonitor.triggerChange()
    try await Task.sleep(nanoseconds: 100_000_000) // 0.1s
    
    mockMonitor.isConnected = true
    mockMonitor.triggerChange()
    try await Task.sleep(nanoseconds: 100_000_000)
}
```

**Expected:**
- No crashes
- No duplicate syncs
- SyncManager state correct

**Verification:**
```swift
XCTAssertFalse(syncManager.isSyncing)
// App still functional
```

---

### Test 25: Corrupted Data Handling

**Purpose:** Verify fails gracefully with invalid data

**Setup:**
```swift
// Manually insert invalid entity
let entity = MessageEntity(context: testContext)
entity.id = "invalid"
// Missing required fields (conversationId, senderId, text)
try? testContext.save()
```

**Action:**
```swift
let result = try? manager.fetchMessages(conversationId: "conv-1")
```

**Expected:**
- Doesn't crash app
- Returns empty or valid messages only
- Logs error

**Verification:**
```swift
// Should not crash
XCTAssertNotNil(result)
```

---

### Test 26: Full Disk Simulation

**Purpose:** Verify handles storage errors

**Setup:**
```swift
// Mock context that fails saves
let mockContext = MockNSManagedObjectContext()
mockContext.shouldFailSaves = true

let manager = LocalDataManager(context: mockContext)
```

**Action:**
```swift
let message = Message(id: "msg-1", ...)
let result = try? manager.saveMessage(message)
```

**Expected:**
- Throws `PersistenceError.saveFailed`
- Doesn't crash
- Error message descriptive

**Verification:**
```swift
XCTAssertThrowsError(try manager.saveMessage(message)) { error in
    XCTAssertTrue(error is PersistenceError)
}
```

---

## Performance Tests (4 benchmarks)

### Test 27: Insert 1000 Messages

**Purpose:** Verify bulk insert performance

**Setup:**
```swift
let messages = (0..<1000).map { i in
    Message(id: UUID().uuidString, conversationId: "perf-test", text: "Message \(i)", ...)
}
```

**Action:**
```swift
let start = Date()
try manager.batchSaveMessages(messages)
let duration = Date().timeIntervalSince(start)
```

**Expected:**
- Duration < 2 seconds
- All 1000 messages saved

**Verification:**
```swift
XCTAssertLessThan(duration, 2.0)

let fetched = try manager.fetchMessages(conversationId: "perf-test")
XCTAssertEqual(fetched.count, 1000)
```

**Target:** <2 seconds  
**Result:** ____ seconds

---

### Test 28: Fetch 1000 Messages

**Purpose:** Verify large query performance

**Setup:**
```swift
// Insert 1000 messages
for i in 0..<1000 {
    try manager.saveMessage(Message(id: "msg-\(i)", conversationId: "perf-test", ...))
}
```

**Action:**
```swift
let start = Date()
let messages = try manager.fetchMessages(conversationId: "perf-test")
let duration = Date().timeIntervalSince(start)
```

**Expected:**
- Duration < 500ms
- Returns all 1000 messages
- Sorted correctly

**Verification:**
```swift
XCTAssertLessThan(duration, 0.5)
XCTAssertEqual(messages.count, 1000)
```

**Target:** <500ms  
**Result:** ____ ms

---

### Test 29: Batch Insert Performance

**Purpose:** Verify batch operations are efficient

**Setup:**
```swift
let messages = (0..<100).map { Message(id: UUID().uuidString, ...) }
```

**Action:**
```swift
let start = Date()
try manager.batchSaveMessages(messages)
let duration = Date().timeIntervalSince(start)
```

**Expected:**
- Duration < 500ms
- All 100 messages saved

**Verification:**
```swift
XCTAssertLessThan(duration, 0.5)
```

**Target:** <500ms for 100 messages  
**Result:** ____ ms

---

### Test 30: Memory Usage

**Purpose:** Verify memory doesn't leak

**Setup:**
```swift
// Profile with Instruments
// Product > Profile > Allocations
```

**Action:**
```swift
// Insert 10,000 messages
for i in 0..<10000 {
    let message = Message(id: "msg-\(i)", ...)
    try manager.saveMessage(message)
}

// Fetch multiple times
for _ in 0..<100 {
    let messages = try manager.fetchMessages(conversationId: "conv-1")
    _ = messages.count
}
```

**Expected:**
- Memory usage < 50MB
- No memory leaks
- Memory released after operations

**Verification:**
- Use Instruments (Allocations, Leaks)
- Check for abandoned memory
- Verify objects deallocated

**Target:** <50MB for 10k messages  
**Result:** ____ MB

---

## Acceptance Tests (3 scenarios)

### Test 31: Messages Persist Through Force Quit

**MVP Requirement:** #3 - Message persistence (survives app restarts)

**Scenario:**
1. Launch app
2. Create conversation
3. Send 5 messages
4. Force quit app (swipe up in app switcher)
5. Relaunch app
6. Navigate to conversation
7. Verify all 5 messages present

**Expected:**
- All messages displayed
- Correct order
- Timestamps accurate
- No data loss

**Result:** ✅ PASS / ❌ FAIL

---

### Test 32: Offline Messages Queue and Sync

**MVP Requirement:** #10 - Offline message queuing with automatic sync

**Scenario:**
1. Go offline (airplane mode)
2. Compose and send 3 messages
3. Verify messages appear in chat (optimistic UI)
4. Verify messages marked as "sending" status
5. Go online (disable airplane mode)
6. Wait 5 seconds
7. Verify messages synced to Firebase
8. Verify status updated to "sent"

**Expected:**
- Messages visible immediately when sent
- Queue locally when offline
- Sync automatically when online
- Status updates correctly

**Result:** ✅ PASS / ❌ FAIL

---

### Test 33: No Data Loss Under Stress

**Quality Gate:** Zero data loss in stress testing

**Scenario:**
1. Send 100 messages rapidly (tap send repeatedly)
2. Force quit app mid-send (after 50 messages)
3. Relaunch app
4. Verify all messages present (queued or sent)
5. Go offline
6. Send 20 more messages
7. Force quit again
8. Relaunch offline
9. Verify all 120 messages present
10. Go online
11. Verify all sync successfully

**Expected:**
- Zero messages lost
- All messages eventually sync
- No duplicates
- Correct order

**Result:** ✅ PASS / ❌ FAIL

---

## Test Execution Plan

### Phase 1: Unit Tests (Day 1, 10 minutes)
- Run all 16 unit tests
- Fix any failures immediately
- Verify 100% pass rate

### Phase 2: Integration Tests (Day 1, 15 minutes)
- Run 3 integration scenarios
- Test with real Core Data (not in-memory)
- Verify data persistence

### Phase 3: Edge Cases (Day 1, 10 minutes)
- Run 6 edge case tests
- Verify graceful error handling
- Check console for excessive errors

### Phase 4: Performance Tests (Day 1, 10 minutes)
- Run 4 performance benchmarks
- Profile with Instruments if needed
- Optimize slow queries

### Phase 5: Acceptance Tests (Day 2, 15 minutes)
- Run 3 acceptance scenarios
- Use physical device (more realistic)
- Verify MVP requirements met

---

## Success Criteria

### All Tests Must Pass

- [ ] **16 unit tests:** 100% pass rate
- [ ] **3 integration tests:** All scenarios working
- [ ] **6 edge cases:** Graceful error handling
- [ ] **4 performance tests:** All targets met
- [ ] **3 acceptance tests:** MVP requirements validated

### Performance Targets Met

- [ ] Insert 1000 messages: <2 seconds
- [ ] Fetch 1000 messages: <500ms
- [ ] Batch insert 100: <500ms
- [ ] Memory usage: <50MB for 10k messages

### Quality Gates Passed

- [ ] Zero Core Data crashes
- [ ] Zero data loss in stress testing
- [ ] Handles 1000+ messages per conversation
- [ ] Works completely offline
- [ ] Syncs automatically when online

---

## Test Report Template

```
## PR#6 Testing Report

**Date:** [Date]
**Tester:** [Name]
**Device:** [Device model]
**iOS Version:** [Version]

### Test Results

| Category | Passed | Failed | Total | Pass Rate |
|----------|--------|--------|-------|-----------|
| Unit Tests | __ / 16 | __ | 16 | __% |
| Integration Tests | __ / 3 | __ | 3 | __% |
| Edge Cases | __ / 6 | __ | 6 | __% |
| Performance Tests | __ / 4 | __ | 4 | __% |
| Acceptance Tests | __ / 3 | __ | 3 | __% |
| **Total** | __ / 32 | __ | 32 | __% |

### Performance Results

| Test | Target | Actual | Status |
|------|--------|--------|--------|
| Insert 1000 | <2s | __s | ✅ / ❌ |
| Fetch 1000 | <500ms | __ms | ✅ / ❌ |
| Batch Insert | <500ms | __ms | ✅ / ❌ |
| Memory | <50MB | __MB | ✅ / ❌ |

### Issues Found

1. [Issue description]
   - Severity: CRITICAL/HIGH/MEDIUM/LOW
   - Fix: [How it was fixed]

### Overall Assessment

✅ PASS / ❌ FAIL

**Recommendation:** READY TO MERGE / NEEDS WORK

**Notes:**
[Additional observations]
```

---

## Troubleshooting Test Failures

### Common Test Failures & Solutions

**Failure:** Context not saving  
**Solution:** Call `context.save()` explicitly, check for validation errors

**Failure:** Fetch returns wrong count  
**Solution:** Verify predicate syntax, check entity names match

**Failure:** Performance test fails  
**Solution:** Add indexes, check for N+1 queries, profile with Instruments

**Failure:** NetworkMonitor not detecting changes  
**Solution:** Test on physical device, use Network Link Conditioner

**Failure:** Sync not triggering  
**Solution:** Verify network observer set up, check Combine subscriptions

---

**Testing Complete:** All 32 tests passing = PR#6 ready for production! 🎉

