# PR#10: Real-Time Messaging & Optimistic UI - Testing Guide

**Total Test Scenarios:** 32 (5 unit, 10 integration, 8 edge cases, 4 performance, 5 acceptance)  
**Estimated Testing Time:** 1-2 hours  
**Critical Tests:** 5 (must pass for MVP)

---

## Test Categories

### 1. Unit Tests (Optional for MVP)
### 2. Integration Tests (CRITICAL - Required)
### 3. Edge Case Tests (Important)
### 4. Performance Tests (Verify targets)
### 5. Acceptance Tests (User scenarios)

---

## Unit Tests (Optional for MVP)

### Test 1.1: Optimistic Message Creation
**Function:** `ChatViewModel.sendMessage()`

**Test Case:**
```swift
func testSendMessageCreatesOptimisticMessage() async {
    // Given: ChatViewModel with empty messages array
    let viewModel = ChatViewModel(
        conversationId: "test-conv",
        chatService: MockChatService(),
        localDataManager: MockLocalDataManager()
    )
    
    // When: sendMessage() called
    viewModel.messageText = "Hello"
    viewModel.sendMessage()
    
    // Then: Message appears with correct properties
    XCTAssertEqual(viewModel.messages.count, 1)
    XCTAssertEqual(viewModel.messages[0].text, "Hello")
    XCTAssertEqual(viewModel.messages[0].status, .sending)
    XCTAssertFalse(viewModel.messages[0].id.isEmpty)
    XCTAssertEqual(viewModel.messageText, "") // Input cleared
}
```

**Expected:** ✅ Message created with status .sending, input cleared

---

### Test 1.2: Message Status Updates
**Function:** `ChatViewModel.updateMessageStatus()`

**Test Case:**
```swift
func testUpdateMessageStatusChangesStatus() {
    // Given: Message with status .sending
    let message = Message(id: "test-id", status: .sending)
    viewModel.messages = [message]
    
    // When: Status updated to .sent
    viewModel.updateMessageStatus("test-id", to: .sent)
    
    // Then: Status changed correctly
    XCTAssertEqual(viewModel.messages[0].status, .sent)
}
```

**Expected:** ✅ Status changes from .sending → .sent

---

### Test 1.3: Message Deduplication
**Function:** `ChatViewModel.handleFirestoreMessages()`

**Test Case:**
```swift
func testHandleFirestoreMessagesPreventsDuplicates() async {
    // Given: Message already exists with id="msg-123"
    let existingMessage = Message(id: "msg-123", text: "Hello")
    viewModel.messages = [existingMessage]
    
    // When: Firestore emits same message again
    let firebaseMessage = Message(id: "msg-123", text: "Hello", status: .sent)
    await viewModel.handleFirestoreMessages([firebaseMessage])
    
    // Then: Only 1 message exists, status updated
    XCTAssertEqual(viewModel.messages.count, 1)
    XCTAssertEqual(viewModel.messages[0].status, .sent)
}
```

**Expected:** ✅ No duplicate, status updated

---

### Test 1.4: Optimistic Message Replacement
**Function:** `ChatViewModel.updateOptimisticMessage()`

**Test Case:**
```swift
func testOptimisticMessageReplacedWithServerMessage() {
    // Given: Optimistic message with tempId
    let tempId = "temp-123"
    let serverId = "server-abc"
    let optimisticMessage = Message(id: tempId, status: .sending)
    viewModel.messages = [optimisticMessage]
    viewModel.messageIdMap[tempId] = serverId
    
    // When: Server message arrives
    let serverMessage = Message(id: serverId, status: .sent)
    viewModel.updateOptimisticMessage(tempId: tempId, serverMessage: serverMessage)
    
    // Then: Temp message replaced
    XCTAssertEqual(viewModel.messages[0].id, serverId)
    XCTAssertEqual(viewModel.messages[0].status, .sent)
    XCTAssertNil(viewModel.messageIdMap[tempId])
}
```

