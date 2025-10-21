# PR#11: Testing Guide - Message Status Indicators

**Feature:** Visual indicators showing message delivery status (sending/sent/delivered/read)  
**Critical Tests:** 4 integration scenarios (must pass)  
**Estimated Testing Time:** 45 minutes  

---

## Test Categories

### 1. Unit Tests (Code-Level Verification)
Test individual methods and computed properties in isolation.

### 2. Integration Tests (Multi-Device Scenarios)
Test real-world user flows with 2+ devices communicating.

### 3. Edge Cases (Boundary Conditions)
Test unusual scenarios: offline, failed sends, race conditions.

### 4. Performance Tests (Speed & Efficiency)
Verify status updates happen within target timeframes.

### 5. Acceptance Tests (User Experience)
Validate that the feature meets user expectations.

---

## Unit Tests

### Test Suite 1: Message Model Status Logic

#### Test 1.1: statusForSender() - One-on-One Chat
```swift
func test_statusForSender_OneOnOne_ReturnsActualStatus() {
    // Given: 1-on-1 conversation
    let conversation = Conversation(
        id: "conv1",
        participants: ["user1", "user2"],
        isGroup: false
    )
    
    let message = Message(
        id: "msg1",
        conversationId: "conv1",
        senderId: "user1",
        text: "Hello",
        sentAt: Date(),
        status: .read
    )
    
    // When: Get status for sender
    let status = message.statusForSender(in: conversation)
    
    // Then: Returns actual status (not aggregated)
    XCTAssertEqual(status, .read)
}
```

**Expected Result:** Returns `.read` (no aggregation needed for 1-on-1)

---

#### Test 1.2: statusForSender() - Group Chat All Read
```swift
func test_statusForSender_Group_AllRead_ReturnsRead() {
    // Given: Group with 3 participants
    let conversation = Conversation(
        id: "conv1",
        participants: ["user1", "user2", "user3"],
        isGroup: true
    )
    
    var message = Message(
        id: "msg1",
        conversationId: "conv1",
        senderId: "user1",
        text: "Hello group",
        sentAt: Date(),
        status: .sent
    )
    
    // All recipients read
    message.readBy = ["user2", "user3"]
    
    // When: Get status for sender
    let status = message.statusForSender(in: conversation)
    
    // Then: Returns read (all participants read)
    XCTAssertEqual(status, .read)
}
```

**Expected Result:** Returns `.read` (worst status is read)

---

#### Test 1.3: statusForSender() - Group Chat Partial Read
```swift
func test_statusForSender_Group_PartialRead_ReturnsDelivered() {
    // Given: Group with 3 participants
    let conversation = Conversation(
        id: "conv1",
        participants: ["user1", "user2", "user3"],
        isGroup: true
    )
    
    var message = Message(
        id: "msg1",
        conversationId: "conv1",
        senderId: "user1",
        text: "Hello group",
        sentAt: Date(),
        status: .sent
    )
    
    // Only 1 recipient read, 1 delivered
    message.readBy = ["user2"]
    message.deliveredTo = ["user2", "user3"]
    
    // When: Get status for sender
    let status = message.statusForSender(in: conversation)
    
    // Then: Returns delivered (worst status)
    XCTAssertEqual(status, .delivered)
}
```

**Expected Result:** Returns `.delivered` (not all read yet)

---

#### Test 1.4: statusIcon() - Returns Correct SF Symbol
```swift
func test_statusIcon_ReturnsCorrectSymbol() {
    var message = Message(/* ... */)
    
    // Test each status
    message.status = .sending
    XCTAssertEqual(message.statusIcon(), "clock")
    
    message.status = .sent
    XCTAssertEqual(message.statusIcon(), "checkmark")
    
    message.status = .delivered
    XCTAssertEqual(message.statusIcon(), "checkmark.circle")
    
    message.status = .read
    XCTAssertEqual(message.statusIcon(), "checkmark.circle.fill")
    
    message.status = .failed
    XCTAssertEqual(message.statusIcon(), "exclamationmark.triangle.fill")
}
```

