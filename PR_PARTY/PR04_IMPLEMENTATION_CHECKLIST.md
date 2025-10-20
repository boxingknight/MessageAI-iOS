# PR #4: Implementation Checklist - Core Models & Data Structure

**Use this as your daily todo list.** Check off items as you complete them.

---

## Pre-Implementation Setup (5 minutes)

- [ ] Read main planning document (`PR04_CORE_MODELS.md`) - 30 min
- [ ] Review User model from PR #2 for consistency - 5 min
- [ ] Verify FirebaseFirestore is imported in Xcode project
- [ ] Git branch created
  ```bash
  git checkout main
  git pull origin main
  git checkout -b feature/core-models
  ```
- [ ] Xcode project open and building
- [ ] Ready to create new files in Models/ folder

**Checkpoint:** Branch created, project building ✓

---

## Phase 1: MessageStatus Enum (15 minutes)

### 1.1: Create MessageStatus.swift File (5 minutes)

- [ ] In Xcode, right-click `Models/` folder
- [ ] Select `New File → Swift File`
- [ ] Name it `MessageStatus.swift`
- [ ] Add to target: `messAI`
- [ ] File created in correct location

### 1.2: Define Enum with Raw Values (5 minutes)

- [ ] Add imports
  ```swift
  import SwiftUI
  ```

- [ ] Define enum
  ```swift
  enum MessageStatus: String, Codable, CaseIterable {
      case sending = "sending"
      case sent = "sent"
      case delivered = "delivered"
      case read = "read"
      case failed = "failed"
  }
  ```

- [ ] Build project (⌘B)
- [ ] No errors ✓

### 1.3: Add Computed Properties (5 minutes)

- [ ] Add displayText property
  ```swift
  var displayText: String {
      switch self {
      case .sending: return "Sending..."
      case .sent: return "Sent"
      case .delivered: return "Delivered"
      case .read: return "Read"
      case .failed: return "Failed"
      }
  }
  ```

- [ ] Add iconName property
  ```swift
  var iconName: String {
      switch self {
      case .sending: return "clock"
      case .sent: return "checkmark"
      case .delivered: return "checkmark.circle"
      case .read: return "checkmark.circle.fill"
      case .failed: return "exclamationmark.circle"
      }
  }
  ```

- [ ] Add color property
  ```swift
  var color: Color {
      switch self {
      case .sending: return .gray
      case .sent: return .gray
      case .delivered: return .blue
      case .read: return .blue
      case .failed: return .red
      }
  }
  ```

- [ ] Build project (⌘B)
- [ ] No errors ✓

### 1.4: Test MessageStatus (Quick verification)

- [ ] Can reference all cases: `MessageStatus.sending`, etc.
- [ ] Can access properties: `MessageStatus.read.displayText`
- [ ] Autocomplete works in Xcode

**Checkpoint:** MessageStatus enum complete (~40 lines) ✓

**Commit:**
```bash
git add messAI/Models/MessageStatus.swift
git commit -m "feat(models): add MessageStatus enum with display properties"
```

---

## Phase 2: Message Model (30 minutes)

### 2.1: Create Message.swift File (3 minutes)

- [ ] Create new Swift file: `Message.swift` in `Models/`
- [ ] Add to messAI target
- [ ] File created ✓

### 2.2: Add Imports (2 minutes)

- [ ] Add required imports
  ```swift
  import Foundation
  import FirebaseFirestore
  ```

- [ ] Build to verify imports work
- [ ] No errors ✓

### 2.3: Define Message Struct (5 minutes)

- [ ] Define struct with conformances
  ```swift
  struct Message: Identifiable, Codable, Equatable, Hashable {
      // Will add properties next
  }
  ```

- [ ] Add all properties
  ```swift
  // Identity
  let id: String
  let conversationId: String
  let senderId: String
  
  // Content
  let text: String
  let imageURL: String?
  
  // Timestamps
  let sentAt: Date
  var deliveredAt: Date?
  var readAt: Date?
  
  // State
  var status: MessageStatus
  
  // Metadata (cached for convenience)
  let senderName: String?
  let senderPhotoURL: String?
  ```