**Expected:** ✅ Temp ID replaced with server ID, map cleaned up

---

### Test 1.5: Can Send Message Validation
**Function:** `ChatViewModel.canSendMessage`

**Test Case:**
```swift
func testCanSendMessageValidation() {
    // Test valid message
    viewModel.messageText = "Hello"
    XCTAssertTrue(viewModel.canSendMessage)
    
    // Test empty string
    viewModel.messageText = ""
    XCTAssertFalse(viewModel.canSendMessage)
    
    // Test whitespace only
    viewModel.messageText = "   "
    XCTAssertFalse(viewModel.canSendMessage)
    
    // Test newlines only
    viewModel.messageText = "\n\n"
    XCTAssertFalse(viewModel.canSendMessage)
}
```

**Expected:** ✅ Validation correct for all cases

---

## Integration Tests (CRITICAL - Required)

### Test 2.1: Real-Time Message Delivery 🔴 CRITICAL
**Scenario:** Two users can message each other in real-time

**Setup:**
- Device A logged in as User 1
- Device B logged in as User 2
- Both devices in same conversation

**Steps:**
1. **Device A:** Send message "Hello from A"
   - [ ] Verify message appears immediately on Device A
   - [ ] Verify status shows "sending..."
   - [ ] Start timer

2. **Wait for delivery:**
   - [ ] Measure time until Device B receives
   - [ ] Should be <2 seconds

3. **Device B:** Verify message received
   - [ ] Message appears with correct text
   - [ ] Sender attribution correct (User 1)
   - [ ] Timestamp is recent

4. **Device B:** Send message "Hello from B"
   - [ ] Verify appears immediately on Device B
   - [ ] Device A receives within 2 seconds

**Expected:**
- ✅ Device A sees message in <50ms
- ✅ Device B receives in <2 seconds
- ✅ Messages appear in correct order
- ✅ No duplicates on either device
- ✅ Works bidirectionally

**Pass Criteria:** 
- Instant on sender (<50ms)
- Delivery to recipient (<2s)
- No duplicates
- Correct attribution

---

### Test 2.2: Optimistic UI Instant Feedback 🔴 CRITICAL
**Scenario:** Message appears instantly when sent

**Setup:**
- Single device, conversation open

**Steps:**
1. Type message "Test instant feedback"
2. Tap send button
3. **Immediately** observe UI (within 50ms)

**Expected:**
- ✅ Message bubble appears immediately
- ✅ Input field clears immediately
- ✅ Keyboard remains visible
- ✅ Status indicator shows "sending..."
- ✅ After 1-2 seconds, status changes to "sent"

**Measurement:** 
- Use slow-motion video on iPhone (240fps) if needed
- Should see message within 2-3 frames = <50ms

**Pass Criteria:** Message visible in <50ms

---

### Test 2.3: Offline Message Queue 🔴 CRITICAL
**Scenario:** Messages queue offline and sync automatically

**Setup:**
- Device A online, conversation open

**Steps:**
1. **Enable airplane mode** on Device A
   - [ ] Verify network banner appears ("No connection...")

2. **Send 3 messages** while offline:
   - "Message 1"
   - "Message 2"  
   - "Message 3"
   - [ ] All 3 appear locally
   - [ ] All show "sending..." status
   - [ ] Verify stored in Core Data

3. **Wait 10 seconds** (still offline)
   - [ ] Messages still visible
   - [ ] Status unchanged

4. **Disable airplane mode**
   - [ ] Network banner disappears
   - [ ] Wait 5 seconds

5. **Verify auto-sync:**
   - [ ] All 3 messages upload to Firestore
   - [ ] Status changes: sending → sent
   - [ ] Device B (if available) receives all 3

**Expected:**
- ✅ All 3 messages visible offline
- ✅ No errors or crashes
- ✅ Automatic sync when online
- ✅ Messages delivered in correct order
- ✅ No messages lost

**Pass Criteria:** 100% message delivery, correct order

---

