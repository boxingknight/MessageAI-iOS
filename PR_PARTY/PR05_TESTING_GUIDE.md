# PR #5: Testing Guide - Chat Service & Firestore Integration

**Purpose:** Comprehensive testing strategy to ensure ChatService works reliably under all conditions.

---

## Testing Philosophy

**Core Principle:** Messages must NEVER be lost. If there's doubt, test more.

**Testing Priorities:**
1. **Data Integrity** - No lost messages, no duplicates
2. **Real-Time Functionality** - Messages deliver < 2 seconds
3. **Offline Resilience** - Queue and retry works
4. **Security** - Unauthorized access blocked
5. **Performance** - Meets targets under load
6. **Resource Management** - No memory leaks

---

## Test Categories

### Category 1: Conversation Management
Tests for creating and fetching conversations

### Category 2: Message Operations
Tests for sending and receiving messages

### Category 3: Real-Time Sync
Tests for listener functionality

### Category 4: Status Tracking
Tests for message status updates

### Category 5: Offline Scenarios
Tests for queue and retry logic

### Category 6: Security
Tests for Firestore rules

### Category 7: Performance
Tests for speed and efficiency

### Category 8: Edge Cases
Tests for unusual scenarios

---

## Category 1: Conversation Management

### Test 1.1: Create One-on-One Conversation

**Setup:**
- Two test users: userA, userB
- Both authenticated

**Steps:**
1. Call `createConversation(participants: [userA.id, userB.id], isGroup: false)`
2. Check returned Conversation object
3. Verify in Firestore console

**Expected Results:**
- ✅ Conversation created with valid UUID
- ✅ `participants` array contains both users
- ✅ `isGroup` is false
- ✅ `createdBy` is current user
- ✅ `createdAt` timestamp exists
- ✅ Firestore document exists in `/conversations/{id}`

**Pass Criteria:** All assertions true

---

### Test 1.2: Create Group Conversation

**Setup:**
- Three test users: userA, userB, userC
- All authenticated

**Steps:**
1. Call `createConversation(participants: [userA.id, userB.id, userC.id], isGroup: true, groupName: "Test Group")`
2. Check returned Conversation object
3. Verify in Firestore console

**Expected Results:**
- ✅ Conversation created with valid UUID
- ✅ `participants` array contains all three users
- ✅ `isGroup` is true
- ✅ `groupName` is "Test Group"
- ✅ Firestore document exists

**Pass Criteria:** All assertions true

---

### Test 1.3: Create Conversation Without Current User

**Setup:**
- Current user logged in as userA
- Pass only userB and userC as participants

**Steps:**
1. Call `createConversation(participants: [userB.id, userC.id], isGroup: false)`
2. Check returned Conversation

**Expected Results:**
- ✅ Current user (userA) automatically added to participants
- ✅ Participants array: [userA.id, userB.id, userC.id]
- ✅ No error thrown

**Pass Criteria:** Current user included automatically

---

### Test 1.4: Fetch Conversations for User

**Setup:**
- User has 3 conversations in Firestore
- Listener set up for user

**Steps:**
1. Call `fetchConversations(userId: currentUser.id)`
2. Collect yielded conversations

**Expected Results:**
- ✅ AsyncThrowingStream yields array of 3 conversations
- ✅ Conversations sorted by `lastMessageAt` (descending)
- ✅ All conversations contain current user in participants
- ✅ Listener fires immediately with existing data

**Pass Criteria:** Correct conversations fetched in correct order

---

### Test 1.5: Fetch Conversations with Real-Time Updates

**Setup:**
- Listener set up for userA
- UserB creates new conversation with userA

**Steps:**
1. Set up listener: `fetchConversations(userId: userA.id)`
2. From another device/simulator, create new conversation with userA
3. Wait for listener to fire

**Expected Results:**
- ✅ Listener fires within 2 seconds of conversation creation
- ✅ New conversation appears in yielded array
- ✅ No duplicates

