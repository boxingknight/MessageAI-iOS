# PR#6: Local Persistence with SwiftData - Implementation Checklist

**Use this as your daily todo list.** Check off items as you complete them.

**Total Estimated Time:** 2-3 hours

---

## Pre-Implementation Setup (10 minutes)

- [ ] Read main planning document `PR06_LOCAL_PERSISTENCE_SWIFTDATA.md` (~45 min)
- [ ] Verify PR #4 is complete (Message, Conversation models exist)
- [ ] Git branch created
  ```bash
  git checkout main
  git pull
  git checkout -b feature/local-persistence
  ```
- [ ] Open Xcode project
- [ ] Current branch confirmed: `feature/local-persistence`

**Prerequisites Verified:**
- [ ] PR #4 complete (`Models/Message.swift` and `Models/Conversation.swift` exist)
- [ ] Firebase SDK installed (from PR #1)
- [ ] Xcode 15+ running
- [ ] iOS Simulator or physical device available for testing

---

## Phase 1: Core Data Setup (45-60 minutes)

### 1.1: Create Core Data Model File (15 minutes)

#### Create Data Model
- [ ] In Xcode, select `messAI` folder
- [ ] File > New > File...
- [ ] Choose "Data Model" template
- [ ] Name: `MessageAI.xcdatamodeld`
- [ ] Location: `messAI/Persistence/`
- [ ] Add to target: `messAI`
- [ ] Create folder if needed

#### Define MessageEntity
- [ ] Click `MessageAI.xcdatamodeld` to open visual editor
- [ ] Click "Add Entity" button
- [ ] Rename "Entity" to "MessageEntity"
- [ ] Add attributes (click "+" under Attributes):
  - [ ] `id` - String, not optional
  - [ ] `conversationId` - String, not optional
  - [ ] `senderId` - String, not optional
  - [ ] `text` - String, not optional
  - [ ] `imageURL` - String, optional
  - [ ] `sentAt` - Date, not optional
  - [ ] `deliveredAt` - Date, optional
  - [ ] `readAt` - Date, optional
  - [ ] `status` - String, not optional
  - [ ] `isSynced` - Boolean, not optional, default: NO
  - [ ] `syncAttempts` - Integer 16, not optional, default: 0
  - [ ] `lastSyncError` - String, optional
  - [ ] `needsSync` - Boolean, not optional, default: NO

#### Define ConversationEntity
- [ ] Add another entity
- [ ] Rename to "ConversationEntity"
- [ ] Add attributes:
  - [ ] `id` - String, not optional
  - [ ] `participantIds` - Transformable, not optional
  - [ ] `isGroup` - Boolean, not optional, default: NO
  - [ ] `groupName` - String, optional
  - [ ] `lastMessage` - String, not optional
  - [ ] `lastMessageAt` - Date, not optional
  - [ ] `createdBy` - String, not optional
  - [ ] `createdAt` - Date, not optional
  - [ ] `unreadCount` - Integer 16, not optional, default: 0

#### Set Up Relationship
- [ ] Select ConversationEntity
- [ ] Add relationship (click "+" under Relationships)
  - [ ] Name: `messages`
  - [ ] Destination: `MessageEntity`
  - [ ] Type: To Many
  - [ ] Delete Rule: Cascade
  - [ ] Inverse: (will set next)
- [ ] Select MessageEntity
- [ ] Add relationship:
  - [ ] Name: `conversation`
  - [ ] Destination: `ConversationEntity`
  - [ ] Type: To One
  - [ ] Delete Rule: Nullify
  - [ ] Inverse: `messages`

#### Add Indexes for Performance
- [ ] Select MessageEntity
- [ ] Click on "Indexes" tab
- [ ] Add indexes:
  - [ ] Index on `conversationId` (for fast conversation queries)
  - [ ] Index on `isSynced` (for sync queries)
  - [ ] Compound index on `conversationId, sentAt` (for sorted message queries)

- [ ] Select ConversationEntity
- [ ] Add index:
  - [ ] Index on `lastMessageAt` (for chat list sorting)

**Checkpoint:** Core Data model file created and configured ✓

**Commit:** `[PR #6] Create Core Data model with MessageEntity and ConversationEntity`

---

### 1.2: Configure Entity Codegen (10 minutes)

#### Set Codegen to Manual/None
- [ ] Select MessageEntity
- [ ] Inspector pane (right side) > Data Model Inspector
- [ ] Codegen: Change from "Class Definition" to "Manual/None"
- [ ] Select ConversationEntity
- [ ] Codegen: Change to "Manual/None"

*Why Manual: We want custom logic in entity classes, so we'll create them ourselves*

#### Create Entity Class Files
- [ ] File > New > File...
- [ ] Choose "Swift File"
- [ ] Name: `MessageEntity+CoreDataClass.swift`
- [ ] Location: `messAI/Persistence/`
- [ ] Add to target: `messAI`
- [ ] Create

- [ ] Add imports and class definition:
  ```swift
  import Foundation
  import CoreData
  
  @objc(MessageEntity)
  public class MessageEntity: NSManagedObject {
      // Convenience initializer
      convenience init(context: NSManagedObjectContext, from message: Message) {
          self.init(context: context)
          self.id = message.id
          self.conversationId = message.conversationId
          self.senderId = message.senderId
          self.text = message.text
          self.imageURL = message.imageURL
          self.sentAt = message.sentAt
          self.deliveredAt = message.deliveredAt
          self.readAt = message.readAt
          self.status = message.status.rawValue
          self.isSynced = false
          self.syncAttempts = 0
          self.needsSync = true
      }
      
      // Convert to Swift model
      func toMessage() -> Message {
          Message(
              id: self.id,
              conversationId: self.conversationId,
              senderId: self.senderId,
              text: self.text,
              imageURL: self.imageURL,
              sentAt: self.sentAt,
              deliveredAt: self.deliveredAt,
              readAt: self.readAt,
              status: MessageStatus(rawValue: self.status) ?? .sending
          )
      }
  }
  ```

- [ ] Create `MessageEntity+CoreDataProperties.swift`
  ```swift
  import Foundation
  import CoreData
  
  extension MessageEntity {
      @nonobjc public class func fetchRequest() -> NSFetchRequest<MessageEntity> {
          return NSFetchRequest<MessageEntity>(entityName: "MessageEntity")
      }
      
      @NSManaged public var id: String
      @NSManaged public var conversationId: String
      @NSManaged public var senderId: String
      @NSManaged public var text: String
      @NSManaged public var imageURL: String?
      @NSManaged public var sentAt: Date
      @NSManaged public var deliveredAt: Date?
      @NSManaged public var readAt: Date?
      @NSManaged public var status: String
      @NSManaged public var isSynced: Bool
      @NSManaged public var syncAttempts: Int16
      @NSManaged public var lastSyncError: String?
      @NSManaged public var needsSync: Bool
      @NSManaged public var conversation: ConversationEntity?
  }
  
  extension MessageEntity : Identifiable {
  }
  ```

#### Create ConversationEntity Files
- [ ] Create `ConversationEntity+CoreDataClass.swift`
  ```swift
  import Foundation
  import CoreData
  
  @objc(ConversationEntity)
  public class ConversationEntity: NSManagedObject {
      convenience init(context: NSManagedObjectContext, from conversation: Conversation) {
          self.init(context: context)
          self.id = conversation.id
          self.participantIds = conversation.participantIds
          self.isGroup = conversation.isGroup
          self.groupName = conversation.groupName
          self.lastMessage = conversation.lastMessage
          self.lastMessageAt = conversation.lastMessageAt
          self.createdBy = conversation.createdBy
          self.createdAt = conversation.createdAt
          self.unreadCount = 0
      }
      
      func toConversation() -> Conversation {
          Conversation(
              id: self.id,
              participantIds: self.participantIds,
              isGroup: self.isGroup,
              groupName: self.groupName,
              lastMessage: self.lastMessage,
              lastMessageAt: self.lastMessageAt,
              createdBy: self.createdBy,
              createdAt: self.createdAt
          )
      }
  }
  ```

- [ ] Create `ConversationEntity+CoreDataProperties.swift`
  ```swift
  import Foundation
  import CoreData
  
  extension ConversationEntity {
      @nonobjc public class func fetchRequest() -> NSFetchRequest<ConversationEntity> {
          return NSFetchRequest<ConversationEntity>(entityName: "ConversationEntity")
      }
      
      @NSManaged public var id: String
      @NSManaged public var participantIds: [String]
      @NSManaged public var isGroup: Bool
      @NSManaged public var groupName: String?
      @NSManaged public var lastMessage: String
      @NSManaged public var lastMessageAt: Date
      @NSManaged public var createdBy: String
      @NSManaged public var createdAt: Date
      @NSManaged public var unreadCount: Int16
      @NSManaged public var messages: NSSet?
  }
  
  // MARK: Generated accessors for messages
  extension ConversationEntity {
      @objc(addMessagesObject:)
      @NSManaged public func addToMessages(_ value: MessageEntity)
      
      @objc(removeMessagesObject:)
      @NSManaged public func removeFromMessages(_ value: MessageEntity)
      
      @objc(addMessages:)
      @NSManaged public func addToMessages(_ values: NSSet)
      
      @objc(removeMessages:)
      @NSManaged public func removeFromMessages(_ values: NSSet)
  }
  
  extension ConversationEntity : Identifiable {
  }
  ```

**Checkpoint:** Entity classes created with convenience methods ✓

**Commit:** `[PR #6] Add Core Data entity classes with model conversion`

---

### 1.3: Create PersistenceController (20 minutes)

- [ ] File > New > File... > Swift File
- [ ] Name: `PersistenceController.swift`
- [ ] Location: `messAI/Persistence/`

- [ ] Implement PersistenceController:
  ```swift
  import CoreData
  
  class PersistenceController {
      static let shared = PersistenceController()
      
      // For SwiftUI previews and testing
      static var preview: PersistenceController = {
          let controller = PersistenceController(inMemory: true)
          let context = controller.container.viewContext
          
          // Add sample data for previews
          let conversation = ConversationEntity(context: context)
          conversation.id = "preview-conversation"
          conversation.participantIds = ["user1", "user2"]
          conversation.isGroup = false
          conversation.lastMessage = "Hello!"
          conversation.lastMessageAt = Date()
          conversation.createdBy = "user1"
          conversation.createdAt = Date()
          conversation.unreadCount = 0
          
          for i in 0..<10 {
              let message = MessageEntity(context: context)
              message.id = UUID().uuidString
              message.text = "Sample message \(i)"
              message.conversationId = "preview-conversation"
              message.senderId = i % 2 == 0 ? "user1" : "user2"
              message.sentAt = Date().addingTimeInterval(TimeInterval(-600 * (10 - i)))
              message.status = "sent"
              message.isSynced = true
              message.syncAttempts = 0
              message.needsSync = false
              message.conversation = conversation
          }
          
          do {
              try context.save()
          } catch {
              print("❌ Preview data creation failed: \(error)")
          }
          
          return controller
      }()
      
      let container: NSPersistentContainer
      
      init(inMemory: Bool = false) {
          container = NSPersistentContainer(name: "MessageAI")
          
          if inMemory {
              // Use in-memory store for testing
              container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
          }
          
          container.loadPersistentStores { description, error in
              if let error = error {
                  // In production, handle this more gracefully
                  fatalError("❌ Core Data failed to load: \(error.localizedDescription)")
              }
              print("✅ Core Data loaded: \(description.url?.absoluteString ?? "unknown")")
          }
          
          // Configure merge policy
          // Property-level merge: newer values win for individual properties
          container.viewContext.automaticallyMergesChangesFromParent = true
          container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
      }
      
      // MARK: - Save
      
      func save() {
          let context = container.viewContext
          
          if context.hasChanges {
              do {
                  try context.save()
                  print("✅ Context saved successfully")
              } catch {
                  print("❌ Failed to save context: \(error)")
              }
          }
      }
      
      // MARK: - Delete All Data (for testing/logout)
      
      func deleteAllData() {
          let context = container.viewContext
          
          // Delete all messages
          let messageFetch = NSFetchRequest<NSFetchRequestResult>(entityName: "MessageEntity")
          let messageDelete = NSBatchDeleteRequest(fetchRequest: messageFetch)
          
          // Delete all conversations
          let conversationFetch = NSFetchRequest<NSFetchRequestResult>(entityName: "ConversationEntity")
          let conversationDelete = NSBatchDeleteRequest(fetchRequest: conversationFetch)
          
          do {
              try context.execute(messageDelete)
              try context.execute(conversationDelete)
              try context.save()
              print("✅ All data deleted")
          } catch {
              print("❌ Failed to delete data: \(error)")
          }
      }
  }
  ```

**Test PersistenceController:**
- [ ] Build project (Cmd+B)
- [ ] No compiler errors
- [ ] Run app briefly (Cmd+R)
- [ ] Check console for "✅ Core Data loaded"

**Checkpoint:** PersistenceController working ✓

**Commit:** `[PR #6] Add PersistenceController with Core Data stack`

---

## Phase 2: Local Data Manager (60-75 minutes)

### 2.1: Create LocalDataManager File (10 minutes)

- [ ] File > New > File... > Swift File
- [ ] Name: `LocalDataManager.swift`
- [ ] Location: `messAI/Persistence/`

- [ ] Add initial structure:
  ```swift
  import CoreData
  
  class LocalDataManager {
      private let context: NSManagedObjectContext
      
      init(context: NSManagedObjectContext = PersistenceController.shared.container.viewContext) {
          self.context = context
      }
      
      // MARK: - Message Operations
      // (Will implement next)
      
      // MARK: - Conversation Operations
      // (Will implement after messages)
      
      // MARK: - Sync Operations
      // (Will implement last)
  }
  
  // MARK: - Errors
  
  enum PersistenceError: LocalizedError {
      case messageNotFound
      case conversationNotFound
      case saveFailed(Error)
      case fetchFailed(Error)
      case deleteFailedError)
      
      var errorDescription: String? {
          switch self {
          case .messageNotFound:
              return "Message not found in local storage"
          case .conversationNotFound:
              return "Conversation not found in local storage"
          case .saveFailed(let error):
              return "Failed to save: \(error.localizedDescription)"
          case .fetchFailed(let error):
              return "Failed to fetch: \(error.localizedDescription)"
          case .deleteFailed(let error):
              return "Failed to delete: \(error.localizedDescription)"
          }
      }
  }
  ```

**Checkpoint:** LocalDataManager file structure created ✓

---

### 2.2: Implement Message Operations (25 minutes)

#### Save Message
- [ ] Add `saveMessage(_:isSynced:)` method:
  ```swift
  func saveMessage(_ message: Message, isSynced: Bool = true) throws {
      // Check if message already exists
      let fetchRequest: NSFetchRequest<MessageEntity> = MessageEntity.fetchRequest()
      fetchRequest.predicate = NSPredicate(format: "id == %@", message.id)
      
      do {
          let results = try context.fetch(fetchRequest)
          let entity: MessageEntity
          
          if let existing = results.first {
              // Update existing message
              entity = existing
          } else {
              // Create new message
              entity = MessageEntity(context: context, from: message)
          }
          
          // Update fields (in case of update)
          entity.conversationId = message.conversationId
          entity.senderId = message.senderId
          entity.text = message.text
          entity.imageURL = message.imageURL
          entity.sentAt = message.sentAt
          entity.deliveredAt = message.deliveredAt
          entity.readAt = message.readAt
          entity.status = message.status.rawValue
          entity.isSynced = isSynced
          entity.needsSync = !isSynced
          
          // Save context
          try context.save()
          
      } catch {
          throw PersistenceError.saveFailed(error)
      }
  }
  ```

#### Fetch Messages
- [ ] Add `fetchMessages(conversationId:)` method:
  ```swift
  func fetchMessages(conversationId: String) throws -> [Message] {
      let fetchRequest: NSFetchRequest<MessageEntity> = MessageEntity.fetchRequest()
      fetchRequest.predicate = NSPredicate(format: "conversationId == %@", conversationId)
      fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \MessageEntity.sentAt, ascending: true)]
      
      do {
          let entities = try context.fetch(fetchRequest)
          return entities.map { $0.toMessage() }
      } catch {
          throw PersistenceError.fetchFailed(error)
      }
  }
  ```

#### Update Message Status
- [ ] Add `updateMessageStatus(id:status:)` method:
  ```swift
  func updateMessageStatus(id: String, status: MessageStatus) throws {
      let fetchRequest: NSFetchRequest<MessageEntity> = MessageEntity.fetchRequest()
      fetchRequest.predicate = NSPredicate(format: "id == %@", id)
      
      do {
          guard let entity = try context.fetch(fetchRequest).first else {
              throw PersistenceError.messageNotFound
          }
          
          entity.status = status.rawValue
          
          // Update delivered/read timestamps
          switch status {
          case .delivered:
              entity.deliveredAt = Date()
          case .read:
              entity.readAt = Date()
          default:
              break
          }
          
          try context.save()
          
      } catch let error as PersistenceError {
          throw error
      } catch {
          throw PersistenceError.saveFailed(error)
      }
  }
  ```

#### Delete Message
- [ ] Add `deleteMessage(id:)` method:
  ```swift
  func deleteMessage(id: String) throws {
      let fetchRequest: NSFetchRequest<MessageEntity> = MessageEntity.fetchRequest()
      fetchRequest.predicate = NSPredicate(format: "id == %@", id)
      
      do {
          guard let entity = try context.fetch(fetchRequest).first else {
              throw PersistenceError.messageNotFound
          }
          
          context.delete(entity)
          try context.save()
          
      } catch let error as PersistenceError {
          throw error
      } catch {
          throw PersistenceError.deleteFailed(error)
      }
  }
  ```

**Checkpoint:** Message CRUD operations complete ✓

**Commit:** `[PR #6] Implement message CRUD operations in LocalDataManager`

---

### 2.3: Implement Conversation Operations (15 minutes)

#### Save Conversation
- [ ] Add `saveConversation(_:)` method:
  ```swift
  func saveConversation(_ conversation: Conversation) throws {
      let fetchRequest: NSFetchRequest<ConversationEntity> = ConversationEntity.fetchRequest()
      fetchRequest.predicate = NSPredicate(format: "id == %@", conversation.id)
      
      do {
          let results = try context.fetch(fetchRequest)
          let entity: ConversationEntity
          
          if let existing = results.first {
              entity = existing
          } else {
              entity = ConversationEntity(context: context, from: conversation)
          }
          
          // Update fields
          entity.participantIds = conversation.participantIds
          entity.isGroup = conversation.isGroup
          entity.groupName = conversation.groupName
          entity.lastMessage = conversation.lastMessage
          entity.lastMessageAt = conversation.lastMessageAt
          entity.createdBy = conversation.createdBy
          entity.createdAt = conversation.createdAt
          
          try context.save()
          
      } catch {
          throw PersistenceError.saveFailed(error)
      }
  }
  ```

#### Fetch Conversations
- [ ] Add `fetchConversations()` method:
  ```swift
  func fetchConversations() throws -> [Conversation] {
      let fetchRequest: NSFetchRequest<ConversationEntity> = ConversationEntity.fetchRequest()
      fetchRequest.sortDescriptors = [
          NSSortDescriptor(keyPath: \ConversationEntity.lastMessageAt, ascending: false)
      ]
      
      do {
          let entities = try context.fetch(fetchRequest)
          return entities.map { $0.toConversation() }
      } catch {
          throw PersistenceError.fetchFailed(error)
      }
  }
  ```

#### Delete Conversation
- [ ] Add `deleteConversation(id:)` method:
  ```swift
  func deleteConversation(id: String) throws {
      let fetchRequest: NSFetchRequest<ConversationEntity> = ConversationEntity.fetchRequest()
      fetchRequest.predicate = NSPredicate(format: "id == %@", id)
      
      do {
          guard let entity = try context.fetch(fetchRequest).first else {
              throw PersistenceError.conversationNotFound
          }
          
          // Messages will cascade delete automatically
          context.delete(entity)
          try context.save()
          
      } catch let error as PersistenceError {
          throw error
      } catch {
          throw PersistenceError.deleteFailed(error)
      }
  }
  ```

**Checkpoint:** Conversation operations complete ✓

**Commit:** `[PR #6] Add conversation CRUD operations to LocalDataManager`

---

### 2.4: Implement Sync Operations (20 minutes)

#### Fetch Unsynced Messages
- [ ] Add `fetchUnsyncedMessages()` method:
  ```swift
  func fetchUnsyncedMessages() throws -> [Message] {
      let fetchRequest: NSFetchRequest<MessageEntity> = MessageEntity.fetchRequest()
      fetchRequest.predicate = NSPredicate(format: "isSynced == NO")
      fetchRequest.sortDescriptors = [
          NSSortDescriptor(keyPath: \MessageEntity.sentAt, ascending: true)
      ]
      
      do {
          let entities = try context.fetch(fetchRequest)
          return entities.map { $0.toMessage() }
      } catch {
          throw PersistenceError.fetchFailed(error)
      }
  }
  ```

#### Mark as Synced
- [ ] Add `markAsSynced(messageId:)` method:
  ```swift
  func markAsSynced(messageId: String) throws {
      let fetchRequest: NSFetchRequest<MessageEntity> = MessageEntity.fetchRequest()
      fetchRequest.predicate = NSPredicate(format: "id == %@", messageId)
      
      do {
          guard let entity = try context.fetch(fetchRequest).first else {
              throw PersistenceError.messageNotFound
          }
          
          entity.isSynced = true
          entity.needsSync = false
          entity.syncAttempts = 0
          entity.lastSyncError = nil
          
          try context.save()
          
      } catch let error as PersistenceError {
          throw error
      } catch {
          throw PersistenceError.saveFailed(error)
      }
  }
  ```

#### Increment Sync Attempts
- [ ] Add `incrementSyncAttempts(messageId:error:)` method:
  ```swift
  func incrementSyncAttempts(messageId: String, error: String? = nil) throws {
      let fetchRequest: NSFetchRequest<MessageEntity> = MessageEntity.fetchRequest()
      fetchRequest.predicate = NSPredicate(format: "id == %@", messageId)
      
      do {
          guard let entity = try context.fetch(fetchRequest).first else {
              throw PersistenceError.messageNotFound
          }
          
          entity.syncAttempts += 1
          entity.lastSyncError = error
          
          // If max attempts reached, stop trying
          if entity.syncAttempts >= 5 {
              entity.needsSync = false
              print("⚠️ Message \(messageId) failed after 5 attempts")
          }
          
          try context.save()
          
      } catch let error as PersistenceError {
          throw error
      } catch {
          throw PersistenceError.saveFailed(error)
      }
  }
  ```

#### Batch Save Messages
- [ ] Add `batchSaveMessages(_:)` method:
  ```swift
  func batchSaveMessages(_ messages: [Message]) throws {
      do {
          for message in messages {
              try saveMessage(message, isSynced: true)
          }
          print("✅ Batch saved \(messages.count) messages")
      } catch {
          throw PersistenceError.saveFailed(error)
      }
  }
  ```

**Checkpoint:** Sync operations complete ✓

**Commit:** `[PR #6] Add sync operations to LocalDataManager`

---

## Phase 3: Sync Manager (45-60 minutes)

### 3.1: Create SyncManager File (10 minutes)

- [ ] File > New > File... > Swift File
- [ ] Name: `SyncManager.swift`
- [ ] Location: `messAI/Persistence/`

- [ ] Add initial structure:
  ```swift
  import Foundation
  import Combine
  
  class SyncManager: ObservableObject {
      @Published var isSyncing: Bool = false
      @Published var pendingMessageCount: Int = 0
      @Published var lastSyncError: String?
      
      private let localDataManager: LocalDataManager
      // Will add chatService in next step after PR #5
      private let networkMonitor: NetworkMonitor
      private var cancellables = Set<AnyCancellable>()
      
      init(
          localDataManager: LocalDataManager,
          networkMonitor: NetworkMonitor = NetworkMonitor.shared
      ) {
          self.localDataManager = localDataManager
          self.networkMonitor = networkMonitor
          
          setupNetworkObserver()
          updatePendingCount()
      }
      
      // MARK: - Network Observation
      // (Implement next)
      
      // MARK: - Sync Operations
      // (Implement after network)
      
      // MARK: - Queue Management
      // (Implement last)
  }
  ```

**Checkpoint:** SyncManager structure created ✓

---

### 3.2: Implement Network Observer (10 minutes)

- [ ] Add `setupNetworkObserver()` method:
  ```swift
  private func setupNetworkObserver() {
      networkMonitor.$isConnected
          .dropFirst() // Ignore initial value
          .sink { [weak self] isConnected in
              if isConnected {
                  print("🟢 Network online - triggering sync")
                  // Will implement sync in next step
                  // self?.syncPendingMessages()
              } else {
                  print("🔴 Network offline - pausing sync")
              }
          }
          .store(in: &cancellables)
  }
  ```

- [ ] Add `updatePendingCount()` method:
  ```swift
  private func updatePendingCount() {
      do {
          let unsynced = try localDataManager.fetchUnsyncedMessages()
          DispatchQueue.main.async {
              self.pendingMessageCount = unsynced.count
          }
      } catch {
          print("❌ Failed to update pending count: \(error)")
      }
  }
  ```

**Checkpoint:** Network observation working ✓

**Commit:** `[PR #6] Add network observation to SyncManager`

---

### 3.3: Implement Sync Operations (15 minutes)

- [ ] Add `queueMessageForSync(_:)` method:
  ```swift
  func queueMessageForSync(_ message: Message) throws {
      do {
          try localDataManager.saveMessage(message, isSynced: false)
          updatePendingCount()
          
          print("📥 Message queued for sync: \(message.id)")
          
          // If online, sync immediately
          if networkMonitor.isConnected {
              Task {
                  await syncPendingMessages()
              }
          }
      } catch {
          throw error
      }
  }
  ```

- [ ] Add `syncPendingMessages()` method (placeholder for now):
  ```swift
  func syncPendingMessages() async {
      guard networkMonitor.isConnected else {
          print("⏸️ Sync skipped: No network connection")
          return
      }
      
      guard !isSyncing else {
          print("⏸️ Sync already in progress")
          return
      }
      
      DispatchQueue.main.async {
          self.isSyncing = true
      }
      
      do {
          let unsyncedMessages = try localDataManager.fetchUnsyncedMessages()
          
          print("🔄 Syncing \(unsyncedMessages.count) pending messages...")
          
          for message in unsyncedMessages {
              // TODO: Integrate with ChatService from PR #5
              // For now, just mark as synced (will replace in PR #5 integration)
              
              // Simulate sync
              try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
              
              try localDataManager.markAsSynced(messageId: message.id)
              print("✅ Synced message: \(message.id)")
          }
          
          updatePendingCount()
          print("✅ Sync complete!")
          
      } catch {
          print("❌ Sync failed: \(error)")
          DispatchQueue.main.async {
              self.lastSyncError = error.localizedDescription
          }
      }
      
      DispatchQueue.main.async {
          self.isSyncing = false
      }
  }
  ```

**Note:** The actual Firebase sync will be integrated in PR #5 when ChatService is available.

**Checkpoint:** Sync operations implemented ✓

**Commit:** `[PR #6] Add sync operations to SyncManager (placeholder for ChatService)`

---

### 3.4: Implement Retry Logic (15 minutes)

- [ ] Add `retryFailedMessages()` method:
  ```swift
  func retryFailedMessages() async {
      do {
          let messages = try localDataManager.fetchUnsyncedMessages()
          let failedMessages = messages.filter { message in
              // Get entity to check sync attempts
              // (This is a simplified check - full implementation needs entity access)
              return true // Will refine in integration
          }
          
          print("🔄 Retrying \(failedMessages.count) failed messages...")
          
          for message in failedMessages {
              // TODO: Implement with ChatService in PR #5
              // For now, increment attempts
              try localDataManager.incrementSyncAttempts(
                  messageId: message.id,
                  error: "Retry pending ChatService integration"
              )
          }
          
      } catch {
          print("❌ Retry failed: \(error)")
      }
  }
  ```

- [ ] Add `clearSyncErrors()` method:
  ```swift
  func clearSyncErrors() {
      DispatchQueue.main.async {
          self.lastSyncError = nil
      }
  }
  ```

**Checkpoint:** Retry logic implemented ✓

**Commit:** `[PR #6] Add retry logic to SyncManager`

---

## Phase 4: Network Monitor (15-20 minutes)

### 4.1: Create NetworkMonitor (15 minutes)

- [ ] File > New > File... > Swift File
- [ ] Name: `NetworkMonitor.swift`
- [ ] Location: `messAI/Utilities/`

- [ ] Implement NetworkMonitor:
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
                  let wasConnected = self?.isConnected ?? true
                  self?.isConnected = path.status == .satisfied
                  
                  // Log connection changes
                  if wasConnected != self?.isConnected {
                      if self?.isConnected == true {
                          print("🟢 Network: Online")
                      } else {
                          print("🔴 Network: Offline")
                      }
                  }
                  
                  // Determine connection type
                  if path.usesInterfaceType(.wifi) {
                      self?.connectionType = .wifi
                      print("📶 Connection: WiFi")
                  } else if path.usesInterfaceType(.cellular) {
                      self?.connectionType = .cellular
                      print("📱 Connection: Cellular")
                  } else if path.usesInterfaceType(.wiredEthernet) {
                      self?.connectionType = .wiredEthernet
                      print("🔌 Connection: Ethernet")
                  } else {
                      self?.connectionType = nil
                  }
              }
          }
          
          monitor.start(queue: queue)
      }
      
      deinit {
          monitor.cancel()
      }
      
      // MARK: - Manual Check
      
      func checkConnection() {
          // Force a check (monitor updates automatically, but this is explicit)
          print("🔍 Checking network connection...")
      }
  }
  ```

**Test NetworkMonitor:**
- [ ] Build project (Cmd+B)
- [ ] Run app (Cmd+R)
- [ ] Check console for "🟢 Network: Online"
- [ ] Enable airplane mode on simulator (Hardware > Network Link)
- [ ] Check console for "🔴 Network: Offline"
- [ ] Disable airplane mode
- [ ] Check console for "🟢 Network: Online"

**Checkpoint:** NetworkMonitor working ✓

**Commit:** `[PR #6] Add NetworkMonitor for connection detection`

---

## Phase 5: App Integration (15 minutes)

### 5.1: Inject PersistenceController into App (10 minutes)

- [ ] Open `messAIApp.swift`
- [ ] Add PersistenceController to environment:
  ```swift
  @main
  struct messAIApp: App {
      @StateObject private var authViewModel = AuthViewModel()
      let persistenceController = PersistenceController.shared
      
      init() {
          FirebaseApp.configure()
      }
      
      var body: some Scene {
          WindowGroup {
              if authViewModel.isAuthenticated {
                  ContentView()
                      .environment(\.managedObjectContext, persistenceController.container.viewContext)
                      .environmentObject(authViewModel)
              } else {
                  AuthenticationView()
                      .environmentObject(authViewModel)
              }
          }
      }
  }
  ```

**Checkpoint:** PersistenceController injected ✓

**Commit:** `[PR #6] Inject PersistenceController into app environment`

---

## Phase 6: Testing (20-30 minutes)

### 6.1: Manual Testing (15 minutes)

#### Test Core Data Setup
- [ ] Run app (Cmd+R)
- [ ] Check console for "✅ Core Data loaded"
- [ ] No crashes on launch

#### Test LocalDataManager
- [ ] In a temporary test view, create LocalDataManager instance
- [ ] Create and save a test message
- [ ] Fetch messages for that conversation
- [ ] Verify message retrieved correctly
- [ ] Delete message
- [ ] Verify deleted

**Simple Test View (temporary):**
- [ ] Create `TestPersistenceView.swift` in Views folder:
  ```swift
  import SwiftUI
  
  struct TestPersistenceView: View {
      @Environment(\.managedObjectContext) private var viewContext
      @State private var testResult = "Not tested yet"
      
      var body: some View {
          VStack(spacing: 20) {
              Text("Persistence Test")
                  .font(.title)
              
              Text(testResult)
                  .padding()
              
              Button("Run Test") {
                  runTest()
              }
              .buttonStyle(.borderedProminent)
          }
          .padding()
      }
      
      func runTest() {
          let manager = LocalDataManager(context: viewContext)
          
          do {
              // Create test message
              let message = Message(
                  id: UUID().uuidString,
                  conversationId: "test-conversation",
                  senderId: "test-user",
                  text: "Test message",
                  sentAt: Date(),
                  status: .sent
              )
              
              // Save
              try manager.saveMessage(message)
              
              // Fetch
              let fetched = try manager.fetchMessages(conversationId: "test-conversation")
              
              if let found = fetched.first(where: { $0.id == message.id }) {
                  testResult = "✅ Success! Saved and retrieved message: \(found.text)"
              } else {
                  testResult = "❌ Message not found after save"
              }
              
          } catch {
              testResult = "❌ Error: \(error.localizedDescription)"
          }
      }
  }
  ```

- [ ] Temporarily show TestPersistenceView in ContentView
- [ ] Run app, tap "Run Test" button
- [ ] Verify "✅ Success!" message

#### Test Persistence Across Restarts
- [ ] Save a test message
- [ ] Force quit app (stop in Xcode)
- [ ] Restart app
- [ ] Fetch messages
- [ ] Verify test message still exists

#### Test NetworkMonitor
- [ ] Run app
- [ ] Check console shows "🟢 Network: Online"
- [ ] Enable airplane mode (Hardware > Network Link Conditioner > 100% Loss)
- [ ] Check console shows "🔴 Network: Offline"
- [ ] Disable airplane mode
- [ ] Check console shows "🟢 Network: Online"

**Checkpoint:** All manual tests passing ✓

---

### 6.2: Performance Testing (5 minutes)

#### Test Large Data Set
- [ ] Create script to insert 1000 test messages
- [ ] Run script
- [ ] Measure time (should be <2 seconds)
- [ ] Fetch all messages
- [ ] Measure time (should be <500ms)

**Test Script (add to TestPersistenceView):**
```swift
func testPerformance() {
    let manager = LocalDataManager(context: viewContext)
    
    let start = Date()
    
    // Insert 1000 messages
    for i in 0..<1000 {
        let message = Message(
            id: UUID().uuidString,
            conversationId: "perf-test",
            senderId: "user-\(i % 10)",
            text: "Performance test message \(i)",
            sentAt: Date(),
            status: .sent
        )
        
        try? manager.saveMessage(message)
    }
    
    let insertTime = Date().timeIntervalSince(start)
    
    // Fetch all
    let fetchStart = Date()
    let messages = try? manager.fetchMessages(conversationId: "perf-test")
    let fetchTime = Date().timeIntervalSince(fetchStart)
    
    testResult = """
    ✅ Performance Test:
    - Inserted 1000 messages in \(String(format: "%.2f", insertTime))s
    - Fetched \(messages?.count ?? 0) messages in \(String(format: "%.3f", fetchTime))s
    """
    
    print(testResult)
}
```

- [ ] Run performance test
- [ ] Verify insert <2s
- [ ] Verify fetch <0.5s

**Checkpoint:** Performance acceptable ✓

---

### 6.3: Cleanup Test Code (5 minutes)

- [ ] Remove or comment out TestPersistenceView
- [ ] Remove temporary test references from ContentView
- [ ] Clean up any console logging if excessive
- [ ] Verify app still compiles and runs

**Checkpoint:** Test code cleaned up ✓

**Commit:** `[PR #6] Add persistence testing and cleanup`

---

## Phase 7: Documentation & Finalization (10 minutes)

### 7.1: Update Documentation (5 minutes)

- [ ] Update `memory-bank/activeContext.md`:
  - Mark PR #6 as complete
  - Update file structure with new persistence files
  - Update lines of code count
  
- [ ] Update `memory-bank/progress.md`:
  - Mark PR #6 tasks complete
  - Update progress percentage
  - Note performance benchmarks

- [ ] Update `PR_PARTY/README.md`:
  - Mark PR #6 as complete
  - Add time taken (actual)
  - Add key learnings

**Checkpoint:** Documentation updated ✓

---

### 7.2: Final Verification (5 minutes)

- [ ] Build project (Cmd+B) - No errors
- [ ] Run on simulator - No crashes
- [ ] Check console - No excessive errors
- [ ] All new files added to git:
  ```bash
  git status
  # Should show all new Persistence/ files
  ```

**Final Checklist:**
- [ ] Core Data model created and configured
- [ ] Entity classes with conversion methods
- [ ] PersistenceController working
- [ ] LocalDataManager with full CRUD
- [ ] SyncManager with network awareness
- [ ] NetworkMonitor detecting connection
- [ ] App integration complete
- [ ] Tests passing
- [ ] Performance acceptable
- [ ] Documentation updated

**Checkpoint:** PR #6 complete! ✓

---

## Final Commit & Merge

- [ ] Stage all changes:
  ```bash
  git add .
  ```

- [ ] Final commit:
  ```bash
  git commit -m "[PR #6] Complete local persistence with Core Data
  
  - Created Core Data model (MessageEntity, ConversationEntity)
  - Implemented PersistenceController with in-memory preview support
  - Built LocalDataManager with full CRUD operations
  - Added SyncManager for offline message queueing
  - Implemented NetworkMonitor for connection detection
  - Integrated into app with environment injection
  - All tests passing, performance targets met
  
  Files: ~1,120 lines of code
  Time: [ACTUAL TIME] hours"
  ```

- [ ] Push to GitHub:
  ```bash
  git push origin feature/local-persistence
  ```

- [ ] Merge to main:
  ```bash
  git checkout main
  git merge feature/local-persistence
  git push origin main
  ```

- [ ] Update PR_PARTY with complete summary

---

## Post-Completion

### Write Complete Summary
- [ ] Create `PR06_COMPLETE_SUMMARY.md`
- [ ] Document what was built
- [ ] Record actual time vs estimated
- [ ] Note any bugs encountered
- [ ] Extract lessons learned
- [ ] Update PR_PARTY README

### Next Steps
- [ ] PR #7: Chat List View (needs LocalDataManager)
- [ ] Later: Integrate SyncManager with ChatService (PR #5)

---

## Troubleshooting

### Issue: Core Data model not found
**Solution:** Ensure `.xcdatamodeld` file is added to app target

### Issue: Entity classes not found
**Solution:** Check Codegen setting is "Manual/None"

### Issue: Context save fails
**Solution:** Check console for specific error, verify all required fields set

### Issue: NetworkMonitor not detecting changes
**Solution:** Run on physical device or use Network Link Conditioner in simulator

---

**Total Estimated Time:** 2-3 hours  
**Total Files Created:** 9 files (~1,120 lines)  
**Integration Points:** messAIApp.swift, future ChatViewModel

---

*This checklist provides step-by-step implementation for offline-first persistence.*

