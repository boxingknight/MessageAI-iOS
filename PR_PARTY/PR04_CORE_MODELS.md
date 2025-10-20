# PR #4: Core Models & Data Structure

**Estimated Time**: 1-2 hours  
**Complexity**: LOW-MEDIUM  
**Dependencies**: PR #2 (User model pattern established)  
**Branch**: `feature/core-models`

---

## Overview

### What We're Building
Creating the fundamental data models that power the entire messaging system: Message, Conversation, MessageStatus, and TypingStatus. These models define how we structure, store, and sync chat data between SwiftUI, SwiftData, and Firebase Firestore.

This PR lays the foundation for all messaging features. Every conversation, every message, every status update flows through these models.

### Why It Matters
**Data models are the skeleton of our app.** Get them wrong and we'll fight bugs forever. Get them right and everything else falls into place.

These models need to:
- **Work with SwiftUI**: Conform to `Identifiable`, `Codable`, `Equatable`, `Hashable`
- **Sync with Firebase**: Convert to/from Firestore dictionaries seamlessly
- **Persist locally**: Compatible with SwiftData entities
- **Handle edge cases**: Null safety, optional fields, default values
- **Support real-time**: Efficient updates without full re-renders

Without solid models, we can't build chat services, UI, or sync logic.

### Success in One Sentence
"This PR is successful when we have type-safe, well-documented models that represent all messaging data and convert cleanly between Swift, SwiftData, and Firestore formats."

---

## Technical Design

### Architecture Decisions

#### Decision 1: Model Type - Struct vs Class

**Options Considered:**
1. **Struct (Value Type)**
   - Pros: SwiftUI-friendly, automatic Equatable, thread-safe, immutable
   - Cons: Copying overhead (minimal), can't use inheritance
   
2. **Class (Reference Type)**
   - Pros: Can use inheritance, single instance in memory
   - Cons: Need manual Equatable, threading issues, mutable state

**Chosen:** Struct (Value Type)

**Rationale:**
- SwiftUI works best with value types (@Published triggers updates on struct changes)
- Automatic Equatable/Hashable (compiler synthesizes)
- Thread-safe by default (no shared mutable state)
- Follows Swift best practices
- Consistent with User model from PR #2

**Implementation:**
```swift
struct Message: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let conversationId: String
    // ... other properties
}
```

**Trade-offs:**
- Gain: SwiftUI reactivity, safety, consistency
- Lose: Minor copy overhead (negligible for these models)

---

#### Decision 2: ID Generation Strategy

**Options Considered:**
1. **UUID on device** (client-side)
   - Pros: Instant, works offline, guaranteed unique
   - Cons: Not sequential, can't sort by ID
   
2. **Firestore auto-generated** (server-side)
   - Pros: Sequential, centralized
   - Cons: Requires network, can't create offline
   
3. **Hybrid** (UUID initially, Firestore ID on sync)
   - Pros: Best of both, optimistic UI works
   - Cons: Need to track both IDs

**Chosen:** UUID on device

**Rationale:**
- Optimistic UI requires instant IDs
- Firestore accepts custom IDs
- Can work fully offline
- Consistent, standard format
- No ID collision (UUID is globally unique)

**Implementation:**
```swift
init(conversationId: String, senderId: String, text: String) {
    self.id = UUID().uuidString
    self.conversationId = conversationId
    self.senderId = senderId
    self.text = text
    self.sentAt = Date()
    self.status = .sending
}
```

**Trade-offs:**
- Gain: Offline capability, optimistic UI
- Lose: IDs not sequential (use timestamp for ordering)

---

#### Decision 3: Timestamp Handling - Date vs Timestamp

**Options Considered:**
1. **Swift Date** (native)
   - Pros: Type-safe, easy to use, Swift standard
   - Cons: Must convert to/from Firestore Timestamp
   
2. **Firestore Timestamp** (Firebase type)
   - Pros: Direct mapping to Firestore
   - Cons: Firebase-specific, not native Swift
   
3. **Unix Timestamp (Double)**
   - Pros: Universal, simple
   - Cons: Not type-safe, easy to confuse

**Chosen:** Swift Date (with conversion helpers)