**Pass Criteria:** Real-time update works, < 2 second latency

---

## Category 2: Message Operations

### Test 2.1: Send Text Message

**Setup:**
- Conversation exists
- User authenticated

**Steps:**
1. Call `sendMessage(conversationId: conv.id, text: "Hello, world!")`
2. Check returned Message object
3. Verify in Firestore console

**Expected Results:**
- ✅ Message created with valid UUID
- ✅ `text` is "Hello, world!"
- ✅ `senderId` is current user
- ✅ `status` is `.sent`
- ✅ `sentAt` timestamp exists
- ✅ Firestore document exists in `/conversations/{id}/messages/{messageId}`
- ✅ Conversation `lastMessage` updated
- ✅ Conversation `lastMessageAt` updated

**Pass Criteria:** Message sent successfully with correct data

---

### Test 2.2: Send Empty Message (Should Fail)

**Setup:**
- Conversation exists

**Steps:**
1. Call `sendMessage(conversationId: conv.id, text: "")`
2. Catch error

**Expected Results:**
- ✅ Throws `ChatError.invalidData`
- ✅ Error message: "Invalid message data. Please try again."
- ✅ No Firestore document created

**Pass Criteria:** Empty messages rejected

---

### Test 2.3: Send Message with Whitespace Only (Should Fail)

**Setup:**
- Conversation exists

**Steps:**
1. Call `sendMessage(conversationId: conv.id, text: "   \n\t  ")`
2. Catch error

**Expected Results:**
- ✅ Throws `ChatError.invalidData`
- ✅ No Firestore document created

**Pass Criteria:** Whitespace-only messages rejected

---

### Test 2.4: Fetch Messages for Conversation

**Setup:**
- Conversation has 5 existing messages

**Steps:**
1. Call `fetchMessages(conversationId: conv.id)`
2. Collect yielded messages

**Expected Results:**
- ✅ AsyncThrowingStream yields array of 5 messages
- ✅ Messages in chronological order (oldest first)
- ✅ All messages have correct `conversationId`
- ✅ Listener fires immediately with existing data

**Pass Criteria:** All messages fetched in correct order

---

### Test 2.5: Fetch Messages with Real-Time Updates

**Setup:**
- Message listener set up
- Another user sends new message

**Steps:**
1. Set up listener: `fetchMessages(conversationId: conv.id)`
2. From another device, send message to conversation
3. Wait for listener to fire

**Expected Results:**
- ✅ Listener fires within 2 seconds of message send
- ✅ New message appears in yielded array
- ✅ Message appended to end (chronological order maintained)
- ✅ No duplicates

**Pass Criteria:** Real-time message delivery < 2 seconds

---

### Test 2.6: Send Multiple Messages Rapidly

**Setup:**
- Conversation exists
- Good network connection

**Steps:**
1. Send 20 messages rapidly in a loop
2. Wait for all to complete
3. Fetch messages from Firestore

**Expected Results:**
- ✅ All 20 messages sent successfully
- ✅ No messages lost
- ✅ No duplicate messages
- ✅ Messages in correct order by `sentAt`
- ✅ All have `.sent` status

**Pass Criteria:** All messages sent without loss or duplication

---

## Category 3: Real-Time Sync

### Test 3.1: Listener Fires on New Message

**Setup:**
- Listener active on conversationA
- Good network connection

**Steps:**
1. Set up message listener
2. Send message from different device
3. Time how long until listener fires

**Expected Results:**
- ✅ Listener fires within 2 seconds
- ✅ New message included in yielded array
- ✅ Console log shows listener trigger

**Pass Criteria:** Latency < 2 seconds

---

### Test 3.2: Listener Fires on Message Status Change

**Setup:**
- Listener active
- Message exists with status `.sent`

**Steps:**
1. Set up listener
2. Update message status to `.delivered`
3. Wait for listener to fire