### Test 2.4: Message Deduplication 🔴 CRITICAL
**Scenario:** No duplicate messages with optimistic UI

**Setup:**
- Device A, simulate slow network (3G)
- Settings → Developer → Network Link Conditioner → 3G

**Steps:**
1. Send message "Deduplication test"
2. Observe carefully:
   - [ ] Message appears immediately (optimistic)
   - [ ] Wait 3-4 seconds (3G delay)
   - [ ] Firestore confirmation arrives
   - [ ] Count message bubbles

**Expected:**
- ✅ Only 1 message bubble visible at all times
- ✅ No flicker or duplicate appearance
- ✅ Status updates smoothly: sending → sent
- ✅ No "flash" when Firestore confirms

**Pass Criteria:** Exactly 1 message bubble, no duplicates

---

### Test 2.5: Listener Lifecycle Management 🟡 HIGH
**Scenario:** Listener starts/stops properly with view lifecycle

**Setup:**
- Device A, Xcode with console logs visible

**Steps:**
1. **Open ChatView:**
   - [ ] Check console for "🎧 Starting real-time listener"
   
2. **Stay in ChatView for 30 seconds:**
   - [ ] Send/receive a few messages
   - [ ] Verify updates arrive

3. **Navigate back to ChatListView:**
   - [ ] Check console for "🛑 Stopping real-time listener"

4. **Reopen same ChatView:**
   - [ ] Check console for "🎧 Starting real-time listener" again

5. **Send message from Device B:**
   - [ ] Verify Device A receives (listener working)

**Expected:**
- ✅ Listener starts on view appear
- ✅ Listener stops on view disappear
- ✅ Listener restarts on reappear
- ✅ No memory leaks (test with Instruments)

**Pass Criteria:** Logs match lifecycle, messages still arrive

---

### Test 2.6: Status Update Propagation
**Scenario:** Message status updates reflect across all states

**Setup:**
- 2 devices, conversation open on both

**Steps:**
1. **Device A:** Send message "Status test"
   - [ ] Status shows "sending..." immediately
   
2. **After 1-2 seconds:**
   - [ ] Status changes to "sent" (uploaded to Firestore)

3. **Device B:** Open conversation
   - [ ] Message appears
   - [ ] Status on Device A changes to "delivered"

4. **Device B:** (Already viewing messages)
   - [ ] Status on Device A changes to "read"

**Expected:**
- ✅ Status: sending → sent → delivered → read
- ✅ Updates appear in <2 seconds
- ✅ Icons change correctly (checkmarks, colors)

**Pass Criteria:** All status transitions work

---

### Test 2.7: Multiple Messages Rapid Fire
**Scenario:** Send many messages quickly, all deliver

**Setup:**
- 2 devices

**Steps:**
1. **Device A:** Send 10 messages rapidly:
   - "Message 1"
   - "Message 2"
   - ...
   - "Message 10"
   - Send as fast as possible (tap tap tap)

2. **Device A:** Verify locally:
   - [ ] All 10 messages visible
   - [ ] In correct order
   - [ ] No duplicates

3. **Wait 5 seconds**

4. **Device B:** Check received messages:
   - [ ] All 10 messages arrive
   - [ ] Correct order
   - [ ] No duplicates

**Expected:**
- ✅ All 10 messages deliver
- ✅ Correct chronological order
- ✅ No lost messages
- ✅ No duplicates

**Pass Criteria:** 100% delivery, correct order

---

### Test 2.8: App Backgrounding & Foregrounding
**Scenario:** Listener survives app lifecycle

**Setup:**
- Device A in conversation

**Steps:**
1. **Send message** "Lifecycle test"
   - [ ] Verify appears

2. **Background app** (Home button)
   - Wait 5 seconds

3. **Device B:** Send message "While backgrounded"

4. **Foreground app:**
   - [ ] Check if message received
   - [ ] Listener reconnected automatically

**Expected:**
- ✅ Listener reconnects on foreground
- ✅ Messages received after backgrounding
- ✅ No crashes or hangs