**Rationale:**
- Native Swift type
- Works with SwiftUI (DateFormatter)
- Type-safe (can't confuse with other numbers)
- Firestore SDK handles conversion
- Consistent with Swift ecosystem

**Implementation:**
```swift
struct Message {
    let sentAt: Date
    let deliveredAt: Date?
    let readAt: Date?
    
    // Firestore conversion
    func toDictionary() -> [String: Any] {
        return [
            "sentAt": Timestamp(date: sentAt),
            "deliveredAt": deliveredAt.map { Timestamp(date: $0) },
            "readAt": readAt.map { Timestamp(date: $0) }
        ]
    }
}
```

**Trade-offs:**
- Gain: Type safety, native Swift, SwiftUI compatibility
- Lose: Need conversion layer (minimal boilerplate)

---

#### Decision 4: Message Status - Enum vs String

**Options Considered:**
1. **Enum with String raw value**
   - Pros: Type-safe, autocomplete, compile-time checking
   - Cons: Need raw value for Firestore
   
2. **Plain String**
   - Pros: Simple, direct Firestore mapping
   - Cons: Typos possible, no type safety
   
3. **Enum with custom Codable**
   - Pros: Type-safe, complete control
   - Cons: More boilerplate

**Chosen:** Enum with String raw value

**Rationale:**
- Type safety prevents bugs
- Xcode autocomplete helps developers
- Clear, fixed set of states
- Raw value maps cleanly to Firestore
- Standard Swift pattern

**Implementation:**
```swift
enum MessageStatus: String, Codable {
    case sending  // Local, not yet sent
    case sent     // Sent to server
    case delivered // Delivered to recipient
    case read     // Opened by recipient
    case failed   // Failed to send
}
```

**Trade-offs:**
- Gain: Type safety, clarity, IDE support
- Lose: Slight verbosity (worth it)

---

#### Decision 5: Optional Fields Strategy

**Options Considered:**
1. **Many optionals** (flexible, minimal defaults)
   - Pros: Explicit about missing data
   - Cons: Unwrapping overhead
   
2. **Minimal optionals** (lots of defaults)
   - Pros: Easier to use, no unwrapping
   - Cons: Can't distinguish "not set" from "set to default"
   
3. **Balanced** (optional only when truly optional)
   - Pros: Clear intent, safe
   - Cons: Need to think about each field

**Chosen:** Balanced approach

**Rationale:**
- Required fields: non-optional (id, conversationId, senderId, text, sentAt)
- Truly optional: optional (imageURL, deliveredAt, readAt)
- State that evolves: use enum or optional (status starts as .sending)

**Implementation:**
```swift
struct Message {
    // Required
    let id: String
    let conversationId: String
    let senderId: String
    let text: String
    let sentAt: Date
    let status: MessageStatus
    
    // Optional (may not have values)
    let imageURL: String?
    let deliveredAt: Date?
    let readAt: Date?
}
```

**Trade-offs:**
- Gain: Clear intent, safer code
- Lose: Some optional unwrapping (manageable)

---

### Data Models

#### Model 1: Message

**Purpose:** Represents a single message in a conversation

**Properties:**
```swift
struct Message: Identifiable, Codable, Equatable, Hashable {
    // Identity
    let id: String              // UUID, unique per message
    let conversationId: String  // Which conversation this belongs to
    let senderId: String        // User ID of sender
    
    // Content
    let text: String            // Message text (empty if image-only)
    let imageURL: String?       // Optional image URL from Storage
    
    // Timestamps
    let sentAt: Date            // When message was created
    var deliveredAt: Date?      // When delivered to recipient device
    var readAt: Date?           // When opened/read by recipient
    
    // State
    var status: MessageStatus   // Current delivery status
    
    // Metadata
    let senderName: String?     // Cached display name (for convenience)
    let senderPhotoURL: String? // Cached profile picture
}
```

**Computed Properties:**
```swift
extension Message {
    // Check if message is from current user
    var isFromCurrentUser: Bool {
        senderId == Auth.auth().currentUser?.uid
    }
    
    // Check if message has been delivered
    var isDelivered: Bool {
        status == .delivered || status == .read
    }
    
    // Check if message has been read
    var isRead: Bool {
        status == .read
    }
    
    // Time since sent (for UI display)
    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        return formatter.localizedString(for: sentAt, relativeTo: Date())
    }
}
```

**Firestore Conversion:**
```swift
extension Message {
    // Convert to Firestore dictionary
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
    
    // Create from Firestore dictionary
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
}
```

---

#### Model 2: MessageStatus

**Purpose:** Enum representing message delivery states

**Definition:**
```swift
enum MessageStatus: String, Codable, CaseIterable {
    case sending   // Local only, not sent to server yet
    case sent      // Successfully sent to Firestore
    case delivered // Delivered to recipient's device
    case read      // Recipient opened/read the message
    case failed    // Failed to send (will retry)
    
    var displayText: String {
        switch self {
        case .sending: return "Sending..."
        case .sent: return "Sent"
        case .delivered: return "Delivered"
        case .read: return "Read"
        case .failed: return "Failed"
        }
    }
    
    var iconName: String {
        switch self {
        case .sending: return "clock"
        case .sent: return "checkmark"
        case .delivered: return "checkmark.circle"
        case .read: return "checkmark.circle.fill"
        case .failed: return "exclamationmark.circle"
        }
    }
    
    var color: Color {
        switch self {
        case .sending: return .gray
        case .sent: return .gray
        case .delivered: return .blue
        case .read: return .blue
        case .failed: return .red
        }
    }
}
```

**State Transitions:**
```
sending → sent → delivered → read
   ↓
failed (can retry → sending)
```

---

#### Model 3: Conversation

**Purpose:** Represents a chat (one-on-one or group)

**Properties:**
```swift
struct Conversation: Identifiable, Codable, Equatable, Hashable {
    // Identity
    let id: String              // UUID or Firestore-generated
    
    // Participants
    let participants: [String]  // Array of user IDs
    let isGroup: Bool           // true if 3+ participants
    let groupName: String?      // Only for group chats
    let groupPhotoURL: String?  // Optional group photo
    
    // Last Message (for preview)
    var lastMessage: String
    var lastMessageAt: Date
    var lastMessageSenderId: String?
    
    // Metadata
    let createdBy: String       // User ID who created
    let createdAt: Date
    
    // Read Status (per user)
    var unreadCount: [String: Int] // userId → unread count
    
    // Group Settings (for group chats)
    var admins: [String]?       // User IDs of group admins
}
```

**Computed Properties:**
```swift
extension Conversation {
    // Get other participant in 1-on-1 chat
    func otherParticipant(currentUserId: String) -> String? {
        guard !isGroup else { return nil }
        return participants.first { $0 != currentUserId }
    }
    
    // Display name for conversation
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
    
    // Display photo URL
    func displayPhotoURL(currentUserId: String, users: [String: User]) -> String? {
        if isGroup {
            return groupPhotoURL
        } else if let otherUserId = otherParticipant(currentUserId: currentUserId),
                  let user = users[otherUserId] {
            return user.photoURL
        }
        return nil
    }
    
    // Unread count for current user
    func unreadCountFor(userId: String) -> Int {
        unreadCount[userId] ?? 0
    }
    
    // Is user an admin (for groups)
    func isAdmin(userId: String) -> Bool {
        admins?.contains(userId) ?? false
    }
}
```

**Firestore Conversion:**
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

---

#### Model 4: TypingStatus

**Purpose:** Track who's typing in real-time

**Properties:**
```swift
struct TypingStatus: Identifiable, Codable, Equatable {
    let id: String              // User ID
    let conversationId: String  // Which conversation
    let isTyping: Bool          // Currently typing?
    let startedAt: Date         // When they started typing
    
    // Computed property
    var isStale: Bool {
        // Consider stale after 3 seconds
        Date().timeIntervalSince(startedAt) > 3
    }
}
```

**Firestore Conversion:**
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

---

### Firestore Schema Design

**Collection Structure:**
```
/users/{userId}
  - (User model from PR #2)

/conversations/{conversationId}
  ├── id: String
  ├── participants: [String]
  ├── isGroup: Bool
  ├── groupName: String?
  ├── groupPhotoURL: String?
  ├── lastMessage: String
  ├── lastMessageAt: Timestamp
  ├── lastMessageSenderId: String?
  ├── createdBy: String
  ├── createdAt: Timestamp
  ├── unreadCount: Map<String, Int>
  └── admins: [String]?
  
  /messages/{messageId}
    ├── id: String
    ├── conversationId: String
    ├── senderId: String
    ├── text: String
    ├── imageURL: String?
    ├── sentAt: Timestamp
    ├── deliveredAt: Timestamp?
    ├── readAt: Timestamp?
    ├── status: String
    ├── senderName: String?
    └── senderPhotoURL: String?

/typingStatus/{conversationId}
  └── {userId}: Timestamp  // When user started typing
```

**Index Requirements:**
```javascript
// Firestore composite indexes needed:

// 1. For fetching user's conversations
conversations:
  - participants (array-contains)
  - lastMessageAt (descending)

// 2. For fetching messages in conversation
messages:
  - conversationId (ascending)
  - sentAt (ascending)
```

---

## Implementation Details

### File Structure

**New Files:**
```
Models/
├── Message.swift           (~200 lines)
├── MessageStatus.swift     (~40 lines)
├── Conversation.swift      (~250 lines)
└── TypingStatus.swift      (~60 lines)
```

**Total New Lines**: ~550 lines of model code

---

### Key Implementation Steps

#### Phase 1: Create MessageStatus Enum (15 minutes)

**File**: `Models/MessageStatus.swift`

**Tasks:**
1. Create enum with raw String values
2. Add display text computed property
3. Add icon name for UI
4. Add color for UI
5. Add CaseIterable conformance for testing

**Code:**
```swift
import SwiftUI

enum MessageStatus: String, Codable, CaseIterable {
    case sending = "sending"
    case sent = "sent"
    case delivered = "delivered"
    case read = "read"
    case failed = "failed"
    
    var displayText: String {
        switch self {
        case .sending: return "Sending..."
        case .sent: return "Sent"
        case .delivered: return "Delivered"
        case .read: return "Read"
        case .failed: return "Failed"
        }
    }
    
    var iconName: String {
        switch self {
        case .sending: return "clock"
        case .sent: return "checkmark"
        case .delivered: return "checkmark.circle"
        case .read: return "checkmark.circle.fill"
        case .failed: return "exclamationmark.circle"
        }
    }
    
    var color: Color {
        switch self {
        case .sending: return .gray
        case .sent: return .gray
        case .delivered: return .blue
        case .read: return .blue
        case .failed: return .red
        }
    }
}
```

---

#### Phase 2: Create Message Model (30 minutes)

**File**: `Models/Message.swift`

**Tasks:**
1. Define struct with all properties
2. Add Identifiable, Codable, Equatable, Hashable conformance
3. Add computed properties
4. Add Firestore conversion (toDictionary)
5. Add Firestore init (from dictionary)
6. Add convenience initializers
7. Add extension for UI helpers

**Structure** (abbreviated):
```swift
import Foundation
import FirebaseFirestore

struct Message: Identifiable, Codable, Equatable, Hashable {
    // Properties (as defined above)
    
    // Default initializer
    init(id: String, conversationId: String, senderId: String, text: String, 
         imageURL: String? = nil, sentAt: Date = Date(), deliveredAt: Date? = nil,
         readAt: Date? = nil, status: MessageStatus = .sending, 
         senderName: String? = nil, senderPhotoURL: String? = nil) {
        // ... assign all properties
    }
    
    // Convenience initializer (for sending new message)
    init(conversationId: String, senderId: String, text: String, 
         senderName: String? = nil, senderPhotoURL: String? = nil) {
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
}

// Extension for computed properties
extension Message {
    // (as defined above)
}

// Extension for Firestore conversion
extension Message {
    // (as defined above)
}
```

---

#### Phase 3: Create Conversation Model (30 minutes)

**File**: `Models/Conversation.swift`

**Tasks:**
1. Define struct with all properties
2. Add conformances
3. Add computed properties for display
4. Add Firestore conversion
5. Add convenience initializers
6. Add helpers for group management

**Structure** (abbreviated):
```swift
import Foundation
import FirebaseFirestore

struct Conversation: Identifiable, Codable, Equatable, Hashable {
    // Properties (as defined above)
    
    // Initializer for new 1-on-1 conversation
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
    
    // Initializer for new group
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
        self.admins = [createdBy]
    }
}

// Extensions (as defined above)
```

---

#### Phase 4: Create TypingStatus Model (15 minutes)

**File**: `Models/TypingStatus.swift`

**Tasks:**
1. Define struct with properties
2. Add conformances
3. Add computed property for staleness
4. Add Firestore conversion

**Code:**
```swift
import Foundation
import FirebaseFirestore

struct TypingStatus: Identifiable, Codable, Equatable {
    let id: String              // User ID
    let conversationId: String
    let isTyping: Bool
    let startedAt: Date
    
    var isStale: Bool {
        Date().timeIntervalSince(startedAt) > 3
    }
    
    init(userId: String, conversationId: String, isTyping: Bool = true) {
        self.id = userId
        self.conversationId = conversationId
        self.isTyping = isTyping
        self.startedAt = Date()
    }
}

// Extension for Firestore (as defined above)
```

---

#### Phase 5: Testing & Validation (15 minutes)

**Tasks:**
1. Create test instances of each model
2. Test Firestore conversion (to/from dictionary)
3. Test computed properties
4. Test equality and hashing
5. Verify Codable (JSON encode/decode)
6. Check for compilation errors
7. Add print statements to verify data

**Test Cases:**
```swift
// In a test function or playground

// Test Message
let message = Message(
    conversationId: "conv1",
    senderId: "user1",
    text: "Hello!"
)
print("Message ID: \(message.id)")
print("Status: \(message.status.displayText)")

// Convert to Firestore and back
let messageDict = message.toDictionary()
let recoveredMessage = Message(dictionary: messageDict)
print("Conversion success: \(recoveredMessage != nil)")

// Test Conversation
let conversation = Conversation(
    participant1: "user1",
    participant2: "user2",
    createdBy: "user1"
)
print("Conversation ID: \(conversation.id)")
print("Other participant: \(conversation.otherParticipant(currentUserId: "user1") ?? "none")")

// Test TypingStatus
let typing = TypingStatus(userId: "user1", conversationId: "conv1")
print("Is typing: \(typing.isTyping)")
print("Is stale: \(typing.isStale)")
```

---

## Testing Strategy

### Unit Tests (Future PR #21)

**Message Model Tests:**
- ✅ Message initializer creates valid instance
- ✅ Firestore conversion (to dictionary) includes all fields
- ✅ Firestore conversion (from dictionary) recovers instance
- ✅ Computed properties return correct values
- ✅ Status transitions work correctly
- ✅ Equality and hashing work

**Conversation Model Tests:**
- ✅ 1-on-1 conversation initializer works
- ✅ Group conversation initializer works
- ✅ otherParticipant returns correct user
- ✅ Display name computed correctly
- ✅ Unread count tracked per user
- ✅ Admin management works for groups

**MessageStatus Tests:**
- ✅ All cases have display text
- ✅ All cases have icon names
- ✅ All cases have colors

**TypingStatus Tests:**
- ✅ Initializer works
- ✅ Staleness detection works
- ✅ Firestore conversion works

---

### Manual Testing Checklist

#### Test 1: Create Models
- [ ] Create Message instance
- [ ] Create Conversation instance (1-on-1)
- [ ] Create Conversation instance (group)
- [ ] Create TypingStatus instance
- [ ] No compilation errors

#### Test 2: Firestore Conversion
- [ ] Message → dictionary → Message (lossless)
- [ ] Conversation → dictionary → Conversation (lossless)
- [ ] TypingStatus → dictionary → TypingStatus (lossless)
- [ ] Optional fields handled correctly (nil → dict → nil)

#### Test 3: Computed Properties
- [ ] Message.isFromCurrentUser works
- [ ] Message.timeAgo returns readable string
- [ ] Conversation.otherParticipant returns correct user
- [ ] Conversation.displayName returns correct name
- [ ] TypingStatus.isStale detects old typing events

#### Test 4: Equality & Hashing
- [ ] Two messages with same data are equal
- [ ] Two messages with different IDs are not equal
- [ ] Models can be used in Set/Dictionary
- [ ] Hashable conformance works

#### Test 5: Edge Cases
- [ ] Message with empty text (image-only)
- [ ] Conversation with 10+ participants
- [ ] TypingStatus exactly at 3-second boundary
- [ ] Nil optional fields handled gracefully

---

## Success Criteria

### Feature is complete when:

- [ ] MessageStatus.swift created with all cases
- [ ] Message.swift created with all properties
- [ ] Conversation.swift created with all properties
- [ ] TypingStatus.swift created with all properties
- [ ] All models conform to required protocols
- [ ] All Firestore conversion methods implemented
- [ ] All computed properties implemented
- [ ] All convenience initializers implemented
- [ ] Manual tests pass
- [ ] Code compiles without errors
- [ ] No warnings in Xcode
- [ ] Models can create instances
- [ ] Models can convert to/from Firestore
- [ ] Models work with SwiftUI (@Published, Identifiable)

---

## Risk Assessment

### Risk 1: Firestore Conversion Bugs
**Likelihood:** MEDIUM  
**Impact:** HIGH (data loss, sync issues)  
**Mitigation:** Thorough testing, nil checks, type validation  
**Recovery:** Fix conversion, re-sync data  
**Status:** 🟡 MITIGATE THROUGH TESTING

### Risk 2: Optional Unwrapping Crashes
**Likelihood:** LOW  
**Impact:** HIGH (app crashes)  
**Mitigation:** Safe unwrapping, default values where appropriate  
**Recovery:** Add nil coalescing, test edge cases  
**Status:** 🟢 MITIGATED

### Risk 3: Timestamp Conversion Issues
**Likelihood:** MEDIUM  
**Impact:** MEDIUM (wrong dates, ordering issues)  
**Mitigation:** Use Firestore Timestamp type consistently  
**Recovery:** Fix conversion logic, verify in Firestore console  
**Status:** 🟡 WATCH CAREFULLY

### Risk 4: Performance - Large Conversations
**Likelihood:** LOW (not in MVP)  
**Impact:** MEDIUM (slow loading)  
**Mitigation:** Pagination in future PR, not an issue for MVP  
**Recovery:** Add pagination, limit query results  
**Status:** 🟢 FUTURE CONCERN

---

## Timeline

**Total Estimate**: 1-2 hours

| Phase | Task | Time | Status |
|-------|------|------|--------|
| 1 | MessageStatus enum | 15 min | ⏳ |
| 2 | Message model | 30 min | ⏳ |
| 3 | Conversation model | 30 min | ⏳ |
| 4 | TypingStatus model | 15 min | ⏳ |
| 5 | Testing & Validation | 15 min | ⏳ |
| **Total** | | **1.75 hours** | ⏳ |

**Buffer**: Estimate 2 hours max (includes thinking time)

---

## Dependencies

### Requires:
- [x] PR #2 complete (User model pattern established)
- [x] Firebase SDK imported
- [x] FirebaseFirestore available

### Blocks:
- PR #5: Chat Service (needs these models)
- PR #6: SwiftData persistence (needs these models)
- All future PRs (everything depends on data models)

---

## Open Questions

**Q1:** Should we cache sender name/photo in Message model?  
**A:** Yes, for performance. Avoids extra lookups when rendering messages.

**Q2:** Should Conversation have last message ID instead of text?  
**A:** No, text is better for preview. We can fetch full message if needed.

**Q3:** How to handle typing status cleanup (stale entries)?  
**A:** Cloud Functions can clean up stale entries (>5 seconds old). For MVP, client-side staleness check is sufficient.

**Q4:** Should we support message editing?  
**A:** Not in MVP. Can add `editedAt: Date?` field in future PR.

---

## References

- [Swift Codable Documentation](https://developer.apple.com/documentation/foundation/archives_and_serialization/encoding_and_decoding_custom_types)
- [Firestore Data Model](https://firebase.google.com/docs/firestore/data-model)
- [Firestore Timestamps](https://firebase.google.com/docs/reference/swift/firebasefirestore/api/reference/Classes/Timestamp)
- User model from PR #2: `Models/User.swift`

---

**Status**: 📋 READY TO IMPLEMENT  
**Next Step**: Create implementation checklist  
**Estimated Completion**: October 20, 2025 (same day)