**Expected Results:**
- ✅ Listener fires immediately
- ✅ Message status updated in yielded array
- ✅ `deliveredAt` timestamp present

**Pass Criteria:** Status changes propagate in real-time

---

### Test 3.3: Multiple Listeners Don't Interfere

**Setup:**
- Two conversations: convA, convB
- Listeners on both

**Steps:**
1. Set up listener for convA
2. Set up listener for convB
3. Send message to convA
4. Verify only convA listener fires

**Expected Results:**
- ✅ ConvA listener fires
- ✅ ConvB listener does NOT fire
- ✅ No cross-contamination

**Pass Criteria:** Listeners independent

---

### Test 3.4: Listener Cleanup (No Memory Leak)

**Setup:**
- Set up listener
- Store reference

**Steps:**
1. Set up listener: `fetchMessages(conversationId: conv.id)`
2. Note listener count in ChatService
3. Terminate AsyncThrowingStream or call `detachConversationListener()`
4. Check listener count

**Expected Results:**
- ✅ Listener count increases by 1 on setup
- ✅ Listener count decreases by 1 on cleanup
- ✅ Console log: "Detached messages listener"
- ✅ No further listener triggers after cleanup

**Pass Criteria:** Listener properly removed, no memory leak

---

### Test 3.5: Listener Survives Network Interruption

**Setup:**
- Listener active
- Good network

**Steps:**
1. Set up listener
2. Enable airplane mode for 10 seconds
3. Disable airplane mode
4. Send message

**Expected Results:**
- ✅ Listener doesn't crash during offline period
- ✅ Listener resumes when online
- ✅ New message received after reconnection

**Pass Criteria:** Listener resilient to network changes

---

## Category 4: Status Tracking

### Test 4.1: Update Message Status to Delivered

**Setup:**
- Message exists with status `.sent`

**Steps:**
1. Call `updateMessageStatus(messageId: msg.id, conversationId: conv.id, status: .delivered)`
2. Verify in Firestore

**Expected Results:**
- ✅ Status updated to `.delivered`
- ✅ `deliveredAt` timestamp added
- ✅ Firestore document updated

**Pass Criteria:** Status updated successfully

---

### Test 4.2: Update Message Status to Read

**Setup:**
- Message exists with status `.delivered`

**Steps:**
1. Call `updateMessageStatus(messageId: msg.id, conversationId: conv.id, status: .read)`
2. Verify in Firestore

**Expected Results:**
- ✅ Status updated to `.read`
- ✅ `readAt` timestamp added
- ✅ Firestore document updated

**Pass Criteria:** Status updated successfully

---

### Test 4.3: Mark All Messages as Read

**Setup:**
- Conversation has 5 unread messages from other user
- Current user authenticated

**Steps:**
1. Call `markAsRead(conversationId: conv.id)`
2. Verify in Firestore
3. Check all messages