**Expected Result:** Each status maps to correct SF Symbol name

---

#### Test 1.5: statusColor() - Returns Correct Color
```swift
func test_statusColor_ReturnsCorrectColor() {
    var message = Message(/* ... */)
    
    // Test sending/sent/delivered = gray
    message.status = .sending
    XCTAssertEqual(message.statusColor(), .gray.opacity(0.6))
    
    message.status = .sent
    XCTAssertEqual(message.statusColor(), .gray)
    
    message.status = .delivered
    XCTAssertEqual(message.statusColor(), .gray)
    
    // Test read = blue
    message.status = .read
    XCTAssertEqual(message.statusColor(), .blue)
    
    // Test failed = red
    message.status = .failed
    XCTAssertEqual(message.statusColor(), .red)
}
```

**Expected Result:** Colors match specification (gray/blue/red)

---

### Test Suite 2: ChatService Status Methods

#### Test 2.1: markMessageAsDelivered() Updates Firestore
```swift
func test_markMessageAsDelivered_UpdatesFirestore() async throws {
    // Given: Message exists in Firestore
    let messageId = "msg123"
    let userId = "user2"
    
    // When: Mark as delivered
    try await chatService.markMessageAsDelivered(
        conversationId: "conv1",
        messageId: messageId,
        userId: userId
    )
    
    // Then: Firestore document updated
    let doc = try await getFirestoreMessage(messageId)
    let deliveredTo = doc["deliveredTo"] as? [String] ?? []
    
    XCTAssertTrue(deliveredTo.contains(userId))
}
```

**Expected Result:** `deliveredTo` array contains userId

---

#### Test 2.2: markAllMessagesAsRead() Batch Updates
```swift
func test_markAllMessagesAsRead_BatchUpdatesMultiple() async throws {
    // Given: 5 unread messages in conversation
    let conversationId = "conv1"
    let userId = "user2"
    
    // Create 5 test messages
    for i in 1...5 {
        try await createTestMessage(
            id: "msg\(i)",
            conversationId: conversationId,
            senderId: "user1"
        )
    }
    
    // When: Mark all as read
    try await chatService.markAllMessagesAsRead(
        conversationId: conversationId,
        userId: userId
    )
    
    // Then: All 5 messages have readBy containing userId
    for i in 1...5 {
        let doc = try await getFirestoreMessage("msg\(i)")
        let readBy = doc["readBy"] as? [String] ?? []
        XCTAssertTrue(readBy.contains(userId), "msg\(i) should be marked as read")
    }
}
```

**Expected Result:** All messages marked as read in batch operation

---

#### Test 2.3: markAllMessagesAsRead() Ignores Own Messages
```swift
func test_markAllMessagesAsRead_IgnoresOwnMessages() async throws {
    // Given: Conversation with own messages
    let conversationId = "conv1"
    let userId = "user1"
    
    // Create message sent by user1
    try await createTestMessage(
        id: "ownMsg",
        conversationId: conversationId,
        senderId: userId
    )
    
    // When: User1 marks all as read
    try await chatService.markAllMessagesAsRead(
        conversationId: conversationId,
        userId: userId
    )
    
    // Then: Own message NOT updated
    let doc = try await getFirestoreMessage("ownMsg")
    let readBy = doc["readBy"] as? [String] ?? []
    XCTAssertFalse(readBy.contains(userId), "Should not mark own message as read")
}
```

**Expected Result:** Own messages not marked as read by self

---

## Integration Tests (Critical - Must Pass)

### Test 3.1: One-on-One Read Receipt Flow

**Setup:**
- Device A: User 1 logged in
- Device B: User 2 logged in
- Both in same conversation

**Steps:**
1. **Device A:** Send message "Hello"
2. **Device A:** Observe status icon
   - Initial: ⏱️ (clock, sending)
   - After 1 second: ✓ (checkmark, sent)
3. **Wait 2 seconds**
4. **Device B:** Verify message received
5. **Device A:** Observe status icon
   - Should show: ✓✓ (double-check gray, delivered)
