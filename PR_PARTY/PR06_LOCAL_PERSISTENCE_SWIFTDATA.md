# PR#6: Local Persistence with SwiftData

**Estimated Time:** 2-3 hours  
**Complexity:** MEDIUM  
**Dependencies:** PR #4 (Core Models) complete  
**Status:** 📋 PLANNED

---

## Overview

### What We're Building

Local persistence layer using SwiftData to enable offline-first messaging. This PR creates the bridge between our Swift models (PR #4) and on-device storage, allowing messages to persist through app restarts, support offline message composition, and enable fast message loading.

### Why It Matters

**Critical for MVP Requirements:**
- ✅ Messages persist through app restarts (MVP requirement #3)
- ✅ Offline message queuing (MVP requirement #10)
- ✅ Fast app launch (messages load instantly from local storage)
- ✅ No data loss under any circumstance (core principle)

**User Impact:**
- Messages never disappear
- App works offline (read old messages, compose new ones)
- Instant message history on app open
- Seamless sync when connection returns

### Success in One Sentence

"This PR is successful when messages persist locally, the app works fully offline, and sync happens automatically when online—with zero data loss."

---

## Technical Design

### Architecture Decisions

#### Decision 1: SwiftData vs Core Data

**Options Considered:**

1. **Option A: SwiftData** (iOS 17+)
   - ✅ Modern, declarative syntax
   - ✅ Native Swift integration
   - ✅ Less boilerplate code
   - ✅ Better type safety
   - ❌ iOS 17+ only (but we can check iOS version)

2. **Option B: Core Data** (iOS 16+)
   - ✅ Broader iOS compatibility (16.0+)
   - ✅ Battle-tested, mature
   - ✅ More documentation available
   - ❌ More boilerplate
   - ❌ Objective-C legacy baggage

3. **Option C: UserDefaults + JSON**
   - ✅ Simple for small data
   - ❌ Not suitable for large message history
   - ❌ No query capabilities
   - ❌ Poor performance at scale

**Chosen:** Option B - Core Data

**Rationale:**
- Our minimum iOS target is 16.0 (set in PR #1)
- SwiftData requires iOS 17.0+
- Cannot raise minimum iOS to 17 (excludes too many users)
- Core Data is mature, well-documented, and performs well
- Can migrate to SwiftData in future if we raise min iOS

**Trade-offs:**
- Gain: Broader device compatibility (iOS 16+)
- Gain: More resources and examples available
- Lose: Some modern Swift conveniences
- Lose: More boilerplate code (but manageable)

#### Decision 2: Entity Structure

**Options Considered:**

1. **Option A: Mirror Firebase structure exactly**
   - ✅ Easy to sync
   - ❌ Includes fields not needed locally
   - ❌ Wastes storage space

2. **Option B: Minimal local storage (IDs only)**
   - ✅ Minimal disk usage
   - ❌ Requires network for every message display
   - ❌ Doesn't work offline

3. **Option C: Store essential fields + sync metadata**
   - ✅ Works offline completely
   - ✅ Efficient storage
   - ✅ Includes sync tracking fields
   - ❌ Slight redundancy with Firebase

**Chosen:** Option C - Essential fields + sync metadata

**Rationale:**
- Need full message data to work offline
- Add `isSynced`, `syncAttempts`, `lastSyncError` for queue management
- Allows retry logic and conflict resolution
- Disk space is cheap, offline functionality is critical

**Trade-offs:**
- Gain: Complete offline functionality
- Gain: Detailed sync status tracking
- Gain: Retry and error handling capability
- Lose: ~10-20% more storage (acceptable)

#### Decision 3: Sync Strategy

**Options Considered:**

1. **Option A: Manual sync (user-triggered)**
   - ✅ User has control
   - ❌ Extra UI complexity
   - ❌ Users forget to sync

2. **Option B: Background sync (scheduled)**
   - ✅ Automatic
   - ❌ May sync when not needed
   - ❌ Battery drain

3. **Option C: Network-aware auto-sync**
   - ✅ Syncs when online detected
   - ✅ Queues when offline
   - ✅ No user intervention
   - ❌ Requires network monitoring

**Chosen:** Option C - Network-aware auto-sync

**Rationale:**
- Aligns with WhatsApp model (seamless, automatic)
- Network monitoring already in scope (PR #15)
- Best user experience (zero thought required)
- Implement network monitoring early (this PR) for foundation

**Trade-offs:**
- Gain: Best UX (invisible to user)
- Gain: Messages send as soon as possible
- Gain: No forgotten unsent messages
- Lose: Need to implement NetworkMonitor now (adds 30min)

---

## Data Model

### Core Data Entity Schema

#### MessageEntity

```swift
@objc(MessageEntity)
public class MessageEntity: NSManagedObject {
    // Primary key
    @NSManaged public var id: String
    
    // Content
    @NSManaged public var conversationId: String
    @NSManaged public var senderId: String
    @NSManaged public var text: String
    @NSManaged public var imageURL: String?
    
    // Timestamps
    @NSManaged public var sentAt: Date
    @NSManaged public var deliveredAt: Date?
    @NSManaged public var readAt: Date?
    
    // Status
    @NSManaged public var status: String  // MessageStatus raw value
    
    // Sync metadata (NEW - not in Firebase)
    @NSManaged public var isSynced: Bool
    @NSManaged public var syncAttempts: Int
    @NSManaged public var lastSyncError: String?
    @NSManaged public var needsSync: Bool  // Flag for pending changes
    
    // Relationships
    @NSManaged public var conversation: ConversationEntity?
}
```

**Size Estimate:** ~150-200 bytes per message (text only)  
**Performance:** Indexed on `conversationId` and `isSynced`

#### ConversationEntity

```swift
@objc(ConversationEntity)
public class ConversationEntity: NSManagedObject {
    // Primary key
    @NSManaged public var id: String
    
    // Participants
    @NSManaged public var participantIds: [String]  // Transformable attribute
    
    // Metadata
    @NSManaged public var isGroup: Bool
    @NSManaged public var groupName: String?
    @NSManaged public var lastMessage: String
    @NSManaged public var lastMessageAt: Date
    @NSManaged public var createdBy: String
    @NSManaged public var createdAt: Date
    
    // Unread tracking
    @NSManaged public var unreadCount: Int
    
    // Relationships
    @NSManaged public var messages: NSSet?  // One-to-many with MessageEntity
}
```

**Size Estimate:** ~200-300 bytes per conversation  
**Performance:** Indexed on `lastMessageAt` for chat list sorting

### Entity Relationships

```
ConversationEntity (1) ───< (many) MessageEntity
    │
    │ Delete Rule: Cascade
    │ (Deleting conversation deletes all messages)
    │
    └─ messages: NSSet (ordered by sentAt)
```

---

## Implementation Details

### File Structure

**New Files:**
```
messAI/
├── Persistence/
│   ├── MessageAI.xcdatamodeld/      (~50 lines - Core Data model file)
│   │   └── MessageAI.xcdatamodel
│   ├── MessageEntity+CoreDataClass.swift (~80 lines)
│   ├── MessageEntity+CoreDataProperties.swift (~60 lines)
│   ├── ConversationEntity+CoreDataClass.swift (~80 lines)
│   ├── ConversationEntity+CoreDataProperties.swift (~60 lines)
│   ├── PersistenceController.swift  (~120 lines - Core Data stack)
│   ├── LocalDataManager.swift       (~300 lines - CRUD operations)
│   └── SyncManager.swift            (~200 lines - Sync logic)
│
└── Utilities/
    └── NetworkMonitor.swift         (~80 lines - Connection detection)
```

**Total New Code:** ~1,030 lines

**Modified Files:**
- `messAIApp.swift` (+10 lines) - Inject PersistenceController
- `Models/Message.swift` (+40 lines) - Add Core Data conversion
- `Models/Conversation.swift` (+40 lines) - Add Core Data conversion

**Total Modified:** +90 lines

**Grand Total:** ~1,120 lines of code

---

### Key Implementation Steps

#### Phase 1: Core Data Setup (45-60 minutes)

**1.1: Create Data Model**
- Create `.xcdatamodeld` file in Xcode
- Define MessageEntity with all attributes
- Define ConversationEntity with all attributes
- Set up relationship (one-to-many)
- Configure delete rule (cascade)
- Add indexes for performance

**1.2: Generate Entity Classes**
- Use Xcode codegen for entity classes
- Review and customize generated code
- Add convenience initializers
- Add computed properties

**1.3: Create PersistenceController**
- Set up Core Data stack
- Configure persistent container
- Add in-memory store for previews/tests
- Implement error handling
- Add migration support (for future)

#### Phase 2: Local Data Manager (60-75 minutes)

**2.1: CRUD Operations**
- `saveMessage(_:)` - Insert or update message
- `fetchMessages(conversationId:)` - Query messages for conversation
- `updateMessage(id:updates:)` - Update specific message
- `deleteMessage(id:)` - Remove message
- `saveConversation(_:)` - Insert or update conversation
- `fetchConversations()` - Query all conversations
- `deleteConversation(id:)` - Remove conversation + cascade

**2.2: Sync Query Operations**
- `fetchUnsyncedMessages()` - Get messages where `isSynced == false`
- `markAsSynced(messageId:)` - Update sync status
- `incrementSyncAttempts(messageId:)` - Track retry count
- `fetchMessagesPendingRetry()` - Failed sync messages

**2.3: Batch Operations**
- `batchSaveMessages(_:)` - Efficient bulk insert
- `batchUpdateStatus(_:)` - Update multiple message statuses
- `clearAllData()` - For logout/testing

#### Phase 3: Sync Manager (45-60 minutes)

**3.1: Core Sync Logic**
- `syncPendingMessages()` - Upload unsynced to Firebase
- `handleIncomingMessage(_:)` - Save from Firebase to local
- `resolveConflicts(_:)` - Handle sync conflicts (server wins)

**3.2: Queue Management**
- Track pending messages
- Retry with exponential backoff (1s, 2s, 4s, 8s, max 30s)
- Max retry attempts: 5
- Mark as failed after max attempts

**3.3: Network Integration**
- Subscribe to NetworkMonitor
- Trigger sync when online
- Pause sync when offline

#### Phase 4: Model Conversion (15-20 minutes)

**4.1: Message Extensions**
```swift
extension Message {
    init(from entity: MessageEntity) {
        // Convert Core Data entity → Swift model
    }
    
    func toEntity(context: NSManagedObjectContext) -> MessageEntity {
        // Convert Swift model → Core Data entity
    }
}
```

**4.2: Conversation Extensions**
```swift
extension Conversation {
    init(from entity: ConversationEntity) {
        // Convert Core Data entity → Swift model
    }
    
    func toEntity(context: NSManagedObjectContext) -> ConversationEntity {
        // Convert Swift model → Core Data entity
    }
}
```

---

## Code Examples

### Example 1: PersistenceController Setup

```swift
import CoreData

class PersistenceController {
    static let shared = PersistenceController()
    
    // For SwiftUI previews
    static var preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.viewContext
        
        // Add sample data for previews
        for i in 0..<10 {
            let message = MessageEntity(context: context)
            message.id = UUID().uuidString
            message.text = "Sample message \(i)"
            message.conversationId = "preview-conversation"
            message.senderId = "user-1"
            message.sentAt = Date()
            message.status = "sent"
            message.isSynced = true
            message.syncAttempts = 0
        }
        
        try? context.save()
        return controller
    }()
    
    let container: NSPersistentContainer
    
    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "MessageAI")
        
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }
        
        container.loadPersistentStores { description, error in
            if let error = error {
                fatalError("Core Data failed to load: \(error.localizedDescription)")
            }
        }
        
        // Auto-merge changes from parent context
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
    
    func save() {
        let context = container.viewContext
        
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                print("❌ Failed to save context: \(error)")
            }
        }
    }
}
```

### Example 2: LocalDataManager CRUD

```swift
import CoreData

class LocalDataManager {
    private let context: NSManagedObjectContext
    
    init(context: NSManagedObjectContext = PersistenceController.shared.container.viewContext) {
        self.context = context
    }
    
    // MARK: - Message Operations
    
    func saveMessage(_ message: Message) throws {
        // Check if message already exists
        let fetchRequest: NSFetchRequest<MessageEntity> = MessageEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", message.id)
        
        let results = try context.fetch(fetchRequest)
        let entity: MessageEntity
        
        if let existing = results.first {
            // Update existing
            entity = existing
        } else {
            // Create new
            entity = MessageEntity(context: context)
            entity.id = message.id
        }
        
        // Update fields
        entity.conversationId = message.conversationId
        entity.senderId = message.senderId
        entity.text = message.text
        entity.imageURL = message.imageURL
        entity.sentAt = message.sentAt
        entity.deliveredAt = message.deliveredAt
        entity.readAt = message.readAt
        entity.status = message.status.rawValue
        
        // Save context
        try context.save()
    }
    
    func fetchMessages(conversationId: String) throws -> [Message] {
        let fetchRequest: NSFetchRequest<MessageEntity> = MessageEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "conversationId == %@", conversationId)
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \MessageEntity.sentAt, ascending: true)]
        
        let entities = try context.fetch(fetchRequest)
        return entities.map { Message(from: $0) }
    }
    
    func fetchUnsyncedMessages() throws -> [Message] {
        let fetchRequest: NSFetchRequest<MessageEntity> = MessageEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "isSynced == NO")
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \MessageEntity.sentAt, ascending: true)]
        
        let entities = try context.fetch(fetchRequest)
        return entities.map { Message(from: $0) }
    }
    
    func markAsSynced(messageId: String) throws {
        let fetchRequest: NSFetchRequest<MessageEntity> = MessageEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", messageId)
        
        guard let entity = try context.fetch(fetchRequest).first else {
            throw PersistenceError.messageNotFound
        }
        
        entity.isSynced = true
        entity.syncAttempts = 0
        entity.lastSyncError = nil
        
        try context.save()
    }
    
    // MARK: - Conversation Operations
    
    func saveConversation(_ conversation: Conversation) throws {
        let fetchRequest: NSFetchRequest<ConversationEntity> = ConversationEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", conversation.id)
        
        let results = try context.fetch(fetchRequest)
        let entity: ConversationEntity
        
        if let existing = results.first {
            entity = existing
        } else {
            entity = ConversationEntity(context: context)
            entity.id = conversation.id
        }
        
        entity.participantIds = conversation.participantIds
        entity.isGroup = conversation.isGroup
        entity.groupName = conversation.groupName
        entity.lastMessage = conversation.lastMessage
        entity.lastMessageAt = conversation.lastMessageAt
        entity.createdBy = conversation.createdBy
        entity.createdAt = conversation.createdAt
        
        try context.save()
    }
    
    func fetchConversations() throws -> [Conversation] {
        let fetchRequest: NSFetchRequest<ConversationEntity> = ConversationEntity.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \ConversationEntity.lastMessageAt, ascending: false)]
        
        let entities = try context.fetch(fetchRequest)
        return entities.map { Conversation(from: $0) }
    }
}

enum PersistenceError: LocalizedError {
    case messageNotFound
    case conversationNotFound
    case saveFailed
    
    var errorDescription: String? {
        switch self {
        case .messageNotFound: return "Message not found in local storage"
        case .conversationNotFound: return "Conversation not found in local storage"
        case .saveFailed: return "Failed to save to local storage"
        }
    }
}
```

### Example 3: SyncManager

```swift
import Foundation
import Combine

class SyncManager: ObservableObject {
    @Published var isSyncing: Bool = false
    @Published var pendingMessageCount: Int = 0
    
    private let localDataManager: LocalDataManager
    private let chatService: ChatService  // From PR #5
    private let networkMonitor: NetworkMonitor
    private var cancellables = Set<AnyCancellable>()
    
    init(
        localDataManager: LocalDataManager,
        chatService: ChatService,
        networkMonitor: NetworkMonitor
    ) {
        self.localDataManager = localDataManager
        self.chatService = chatService
        self.networkMonitor = networkMonitor
        
        setupNetworkObserver()
    }
    
    private func setupNetworkObserver() {
        // Sync when network becomes available
        networkMonitor.$isConnected
            .dropFirst() // Ignore initial value
            .filter { $0 == true } // Only when going online
            .sink { [weak self] _ in
                self?.syncPendingMessages()
            }
            .store(in: &cancellables)
    }
    
    func syncPendingMessages() {
        guard networkMonitor.isConnected else {
            print("⏸️ Sync skipped: No network connection")
            return
        }
        
        guard !isSyncing else {
            print("⏸️ Sync already in progress")
            return
        }
        
        isSyncing = true
        
        Task {
            do {
                let unsyncedMessages = try localDataManager.fetchUnsyncedMessages()
                pendingMessageCount = unsyncedMessages.count
                
                print("🔄 Syncing \(unsyncedMessages.count) pending messages...")
                
                for message in unsyncedMessages {
                    do {
                        // Send to Firebase
                        try await chatService.sendMessage(
                            conversationId: message.conversationId,
                            text: message.text,
                            imageURL: message.imageURL
                        )
                        
                        // Mark as synced locally
                        try localDataManager.markAsSynced(messageId: message.id)
                        
                        print("✅ Synced message: \(message.id)")
                        
                    } catch {
                        // Increment sync attempts
                        try localDataManager.incrementSyncAttempts(messageId: message.id)
                        print("❌ Failed to sync message \(message.id): \(error)")
                    }
                }
                
                print("✅ Sync complete!")
                
            } catch {
                print("❌ Sync failed: \(error)")
            }
            
            isSyncing = false
        }
    }
    
    func queueMessageForSync(_ message: Message) throws {
        var queuedMessage = message
        queuedMessage.status = .sending
        
        // Save to local storage as unsynced
        try localDataManager.saveMessage(queuedMessage, isSynced: false)
        pendingMessageCount += 1
        
        // If online, sync immediately
        if networkMonitor.isConnected {
            syncPendingMessages()
        }
    }
}
```

### Example 4: NetworkMonitor

```swift
import Network
import Combine

class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    @Published var isConnected: Bool = true
    @Published var connectionType: NWInterface.InterfaceType?
    
    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
                
                // Determine connection type
                if path.usesInterfaceType(.wifi) {
                    self?.connectionType = .wifi
                } else if path.usesInterfaceType(.cellular) {
                    self?.connectionType = .cellular
                } else if path.usesInterfaceType(.wiredEthernet) {
                    self?.connectionType = .wiredEthernet
                } else {
                    self?.connectionType = nil
                }
                
                print(self?.isConnected == true ? "🟢 Online" : "🔴 Offline")
            }
        }
        
        monitor.start(queue: queue)
    }
    
    deinit {
        monitor.cancel()
    }
}
```

---

## Testing Strategy

### Test Categories

#### Unit Tests

**LocalDataManager Tests:**
- `testSaveMessage()` - Creates and saves new message
- `testFetchMessages()` - Retrieves messages for conversation
- `testUpdateMessage()` - Updates existing message
- `testDeleteMessage()` - Removes message
- `testFetchUnsyncedMessages()` - Queries unsynced messages
- `testMarkAsSynced()` - Updates sync status
- `testSaveConversation()` - Creates conversation
- `testFetchConversations()` - Retrieves all conversations
- `testBatchOperations()` - Bulk insert/update

**SyncManager Tests:**
- `testQueueMessage()` - Adds message to sync queue
- `testSyncWhenOnline()` - Syncs when network available
- `testPauseWhenOffline()` - Doesn't sync when offline
- `testRetryLogic()` - Exponential backoff works
- `testMaxRetries()` - Stops after 5 attempts

**NetworkMonitor Tests:**
- `testOnlineDetection()` - Detects connected state
- `testOfflineDetection()` - Detects disconnected state
- `testConnectionTypeDetection()` - Identifies WiFi/cellular

#### Integration Tests

**Scenario 1: Save & Retrieve**
1. Save message to Core Data
2. Fetch message by conversation ID
3. Verify all fields match
4. Expected: Lossless round-trip

**Scenario 2: Offline Queue**
1. Go offline
2. Send 3 messages
3. Verify saved locally with `isSynced: false`
4. Go online
5. Verify sync triggered automatically
6. Verify all 3 messages synced

**Scenario 3: App Restart Persistence**
1. Save 10 messages
2. Terminate app (simulated)
3. Restart app
4. Query messages
5. Expected: All 10 messages still present

#### Edge Cases

- **Empty Database**: Query returns empty array (no crash)
- **Duplicate IDs**: Update existing instead of creating duplicate
- **Sync Conflicts**: Server data overwrites local
- **Network Flapping**: Rapid online/offline doesn't break sync
- **Corrupted Data**: Fails gracefully with error
- **Full Disk**: Catch and handle storage errors

#### Performance Tests

**Benchmarks:**
- `testInsert1000Messages()` - Should complete in <2 seconds
- `testQueryLargeConversation()` - Fetch 1000 messages in <500ms
- `testBatchInsert()` - 100 messages in <500ms
- `testMemoryUsage()` - No memory leaks after 1000 operations

**Targets:**
- Insert: <2ms per message
- Query: <500ms for 1000 messages
- Update: <1ms per message
- Delete: <1ms per message
- Memory: <50MB for 10k messages

---

## Success Criteria

### Feature is complete when:

- [ ] Core Data model defined with MessageEntity and ConversationEntity
- [ ] PersistenceController set up and injected into app
- [ ] LocalDataManager implements all CRUD operations
- [ ] SyncManager queues and syncs unsynced messages
- [ ] NetworkMonitor detects online/offline state
- [ ] Model extensions convert between Swift models and Core Data entities
- [ ] Messages persist through app restarts (tested)
- [ ] Offline messages queue and sync when online (tested)
- [ ] All unit tests pass (16 tests)
- [ ] All integration tests pass (3 scenarios)
- [ ] Performance targets met (<2s for 1000 message insert)
- [ ] No memory leaks (verified with Instruments)
- [ ] Documentation complete (inline comments + this doc)

### Performance Targets

- ✅ Message insert: <2ms average
- ✅ Message query: <500ms for 1000 messages
- ✅ Conversation list query: <100ms
- ✅ Sync 100 messages: <5 seconds
- ✅ Memory usage: <50MB for 10k messages

### Quality Gates

- ✅ Zero Core Data crashes
- ✅ Zero data loss in stress testing
- ✅ Handles 1000+ messages per conversation
- ✅ Works offline completely (read + compose)
- ✅ Syncs automatically when online
- ✅ No console errors or warnings

---

## Risk Assessment

### Risk 1: Core Data Learning Curve
**Likelihood:** MEDIUM  
**Impact:** MEDIUM  
**Issue:** Team may not be familiar with Core Data  
**Mitigation:** Follow Apple's documentation closely, use code examples from this doc  
**Status:** 🟡 Documented

### Risk 2: Sync Conflicts
**Likelihood:** HIGH  
**Impact:** HIGH  
**Issue:** Local and server data may conflict  
**Mitigation:** Server timestamp always wins (last-write-wins), client updates local  
**Status:** 🟢 Strategy defined

### Risk 3: Performance Degradation
**Likelihood:** MEDIUM  
**Impact:** HIGH  
**Issue:** Large message history may slow queries  
**Mitigation:** Add indexes on `conversationId` and `isSynced`, paginate queries  
**Status:** 🟢 Mitigated

### Risk 4: Storage Limits
**Likelihood:** LOW  
**Impact:** MEDIUM  
**Issue:** Device may run out of storage  
**Mitigation:** Implement message pruning (keep last 1000 per conversation), compress images  
**Status:** 🟢 Planned for future PR

### Risk 5: Migration Complexity
**Likelihood:** LOW  
**Impact:** MEDIUM  
**Issue:** Future schema changes require migration  
**Mitigation:** Use Core Data lightweight migration, version models properly  
**Status:** 🟢 Foundation in place

**Overall Risk:** MEDIUM - Manageable with careful implementation

---

## Open Questions

1. **Message Retention Policy:**
   - Question: How long should we keep messages locally?
   - Option A: Keep all messages forever
   - Option B: Keep last 1000 per conversation
   - Option C: Keep last 30 days
   - Decision needed by: PR #6 implementation
   - **Recommendation:** Option A for MVP (keep all), add pruning in future PR

2. **Sync Trigger:**
   - Question: When should we trigger sync?
   - Option A: Only on network state change (online)
   - Option B: Also on app foreground
   - Option C: Also periodically (every 5 minutes)
   - Decision needed by: PR #6 implementation
   - **Recommendation:** Option B (network change + foreground)

3. **Conflict Resolution:**
   - Question: What if local message edited while offline, then conflicts with server?
   - Option A: Server always wins
   - Option B: Client always wins
   - Option C: Merge with timestamp
   - Decision needed by: PR #6 implementation
   - **Recommendation:** Option A (server wins, simpler for MVP)

---

## Timeline

**Total Estimate:** 2-3 hours

| Phase | Task | Time | Status |
|-------|------|------|--------|
| 1 | Core Data Setup | 45-60 min | ⏳ |
| 2 | Local Data Manager | 60-75 min | ⏳ |
| 3 | Sync Manager | 45-60 min | ⏳ |
| 4 | Model Conversion | 15-20 min | ⏳ |
| 5 | Testing & Debug | 15-30 min | ⏳ |

**Dependencies:**
- Requires PR #4 (Core Models) complete
- Blocks PR #7 (Chat List View - needs local data)
- Blocks PR #10 (Real-time messaging - needs optimistic UI with local storage)

---

## Dependencies

### Requires:
- [x] PR #4 complete (Message, Conversation models)
- [ ] Firebase SDK installed (from PR #1)
- [ ] Xcode 15+ (Core Data support)

### Blocks:
- PR #7 (Chat List View - needs LocalDataManager to query conversations)
- PR #10 (Real-Time Messaging - needs optimistic UI with local storage)
- PR #15 (Offline Support - builds on this foundation)

### Related:
- PR #5 (Chat Service - will integrate with SyncManager)
- PR #15 (Offline Support - extends NetworkMonitor)

---

## References

- **Core Data Documentation:** https://developer.apple.com/documentation/coredata
- **Core Data Programming Guide:** https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/CoreData/
- **Using Core Data with SwiftUI:** https://developer.apple.com/tutorials/app-dev-training/persisting-data
- **Similar Implementation:** WhatsApp message persistence (conceptually)

---

## Notes for Implementation

### Pre-Implementation Checklist
- [ ] Read this document thoroughly (45 minutes)
- [ ] Review Core Data basics if unfamiliar
- [ ] Have PR #4 models available for reference
- [ ] Create feature branch: `feature/local-persistence`

### During Implementation
- Create Core Data model visually in Xcode (easier than code)
- Use Xcode's codegen for entity classes (Class Definition)
- Test each component individually before integration
- Use in-memory store for unit tests (faster)
- Profile with Instruments to verify no memory leaks

### Post-Implementation
- Test with 1000+ messages
- Verify messages persist through force quit
- Test offline queue thoroughly
- Update memory bank
- Write complete summary

---

**This PR builds the foundation for offline-first messaging. Everything after this depends on reliable local persistence.**