**Pass Criteria:** Messages arrive after backgrounding

---

### Test 2.9: Connection Flapping
**Scenario:** Handle airplane mode on/off rapidly

**Setup:**
- Device A, conversation open

**Steps:**
1. Send message "Test 1" (online)
2. Enable airplane mode
3. Send message "Test 2" (offline)
4. Wait 2 seconds
5. Disable airplane mode
6. Wait 2 seconds
7. Enable airplane mode again
8. Send message "Test 3" (offline)
9. Disable airplane mode
10. Wait 5 seconds

**Expected:**
- ✅ All 3 messages eventually sync
- ✅ No duplicate sends
- ✅ Correct order maintained
- ✅ No crashes

**Pass Criteria:** All messages deliver exactly once

---

### Test 2.10: Cross-Device Consistency
**Scenario:** Same conversation on 2 devices shows identical messages

**Setup:**
- User 1 logged in on Device A and Device B simultaneously

**Steps:**
1. **Device A:** Send "Message from A"
2. **Device B:** Verify appears
3. **Device B:** Send "Message from B"
4. **Device A:** Verify appears
5. **Another user (Device C):** Send "Message from C"
6. **Both A and B:** Verify message appears

**Expected:**
- ✅ All devices show identical message list
- ✅ Same order on all devices
- ✅ Timestamps match
- ✅ Status updates sync

**Pass Criteria:** Perfect consistency across devices

---

## Edge Case Tests (Important)

### Test 3.1: Empty Message Handling
**Input:** User tries to send empty message

**Steps:**
1. Type nothing (empty string)
2. Tap send button

**Expected:**
- ✅ Send button disabled
- ✅ No message created
- ✅ Input field unchanged

---

### Test 3.2: Whitespace-Only Message
**Input:** "     " (spaces only)

**Steps:**
1. Type only spaces
2. Tap send

**Expected:**
- ✅ Send button disabled
- ✅ No message created (trimmed to empty)

---

### Test 3.3: Very Long Message
**Input:** 10,000 character message

**Steps:**
1. Paste very long text
2. Send message

**Expected:**
- ✅ Message sends successfully
- ✅ Displays correctly in bubble
- ✅ No truncation (or clear truncation if limited)
- ✅ Scroll works in bubble

---

### Test 3.4: Special Characters
**Input:** "Hello 👋 🎉 こんにちは مرحبا"

**Steps:**
1. Send message with emoji and non-Latin characters
2. Verify on recipient device

**Expected:**
- ✅ All characters display correctly
- ✅ No encoding issues
- ✅ Emoji render properly

---

### Test 3.5: Network Error During Send
**Scenario:** Firestore rejects message (auth error, etc.)

**Steps:**
1. Simulate auth error (sign out mid-send)
2. Send message

**Expected:**
- ✅ Message shows "failed" status
- ✅ Error message displayed
- ✅ Retry option available
- ✅ Message not lost from UI

---

### Test 3.6: App Force Quit Mid-Send
**Scenario:** User force quits app while message uploading

**Steps:**
1. Send message
2. Immediately force quit (swipe up in app switcher)
3. Reopen app

**Expected:**
- ✅ Message visible with "sending..." or "failed" status
- ✅ Auto-retry when app reopens
- ✅ No data loss

---

### Test 3.7: Old Messages Don't Re-trigger Listener
**Scenario:** Opening conversation with 100+ old messages

**Steps:**
1. Load conversation with lots of history
2. Observe listener behavior

**Expected:**
- ✅ Only NEW messages trigger updates
- ✅ Old messages don't cause notifications
- ✅ Performance remains good

---

### Test 3.8: Concurrent Sends from Same User
**Scenario:** User sends from 2 devices simultaneously

**Steps:**
1. Device A: Send "From A"
2. Device B: Send "From B" (same user, same second)

**Expected:**
- ✅ Both messages deliver
- ✅ Correct chronological order
- ✅ No conflicts
- ✅ Both devices see both messages

---