6. **Device B:** Open conversation (navigate to ChatView)
7. **Wait 2 seconds**
8. **Device A:** Observe status icon
   - Should show: ✓✓ (double-check blue, read)

**Expected Results:**
- [x] Status progresses: ⏱️ → ✓ → ✓✓ (gray) → ✓✓ (blue)
- [x] Each transition happens within 2 seconds
- [x] No flickering or duplicate icons
- [x] Blue checkmark clearly visible
- [x] Status persists after app restart

**Performance Target:** Status update <2 seconds at each stage

---

### Test 3.2: Offline Delivery Confirmation

**Setup:**
- Device A: User 1 online
- Device B: User 2 OFFLINE (airplane mode)

**Steps:**
1. **Device A:** Send message "Test offline"
2. **Device A:** Observe status
   - Should show: ✓ (checkmark, sent)
   - Should NOT show: ✓✓ (delivered)
3. **Wait 5 seconds** (confirm stays at "sent")
4. **Device B:** Disable airplane mode (go online)
5. **Wait 10 seconds** (allow sync)
6. **Device A:** Observe status
   - Should NOW show: ✓✓ (double-check gray, delivered)
7. **Device B:** Open conversation
8. **Wait 2 seconds**
9. **Device A:** Observe status
   - Should show: ✓✓ (double-check blue, read)

**Expected Results:**
- [x] Message stays "sent" while recipient offline
- [x] Updates to "delivered" when recipient comes online
- [x] Updates to "read" when recipient opens conversation
- [x] All updates happen automatically (no manual refresh)
- [x] No duplicate messages

**Performance Target:** Status update <5 seconds after coming online

---

### Test 3.3: Group Chat Status Aggregation

**Setup:**
- Group with 3 users: A, B, C
- Device A: User A logged in
- Device B: User B logged in
- Device C: User C logged in
- All in same group conversation

**Steps:**
1. **Device A:** Send message "Group test"
2. **Device A:** Observe status
   - Initial: ⏱️ (sending)
   - After 1 second: ✓ (sent)
3. **Wait 2 seconds**
4. **Device A:** Observe status
   - Should show: ✓✓ (gray, delivered) - all received but not read
5. **Device B:** Open conversation
6. **Wait 2 seconds**
7. **Device A:** Observe status
   - Should STILL show: ✓✓ (gray, delivered) - only 1/2 read
8. **Device C:** Open conversation
9. **Wait 2 seconds**
10. **Device A:** Observe status
    - Should NOW show: ✓✓ (blue, read) - all read

**Expected Results:**
- [x] Status shows worst case (most conservative)
- [x] Turns gray when all delivered but not all read
- [x] Only turns blue when ALL participants read
- [x] Updates happen in real-time
- [x] No confusion about who read

**Performance Target:** Status update <2 seconds per user action

---

### Test 3.4: Failed Message Indication

**Setup:**
- Device A: User 1 logged in

**Steps:**
1. **Device A:** Start composing message
2. **Device A:** Enable airplane mode
3. **Device A:** Send message "Will fail"
4. **Device A:** Observe status
   - Should show: ⏱️ (clock, sending)
5. **Wait 10 seconds** (timeout)
6. **Device A:** Observe status
   - Should show: ⚠️ (exclamation red, failed)
7. **Device A:** Disable airplane mode
8. **Device A:** Tap failed message (future: retry button)
9. **Expected:** Message resends, status progresses normally

**Expected Results:**
- [x] Failed message shows red exclamation mark
- [x] Failed message persists locally (not lost)
- [x] Message clearly distinguishable from sent
- [x] Retry mechanism available (future PR)

**Performance Target:** Failure detected within 10 seconds

---

## Edge Case Tests

### Test 4.1: Rapid Message Sending
**Scenario:** User sends 10 messages rapidly (1 per second)  
**Expected:** All messages show correct status, no race conditions

### Test 4.2: App Backgrounded During Send
**Scenario:** Send message, immediately background app  
**Expected:** Status updates when app foregrounded