- [ ] Build (⌘B)
- [ ] No errors ✓

### 2.4: Add Default Initializer (5 minutes)

- [ ] Add full initializer
  ```swift
  init(
      id: String,
      conversationId: String,
      senderId: String,
      text: String,
      imageURL: String? = nil,
      sentAt: Date = Date(),
      deliveredAt: Date? = nil,
      readAt: Date? = nil,
      status: MessageStatus = .sending,
      senderName: String? = nil,
      senderPhotoURL: String? = nil
  ) {
      self.id = id
      self.conversationId = conversationId
      self.senderId = senderId
      self.text = text
      self.imageURL = imageURL
      self.sentAt = sentAt
      self.deliveredAt = deliveredAt
      self.readAt = readAt
      self.status = status
      self.senderName = senderName
      self.senderPhotoURL = senderPhotoURL
  }
  ```

- [ ] Build (⌘B)
- [ ] Can create instance: `Message(id: "1", conversationId: "conv1", senderId: "user1", text: "Hello")`

### 2.5: Add Convenience Initializer (3 minutes)

- [ ] Add convenience init for new messages
  ```swift
  init(
      conversationId: String,
      senderId: String,
      text: String,
      senderName: String? = nil,
      senderPhotoURL: String? = nil
  ) {
      self.init(
          id: UUID().uuidString,
          conversationId: conversationId,
          senderId: senderId,
          text: text,
          imageURL: nil,
          sentAt: Date(),
          deliveredAt: nil,
          readAt: nil,
          status: .sending,
          senderName: senderName,
          senderPhotoURL: senderPhotoURL
      )
  }
  ```

- [ ] Test: Can create with just 3 params
- [ ] UUID generates automatically

### 2.6: Add Computed Properties Extension (5 minutes)

- [ ] Add extension below struct
  ```swift
  extension Message {
      var isFromCurrentUser: Bool {
          // Will need Auth.auth().currentUser?.uid
          // For now, just structure
          senderId == (Auth.auth().currentUser?.uid ?? "")
      }
      
      var isDelivered: Bool {
          status == .delivered || status == .read
      }
      
      var isRead: Bool {
          status == .read
      }
      
      var timeAgo: String {
          let formatter = RelativeDateTimeFormatter()
          formatter.unitsStyle = .short
          return formatter.localizedString(for: sentAt, relativeTo: Date())
      }
  }
  ```

- [ ] Add import for Auth: `import FirebaseAuth`
- [ ] Build (⌘B)
- [ ] No errors ✓

### 2.7: Add Firestore Conversion - toDictionary (5 minutes)

- [ ] Add extension for Firestore
  ```swift
  extension Message {
      func toDictionary() -> [String: Any] {
          var dict: [String: Any] = [
              "id": id,
              "conversationId": conversationId,
              "senderId": senderId,
              "text": text,
              "sentAt": Timestamp(date: sentAt),
              "status": status.rawValue
          ]
          
          // Optional fields
          if let imageURL = imageURL {
              dict["imageURL"] = imageURL
          }
          if let deliveredAt = deliveredAt {
              dict["deliveredAt"] = Timestamp(date: deliveredAt)
          }
          if let readAt = readAt {
              dict["readAt"] = Timestamp(date: readAt)
          }
          if let senderName = senderName {
              dict["senderName"] = senderName
          }
          if let senderPhotoURL = senderPhotoURL {
              dict["senderPhotoURL"] = senderPhotoURL
          }
          
          return dict
      }
  }
  ```

- [ ] Build (⌘B)
- [ ] Test: Can call `message.toDictionary()`

### 2.8: Add Firestore Conversion - init from Dictionary (5 minutes)

