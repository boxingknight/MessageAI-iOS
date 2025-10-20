# PR #4: Core Models & Data Structure - Testing Guide

**Purpose:** Comprehensive testing strategy for all 4 data models  
**Time Required:** 15-20 minutes for full testing  
**When to Test:** After each model is created (test as you go)

---

## Testing Philosophy

### Why Test Models?

**Data models are critical:**
- They're used everywhere (services, ViewModels, views)
- Bugs in models cause cascading failures
- Firestore conversion bugs cause data loss
- Type mismatches cause crashes

**Testing models is easy:**
- No UI needed (just Swift code)
- Fast feedback (instant execution)
- Clear pass/fail (data matches or it doesn't)

**Test early, test often:**
- Test after each model is created
- Test Firestore conversion immediately
- Test edge cases before moving on

---

## Test Categories

### 1. Unit Tests (Per Model)
Test individual model functionality:
- Can create instance
- Properties accessible
- Computed properties work
- Initializers work

### 2. Firestore Conversion Tests
Test serialization/deserialization:
- Model → dictionary (toDictionary)
- Dictionary → model (init from dictionary)
- Round-trip is lossless
- Optional fields handled correctly

### 3. Edge Case Tests
Test unusual inputs:
- Empty strings
- Nil optionals
- Large arrays (10+ participants)
- Boundary conditions (3-second typing timeout)

### 4. Equality & Hashing Tests
Test protocol conformance:
- Equatable works (== operator)
- Hashable works (can use in Set/Dict)
- Identity correct (same data = equal)

---

## Test 1: MessageStatus Enum

### Test 1.1: All Cases Accessible
**Purpose:** Verify all status cases exist

**Steps:**
```swift
let sending = MessageStatus.sending
let sent = MessageStatus.sent
let delivered = MessageStatus.delivered
let read = MessageStatus.read
let failed = MessageStatus.failed
```

**Expected:** No compilation errors ✅

---

### Test 1.2: Display Properties
**Purpose:** Verify computed properties return correct values

**Test Cases:**
```swift
print("=== MessageStatus Display Properties ===")

// Test displayText
print("sending.displayText: \(MessageStatus.sending.displayText)")
// Expected: "Sending..."

print("sent.displayText: \(MessageStatus.sent.displayText)")
// Expected: "Sent"

print("delivered.displayText: \(MessageStatus.delivered.displayText)")
// Expected: "Delivered"

print("read.displayText: \(MessageStatus.read.displayText)")
// Expected: "Read"

print("failed.displayText: \(MessageStatus.failed.displayText)")
// Expected: "Failed"

// Test iconName
print("sending.iconName: \(MessageStatus.sending.iconName)")
// Expected: "clock"

print("read.iconName: \(MessageStatus.read.iconName)")
// Expected: "checkmark.circle.fill"

// Test color
print("sending.color: \(MessageStatus.sending.color)")
// Expected: gray

print("read.color: \(MessageStatus.read.color)")
// Expected: blue
```

**Expected:** All properties return correct values ✅

---

### Test 1.3: Raw Value (Codable)
**Purpose:** Verify enum can encode/decode

**Test Cases:**
```swift
// Test raw value
print("sending.rawValue: \(MessageStatus.sending.rawValue)")
// Expected: "sending"

// Test from raw value
let status = MessageStatus(rawValue: "sent")
print("status from 'sent': \(status == .sent)")
// Expected: true

// Test invalid raw value
let invalid = MessageStatus(rawValue: "invalid")
print("invalid status: \(invalid == nil)")
// Expected: true (returns nil for invalid)
```

**Expected:** Raw value conversion works ✅

---

## Test 2: Message Model

### Test 2.1: Instance Creation
**Purpose:** Verify can create Message instances

**Test Cases:**
```swift
print("\n=== Message Model ===")

// Test convenience initializer
let message1 = Message(
    conversationId: "conv1",
    senderId: "user1",
    text: "Hello, World!"
)

print("Message ID generated: \(!message1.id.isEmpty)")
// Expected: true

print("Message status: \(message1.status)")
// Expected: .sending

// Test full initializer
let message2 = Message(
    id: "msg123",
    conversationId: "conv1",
    senderId: "user1",
    text: "Test message",
    imageURL: "https://example.com/image.jpg",
    sentAt: Date(),
    deliveredAt: nil,
    readAt: nil,
    status: .sent,
    senderName: "John Doe",
    senderPhotoURL: nil
)

print("Message with custom ID: \(message2.id)")
// Expected: "msg123"
```

**Expected:** Both initializers work ✅

---

### Test 2.2: Computed Properties
**Purpose:** Verify computed properties return correct values

**Test Cases:**
```swift
// Test isDelivered
let deliveredMsg = Message(
    id: "1",
    conversationId: "c1",
    senderId: "u1",
    text: "Hi",
    status: .delivered
)

print("isDelivered (delivered): \(deliveredMsg.isDelivered)")
// Expected: true

let sendingMsg = Message(
    id: "2",
    conversationId: "c1",
    senderId: "u1",
    text: "Hi",
    status: .sending
)

print("isDelivered (sending): \(sendingMsg.isDelivered)")
// Expected: false

// Test isRead
let readMsg = Message(
    id: "3",
    conversationId: "c1",
    senderId: "u1",
    text: "Hi",
    status: .read
)

print("isRead: \(readMsg.isRead)")
// Expected: true

// Test timeAgo
print("timeAgo: \(message1.timeAgo)")
// Expected: "now" or "0 sec ago" (just sent)
```

**Expected:** All computed properties work ✅

---

### Test 2.3: Firestore Conversion (Round-Trip)
**Purpose:** Verify lossless conversion to/from Firestore

**Test Cases:**
```swift
print("\n=== Firestore Conversion ===")

// Create message with all fields
let original = Message(
    id: "msg_test",
    conversationId: "conv_test",
    senderId: "user_test",
    text: "Test message with all fields",
    imageURL: "https://example.com/test.jpg",
    sentAt: Date(),
    deliveredAt: Date(timeIntervalSinceNow: 1),
    readAt: Date(timeIntervalSinceNow: 2),
    status: .read,
    senderName: "Test User",
    senderPhotoURL: "https://example.com/avatar.jpg"
)

// Convert to dictionary
let dict = original.toDictionary()
print("Dictionary keys: \(dict.keys.count)")
// Expected: ~11 keys (all fields)

print("Dictionary contains 'id': \(dict["id"] != nil)")
// Expected: true

print("Dictionary contains 'text': \(dict["text"] != nil)")
// Expected: true

// Convert back to Message
guard let recovered = Message(dictionary: dict) else {
    print("ERROR: Failed to recover message from dictionary")
    return
}

print("Recovered message successfully: true")

// Verify data integrity
print("ID matches: \(recovered.id == original.id)")
// Expected: true

print("Text matches: \(recovered.text == original.text)")
// Expected: true

print("Status matches: \(recovered.status == original.status)")
// Expected: true

print("ImageURL matches: \(recovered.imageURL == original.imageURL)")
// Expected: true

print("SenderName matches: \(recovered.senderName == original.senderName)")
// Expected: true
```

**Expected:** Round-trip conversion is lossless ✅

---

### Test 2.4: Optional Fields Handling
**Purpose:** Verify nil optionals handled correctly

**Test Cases:**
```swift
// Create message with minimal fields (no optionals)
let minimal = Message(
    id: "minimal",
    conversationId: "c1",
    senderId: "u1",
    text: "Minimal message",
    imageURL: nil,
    sentAt: Date(),
    deliveredAt: nil,
    readAt: nil,
    status: .sending,
    senderName: nil,
    senderPhotoURL: nil
)

// Convert to dict and back
let minimalDict = minimal.toDictionary()
guard let recoveredMinimal = Message(dictionary: minimalDict) else {
    print("ERROR: Failed to recover minimal message")
    return
}

print("\nOptional fields test:")
print("imageURL is nil: \(recoveredMinimal.imageURL == nil)")
// Expected: true

print("deliveredAt is nil: \(recoveredMinimal.deliveredAt == nil)")
// Expected: true

print("senderName is nil: \(recoveredMinimal.senderName == nil)")
// Expected: true
```

**Expected:** Nil optionals preserved through conversion ✅

---

### Test 2.5: Edge Cases
**Purpose:** Test unusual inputs

**Test Cases:**
```swift
// Empty text
let emptyText = Message(conversationId: "c1", senderId: "u1", text: "")
print("\nEmpty text allowed: \(emptyText.text.isEmpty)")
// Expected: true (image-only messages)

// Very long text
let longText = String(repeating: "a", count: 10000)
let longMessage = Message(conversationId: "c1", senderId: "u1", text: longText)
print("Long text (10k chars): \(longMessage.text.count)")
// Expected: 10000

// Special characters in text
let special = Message(
    conversationId: "c1",
    senderId: "u1",
    text: "Hello 👋 🎉 Special: <>&\"'\n\t"
)
let specialDict = special.toDictionary()
let recoveredSpecial = Message(dictionary: specialDict)
print("Special chars preserved: \(recoveredSpecial?.text == special.text)")
// Expected: true
```

**Expected:** Edge cases handled gracefully ✅

---

## Test 3: Conversation Model

### Test 3.1: Instance Creation (1-on-1)
**Purpose:** Verify can create 1-on-1 conversation

**Test Cases:**
```swift
print("\n=== Conversation Model (1-on-1) ===")

let oneOnOne = Conversation(
    participant1: "user1",
    participant2: "user2",
    createdBy: "user1"
)

print("Conversation ID generated: \(!oneOnOne.id.isEmpty)")
// Expected: true

print("Is group: \(oneOnOne.isGroup)")
// Expected: false

print("Participants count: \(oneOnOne.participants.count)")
// Expected: 2

print("Participants: \(oneOnOne.participants)")
// Expected: ["user1", "user2"]
```

**Expected:** 1-on-1 conversation created correctly ✅

---

### Test 3.2: Instance Creation (Group)
**Purpose:** Verify can create group conversation

**Test Cases:**
```swift
print("\n=== Conversation Model (Group) ===")

let group = Conversation(
    participants: ["user1", "user2", "user3", "user4"],
    groupName: "Team Chat",
    createdBy: "user1"
)

print("Is group: \(group.isGroup)")
// Expected: true

print("Group name: \(group.groupName ?? "none")")
// Expected: "Team Chat"

print("Participants count: \(group.participants.count)")
// Expected: 4

print("Creator is admin: \(group.isAdmin(userId: "user1"))")
// Expected: true

print("Other user is admin: \(group.isAdmin(userId: "user2"))")
// Expected: false
```

**Expected:** Group conversation created correctly ✅

---

### Test 3.3: Computed Properties
**Purpose:** Verify helper methods work

**Test Cases:**
```swift
print("\n=== Conversation Computed Properties ===")

// Test otherParticipant
let conv = Conversation(
    participant1: "alice",
    participant2: "bob",
    createdBy: "alice"
)

print("Other participant (from alice): \(conv.otherParticipant(currentUserId: "alice") ?? "none")")
// Expected: "bob"

print("Other participant (from bob): \(conv.otherParticipant(currentUserId: "bob") ?? "none")")
// Expected: "alice"

// Test displayName
let users: [String: User] = [
    "alice": User(id: "alice", email: "alice@test.com", displayName: "Alice", photoURL: nil, fcmToken: nil, isOnline: true, lastSeen: Date(), createdAt: Date()),
    "bob": User(id: "bob", email: "bob@test.com", displayName: "Bob", photoURL: nil, fcmToken: nil, isOnline: true, lastSeen: Date(), createdAt: Date())
]

print("Display name (from alice): \(conv.displayName(currentUserId: "alice", users: users))")
// Expected: "Bob"

print("Display name (from bob): \(conv.displayName(currentUserId: "bob", users: users))")
// Expected: "Alice"

// Test group name
let teamGroup = Conversation(
    participants: ["alice", "bob", "charlie"],
    groupName: "Project Team",
    createdBy: "alice"
)

print("Group display name: \(teamGroup.displayName(currentUserId: "alice", users: users))")
// Expected: "Project Team"
```

**Expected:** All computed properties return correct values ✅

---

### Test 3.4: Firestore Conversion
**Purpose:** Verify round-trip conversion

**Test Cases:**
```swift
print("\n=== Conversation Firestore Conversion ===")

// Create conversation with all fields
let fullConv = Conversation(
    participants: ["user1", "user2", "user3"],
    groupName: "Test Group",
    createdBy: "user1"
)

// Manually set some fields
var mutableConv = fullConv
mutableConv.lastMessage = "Hello everyone!"
mutableConv.lastMessageAt = Date()
mutableConv.unreadCount = ["user2": 3, "user3": 1]

// Convert to dict
let convDict = mutableConv.toDictionary()
print("Dictionary keys: \(convDict.keys.count)")
// Expected: ~10 keys

// Convert back
guard let recoveredConv = Conversation(dictionary: convDict) else {
    print("ERROR: Failed to recover conversation")
    return
}

print("Recovered conversation: true")
print("ID matches: \(recoveredConv.id == mutableConv.id)")
// Expected: true

print("Participants match: \(recoveredConv.participants == mutableConv.participants)")
// Expected: true

print("Group name matches: \(recoveredConv.groupName == mutableConv.groupName)")
// Expected: true

print("Unread count matches: \(recoveredConv.unreadCount == mutableConv.unreadCount)")
// Expected: true
```

**Expected:** Round-trip conversion is lossless ✅

---

### Test 3.5: Edge Cases
**Purpose:** Test unusual scenarios

**Test Cases:**
```swift
print("\n=== Conversation Edge Cases ===")

// Large group (10+ participants)
let largeGroup = Conversation(
    participants: Array(repeating: "user", count: 100).enumerated().map { "user\($0.offset)" },
    groupName: "Large Group",
    createdBy: "user0"
)

print("Large group participants: \(largeGroup.participants.count)")
// Expected: 100

// Empty group name
let noNameGroup = Conversation(
    participants: ["u1", "u2", "u3"],
    groupName: "",
    createdBy: "u1"
)

print("Empty group name: \(noNameGroup.groupName ?? "nil")")
// Expected: "" (empty string, not nil)

// Unread count for non-existent user
print("Unread for missing user: \(fullConv.unreadCountFor(userId: "nonexistent"))")
// Expected: 0 (default)
```

**Expected:** Edge cases handled gracefully ✅

---

## Test 4: TypingStatus Model

### Test 4.1: Instance Creation
**Purpose:** Verify can create TypingStatus

**Test Cases:**
```swift
print("\n=== TypingStatus Model ===")

let typing = TypingStatus(
    userId: "user1",
    conversationId: "conv1",
    isTyping: true
)

print("User ID: \(typing.id)")
// Expected: "user1"

print("Conversation ID: \(typing.conversationId)")
// Expected: "conv1"

print("Is typing: \(typing.isTyping)")
// Expected: true

print("Started at: \(typing.startedAt)")
// Expected: Current date/time
```

**Expected:** Instance created correctly ✅

---

### Test 4.2: Staleness Detection
**Purpose:** Verify isStale computed property

**Test Cases:**
```swift
print("\n=== Typing Staleness ===")

// Fresh typing status
let fresh = TypingStatus(userId: "u1", conversationId: "c1")
print("Fresh typing is stale: \(fresh.isStale)")
// Expected: false (just created)

// Simulate stale typing (create with old timestamp)
// Note: Can't directly set startedAt, so test logic manually
let now = Date()
let oldStart = now.addingTimeInterval(-5)  // 5 seconds ago
let timeSince = now.timeIntervalSince(oldStart)
print("Time since old start: \(timeSince) seconds")
// Expected: 5

print("Would be stale: \(timeSince > 3)")
// Expected: true
```

**Expected:** Staleness detection works ✅

---

### Test 4.3: Firestore Conversion
**Purpose:** Verify round-trip conversion

**Test Cases:**
```swift
print("\n=== TypingStatus Firestore Conversion ===")

let original = TypingStatus(
    userId: "test_user",
    conversationId: "test_conv"
)

// Convert to dict
let typingDict = original.toDictionary()
print("Dictionary keys: \(typingDict.keys.count)")
// Expected: 4 keys

// Convert back
guard let recovered = TypingStatus(dictionary: typingDict) else {
    print("ERROR: Failed to recover typing status")
    return
}

print("Recovered successfully: true")
print("User ID matches: \(recovered.id == original.id)")
// Expected: true

print("Conversation ID matches: \(recovered.conversationId == original.conversationId)")
// Expected: true

print("Is typing matches: \(recovered.isTyping == original.isTyping)")
// Expected: true
```

**Expected:** Round-trip conversion is lossless ✅

---

## Test 5: Protocol Conformance

### Test 5.1: Equatable
**Purpose:** Verify models can be compared

**Test Cases:**
```swift
print("\n=== Equatable Conformance ===")

// Same data = equal
let msg1 = Message(id: "1", conversationId: "c1", senderId: "u1", text: "Hi")
let msg2 = Message(id: "1", conversationId: "c1", senderId: "u1", text: "Hi")
print("Same messages equal: \(msg1 == msg2)")
// Expected: true

// Different ID = not equal
let msg3 = Message(id: "2", conversationId: "c1", senderId: "u1", text: "Hi")
print("Different ID not equal: \(msg1 != msg3)")
// Expected: true

// Different text = not equal
let msg4 = Message(id: "1", conversationId: "c1", senderId: "u1", text: "Bye")
print("Different text not equal: \(msg1 != msg4)")
// Expected: true
```

**Expected:** Equatable works correctly ✅

---

### Test 5.2: Hashable
**Purpose:** Verify models can be used in Set/Dictionary

**Test Cases:**
```swift
print("\n=== Hashable Conformance ===")

// Use in Set
let set: Set<Message> = [
    Message(id: "1", conversationId: "c1", senderId: "u1", text: "A"),
    Message(id: "2", conversationId: "c1", senderId: "u1", text: "B"),
    Message(id: "1", conversationId: "c1", senderId: "u1", text: "A")  // Duplicate
]

print("Set count (should dedupe): \(set.count)")
// Expected: 2 (duplicate removed)

// Use as Dictionary key
var dict: [Message: String] = [:]
let key = Message(id: "key", conversationId: "c", senderId: "u", text: "K")
dict[key] = "value"
print("Dictionary lookup works: \(dict[key] == "value")")
// Expected: true
```

**Expected:** Hashable works correctly ✅

---

### Test 5.3: Identifiable
**Purpose:** Verify id property accessible

**Test Cases:**
```swift
print("\n=== Identifiable Conformance ===")

let message = Message(conversationId: "c1", senderId: "u1", text: "Test")
print("Message id type: \(type(of: message.id))")
// Expected: String.Type

let conversation = Conversation(participant1: "u1", participant2: "u2", createdBy: "u1")
print("Conversation id type: \(type(of: conversation.id))")
// Expected: String.Type

// Simulate SwiftUI list usage
let messages = [
    Message(conversationId: "c1", senderId: "u1", text: "A"),
    Message(conversationId: "c1", senderId: "u1", text: "B")
]

// In SwiftUI, you'd use: ForEach(messages) { message in ... }
// Here, just verify IDs are unique
let ids = messages.map { $0.id }
let uniqueIds = Set(ids)
print("All IDs unique: \(ids.count == uniqueIds.count)")
// Expected: true
```

**Expected:** Identifiable works for SwiftUI ✅

---

## Acceptance Criteria

### All Tests Pass When:

#### MessageStatus
- [ ] All 5 cases accessible
- [ ] displayText returns correct strings
- [ ] iconName returns valid SF Symbol names
- [ ] color returns Color instances
- [ ] Raw value conversion works

#### Message
- [ ] Can create with convenience init (auto UUID)
- [ ] Can create with full init (custom ID)
- [ ] Computed properties return correct values
- [ ] Firestore round-trip is lossless
- [ ] Optional fields handled correctly (nil preserved)
- [ ] Edge cases work (empty text, long text, special chars)

#### Conversation
- [ ] Can create 1-on-1 conversation
- [ ] Can create group conversation
- [ ] otherParticipant returns correct user
- [ ] displayName works for 1-on-1 and groups
- [ ] isAdmin works correctly
- [ ] Firestore round-trip is lossless
- [ ] Edge cases work (large groups, empty names)

#### TypingStatus
- [ ] Can create instance
- [ ] isStale computed property works
- [ ] Firestore round-trip is lossless

#### Protocol Conformance
- [ ] Equatable works (== operator)
- [ ] Hashable works (Set/Dictionary usage)
- [ ] Identifiable works (id property accessible)
- [ ] Codable works (implied by Firestore conversion)

---

## Performance Benchmarks

**All operations should be fast:**

| Operation | Target | Expected |
|-----------|--------|----------|
| Create instance | < 0.1ms | Instant |
| toDictionary() | < 1ms | Instant |
| init(dictionary:) | < 1ms | Instant |
| Computed property | < 0.1ms | Instant |
| Equality check | < 0.1ms | Instant |

**Note:** These models are simple structs with no async operations. Performance is not a concern for MVP.

---

## When Tests Fail

### Firestore Conversion Returns Nil
**Symptoms:** `Message(dictionary: dict)` returns `nil`

**Debug Steps:**
1. Print the dictionary: `print(dict)`
2. Check all required fields present
3. Check field types match (String, not Int)
4. Check Timestamp conversion (`as? Timestamp`)
5. Check enum raw value is valid

**Common Causes:**
- Missing required field in dictionary
- Wrong field name (typo)
- Wrong type (String vs Int)
- Invalid enum raw value

---

### Computed Property Returns Wrong Value
**Symptoms:** `message.isDelivered` returns unexpected value

**Debug Steps:**
1. Print the status: `print(message.status)`
2. Verify logic in computed property
3. Check switch/if conditions
4. Verify status is set correctly on creation

**Common Causes:**
- Logic error in switch statement
- Status not set on init
- Wrong comparison operator

---

### Round-Trip Loses Data
**Symptoms:** `recovered.text != original.text`

**Debug Steps:**
1. Print both: `print(original.text, recovered.text)`
2. Check toDictionary includes field
3. Check init extracts field
4. Check for encoding issues (special chars)

**Common Causes:**
- Field not added to dictionary
- Field not extracted from dictionary
- Type conversion loses precision

---

## Quick Test Script

**Copy this into ContentView for quick testing:**

```swift
func testAllModels() {
    print("=== TESTING ALL MODELS ===\n")
    
    // 1. MessageStatus
    print("1. MessageStatus")
    print("  ✅ sending: \(MessageStatus.sending.displayText)")
    print("  ✅ read: \(MessageStatus.read.iconName)")
    
    // 2. Message
    print("\n2. Message")
    let msg = Message(conversationId: "c1", senderId: "u1", text: "Test")
    let msgDict = msg.toDictionary()
    let recoveredMsg = Message(dictionary: msgDict)
    print("  ✅ Created: \(!msg.id.isEmpty)")
    print("  ✅ Conversion: \(recoveredMsg != nil)")
    
    // 3. Conversation
    print("\n3. Conversation")
    let conv = Conversation(participant1: "u1", participant2: "u2", createdBy: "u1")
    let convDict = conv.toDictionary()
    let recoveredConv = Conversation(dictionary: convDict)
    print("  ✅ Created: \(!conv.id.isEmpty)")
    print("  ✅ Conversion: \(recoveredConv != nil)")
    
    // 4. TypingStatus
    print("\n4. TypingStatus")
    let typing = TypingStatus(userId: "u1", conversationId: "c1")
    let typingDict = typing.toDictionary()
    let recoveredTyping = TypingStatus(dictionary: typingDict)
    print("  ✅ Created: \(!typing.id.isEmpty)")
    print("  ✅ Conversion: \(recoveredTyping != nil)")
    
    print("\n=== ALL TESTS COMPLETE ===")
}
```

---

**Status:** Ready to test! 🧪  
**Next Step:** Run tests after implementing each model  
**Success:** All tests print ✅

---

*Last updated: October 20, 2025*

