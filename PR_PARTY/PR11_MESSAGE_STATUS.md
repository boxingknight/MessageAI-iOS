# PR#11: Message Status Indicators

**Estimated Time:** 2-3 hours  
**Complexity:** MEDIUM  
**Dependencies:** PR #4 (Models), PR #5 (ChatService), PR #9 (ChatView), PR #10 (Real-Time Messaging)

---

## Overview

### What We're Building

Message status indicators provide **essential visibility** into the message delivery lifecycle—answering the critical user question: "Did my message get there?" This PR implements:
- **Visual Status Indicators**: Checkmarks, clocks, and colors that show message state
- **Read Receipts**: Track when recipients view messages
- **Delivery Confirmation**: Know when messages reach the recipient's device
- **Status Updates in Real-Time**: See status change as events happen (sent → delivered → read)
- **Group Chat Status**: Handle status for multiple recipients (show most conservative status)

Think: WhatsApp's gray/blue checkmarks, iMessage's "Delivered/Read" text, Telegram's status progression.

### Why It Matters

Users **expect** to know message status. Without it:
- ❌ "Did my message send?" (anxiety)
- ❌ "Did they see it?" (uncertainty)
- ❌ "Should I resend?" (confusion)
- ❌ App feels unreliable (trust issues)

With proper status indicators:
- ✅ Instant confidence message was sent
- ✅ Know when recipient received it
- ✅ See when they've read it
- ✅ Trust the system is working
- ✅ No duplicate sends (clear feedback)

**Industry Standard:** Every major messaging app has this. It's not optional.

### Success in One Sentence

"This PR is successful when users can clearly see the status of every message (sending/sent/delivered/read) with visual indicators that update in real-time, work in both 1-on-1 and group chats, and match the intuitive patterns of WhatsApp/iMessage."

---

## Technical Design

### Architecture Decisions

#### Decision 1: Status Visual Design System

**Options Considered:**
1. **Text Labels Only** - "Sending...", "Sent", "Delivered", "Read"
   - Pros: Explicit, clear
   - Cons: Takes up space, verbose, not standard

2. **Checkmarks + Color** - Gray checkmark (sent), blue double-check (read)
   - Pros: Industry standard, compact, intuitive
   - Cons: Requires learning (first use)

3. **Icons + Timestamps** - Clock, checkmark, eye icon with times
   - Pros: Very explicit
   - Cons: Cluttered, too much information

**Chosen:** Checkmarks + Color (Option 2) - WhatsApp Pattern

**Rationale:**
- WhatsApp has trained 2+ billion users on this pattern
- Compact: fits in message bubble footer
- Intuitive after first exposure
- Accessible: color + shape redundancy (colorblind-friendly)
- Industry standard across iMessage, Telegram, Signal

**Visual Spec:**
```
sending:   ⏱️ Clock icon (gray)
sent:      ✓ Single checkmark (gray)
delivered: ✓✓ Double checkmark (gray)
read:      ✓✓ Double checkmark (blue/tint color)
failed:    ⚠️ Exclamation mark (red)
```

**Trade-offs:**
- Gain: Compact, familiar, scalable, accessible
- Lose: Slight learning curve (acceptable with tooltips/onboarding)

---

#### Decision 2: Read Receipt Tracking Strategy

**Options Considered:**
1. **Manual Tracking** - Send status update on conversation open
   - Pros: Simple
   - Cons: Unreliable (what if user never opens conversation?)

2. **Visibility-Based Tracking** - Mark as read when scrolled into view
   - Pros: Accurate (user actually saw it)
   - Cons: Complex to implement, battery drain

3. **Conversation-Level Tracking** - Mark all as read when conversation opens
   - Pros: Simple, reliable, standard pattern
   - Cons: Less granular (marks all, even if not scrolled)

**Chosen:** Conversation-Level Tracking (Option 3)

**Rationale:**
- WhatsApp/iMessage pattern: opening conversation = reading messages
- Simple to implement reliably
- Low overhead (one Firestore write per conversation open)
- Standard user expectation
- Good enough for MVP (can add granular tracking later)

**Implementation Flow:**
```
User Opens Conversation:
1. ChatView appears
2. Fetch last read timestamp for current user
3. Find all messages after that timestamp
4. Batch update: mark all as read
5. Update Firestore: lastReadAt = now()
6. Firestore triggers status update for senders
7. Sender sees: delivered ✓✓ → read ✓✓ (blue)
```