### Test 4.3: Force Quit During Status Update
**Scenario:** Status updating when app force quit  
**Expected:** Status catches up on next launch

### Test 4.4: Network Flapping (On/Off/On)
**Scenario:** Connection goes on/off repeatedly  
**Expected:** Status eventually syncs correctly, no duplicates

### Test 4.5: Very Large Group (20+ people)
**Scenario:** Send message to group with 20+ participants  
**Expected:** Status aggregation works, reasonable performance

---

## Performance Tests

### Test 5.1: Status Update Latency
**Measurement:** Time from action to status update  
**Method:** Timestamp logs in code  
**Target:** <2 seconds  
**Critical:** YES

**Test:**
```swift
// In ChatViewModel
let startTime = Date()
await markConversationAsViewed()
let elapsed = Date().timeIntervalSince(startTime)
print("⏱️ Status update took: \(elapsed)s")
```

**Pass Criteria:** 95% of updates <2 seconds

---

### Test 5.2: Batch Read Performance
**Measurement:** Time to mark 50 messages as read  
**Method:** Create 50 test messages, time batch operation  
**Target:** <500ms  
**Critical:** YES

**Test:**
```swift
let startTime = Date()
try await chatService.markAllMessagesAsRead(
    conversationId: conversationId,
    userId: userId
)
let elapsed = Date().timeIntervalSince(startTime)
print("⏱️ Batch read took: \(elapsed)s for 50 messages")
```

**Pass Criteria:** <500ms consistently

---

### Test 5.3: UI Update Smoothness
**Measurement:** Frame rate during status changes  
**Method:** Visual observation, Instruments  
**Target:** 60fps  
**Critical:** YES

**Test:**
1. Open Instruments → Time Profiler
2. Send 10 messages rapidly
3. Observe status updates
4. Check FPS counter

**Pass Criteria:** No frame drops, smooth transitions

---

### Test 5.4: Firestore Read Count
**Measurement:** Number of reads per user per day  
**Method:** Firebase console → Usage tab  
**Target:** <100 reads/user/day  
**Critical:** NO (monitor only)

**Test:**
1. Simulate normal usage (50 messages sent/received)
2. Check Firebase console after 24 hours
3. Calculate reads per user

**Pass Criteria:** <100 reads/user/day (cost management)

---

## Acceptance Tests (User Experience)

### Test 6.1: Status Clarity
**Question:** Can user understand message state at a glance?  
**Method:** Show to non-technical user, ask "What does this mean?"  
**Expected:** User correctly identifies sent/delivered/read

---

### Test 6.2: Transition Smoothness
**Question:** Do status changes feel smooth and natural?  
**Method:** Send message, observe all transitions  
**Expected:** No jarring jumps, animations feel good

---

### Test 6.3: Visual Hierarchy
**Question:** Does status icon stand out appropriately?  
**Method:** View message bubble, check if status visible but not distracting  
**Expected:** Icon visible, doesn't overpower message content

---

### Test 6.4: Dark Mode Support
**Question:** Are status icons visible in dark mode?  
**Method:** Toggle dark mode, check all 5 status states  
**Expected:** All icons clearly visible, colors appropriate

---

### Test 6.5: Accessibility
**Question:** Can VoiceOver users understand status?  
**Method:** Enable VoiceOver, tap status icon  
**Expected:** Announces "Sent", "Delivered", "Read" correctly

---

## Testing Checklist (Use This!)

### Pre-Testing Setup
- [ ] PR #10 complete (real-time messaging working)
- [ ] Two devices/simulators ready
- [ ] Both logged in as different users
- [ ] Both in same test conversation
- [ ] Firebase console open (monitor Firestore)
- [ ] Stopwatch ready (performance tests)

### Unit Tests
- [ ] All Message model tests passing (5 tests)
- [ ] All ChatService tests passing (3 tests)
- [ ] No compiler warnings or errors