**Expected Results:**
- ✅ All 5 messages status = `.read`
- ✅ All 5 messages have `readAt` timestamp
- ✅ Batch operation succeeds
- ✅ Own messages NOT updated (only other user's)

**Pass Criteria:** Batch read marking works correctly

---

### Test 4.4: Mark as Read with No Unread Messages

**Setup:**
- All messages already read

**Steps:**
1. Call `markAsRead(conversationId: conv.id)`
2. Verify no errors

**Expected Results:**
- ✅ No error thrown
- ✅ Console log: "No messages to mark as read"
- ✅ No Firestore writes

**Pass Criteria:** Handles empty case gracefully

---

## Category 5: Offline Scenarios

### Test 5.1: Send Message While Offline

**Setup:**
- Airplane mode enabled
- Conversation exists

**Steps:**
1. Enable airplane mode
2. Call `sendMessage(conversationId: conv.id, text: "Offline test")`
3. Catch error
4. Check pending queue

**Expected Results:**
- ✅ Throws `ChatError.networkUnavailable`
- ✅ Message added to `pendingMessages` queue
- ✅ Message status = `.failed`
- ✅ No Firestore document created yet

**Pass Criteria:** Message queued for retry

---

### Test 5.2: Retry Pending Messages When Online

**Setup:**
- 3 messages in pending queue
- Airplane mode disabled

**Steps:**
1. Disable airplane mode
2. Call `retryPendingMessages()`
3. Wait for completion
4. Check Firestore

**Expected Results:**
- ✅ All 3 messages uploaded to Firestore
- ✅ All removed from pending queue
- ✅ Console logs: "Successfully retried message: {id}"
- ✅ Conversation `lastMessage` updated

**Pass Criteria:** All pending messages sent successfully

---

### Test 5.3: Get Pending Messages for Conversation

**Setup:**
- 5 pending messages: 3 for convA, 2 for convB

**Steps:**
1. Call `getPendingMessages(for: convA.id)`
2. Check returned array

**Expected Results:**
- ✅ Returns array of 3 messages
- ✅ All messages have `conversationId` == convA.id
- ✅ Messages from convB NOT included

**Pass Criteria:** Correct filtering by conversation

---

### Test 5.4: Offline Send, Restart App, Auto-Retry

**Note:** This requires SwiftData persistence from PR #6. For PR #5:

**Setup:**
- Airplane mode enabled
- Send message (queued)

**Steps:**
1. Send message while offline (queued in memory)
2. **DON'T** restart app (would lose queue)
3. Disable airplane mode
4. Call `retryPendingMessages()`

**Expected Results for PR #5:**
- ✅ Message retries successfully (if app still running)
- ❌ Message lost on app restart (expected in PR #5)

**Expected Results for PR #6:**
- ✅ Message retries successfully even after app restart

**Pass Criteria:** In-memory queue works; persistent queue in PR #6

---

## Category 6: Security

### Test 6.1: Read Conversation You're Not In (Should Fail)

**Setup:**
- UserA creates conversation with userB
- UserC tries to access it

**Steps:**
1. Log in as userC
2. Try to fetch conversation or messages
3. Verify error

**Expected Results:**
- ✅ Firestore throws permission denied error
- ✅ Error mapped to `ChatError.permissionDenied`
- ✅ User-friendly message shown

**Pass Criteria:** Unauthorized access blocked

---

### Test 6.2: Send Message to Conversation You're Not In (Should Fail)

**Setup:**
- Conversation between userA and userB
- UserC tries to send message

**Steps:**
1. Log in as userC
2. Try to call `sendMessage(conversationId: conv.id, text: "Hack attempt")`
3. Verify error

**Expected Results:**
- ✅ Firestore rejects write
- ✅ Error thrown
- ✅ No message created in Firestore

**Pass Criteria:** Unauthorized write blocked

---

### Test 6.3: Create Conversation with Only Self (Should Fail)

**Setup:**
- Try to create conversation with only current user

**Steps:**
1. Call `createConversation(participants: [currentUser.id], isGroup: false)`
2. Verify error

**Expected Results:**
- ✅ Throws `ChatError.invalidData`
- ✅ Error: "A conversation requires at least 2 participants"
- ✅ No Firestore document created

**Pass Criteria:** Single-user conversations rejected

---

### Test 6.4: Update Other User's Message (Should Fail)

**Setup:**
- UserA sends message
- UserB tries to edit it

**Steps:**
1. Log in as userB
2. Try to update userA's message text
3. Verify error

**Expected Results:**
- ✅ Firestore rejects update
- ✅ Permission denied error
- ✅ Message unchanged

**Pass Criteria:** Can't edit others' messages

---

### Test 6.5: Update Message Status (Should Succeed)

**Setup:**
- UserA sends message
- UserB marks it as read

**Steps:**
1. UserA sends message
2. Log in as userB
3. Call `updateMessageStatus(..., status: .read)`
4. Verify success

**Expected Results:**
- ✅ Status update succeeds
- ✅ UserB can update status fields (status, deliveredAt, readAt)
- ✅ UserB cannot update text/sender fields

**Pass Criteria:** Status updates allowed for recipients

---

## Category 7: Performance

### Test 7.1: Message Send Latency

**Setup:**
- Good network connection
- Conversation exists

**Steps:**
1. Record start time
2. Send message
3. Wait for completion
4. Record end time
5. Calculate latency

**Expected Results:**
- ✅ Average latency < 500ms over 10 sends
- ✅ 95th percentile < 1000ms

**Pass Criteria:** Meets latency targets

---

### Test 7.2: Real-Time Delivery Latency

**Setup:**
- Two devices with listeners
- Good network

**Steps:**
1. Device A sets up listener
2. Device B sends message
3. Time until Device A listener fires
4. Repeat 10 times
5. Calculate average

**Expected Results:**
- ✅ Average latency < 2 seconds
- ✅ 95th percentile < 3 seconds

**Pass Criteria:** Real-time delivery meets targets

---

### Test 7.3: Fetch 100 Messages Performance

**Setup:**
- Conversation with 100 messages

**Steps:**
1. Record start time
2. Call `fetchMessages(conversationId: conv.id)`
3. Wait for first yield
4. Record end time

**Expected Results:**
- ✅ Initial load < 2 seconds
- ✅ All 100 messages received
- ✅ No pagination errors

**Pass Criteria:** Large conversation loads quickly

---

### Test 7.4: Multiple Concurrent Listeners

**Setup:**
- 5 conversations
- Listener on each

**Steps:**
1. Set up 5 listeners simultaneously
2. Send message to each conversation
3. Verify all listeners fire

**Expected Results:**
- ✅ All 5 listeners work independently
- ✅ No slowdown with multiple listeners
- ✅ No memory issues

**Pass Criteria:** Scales to multiple conversations

---

### Test 7.5: Batch Update Performance

**Setup:**
- Conversation with 50 unread messages

**Steps:**
1. Record start time
2. Call `markAsRead(conversationId: conv.id)`
3. Wait for completion
4. Record end time

**Expected Results:**
- ✅ Batch update completes < 3 seconds
- ✅ All 50 messages updated
- ✅ Single batch operation (not 50 individual updates)

**Pass Criteria:** Batch operations efficient

---

## Category 8: Edge Cases

### Test 8.1: Send Message to Deleted Conversation

**Setup:**
- Conversation deleted from Firestore
- Client still has reference

**Steps:**
1. Delete conversation from Firestore console
2. Try to send message
3. Verify error

**Expected Results:**
- ✅ Throws `ChatError.conversationNotFound`
- ✅ Helpful error message
- ✅ No crash

**Pass Criteria:** Graceful handling of deleted conversation

---

### Test 8.2: Very Long Message Text

**Setup:**
- Text with 10,000 characters

**Steps:**
1. Create string with 10,000 characters
2. Call `sendMessage(..., text: longText)`
3. Verify success or appropriate error

**Expected Results:**
- ✅ Either succeeds (if Firestore allows)
- ✅ Or throws error with clear message
- ✅ No crash

**Pass Criteria:** Long text handled gracefully

---

### Test 8.3: Special Characters in Message

**Setup:**
- Text with emojis, newlines, special chars

**Steps:**
1. Send message: "Hello 👋\nThis has\t tabs and \"quotes\" & symbols!"
2. Fetch message
3. Verify content

**Expected Results:**
- ✅ Message sent successfully
- ✅ All special characters preserved
- ✅ No encoding issues

**Pass Criteria:** Special characters handled correctly

---

### Test 8.4: Listener on Non-Existent Conversation

**Setup:**
- Fake conversation ID

**Steps:**
1. Call `fetchMessages(conversationId: "fake-id-12345")`
2. Wait for listener

**Expected Results:**
- ✅ Listener yields empty array (not error)
- ✅ No crash
- ✅ Listener can still receive future messages if conversation created

**Pass Criteria:** Handles non-existent conversation gracefully

---

### Test 8.5: Send Message Without Authentication

**Setup:**
- User logged out

**Steps:**
1. Log out current user
2. Try to send message
3. Verify error

**Expected Results:**
- ✅ Throws `ChatError.permissionDenied`
- ✅ Error message: "You don't have permission"
- ✅ No Firestore write

**Pass Criteria:** Unauthenticated access blocked

---

## Acceptance Criteria

**This PR is complete and ready to merge when:**

### Functionality
- [ ] All conversation management tests pass (5/5)
- [ ] All message operation tests pass (6/6)
- [ ] All real-time sync tests pass (5/5)
- [ ] All status tracking tests pass (4/4)
- [ ] All offline scenario tests pass (4/4)
- [ ] All security tests pass (5/5)
- [ ] All performance tests pass (5/5)
- [ ] All edge case tests pass (5/5)

**Total:** 39 tests passing

### Performance
- [ ] Message send: < 500ms average
- [ ] Real-time delivery: < 2 seconds
- [ ] Listener setup: < 1 second
- [ ] 100 message fetch: < 2 seconds
- [ ] Batch read: < 3 seconds

### Security
- [ ] Firestore rules deployed
- [ ] Unauthorized access blocked
- [ ] No permission-denied errors for valid operations
- [ ] Can't read others' conversations
- [ ] Can't edit others' messages (except status)

### Code Quality
- [ ] No compiler warnings
- [ ] No console errors (except expected test failures)
- [ ] Listeners clean up properly (verified with Instruments)
- [ ] All methods have documentation comments
- [ ] Error messages user-friendly

---

## Testing Tools

### Xcode
- Run app on simulator: Cmd+R
- View console: Cmd+Shift+Y
- Instruments (memory leaks): Cmd+I

### Firebase
- Firestore console: Check data in real-time
- Rules playground: Test security rules
- Emulator: Test locally (optional)

### Network
- Airplane mode: Test offline
- Network Link Conditioner: Simulate poor networks

---

## Test Execution Order

**Recommended sequence:**

1. **Day 1: Basic Functionality**
   - Category 1: Conversation Management (30 min)
   - Category 2: Message Operations (30 min)
   - Category 3: Real-Time Sync (20 min)

2. **Day 1: Advanced Features**
   - Category 4: Status Tracking (15 min)
   - Category 5: Offline Scenarios (20 min)

3. **Day 1/2: Security & Edge Cases**
   - Category 6: Security (20 min)
   - Category 8: Edge Cases (15 min)

4. **Day 2: Performance & Polish**
   - Category 7: Performance (30 min)
   - Bug fixes (variable)

**Total Testing Time:** 3-4 hours

---

## Bug Documentation

If bugs found, document in this format:

```markdown
## Bug #1: [Descriptive Title]
**Severity:** CRITICAL/HIGH/MEDIUM/LOW
**Found During:** Test X.Y
**Symptoms:** [What went wrong]
**Root Cause:** [Why it happened]
**Fix:** [What was changed]
**Time to Fix:** X minutes
**Prevented By:** [How to avoid in future]
```

---

## Success Metrics Summary

**This PR is successful when:**
- ✅ All 39 test cases pass
- ✅ Performance targets met
- ✅ Security rules working
- ✅ Zero data loss demonstrated
- ✅ No memory leaks confirmed
- ✅ Messages deliver reliably under all conditions

**Quality Bar:** Real-time messaging that NEVER loses messages, works offline, and delivers instantly.

---

*"If it's not tested, it's broken." - Murphy's Law*

Test thoroughly. This is the foundation of reliable messaging! 🚀