## Performance Tests (Verify Targets)

### Test 4.1: Optimistic UI Response Time
**Metric:** <50ms from tap to message visible

**Test:**
1. High-speed camera or 240fps video on iPhone
2. Tap send
3. Count frames until message appears

**Pass Criteria:** <50ms (12 frames at 240fps)

---

### Test 4.2: Real-Time Delivery Latency
**Metric:** <2 seconds from send to recipient receives

**Test:**
1. Device A: Tap send, start stopwatch
2. Device B: Stop stopwatch when message appears

**Pass Criteria:** <2 seconds consistently (10 tests)

---

### Test 4.3: Memory Leak Detection
**Metric:** 0 leaked objects

**Test:**
1. Open Instruments (Cmd+I)
2. Choose "Leaks" template
3. Open/close ChatView 10 times
4. Send 20 messages
5. Check for leaked Firestore listeners

**Pass Criteria:** 0 leaks detected

---

### Test 4.4: Scroll Performance with Real-Time Updates
**Metric:** 60fps while receiving messages

**Test:**
1. Load conversation with 100+ messages
2. Device B: Send 10 messages rapidly
3. Device A: Scroll while messages arrive
4. Check FPS meter

**Pass Criteria:** Maintains 60fps

---

## Acceptance Tests (User Scenarios)

### Test 5.1: First-Time User Sends Message
**User Story:** New user sends their first message

**Steps:**
1. Sign up as new user
2. Start conversation with another user
3. Type "Hello, this is my first message!"
4. Tap send

**Expected:**
- ✅ Message appears immediately
- ✅ Clear feedback (status indicator)
- ✅ Feels fast and responsive
- ✅ Other user receives within 2 seconds

**User Says:** "Wow, that was instant!"

---

### Test 5.2: User Messages While Commuting (Poor Network)
**User Story:** User on subway with spotty connection

**Scenario:**
1. Enable Network Link Conditioner: "Very Bad Network"
2. Send 5 messages
3. Some sends succeed, some fail (intermittent)

**Expected:**
- ✅ All messages visible locally
- ✅ Failed messages clearly marked
- ✅ Auto-retry when connection improves
- ✅ All eventually deliver

**User Says:** "It handled my bad connection gracefully"

---

### Test 5.3: User Sends Message Then Immediately Closes App
**User Story:** Send and quit (common pattern)

**Steps:**
1. Open chat
2. Type message
3. Tap send
4. Immediately force quit (within 1 second)
5. Reopen app later

**Expected:**
- ✅ Message still visible when reopened
- ✅ Message uploaded successfully
- ✅ Recipient received it

**User Says:** "I didn't lose my message even though I quit fast"

---

### Test 5.4: User Has Active Conversation (Back and Forth)
**User Story:** Natural conversation flow

**Steps:**
1. User A: "Hey, how are you?"
2. User B: "Good! You?"
3. User A: "Great, want to grab coffee?"
4. User B: "Sure, when?"
5. User A: "How about 3pm?"
6. User B: "Perfect, see you then!"

**Expected:**
- ✅ All messages deliver instantly
- ✅ Feels like real-time chat
- ✅ Natural flow, no delays
- ✅ Status indicators work

**User Says:** "This feels just like iMessage"

---

### Test 5.5: User Reconnects After Being Offline
**User Story:** Went into airplane mode, now back online

**Steps:**
1. Enable airplane mode
2. Try to send 3 messages (all queue)
3. Wait 1 minute
4. Disable airplane mode
5. Observe

**Expected:**
- ✅ All 3 messages send automatically
- ✅ No manual action needed
- ✅ Clear feedback ("Syncing...")
- ✅ Recipient gets all 3 in order

**User Says:** "It just worked when I came back online"

---

## Testing Checklist Summary

### Critical Tests (Must Pass)
- [ ] Test 2.1: Real-time delivery <2s ✅
- [ ] Test 2.2: Optimistic UI <50ms ✅
- [ ] Test 2.3: Offline queue + sync ✅
- [ ] Test 2.4: No duplicates ✅
- [ ] Test 2.5: Listener lifecycle ✅