**Trade-offs:**
- Gain: Simple, reliable, standard, performant
- Lose: Less granular (acceptable for messaging apps)

---

#### Decision 3: Group Chat Status Aggregation

**Problem:** In group chat with 5 people, what status does sender see?
- Person A: read
- Person B: delivered
- Person C: sent
- Person D: sending
- Person E: failed

**Options Considered:**
1. **Show All Statuses** - List each recipient's status
   - Pros: Complete information
   - Cons: Cluttered, overwhelming

2. **Show Worst Status** - Display most conservative (sending > sent > delivered > read)
   - Pros: Clear single indicator, conservative
   - Cons: Hides progress (if 4/5 read, still shows "sent")

3. **Show Count** - "Read by 3/5"
   - Pros: Shows progress
   - Cons: Takes space, less intuitive

4. **Hybrid** - Show worst status icon + tap for details
   - Pros: Compact + detailed
   - Cons: Requires modal/sheet

**Chosen:** Show Worst Status (Option 2) for MVP

**Rationale:**
- Simple to implement
- Clear single source of truth
- Conservative (if one person hasn't received, sender sees "sent")
- Matches WhatsApp pattern
- Can add detailed view in future PR (tap to see list)

**Implementation Logic:**
```swift
func aggregateStatus(participants: [Participant]) -> MessageStatus {
    let statuses = participants.map { $0.messageStatus }
    
    // Priority order (worst to best)
    if statuses.contains(.failed) { return .failed }
    if statuses.contains(.sending) { return .sending }
    if statuses.contains(.sent) { return .sent }
    if statuses.contains(.delivered) { return .delivered }
    
    // All read
    return .read
}
```

**Trade-offs:**
- Gain: Simple, clear, reliable, MVP-appropriate
- Lose: Granularity (defer to future PR)

---

#### Decision 4: Status Update Propagation

**Options Considered:**
1. **Poll for Updates** - Check Firestore every N seconds
   - Pros: Simple
   - Cons: High latency, wasted requests

2. **Firestore Listeners on Status Subcollection** - Track per-user status
   - Pros: Real-time, accurate
   - Cons: Complex schema, more reads

3. **Update Message Document Directly** - Store status in message doc
   - Pros: Simple schema, works with existing listeners
   - Cons: Requires merge strategy for group chats

**Chosen:** Update Message Document (Option 3) with Smart Merging

**Rationale:**
- Simplest schema: message document has `readBy: [userId]` array
- Works with existing Firestore snapshot listeners (PR #10)
- Real-time updates (<2 seconds)
- Efficient: one update per user
- Scalable: up to 50 participants (Firebase array limit)

**Schema Addition:**
```javascript
// In Firestore: /conversations/{id}/messages/{msgId}
{
  id: "msg123",
  senderId: "user1",
  text: "Hello",
  sentAt: Timestamp,
  status: "sent", // sender's perspective
  
  // NEW: Recipient tracking
  deliveredTo: ["user2", "user3"], // Array of user IDs
  readBy: ["user2"]                // Array of user IDs
}
```

**Trade-offs:**
- Gain: Simple, real-time, works with existing code
- Lose: Limited to 50 participants (acceptable for MVP)

---

### Data Model Changes

#### Updated Message Model

```swift
// Models/Message.swift

struct Message: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let conversationId: String
    let senderId: String
    let text: String
    let imageURL: String?
    let sentAt: Date
    var deliveredAt: Date?  // When first delivered to ANY recipient
    var readAt: Date?       // When first read by ANY recipient
    var status: MessageStatus
    
    // NEW: Recipient tracking (for group chats)
    var deliveredTo: [String] = []  // Array of user IDs who received
    var readBy: [String] = []       // Array of user IDs who read
    
    // MARK: - Computed Properties
    
    /// Returns status from current user's perspective
    func statusForSender(in conversation: Conversation) -> MessageStatus {
        // If failed, show failed
        if status == .failed || status == .sending {
            return status
        }
        
        // For 1-on-1, simple status
        if !conversation.isGroup {
            return status
        }
        
        // For group: aggregate based on recipients
        let otherParticipants = conversation.participants.filter { $0 != senderId }
        
        // Check read status
        let allRead = otherParticipants.allSatisfy { readBy.contains($0) }
        if allRead { return .read }
        
        // Check delivered status
        let allDelivered = otherParticipants.allSatisfy { deliveredTo.contains($0) }
        if allDelivered { return .delivered }
        
        // At least sent
        return .sent
    }
    
    /// Returns visual indicator for message status
    func statusIcon() -> String {
        switch status {
        case .sending:
            return "clock"
        case .sent:
            return "checkmark"
        case .delivered:
            return "checkmark.circle"
        case .read:
            return "checkmark.circle.fill"
        case .failed:
            return "exclamationmark.triangle"
        }
    }
    
    /// Returns color for status icon
    func statusColor() -> Color {
        switch status {
        case .sending:
            return .gray
        case .sent:
            return .gray
        case .delivered:
            return .gray
        case .read:
            return .blue
        case .failed:
            return .red
        }
    }
    
    // MARK: - Firestore Conversion
    
    init(from dict: [String: Any]) throws {
        guard let id = dict["id"] as? String,
              let conversationId = dict["conversationId"] as? String,
              let senderId = dict["senderId"] as? String,
              let text = dict["text"] as? String,
              let sentAtTimestamp = dict["sentAt"] as? Timestamp else {
            throw MessageError.invalidData
        }
        
        self.id = id
        self.conversationId = conversationId
        self.senderId = senderId
        self.text = text
        self.imageURL = dict["imageURL"] as? String
        self.sentAt = sentAtTimestamp.dateValue()
        
        // Optional timestamps
        if let deliveredAtTimestamp = dict["deliveredAt"] as? Timestamp {
            self.deliveredAt = deliveredAtTimestamp.dateValue()
        }
        if let readAtTimestamp = dict["readAt"] as? Timestamp {
            self.readAt = readAtTimestamp.dateValue()
        }
        
        // Status
        if let statusString = dict["status"] as? String,
           let messageStatus = MessageStatus(rawValue: statusString) {
            self.status = messageStatus
        } else {
            self.status = .sent
        }
        
        // NEW: Recipient tracking
        self.deliveredTo = dict["deliveredTo"] as? [String] ?? []
        self.readBy = dict["readBy"] as? [String] ?? []
    }
    
    func toFirestoreData() -> [String: Any] {
        var data: [String: Any] = [
            "id": id,
            "conversationId": conversationId,
            "senderId": senderId,
            "text": text,
            "sentAt": Timestamp(date: sentAt),
            "status": status.rawValue,
            "deliveredTo": deliveredTo,
            "readBy": readBy
        ]
        
        if let imageURL = imageURL {
            data["imageURL"] = imageURL
        }
        if let deliveredAt = deliveredAt {
            data["deliveredAt"] = Timestamp(date: deliveredAt)
        }
        if let readAt = readAt {
            data["readAt"] = Timestamp(date: readAt)
        }
        
        return data
    }
}
```

---

### ChatService Extensions

#### Add Status Update Methods

```swift
// Services/ChatService.swift

// MARK: - Status Tracking

/// Mark message as delivered to current user
func markMessageAsDelivered(
    conversationId: String,
    messageId: String,
    userId: String
) async throws {
    let messageRef = db.collection("conversations")
        .document(conversationId)
        .collection("messages")
        .document(messageId)
    
    try await messageRef.updateData([
        "deliveredTo": FieldValue.arrayUnion([userId]),
        "deliveredAt": FieldValue.serverTimestamp()
    ])
}

/// Mark message as read by current user
func markMessageAsRead(
    conversationId: String,
    messageId: String,
    userId: String
) async throws {
    let messageRef = db.collection("conversations")
        .document(conversationId)
        .collection("messages")
        .document(messageId)
    
    try await messageRef.updateData([
        "readBy": FieldValue.arrayUnion([userId]),
        "readAt": FieldValue.serverTimestamp()
    ])
}

/// Batch mark all messages in conversation as read
func markAllMessagesAsRead(
    conversationId: String,
    userId: String,
    upToDate: Date
) async throws {
    let messagesQuery = db.collection("conversations")
        .document(conversationId)
        .collection("messages")
        .whereField("sentAt", isLessThanOrEqualTo: Timestamp(date: upToDate))
        .whereField("senderId", isNotEqualTo: userId) // Don't mark own messages as read
    
    let snapshot = try await messagesQuery.getDocuments()
    
    let batch = db.batch()
    
    for document in snapshot.documents {
        let messageRef = document.reference
        
        // Only update if not already read by this user
        let readBy = document.data()["readBy"] as? [String] ?? []
        if !readBy.contains(userId) {
            batch.updateData([
                "readBy": FieldValue.arrayUnion([userId]),
                "readAt": FieldValue.serverTimestamp()
            ], forDocument: messageRef)
        }
    }
    
    try await batch.commit()
}

/// Mark messages as delivered when conversation opened (background)
func markMessagesAsDelivered(
    conversationId: String,
    userId: String
) async throws {
    let messagesQuery = db.collection("conversations")
        .document(conversationId)
        .collection("messages")
        .whereField("senderId", isNotEqualTo: userId)
    
    let snapshot = try await messagesQuery.getDocuments()
    
    let batch = db.batch()
    
    for document in snapshot.documents {
        let messageRef = document.reference
        
        // Only update if not already delivered to this user
        let deliveredTo = document.data()["deliveredTo"] as? [String] ?? []
        if !deliveredTo.contains(userId) {
            batch.updateData([
                "deliveredTo": FieldValue.arrayUnion([userId])
            ], forDocument: messageRef)
        }
    }
    
    try await batch.commit()
}
```

---

## Implementation Details

### File Structure

**Modified Files:**
```
messAI/
├── Models/
│   └── Message.swift (+ ~80 lines)
│       Add:
│       - deliveredTo: [String]
│       - readBy: [String]
│       - statusForSender(in:) computed property
│       - statusIcon() helper
│       - statusColor() helper
│
├── Services/
│   └── ChatService.swift (+ ~120 lines)
│       Add:
│       - markMessageAsDelivered()
│       - markMessageAsRead()
│       - markAllMessagesAsRead()
│       - markMessagesAsDelivered()
│
├── ViewModels/
│   └── ChatViewModel.swift (+ ~60 lines)
│       Add:
│       - markConversationAsRead() on appear
│       - markMessagesDelivered() on appear
│       - Handle status updates from Firestore
│
└── Views/
    └── Chat/
        └── MessageBubbleView.swift (+ ~40 lines)
            Add:
            - Status icon display (footer)
            - Color coding based on status
            - Timestamp + status horizontal stack
```

**No New Files:** All changes are enhancements to existing files

**Total New Code:** ~300 lines  
**Total Modified Files:** 4 files

---

### Key Implementation Steps

#### Phase 1: Message Model Updates (30-40 minutes)

**Step 1.1: Update Message Model**
```swift
// In Models/Message.swift

// Add recipient tracking properties
var deliveredTo: [String] = []
var readBy: [String] = []

// Add computed property for group status
func statusForSender(in conversation: Conversation) -> MessageStatus {
    if status == .failed || status == .sending {
        return status
    }
    
    if !conversation.isGroup {
        return status
    }
    
    let otherParticipants = conversation.participants.filter { $0 != senderId }
    
    if otherParticipants.allSatisfy({ readBy.contains($0) }) {
        return .read
    }
    
    if otherParticipants.allSatisfy({ deliveredTo.contains($0) }) {
        return .delivered
    }
    
    return .sent
}

// Add helper for icon/color
func statusIcon() -> String {
    switch status {
    case .sending: return "clock"
    case .sent: return "checkmark"
    case .delivered: return "checkmark.circle"
    case .read: return "checkmark.circle.fill"
    case .failed: return "exclamationmark.triangle"
    }
}

func statusColor() -> Color {
    switch status {
    case .sending, .sent, .delivered: return .gray
    case .read: return .blue
    case .failed: return .red
    }
}

// Update Firestore conversion
init(from dict: [String: Any]) throws {
    // ... existing code ...
    
    // NEW: Parse recipient arrays
    self.deliveredTo = dict["deliveredTo"] as? [String] ?? []
    self.readBy = dict["readBy"] as? [String] ?? []
}

func toFirestoreData() -> [String: Any] {
    var data: [String: Any] = [
        // ... existing fields ...
        "deliveredTo": deliveredTo,
        "readBy": readBy
    ]
    return data
}
```

---

#### Phase 2: ChatService Status Methods (40-50 minutes)

**Step 2.1: Add Status Update Methods**
```swift
// In Services/ChatService.swift

func markMessageAsDelivered(
    conversationId: String,
    messageId: String,
    userId: String
) async throws {
    let messageRef = db.collection("conversations")
        .document(conversationId)
        .collection("messages")
        .document(messageId)
    
    try await messageRef.updateData([
        "deliveredTo": FieldValue.arrayUnion([userId]),
        "deliveredAt": FieldValue.serverTimestamp()
    ])
}

func markMessageAsRead(
    conversationId: String,
    messageId: String,
    userId: String
) async throws {
    let messageRef = db.collection("conversations")
        .document(conversationId)
        .collection("messages")
        .document(messageId)
    
    try await messageRef.updateData([
        "readBy": FieldValue.arrayUnion([userId]),
        "readAt": FieldValue.serverTimestamp()
    ])
}

func markAllMessagesAsRead(
    conversationId: String,
    userId: String,
    upToDate: Date = Date()
) async throws {
    let messagesQuery = db.collection("conversations")
        .document(conversationId)
        .collection("messages")
        .whereField("sentAt", isLessThanOrEqualTo: Timestamp(date: upToDate))
        .whereField("senderId", isNotEqualTo: userId)
    
    let snapshot = try await messagesQuery.getDocuments()
    
    let batch = db.batch()
    
    for document in snapshot.documents {
        let readBy = document.data()["readBy"] as? [String] ?? []
        if !readBy.contains(userId) {
            batch.updateData([
                "readBy": FieldValue.arrayUnion([userId]),
                "readAt": FieldValue.serverTimestamp()
            ], forDocument: document.reference)
        }
    }
    
    try await batch.commit()
}
```

---

#### Phase 3: ChatViewModel Integration (30-40 minutes)

**Step 3.1: Add Lifecycle Status Updates**
```swift
// In ViewModels/ChatViewModel.swift

func markConversationAsViewed() async {
    // Called when ChatView appears
    do {
        // Mark messages as delivered (opened app)
        try await chatService.markMessagesAsDelivered(
            conversationId: conversationId,
            userId: currentUserId
        )
        
        // Mark messages as read (viewing conversation)
        try await chatService.markAllMessagesAsRead(
            conversationId: conversationId,
            userId: currentUserId
        )
        
    } catch {
        print("⚠️ Failed to update message status: \(error)")
    }
}

// Update loadMessages() to call markConversationAsViewed
func loadMessages() async {
    isLoading = true
    
    do {
        let localEntities = try localDataManager.fetchMessages(
            conversationId: conversationId
        )
        messages = localEntities.map { Message(from: $0) }
        isLoading = false
        
        startRealtimeSync()
        
        // NEW: Mark conversation as viewed
        await markConversationAsViewed()
        
    } catch {
        errorMessage = "Failed to load messages: \(error.localizedDescription)"
        showError = true
        isLoading = false
    }
}
```

---

#### Phase 4: MessageBubbleView Status Display (30-40 minutes)

**Step 4.1: Add Status Indicator to Bubble**
```swift
// In Views/Chat/MessageBubbleView.swift

// Update the message bubble footer
HStack(spacing: 4) {
    Text(message.sentAt, style: .time)
        .font(.caption2)
        .foregroundColor(isSentByCurrentUser ? .white.opacity(0.7) : .secondary)
    
    // NEW: Status indicator (only for sent messages)
    if isSentByCurrentUser {
        Image(systemName: message.statusIcon())
            .font(.caption2)
            .foregroundColor(message.statusColor())
            .opacity(message.status == .read ? 1.0 : 0.7)
    }
}
.padding(.top, 2)
```

**Step 4.2: Add Status Indicator Definitions**
```swift
// Extension on Message for status display
extension Message {
    func statusIcon() -> String {
        switch status {
        case .sending:
            return "clock"
        case .sent:
            return "checkmark"
        case .delivered:
            return "checkmark.circle"
        case .read:
            return "checkmark.circle.fill"
        case .failed:
            return "exclamationmark.triangle.fill"
        }
    }
    
    func statusColor() -> Color {
        switch status {
        case .sending:
            return .gray.opacity(0.6)
        case .sent:
            return .gray
        case .delivered:
            return .gray
        case .read:
            return .blue
        case .failed:
            return .red
        }
    }
    
    func statusText() -> String? {
        // Optional: tooltip or accessibility label
        switch status {
        case .sending: return "Sending..."
        case .sent: return "Sent"
        case .delivered: return "Delivered"
        case .read: return "Read"
        case .failed: return "Failed to send"
        }
    }
}
```

---

## Testing Strategy

### Unit Tests

**Message Model Tests:**
```swift
func testStatusForSender_GroupChat_AllRead() {
    // Given: Group conversation with 3 participants
    // Message read by all recipients
    // When: Call statusForSender()
    // Then: Returns .read
}

func testStatusForSender_GroupChat_PartialRead() {
    // Given: Group conversation, 2/3 read
    // When: Call statusForSender()
    // Then: Returns .delivered (worst status)
}

func testStatusIcon_ReturnsCorrectSFSymbol() {
    // Given: Message with each status
    // When: Call statusIcon()
    // Then: Returns correct SF Symbol name
}

func testStatusColor_ReturnsCorrectColor() {
    // Given: Message with .read status
    // When: Call statusColor()
    // Then: Returns .blue
}
```

**ChatService Tests:**
```swift
func testMarkMessageAsDelivered_UpdatesFirestore() async {
    // Given: Message exists in Firestore
    // When: markMessageAsDelivered() called
    // Then: deliveredTo array contains userId
}

func testMarkAllMessagesAsRead_BatchUpdates() async {
    // Given: 5 unread messages in conversation
    // When: markAllMessagesAsRead() called
    // Then: All 5 messages have readBy containing userId
}

func testMarkAllMessagesAsRead_IgnoresOwnMessages() async {
    // Given: Conversation with own messages
    // When: markAllMessagesAsRead() called
    // Then: Own messages not updated
}
```

---

### Integration Tests

**Read Receipt Test (Critical):**
```
Test: User A sees "read" when User B opens conversation
Setup:
- Device A logged in as User 1
- Device B logged in as User 2
- User 1 sends message "Hello"

Steps:
1. User 1 sends message
2. Verify message shows ✓ (sent) on Device A
3. User 2 opens conversation on Device B
4. Wait 2 seconds
5. Check Device A

Expected:
- Device A shows ✓✓ (blue) read status
- Status update happens within 2 seconds
- Message bubble updates visually
```

---

**Delivery Confirmation Test:**
```
Test: Message marked as delivered when recipient is online
Setup:
- Device A (User 1), Device B (User 2)
- Both online, both in conversation

Steps:
1. User 1 sends "Test message"
2. Wait 1 second
3. Check status on Device A

Expected:
- Status progresses: ⏱️ → ✓ → ✓✓ (gray) within 2 seconds
- Each transition visible
- Final status: delivered (gray double-check)
```

---

**Group Chat Status Test:**
```
Test: Group chat shows worst status
Setup:
- Group with 3 users: A, B, C
- User A sends message
- User B opens conversation (reads)
- User C doesn't open (only delivered)

Steps:
1. User A sends message in group
2. User B opens conversation
3. User C's device receives (but doesn't open)
4. Check status on User A's device

Expected:
- Initially: ✓ (sent)
- After B reads: ✓✓ (delivered - because C hasn't read)
- After C reads: ✓✓ (blue - all read)
```

---

**Offline Status Test:**
```
Test: Status updates when user comes online
Setup:
- Device A online
- Device B offline (airplane mode)

Steps:
1. User A sends message
2. Device A shows ✓ (sent)
3. Device B goes online
4. Device B receives message (but doesn't open conversation)
5. Wait 2 seconds
6. Check Device A

Expected:
- Device A status updates to ✓✓ (delivered)
- Update happens automatically (no refresh needed)
```

---

## Success Criteria

### Feature Complete When:

- [ ] Message bubbles show status icons (clock/checkmark/double-check)
- [ ] Status icons color-coded correctly (gray/blue/red)
- [ ] Status updates in real-time (no refresh needed)
- [ ] Opening conversation marks messages as read
- [ ] Read receipts work in 1-on-1 chats
- [ ] Group chat shows aggregated status (worst status)
- [ ] Delivered status works when recipient online
- [ ] Failed messages show red exclamation mark
- [ ] Status persists through app restart
- [ ] All unit tests passing (8+ tests)
- [ ] All integration tests passing (4 critical scenarios)
- [ ] Accessibility labels for status icons
- [ ] Works offline → online (status catches up)

---

### Performance Targets

| Metric | Target | Measurement Method |
|--------|--------|-------------------|
| Status update latency | <2 seconds | Send → recipient opens → status update |
| Batch read operation | <500ms | Mark 50 messages as read |
| UI update smoothness | 60fps | Status icon transition |
| Firestore read cost | <100 reads/user/day | Monitor Firebase console |

---

## Risk Assessment

### Risk 1: Firestore Array Size Limits 🟡 MEDIUM
**Issue:** Firebase arrays limited to 1,000 items, but practical limit ~50  
**Impact:** Group chats with 50+ participants can't track individual status  
**Mitigation:**
- Document limit in code comments
- For MVP: 50 participant limit acceptable
- Future: Switch to subcollection if needed
- Status: ACCEPT for MVP

---

### Risk 2: Read Receipt Privacy Concerns 🟢 LOW
**Issue:** Some users don't want senders to know they read messages  
**Impact:** Privacy feature request  
**Mitigation:**
- MVP: Always show read receipts (standard for messaging)
- Future PR: Add setting to disable read receipts
- Industry standard: WhatsApp/iMessage have toggle
- Status: DEFER to future PR

---

### Risk 3: Status Update Race Conditions 🟡 MEDIUM
**Issue:** Multiple users marking as read simultaneously  
**Impact:** Firestore conflicts, slow updates  
**Mitigation:**
- Use `FieldValue.arrayUnion()` (idempotent)
- Firestore handles conflicts automatically
- Test with 2+ users marking simultaneously
- Status: MITIGATED

---

### Risk 4: Excessive Firestore Writes 🟢 LOW
**Issue:** Every conversation open = batch write  
**Impact:** Firebase costs could grow  
**Mitigation:**
- Check if already read before writing
- Batch operations (cheaper than individual)
- Monitor Firebase usage dashboard
- For MVP: acceptable cost (<$5/month)
- Status: ACCEPT

---

## Timeline

**Total Estimate:** 2-3 hours

| Phase | Task | Time |
|-------|------|------|
| 1 | Message model updates | 30-40 min |
| 2 | ChatService status methods | 40-50 min |
| 3 | ChatViewModel integration | 30-40 min |
| 4 | MessageBubbleView UI | 30-40 min |
| 5 | Testing & verification | 20-30 min |

---

## Dependencies

### Requires:
- [x] PR #4: Core Models (Message, MessageStatus enum)
- [x] PR #5: ChatService (Firestore operations)
- [ ] PR #9: ChatView UI (MessageBubbleView exists)
- [ ] PR #10: Real-Time Messaging (Firestore listeners working)

### Blocks:
- PR #12: Presence & Typing (can build on status infrastructure)
- PR #14: Image Sharing (uses same status pattern)

---

## Firestore Security Rules Update

```javascript
// Add to firebase/firestore.rules

rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    match /conversations/{conversationId}/messages/{messageId} {
      // ... existing rules ...
      
      // Allow participants to update deliveredTo and readBy arrays
      allow update: if request.auth != null
                    && request.auth.uid in get(/databases/$(database)/documents/conversations/$(conversationId)).data.participants
                    && request.resource.data.diff(resource.data).affectedKeys().hasOnly(['deliveredTo', 'readBy', 'deliveredAt', 'readAt', 'status'])
                    && request.auth.uid in request.resource.data.deliveredTo
                    || request.auth.uid in request.resource.data.readBy;
    }
  }
}
```

**Deploy:**
```bash
firebase deploy --only firestore:rules
```

---

## Open Questions

1. **Should we show timestamps for each status?**
   - **Decision:** No, too cluttered. Just show sent timestamp
   - **Reason:** Standard pattern, keeps bubble clean

2. **Should users be able to disable read receipts?**
   - **Decision:** No for MVP, yes for future PR
   - **Reason:** Standard feature, but not critical for launch

3. **How to handle status in very large groups (100+ people)?**
   - **Decision:** Defer to future PR, 50 participant limit for MVP
   - **Reason:** Firebase array limits, edge case

---

*This specification provides complete technical design for PR #11. Message status indicators are essential UX—prioritize clarity and reliability over complexity.*