- [ ] Add init in same extension
  ```swift
  init?(dictionary: [String: Any]) {
      guard
          let id = dictionary["id"] as? String,
          let conversationId = dictionary["conversationId"] as? String,
          let senderId = dictionary["senderId"] as? String,
          let text = dictionary["text"] as? String,
          let sentAtTimestamp = dictionary["sentAt"] as? Timestamp,
          let statusString = dictionary["status"] as? String,
          let status = MessageStatus(rawValue: statusString)
      else {
          return nil
      }
      
      self.id = id
      self.conversationId = conversationId
      self.senderId = senderId
      self.text = text
      self.sentAt = sentAtTimestamp.dateValue()
      self.status = status
      
      // Optional fields
      self.imageURL = dictionary["imageURL"] as? String
      self.deliveredAt = (dictionary["deliveredAt"] as? Timestamp)?.dateValue()
      self.readAt = (dictionary["readAt"] as? Timestamp)?.dateValue()
      self.senderName = dictionary["senderName"] as? String
      self.senderPhotoURL = dictionary["senderPhotoURL"] as? String
  }
  ```

- [ ] Build (⌘B)
- [ ] No errors ✓

**Checkpoint:** Message model complete (~200 lines) ✓

**Commit:**
```bash
git add messAI/Models/Message.swift
git commit -m "feat(models): add Message model with Firestore conversion"
```

---

## Phase 3: Conversation Model (30 minutes)

### 3.1: Create Conversation.swift File (3 minutes)

- [ ] Create new Swift file: `Conversation.swift` in `Models/`
- [ ] Add to messAI target
- [ ] Add imports:
  ```swift
  import Foundation
  import FirebaseFirestore
  ```

### 3.2: Define Conversation Struct (5 minutes)

- [ ] Define struct
  ```swift
  struct Conversation: Identifiable, Codable, Equatable, Hashable {
      // Identity
      let id: String
      
      // Participants
      let participants: [String]
      let isGroup: Bool
      let groupName: String?
      let groupPhotoURL: String?
      
      // Last Message
      var lastMessage: String
      var lastMessageAt: Date
      var lastMessageSenderId: String?
      
      // Metadata
      let createdBy: String
      let createdAt: Date
      
      // Read Status
      var unreadCount: [String: Int]
      
      // Group Settings
      var admins: [String]?
  }
  ```

- [ ] Build (⌘B)
- [ ] No errors ✓

### 3.3: Add Initializer for 1-on-1 Chat (5 minutes)

- [ ] Add initializer
  ```swift
  init(participant1: String, participant2: String, createdBy: String) {
      self.id = UUID().uuidString
      self.participants = [participant1, participant2]
      self.isGroup = false
      self.groupName = nil
      self.groupPhotoURL = nil
      self.lastMessage = ""
      self.lastMessageAt = Date()
      self.lastMessageSenderId = nil
      self.createdBy = createdBy
      self.createdAt = Date()
      self.unreadCount = [:]
      self.admins = nil
  }
  ```

- [ ] Test: Can create 1-on-1 conversation

### 3.4: Add Initializer for Group Chat (5 minutes)

- [ ] Add group initializer
  ```swift
  init(participants: [String], groupName: String, createdBy: String) {
      self.id = UUID().uuidString
      self.participants = participants
      self.isGroup = true
      self.groupName = groupName
      self.groupPhotoURL = nil
      self.lastMessage = ""
      self.lastMessageAt = Date()
      self.lastMessageSenderId = nil
      self.createdBy = createdBy
      self.createdAt = Date()
      self.unreadCount = [:]
      self.admins = [createdBy]  // Creator is admin
  }
  ```

- [ ] Test: Can create group conversation

### 3.5: Add Computed Properties Extension (5 minutes)