### Important Tests (Should Pass)
- [ ] Test 2.6: Status updates ✅
- [ ] Test 2.7: Rapid fire messages ✅
- [ ] Test 2.8: App lifecycle ✅
- [ ] Test 3.5: Error handling ✅
- [ ] Test 4.3: No memory leaks ✅

### Nice-to-Have Tests (Time Permitting)
- [ ] Unit tests (1.1-1.5)
- [ ] Edge cases (3.1-3.8)
- [ ] Performance tests (4.1-4.4)
- [ ] All acceptance tests (5.1-5.5)

---

## Test Execution Plan

### Phase 1: Quick Smoke Test (5 minutes)
1. Run app on 1 device
2. Send 1 message
3. Verify appears instantly
4. Check console logs (no errors)

**Pass?** → Continue to Phase 2

---

### Phase 2: Core Integration Tests (30 minutes)
1. Test 2.1: Real-time delivery (15 min)
2. Test 2.2: Optimistic UI (5 min)
3. Test 2.3: Offline queue (10 min)

**All Pass?** → Continue to Phase 3

---

### Phase 3: Edge Cases & Performance (30 minutes)
1. Test 2.4: Deduplication (10 min)
2. Test 2.7: Rapid fire (10 min)
3. Test 4.3: Memory leaks (10 min)

**All Pass?** → Feature Complete! ✅

---

### Phase 4: Acceptance Testing (Optional, 20 minutes)
1. Test 5.1-5.5: User scenarios
2. Get feedback from test users
3. Document any UX issues

---

## Bug Reporting Template

When a test fails, document:

```markdown
### Bug: [Descriptive Title]

**Test:** [Test number/name]
**Severity:** 🔴 CRITICAL / 🟡 HIGH / 🟠 MEDIUM / 🟢 LOW

**Symptoms:**
- [What you observed]

**Expected:**
- [What should happen]

**Steps to Reproduce:**
1. [Step 1]
2. [Step 2]
3. [Result]

**Screenshots/Logs:**
[Attach relevant info]

**Potential Cause:**
[Your hypothesis]
```

---

## Success Criteria

**PR #10 is complete when:**

- ✅ All 5 critical tests pass
- ✅ At least 7/10 important tests pass
- ✅ No memory leaks detected
- ✅ Real-time delivery <2 seconds
- ✅ Optimistic UI <50ms
- ✅ 100% message delivery (offline → online)

---

## Troubleshooting Failed Tests

### If Test 2.1 Fails (Real-time delivery)
- Check Firestore listener is registered (console logs)
- Verify Firebase rules allow reads
- Test Firestore directly in console
- Check internet connection on both devices

### If Test 2.2 Fails (Optimistic UI)
- Profile with Time Profiler (Instruments)
- Check for blocking operations on main thread
- Verify message appended to array immediately
- Check SwiftUI view updates (@Published working?)

### If Test 2.3 Fails (Offline queue)
- Verify Core Data saving (check with database browser)
- Check `isSynced` flag is false
- Test NetworkMonitor is detecting online state
- Verify SyncManager.syncQueuedMessages() is called

### If Test 2.4 Fails (Duplicates)
- Add extensive logging to deduplication logic
- Check messageIdMap is populated correctly
- Verify temp ID → server ID mapping
- Test with artificial delays (slow network)

### If Test 4.3 Fails (Memory leaks)
- Check listener cleanup in stopRealtimeSync()
- Verify [weak self] in closures
- Test listener.remove() is called
- Run Allocations instrument for detailed view

---

**Total Testing Time:** 1-2 hours  
**Critical Path:** Tests 2.1-2.5 (must pass)  
**Success Rate Target:** >90% of tests passing

**Remember:** Testing is not optional. Real-time messaging is complex—thorough testing prevents production bugs.

---

*"Test on real devices with real network conditions. Simulators lie."*