### Integration Tests (Critical)
- [ ] Test 3.1: One-on-one read receipts ✓
- [ ] Test 3.2: Offline delivery confirmation ✓
- [ ] Test 3.3: Group chat status aggregation ✓
- [ ] Test 3.4: Failed message indication ✓

### Edge Case Tests
- [ ] Rapid message sending (10 messages)
- [ ] App backgrounded during send
- [ ] Force quit during status update
- [ ] Network flapping (on/off/on)
- [ ] Large group (20+ people)

### Performance Tests
- [ ] Status update latency (<2 seconds)
- [ ] Batch read performance (<500ms)
- [ ] UI smoothness (60fps)
- [ ] Firestore read count (<100/user/day)

### Acceptance Tests
- [ ] Status clarity (user understands)
- [ ] Transition smoothness (feels good)
- [ ] Visual hierarchy (appropriate emphasis)
- [ ] Dark mode support (visible)
- [ ] Accessibility (VoiceOver works)

### Final Verification
- [ ] All 5 status states tested (sending/sent/delivered/read/failed)
- [ ] Works in light and dark mode
- [ ] No console errors or warnings
- [ ] No memory leaks (Instruments check)
- [ ] Firestore security rules deployed and working

---

## Test Reporting Template

### Test Session Report

**Date:** [Date]  
**Tester:** [Name]  
**Duration:** [Time]  
**Environment:** [Devices/simulators used]

**Tests Passed:** X / Y  
**Tests Failed:** X / Y  
**Blocked Tests:** X / Y

---

### Failed Tests Detail

#### Test 3.1: One-on-One Read Receipts
**Status:** ❌ FAILED  
**Expected:** Status updates to blue checkmark when opened  
**Actual:** Status stays gray, never updates to blue  
**Root Cause:** [Analysis]  
**Fix:** [Solution]  
**Re-test Result:** [Pass/Fail]

---

## Debugging Guide

### Issue: Status Icons Don't Appear

**Symptoms:** Message bubbles render, but no status icon visible

**Debug Steps:**
1. Check MessageBubbleView has status icon code
2. Verify `isSentByCurrentUser` is true
3. Add print: `print("Status: \(message.status), Icon: \(message.statusIcon())")`
4. Check SF Symbol name is correct in Assets

**Common Causes:**
- Missing `if isSentByCurrentUser { }` wrapper
- Wrong SF Symbol name
- Icon color matches background (check opacity)

---

### Issue: Status Never Updates to "Read"

**Symptoms:** Status stays at "delivered" even when conversation opened

**Debug Steps:**
1. Check Firestore console: Is `readBy` array updating?
2. Verify `markAllMessagesAsRead()` is called in ChatViewModel
3. Check real-time listener is handling status updates
4. Add logging in `handleFirestoreMessages()`

**Common Causes:**
- `markConversationAsViewed()` not called
- Real-time listener not updating existing messages
- Firestore security rules deny update
- Network connectivity issue

---

### Issue: Group Status Always Gray (Never Blue)

**Symptoms:** Even when all read, status doesn't turn blue

**Debug Steps:**
1. Check `readBy` array in Firestore for all participants
2. Verify `statusForSender(in:)` logic for groups
3. Add logging: `print("readBy: \(readBy), participants: \(otherParticipants)")`
4. Check `allSatisfy` condition

**Common Causes:**
- Not all participants actually read
- Sender included in `readBy` check (should exclude)
- Group flag not set correctly on conversation

---

## Success Criteria Summary

### Feature Complete When:
✅ All 4 critical integration tests pass  
✅ All 5 status states display correctly  
✅ Performance targets met (<2s latency)  
✅ Works in light and dark mode  
✅ Accessibility labels present  
✅ No memory leaks detected  
✅ Firestore rules deployed and tested

---

**Testing Time Estimate:** 45 minutes  
**Critical Path:** Integration tests (4 scenarios)  
**Most Important:** Test 3.1 (one-on-one read receipts) - this is the core feature

**Remember:** Status indicators are user-facing. Test thoroughly. Users will notice if broken. 🧪