- [ ] Add extension
  ```swift
  extension Conversation {
      func otherParticipant(currentUserId: String) -> String? {
          guard !isGroup else { return nil }
          return participants.first { $0 != currentUserId }
      }
      
      func displayName(currentUserId: String, users: [String: User]) -> String {
          if isGroup {
              return groupName ?? "Group Chat"
          } else if let otherUserId = otherParticipant(currentUserId: currentUserId),
                    let user = users[otherUserId] {
              return user.displayName
          } else {
              return "Unknown"
          }
      }
      
      func displayPhotoURL(currentUserId: String, users: [String: User]) -> String? {
          if isGroup {
              return groupPhotoURL
          } else if let otherUserId = otherParticipant(currentUserId: currentUserId),
                    let user = users[otherUserId] {
              return user.photoURL
          }
          return nil
      }
      
      func unreadCountFor(userId: String) -> Int {
          unreadCount[userId] ?? 0
      }
      
      func isAdmin(userId: String) -> Bool {
          admins?.contains(userId) ?? false
      }
  }
  ```

- [ ] Build (⌘B)
- [ ] No errors ✓

### 3.6: Add Firestore Conversion (7 minutes)

- [ ] Add toDictionary
  ```swift
  extension Conversation {
      func toDictionary() -> [String: Any] {
          var dict: [String: Any] = [
              "id": id,
              "participants": participants,
              "isGroup": isGroup,
              "lastMessage": lastMessage,
              "lastMessageAt": Timestamp(date: lastMessageAt),
              "createdBy": createdBy,
              "createdAt": Timestamp(date: createdAt),
              "unreadCount": unreadCount
          ]
          
          if let groupName = groupName {
              dict["groupName"] = groupName
          }
          if let groupPhotoURL = groupPhotoURL {
              dict["groupPhotoURL"] = groupPhotoURL
          }
          if let lastMessageSenderId = lastMessageSenderId {
              dict["lastMessageSenderId"] = lastMessageSenderId
          }
          if let admins = admins {
              dict["admins"] = admins
          }
          
          return dict
      }
      
      init?(dictionary: [String: Any]) {
          guard
              let id = dictionary["id"] as? String,
              let participants = dictionary["participants"] as? [String],
              let isGroup = dictionary["isGroup"] as? Bool,
              let lastMessage = dictionary["lastMessage"] as? String,
              let lastMessageAtTimestamp = dictionary["lastMessageAt"] as? Timestamp,
              let createdBy = dictionary["createdBy"] as? String,
              let createdAtTimestamp = dictionary["createdAt"] as? Timestamp
          else {
              return nil
          }
          
          self.id = id
          self.participants = participants
          self.isGroup = isGroup
          self.lastMessage = lastMessage
          self.lastMessageAt = lastMessageAtTimestamp.dateValue()
          self.createdBy = createdBy
          self.createdAt = createdAtTimestamp.dateValue()
          
          self.unreadCount = dictionary["unreadCount"] as? [String: Int] ?? [:]
          self.groupName = dictionary["groupName"] as? String
          self.groupPhotoURL = dictionary["groupPhotoURL"] as? String
          self.lastMessageSenderId = dictionary["lastMessageSenderId"] as? String
          self.admins = dictionary["admins"] as? [String]
      }
  }
  ```

- [ ] Build (⌘B)
- [ ] No errors ✓

**Checkpoint:** Conversation model complete (~250 lines) ✓

**Commit:**
```bash
git add messAI/Models/Conversation.swift
git commit -m "feat(models): add Conversation model with group support"
```

---

## Phase 4: TypingStatus Model (15 minutes)

### 4.1: Create TypingStatus.swift File (3 minutes)

- [ ] Create new Swift file: `TypingStatus.swift` in `Models/`
- [ ] Add imports:
  ```swift
  import Foundation
  import FirebaseFirestore
  ```

### 4.2: Define TypingStatus Struct (5 minutes)

- [ ] Define struct
  ```swift
  struct TypingStatus: Identifiable, Codable, Equatable {
      let id: String              // User ID
      let conversationId: String
      let isTyping: Bool
      let startedAt: Date
      
      var isStale: Bool {
          Date().timeIntervalSince(startedAt) > 3
      }
  }
  ```

- [ ] Build (⌘B)
- [ ] No errors ✓

### 4.3: Add Initializer (3 minutes)

- [ ] Add init
  ```swift
  init(userId: String, conversationId: String, isTyping: Bool = true) {
      self.id = userId
      self.conversationId = conversationId
      self.isTyping = isTyping
      self.startedAt = Date()
  }
  ```

- [ ] Test: Can create typing status

### 4.4: Add Firestore Conversion (4 minutes)

- [ ] Add extension
  ```swift
  extension TypingStatus {
      func toDictionary() -> [String: Any] {
          return [
              "userId": id,
              "conversationId": conversationId,
              "isTyping": isTyping,
              "startedAt": Timestamp(date: startedAt)
          ]
      }
      
      init?(dictionary: [String: Any]) {
          guard
              let userId = dictionary["userId"] as? String,
              let conversationId = dictionary["conversationId"] as? String,
              let isTyping = dictionary["isTyping"] as? Bool,
              let startedAtTimestamp = dictionary["startedAt"] as? Timestamp
          else {
              return nil
          }
          
          self.id = userId
          self.conversationId = conversationId
          self.isTyping = isTyping
          self.startedAt = startedAtTimestamp.dateValue()
      }
  }
  ```

- [ ] Build (⌘B)
- [ ] No errors ✓

**Checkpoint:** TypingStatus model complete (~60 lines) ✓

**Commit:**
```bash
git add messAI/Models/TypingStatus.swift
git commit -m "feat(models): add TypingStatus model for real-time indicators"
```

---

## Phase 5: Testing & Validation (15 minutes)

### 5.1: Create Test Function in ContentView (Temporary) (5 minutes)

- [ ] Open `ContentView.swift`
- [ ] Add test function
  ```swift
  func testModels() {
      print("=== Testing Models ===")
      
      // Test MessageStatus
      print("\n1. MessageStatus:")
      print("  Sending: \(MessageStatus.sending.displayText)")
      print("  Icon: \(MessageStatus.read.iconName)")
      
      // Test Message
      print("\n2. Message:")
      let message = Message(
          conversationId: "conv1",
          senderId: "user1",
          text: "Hello, World!"
      )
      print("  ID: \(message.id)")
      print("  Status: \(message.status.displayText)")
      print("  Time ago: \(message.timeAgo)")
      
      // Test Firestore conversion
      let messageDict = message.toDictionary()
      print("  Converted to dict: \(messageDict.keys.count) keys")
      
      if let recovered = Message(dictionary: messageDict) {
          print("  Recovered from dict: ✅")
          print("  Text matches: \(recovered.text == message.text)")
      }
      
      // Test Conversation
      print("\n3. Conversation:")
      let conversation = Conversation(
          participant1: "user1",
          participant2: "user2",
          createdBy: "user1"
      )
      print("  ID: \(conversation.id)")
      print("  Is group: \(conversation.isGroup)")
      print("  Other participant: \(conversation.otherParticipant(currentUserId: "user1") ?? "none")")
      
      // Test Group
      let group = Conversation(
          participants: ["user1", "user2", "user3"],
          groupName: "Test Group",
          createdBy: "user1"
      )
      print("  Group name: \(group.groupName ?? "none")")
      print("  Is admin: \(group.isAdmin(userId: "user1"))")
      
      // Test TypingStatus
      print("\n4. TypingStatus:")
      let typing = TypingStatus(userId: "user1", conversationId: "conv1")
      print("  Is typing: \(typing.isTyping)")
      print("  Is stale: \(typing.isStale)")
      
      print("\n=== All Tests Complete ===\n")
  }
  ```

- [ ] Add button to trigger test in body
  ```swift
  Button("Test Models") {
      testModels()
  }
  ```

### 5.2: Run Tests (5 minutes)

- [ ] Build and run app (⌘R)
- [ ] Tap "Test Models" button
- [ ] Check console output:
  - [ ] MessageStatus displays correctly
  - [ ] Message creates with UUID
  - [ ] Message converts to/from dict
  - [ ] Conversation creates correctly
  - [ ] Group conversation works
  - [ ] TypingStatus creates correctly
  - [ ] All tests print success messages

### 5.3: Test Firestore Round-Trip (3 minutes)

- [ ] Verify in console:
  - [ ] Message → dict → Message preserves all data
  - [ ] Conversation → dict → Conversation preserves all data
  - [ ] TypingStatus → dict → TypingStatus preserves all data
  - [ ] Optional fields (nil) handled correctly

### 5.4: Test Edge Cases (2 minutes)

- [ ] Create message with empty text: `Message(conversationId: "c1", senderId: "u1", text: "")`
- [ ] Create conversation with 10 participants
- [ ] Create typing status and wait 4 seconds, verify isStale = true
- [ ] All edge cases handled gracefully

**Checkpoint:** All models tested and working ✓

---

## Phase 6: Cleanup & Documentation (5 minutes)

### 6.1: Remove Test Code (2 minutes)

- [ ] Remove `testModels()` function from ContentView
- [ ] Remove "Test Models" button
- [ ] ContentView back to normal (or placeholder)
- [ ] Build (⌘B) - no errors

### 6.2: Add Documentation Comments (3 minutes)

- [ ] Add doc comments to each model (brief description)
  ```swift
  /// Represents a single message in a conversation
  struct Message: Identifiable, Codable, Equatable, Hashable {
      // ...
  }
  ```

- [ ] Add doc comments to key methods
  ```swift
  /// Converts message to Firestore-compatible dictionary
  func toDictionary() -> [String: Any] {
      // ...
  }
  ```

- [ ] Build (⌘B) - no errors

**Checkpoint:** Code cleaned up and documented ✓

---

## Final Checks (5 minutes)

### Code Quality
- [ ] All files in correct location (`Models/` folder)
- [ ] No compilation errors
- [ ] No warnings in Xcode
- [ ] All models conform to required protocols
- [ ] Code formatted consistently

### Functionality
- [ ] Can create instances of all models
- [ ] Firestore conversion works both ways
- [ ] Computed properties return expected values
- [ ] Edge cases handled gracefully

### Documentation
- [ ] File headers present
- [ ] Key methods have doc comments
- [ ] Code is readable and clear

---

## Completion Checklist

- [ ] All 4 model files created
- [ ] MessageStatus.swift (~40 lines) ✓
- [ ] Message.swift (~200 lines) ✓
- [ ] Conversation.swift (~250 lines) ✓
- [ ] TypingStatus.swift (~60 lines) ✓
- [ ] All tests passing
- [ ] All models tested manually
- [ ] Firestore conversion verified
- [ ] Edge cases tested
- [ ] Code cleaned up
- [ ] Documentation added
- [ ] No errors, no warnings
- [ ] Ready for PR #5 (Chat Service)

---

## Final Commit & Push

```bash
# Stage all model files
git add messAI/Models/

# Final commit
git commit -m "feat(models): complete core data models

- MessageStatus enum with display properties
- Message model with Firestore conversion
- Conversation model with group support
- TypingStatus model for real-time indicators
- All models tested and validated
- Ready for chat service integration (PR #5)"

# Push to GitHub
git push -u origin feature/core-models
```

---

## Update Documentation

### Update PR_PARTY README
- [ ] Mark PR #4 as complete
- [ ] Add time taken (actual vs estimated)
- [ ] Add files created count
- [ ] Add lines of code count

### Update Memory Bank
- [ ] Update `activeContext.md` with PR #4 completion
- [ ] Update `progress.md` with checked tasks
- [ ] Note any insights or lessons learned

---

## Celebrate! 🎉

**PR #4 Complete!**
- ✅ 4 model files created (~550 lines)
- ✅ All models tested and validated
- ✅ Foundation laid for messaging system
- ✅ Ready for PR #5 (Chat Service)

**Time Taken:** ___ hours (estimated: 1-2 hours)

**Next PR:** PR #5 - Chat Service & Firestore Integration (~3-4 hours)

---

*Great work! These models are the foundation of the entire messaging system. Everything else builds on this solid base.*

