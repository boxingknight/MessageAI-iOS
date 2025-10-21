# PR#12: Testing Guide - Presence & Typing Indicators

**Test Categories:** 4 (Unit, Integration, Edge Cases, Performance)  
**Total Scenarios:** 22 test cases  
**Testing Time:** ~1 hour (30 min automated/unit, 30 min manual/integration)  
**Required:** 2+ iOS devices or 1 device + simulator

---

## Test Categories

### Test Priority

**P0 (Critical - Must Pass):**
- App lifecycle updates presence
- Typing indicators appear/disappear
- Real-time updates work (<2 second latency)
- No memory leaks

**P1 (High - Should Pass):**
- Presence displays correctly in UI
- Typing debounce reduces writes
- Offline gracefully handled
- Security rules enforced

**P2 (Medium - Nice to Have):**
- Animation smooth (60fps)
- Stale presence handled
- Multi-user typing aggregation
- Performance benchmarks met

---

## Unit Tests (Presence Logic)

### Test 1: Presence Model Creation

**Category:** Unit Test  
**Priority:** P1  
**Time:** 2 minutes

**Test:**
```swift
func testPresenceCreation() {
    // Given
    let userId = "user123"
    let now = Date()
    
    // When
    let presence = Presence(
        userId: userId,
        isOnline: true,
        lastSeen: now,
        updatedAt: now
    )
    
    // Then
    XCTAssertEqual(presence.userId, userId)
    XCTAssertTrue(presence.isOnline)
    XCTAssertEqual(presence.presenceText, "Active now")
    XCTAssertEqual(presence.statusColor, "green")
}
```

**Expected:** Presence object created with correct properties  
**Actual:** ___________________  
**Pass/Fail:** ___________________

---

### Test 2: Presence Text Formatting - Recent

**Category:** Unit Test  
**Priority:** P1  
**Time:** 2 minutes

**Test:**
```swift
func testPresenceText_RecentlyOnline() {
    // Given
    let twoMinutesAgo = Date().addingTimeInterval(-120)
    
    // When
    let presence = Presence(
        userId: "user123",
        isOnline: false,
        lastSeen: twoMinutesAgo,
        updatedAt: Date()
    )
    
    // Then
    XCTAssertEqual(presence.presenceText, "2m ago")
}
```

**Expected:** "2m ago"  
**Actual:** ___________________  
**Pass/Fail:** ___________________

---

### Test 3: Presence Text Formatting - Long Ago

**Category:** Unit Test  
**Priority:** P1  
**Time:** 2 minutes

**Test:**
```swift
func testPresenceText_LongAgo() {
    // Given
    let twoDaysAgo = Date().addingTimeInterval(-172800)
    
    // When
    let presence = Presence(
        userId: "user123",
        isOnline: false,
        lastSeen: twoDaysAgo,
        updatedAt: Date()
    )
    
    // Then
    XCTAssertEqual(presence.presenceText, "Last seen recently")
}
```

**Expected:** "Last seen recently"  
**Actual:** ___________________  
**Pass/Fail:** ___________________

---

### Test 4: Firestore Conversion Round-Trip

**Category:** Unit Test  
**Priority:** P0  
**Time:** 3 minutes

**Test:**
```swift
func testPresence_FirestoreConversion() {
    // Given
    let original = Presence(
        userId: "user123",
        isOnline: true,
        lastSeen: Date(),
        updatedAt: Date()
    )
    
    // When
    let dict = original.toFirestore()
    let converted = Presence.fromFirestore(dict, userId: "user123")
    
    // Then
    XCTAssertNotNil(converted)
    XCTAssertEqual(original.userId, converted?.userId)
    XCTAssertEqual(original.isOnline, converted?.isOnline)
}
```

**Expected:** Original and converted presence are equal (lossless conversion)  
**Actual:** ___________________  
**Pass/Fail:** ___________________

---

### Test 5: Typing Debounce - Multiple Rapid Calls

**Category:** Unit Test  
**Priority:** P0  
**Time:** 5 minutes

**Test:**
```swift
func testTypingDebounce_MultipleRapidCalls() async throws {
    // Given
    let viewModel = ChatViewModel(conversationId: "conv123")
    let mockService = MockChatService()
    viewModel.chatService = mockService
    
    // When
    viewModel.userStartedTyping()
    try await Task.sleep(for: .milliseconds(100))
    viewModel.userStartedTyping()  // Cancel previous
    try await Task.sleep(for: .milliseconds(100))
    viewModel.userStartedTyping()  // Cancel previous
    
    // Wait for debounce window
    try await Task.sleep(for: .milliseconds(600))
    
    // Then
    XCTAssertEqual(mockService.typingUpdateCount, 1, "Should only send 1 update (last one)")
}
```

**Expected:** Only 1 Firestore write (last call after 500ms)  
**Actual:** ___________________  
**Pass/Fail:** ___________________

---

### Test 6: Typing Expiration - Stale Entries Filtered

**Category:** Unit Test  
**Priority:** P0  
**Time:** 3 minutes

**Test:**
```swift
func testTypingExpiration_StaleEntriesRemoved() {
    // Given
    let now = Date()
    let recentTyping = now.addingTimeInterval(-1)  // 1 second ago (active)
    let staleTyping = now.addingTimeInterval(-5)   // 5 seconds ago (stale)
    
    let typingMap: [String: Date] = [
        "user1": recentTyping,  // Should keep
        "user2": staleTyping     // Should filter out
    ]
    
    // When
    let activeTyping = typingMap.filter { _, timestamp in
        now.timeIntervalSince(timestamp) < 3.0
    }
    
    // Then
    XCTAssertEqual(activeTyping.count, 1, "Should only have 1 active user")
    XCTAssertNotNil(activeTyping["user1"], "user1 should be active")
    XCTAssertNil(activeTyping["user2"], "user2 should be filtered out")
}
```

**Expected:** Only entries <3 seconds old remain  
**Actual:** ___________________  
**Pass/Fail:** ___________________

---

## Integration Tests (Real-Time Behavior)

### Test 7: App Lifecycle Updates Presence

**Category:** Integration Test  
**Priority:** P0 (Critical)  
**Time:** 5 minutes  
**Devices:** 1 device + Firestore console

**Test Steps:**
1. Launch app while logged in as User A
2. Open Firestore console → `presence/{userA_id}`
3. Verify: `isOnline: true`, `lastSeen` updated to now
4. Background app (press Home button, Cmd+Shift+H on simulator)
5. Check Firestore: `isOnline: false`, `lastSeen` updated
6. Foreground app again
7. Check Firestore: `isOnline: true` again

**Expected:**
- [ ] Launch → online
- [ ] Background → offline
- [ ] Foreground → online

**Actual Results:**
- Launch: ___________________
- Background: ___________________
- Foreground: ___________________

**Pass/Fail:** ___________________

---

### Test 8: Presence Indicator Updates in Chat List

**Category:** Integration Test  
**Priority:** P0 (Critical)  
**Time:** 10 minutes  
**Devices:** 2 devices (Device A + Device B)

**Setup:**
- User A and User B both logged in
- Both users have conversation with each other

**Test Steps:**
1. Device A: Open chat list
2. Device A: Verify User B shows green dot + "Active now"
3. Device B: Background app (Home button)
4. Device A: Within 2 seconds, see gray dot + "Last seen just now"
5. Device B: Foreground app
6. Device A: Within 2 seconds, see green dot + "Active now" again

**Expected:**
- [ ] Real-time updates <2 seconds
- [ ] Dot color changes (green ↔ gray)
- [ ] Text changes ("Active now" ↔ "Last seen X ago")

**Actual Results:**
- Latency (B background → A sees offline): ___________________
- Latency (B foreground → A sees online): ___________________
- Dot color correct: Yes / No
- Text correct: Yes / No

**Pass/Fail:** ___________________

---

### Test 9: Typing Indicator Real-Time

**Category:** Integration Test  
**Priority:** P0 (Critical)  
**Time:** 10 minutes  
**Devices:** 2 devices (Device A + Device B)

**Setup:**
- User A and User B in same conversation
- Both devices showing ChatView

**Test Steps:**
1. Device B: Start typing in message input field
2. Device A: Within 1 second, see "User B is typing..."
3. Device A: Verify dots animate (1 → 2 → 3 → 1)
4. Device B: Stop typing (clear text or wait)
5. Device A: Within 3 seconds, typing indicator disappears
6. Device B: Type again
7. Device A: Typing indicator reappears within 1 second

**Expected:**
- [ ] Typing appears <1 second
- [ ] Dots animate smoothly
- [ ] Typing disappears within 3 seconds
- [ ] Typing reappears on new typing

**Actual Results:**
- Typing latency (B types → A sees): ___________________
- Animation smooth: Yes / No
- Auto-disappear time: ___________________
- Reappear latency: ___________________

**Pass/Fail:** ___________________

---

### Test 10: Typing Expires After 3 Seconds

**Category:** Integration Test  
**Priority:** P1  
**Time:** 5 minutes  
**Devices:** 2 devices

**Setup:**
- User A and B in conversation

**Test Steps:**
1. Device B: Start typing
2. Device A: See typing indicator
3. Device B: Stop typing (don't clear text, just stop)
4. Wait 3 seconds
5. Device A: Typing indicator auto-disappears

**Expected:**
- [ ] Typing indicator clears after 3 seconds automatically

**Actual Results:**
- Auto-clear time: ___________________
- Cleared successfully: Yes / No

**Pass/Fail:** ___________________

---

### Test 11: Multiple Users Typing (Group Chat)

**Category:** Integration Test  
**Priority:** P2  
**Time:** 15 minutes  
**Devices:** 3 devices (A, B, C)

**Setup:**
- Group chat with User A, B, C
- All devices in ChatView

**Test Steps:**
1. Device B: Start typing
2. Device A: See "User B is typing..."
3. Device C: Also start typing
4. Device A: See "User B, User C are typing..."
5. Device B: Send message (stops typing)
6. Device A: See only "User C is typing..."

**Expected:**
- [ ] Multiple typing indicators aggregate
- [ ] Names update as users start/stop typing
- [ ] Sending message clears that user's typing

**Actual Results:**
- Single user typing: ___________________
- Multiple users typing: ___________________
- User stops typing: ___________________

**Pass/Fail:** ___________________

---

## Edge Cases

### Test 12: Presence When App Force Quit

**Category:** Edge Case  
**Priority:** P2  
**Time:** 5 minutes  
**Devices:** 2 devices

**Test Steps:**
1. Device A: Logged in, app active (online)
2. Device A: Force quit app (swipe up in app switcher)
3. Device B: Check conversation with User A
4. Device B: Should show "Last seen just now" (not "Active now")

**Expected:**
- [ ] Force quit eventually marks user offline
- [ ] May take 1-5 minutes (acceptable)

**Actual Results:**
- Status after force quit: ___________________
- Time until marked offline: ___________________

**Pass/Fail:** ___________________

**Known Limitation:** iOS doesn't run code on force quit. Acceptable for MVP.

---

### Test 13: Typing When Network Lost

**Category:** Edge Case  
**Priority:** P1  
**Time:** 5 minutes  
**Devices:** 2 devices

**Test Steps:**
1. Device A: Enable airplane mode
2. Device A: Start typing in conversation
3. Device B: Should NOT see typing indicator (A is offline)
4. Device A: Verify no errors in console
5. Device A: Disable airplane mode
6. Device A: Type again
7. Device B: Typing indicator appears

**Expected:**
- [ ] Offline typing doesn't crash
- [ ] No errors displayed to user
- [ ] Typing resumes when online

**Actual Results:**
- Offline typing errors: Yes / No
- Typing resumes online: Yes / No

**Pass/Fail:** ___________________

---

### Test 14: Typing When Conversation Backgrounded

**Category:** Edge Case  
**Priority:** P2  
**Time:** 5 minutes  
**Devices:** 2 devices

**Test Steps:**
1. Device A and B in conversation
2. Device B: Start typing
3. Device A: See typing indicator
4. Device A: Background app (Home button)
5. Wait 5 seconds
6. Device A: Foreground app
7. If Device B still typing: indicator should reappear
8. If Device B stopped: no indicator

**Expected:**
- [ ] Typing state syncs on app resume

**Actual Results:**
- Typing visible after resume: ___________________
- Correct based on Device B state: Yes / No

**Pass/Fail:** ___________________

---

### Test 15: Presence for User Not in Contacts

**Category:** Edge Case  
**Priority:** P2  
**Time:** 3 minutes  
**Devices:** 1 device

**Test Steps:**
1. Create conversation with User B
2. User B: Delete account (or delete presence document in Firestore)
3. Device A: View conversation
4. Should show: No presence dot, no last seen text (graceful fallback)

**Expected:**
- [ ] Missing presence doesn't crash
- [ ] Shows neutral state (no dot, no text)

**Actual Results:**
- App crashes: Yes / No
- Graceful fallback: Yes / No

**Pass/Fail:** ___________________

---

### Test 16: Simultaneous Typing and Sending

**Category:** Edge Case  
**Priority:** P1  
**Time:** 5 minutes  
**Devices:** 2 devices

**Test Steps:**
1. Device A and B in conversation
2. Device A: Start typing
3. Device B: See "User A is typing..."
4. Device A: Send message (before typing expires)
5. Device B: Should:
   - See message appear
   - Typing indicator disappears immediately (not 3 seconds later)

**Expected:**
- [ ] Message appears
- [ ] Typing clears instantly on send (not delayed)

**Actual Results:**
- Message appears: Yes / No
- Typing clears immediately: Yes / No
- Typing clear time: ___________________

**Pass/Fail:** ___________________

---

### Test 17: Rapid Typing (Stress Test)

**Category:** Edge Case  
**Priority:** P1  
**Time:** 5 minutes  
**Devices:** 2 devices

**Test Steps:**
1. Device A: Type very rapidly (10+ characters per second)
2. Device B: Observe typing indicator
3. Monitor: Firestore writes in console
4. Expected: Max 2 writes/second (debounced)

**Expected:**
- [ ] Typing indicator appears
- [ ] No more than 2 Firestore writes/second
- [ ] No lag or jank

**Actual Results:**
- Typing visible: Yes / No
- Max writes/second: ___________________
- Lag/jank: Yes / No

**Pass/Fail:** ___________________

---

### Test 18: Group Typing Overload (10+ Users)

**Category:** Edge Case  
**Priority:** P2  
**Time:** 10 minutes (if group testing available)  
**Devices:** 3+ devices

**Test Steps:**
1. Group chat with 5+ participants
2. 3+ users start typing simultaneously
3. Verify: Typing indicator doesn't overflow UI
4. Should show: "Alice, Bob, and 2 others are typing..."

**Expected:**
- [ ] UI doesn't break with many typists
- [ ] Typing text aggregates correctly

**Actual Results:**
- UI handles many typists: Yes / No
- Text displays correctly: Yes / No

**Pass/Fail:** ___________________

---

### Test 19: Presence with Poor Network

**Category:** Edge Case  
**Priority:** P1  
**Time:** 10 minutes  
**Devices:** 2 devices

**Setup:**
- Use Network Link Conditioner (Xcode → Developer Tools)
- Throttle to 3G speeds

**Test Steps:**
1. Device A: Throttle network to 3G
2. Device A: Background app
3. Device B: Observe presence update
4. May take 3-5 seconds (acceptable)
5. Device A: Foreground app
6. Device B: Observe presence update

**Expected:**
- [ ] Presence updates eventually (3-5 seconds OK)
- [ ] No errors or crashes

**Actual Results:**
- Background update time: ___________________
- Foreground update time: ___________________
- Errors: Yes / No

**Pass/Fail:** ___________________

---

### Test 20: Memory Leak - Open/Close 10 Times

**Category:** Edge Case  
**Priority:** P0 (Critical)  
**Time:** 15 minutes  
**Devices:** 1 device + Instruments

**Test Steps:**
1. Open Xcode → Product → Profile → Allocations
2. Launch app, navigate to ChatView
3. Take memory snapshot (baseline)
4. Navigate back to ChatListView
5. Navigate to ChatView again
6. Repeat 10 times (open ChatView → back → open → back)
7. Take final memory snapshot
8. Compare: Memory should return to baseline (±10%)

**Expected:**
- [ ] Memory returns to baseline
- [ ] Listener count returns to 0
- [ ] No growing allocations

**Actual Results:**
- Baseline memory: ___________________
- Final memory: ___________________
- Difference: ___________________
- Listener count final: ___________________

**Pass/Fail:** ___________________

---

## Performance Tests

### Test 21: Presence Update Latency

**Category:** Performance Test  
**Priority:** P0  
**Time:** 10 minutes  
**Devices:** 2 devices + stopwatch

**Test Steps:**
1. Device A and B both logged in
2. Device A: Open chat list
3. Device B: Background app
4. Start stopwatch
5. Device A: When presence changes to offline, stop stopwatch
6. Record time
7. Repeat 5 times, calculate average

**Expected:**
- [ ] Average latency <2 seconds

**Actual Results:**
- Test 1: ___________________ seconds
- Test 2: ___________________ seconds
- Test 3: ___________________ seconds
- Test 4: ___________________ seconds
- Test 5: ___________________ seconds
- **Average:** ___________________ seconds

**Pass/Fail:** ___________________

---

### Test 22: Typing Indicator Latency

**Category:** Performance Test  
**Priority:** P0  
**Time:** 10 minutes  
**Devices:** 2 devices + stopwatch

**Test Steps:**
1. Device A and B in conversation
2. Device B: Start typing
3. Start stopwatch
4. Device A: When typing indicator appears, stop stopwatch
5. Record time
6. Repeat 5 times, calculate average

**Expected:**
- [ ] Average latency <1 second

**Actual Results:**
- Test 1: ___________________ seconds
- Test 2: ___________________ seconds
- Test 3: ___________________ seconds
- Test 4: ___________________ seconds
- Test 5: ___________________ seconds
- **Average:** ___________________ seconds

**Pass/Fail:** ___________________

---

### Test 23: Typing Debounce Effectiveness

**Category:** Performance Test  
**Priority:** P1  
**Time:** 5 minutes  
**Devices:** 1 device + Firebase console

**Test Steps:**
1. Open Firebase Console → Firestore → Usage tab
2. Note current write count
3. Device: Type rapidly for 10 seconds (continuous typing)
4. Stop typing
5. Check Firebase Console: count new writes
6. Calculate: writes per second = (new writes) / 10

**Expected:**
- [ ] Max 2-3 writes/second (debounced)

**Actual Results:**
- Initial writes: ___________________
- Final writes: ___________________
- New writes: ___________________
- Writes/second: ___________________

**Pass/Fail:** ___________________

---

### Test 24: Animation Frame Rate

**Category:** Performance Test  
**Priority:** P2  
**Time:** 5 minutes  
**Devices:** 1 device

**Test Steps:**
1. Open ChatView with typing indicator visible
2. Xcode → Debug → View Debugging → Rendering → Color Blended Layers
3. Observe typing indicator animation (dots)
4. Should be smooth, no dropped frames
5. Use Instruments → Core Animation FPS

**Expected:**
- [ ] 60 fps for typing animation

**Actual Results:**
- FPS: ___________________
- Smooth animation: Yes / No

**Pass/Fail:** ___________________

---

## Acceptance Criteria Tests

### Test 25: Full Presence Flow (Manual)

**Category:** Acceptance Test  
**Priority:** P0  
**Time:** 15 minutes  
**Devices:** 2 devices

**Scenario:** User sees accurate online/offline status

**Test Steps:**
1. User A logs in → online
2. User B sees green dot in chat list
3. User B opens conversation with A
4. Navigation shows "Active now"
5. User A backgrounds app
6. User B sees gray dot, "Last seen just now"
7. Wait 2 minutes
8. User B sees "Last seen 2m ago"
9. User A foregrounds app
10. User B sees green dot, "Active now" (within 2 seconds)

**Expected:** ✅ All status updates accurate and timely

**Actual:** ___________________

**Pass/Fail:** ___________________

---

### Test 26: Full Typing Flow (Manual)

**Category:** Acceptance Test  
**Priority:** P0  
**Time:** 10 minutes  
**Devices:** 2 devices

**Scenario:** User sees real-time typing indicator

**Test Steps:**
1. User A and B in conversation
2. User B starts typing
3. Within 1 second: User A sees "User B is typing..."
4. Dots animate (1 → 2 → 3 → 1)
5. User B pauses (doesn't type for 3 seconds)
6. Typing indicator disappears
7. User B types again
8. Typing indicator reappears
9. User B sends message
10. Typing indicator disappears immediately
11. Message appears for User A

**Expected:** ✅ Typing indicator works flawlessly, enhances UX

**Actual:** ___________________

**Pass/Fail:** ___________________

---

## Test Summary Template

### Completion Checklist

**Unit Tests (6):**
- [ ] Test 1: Presence creation
- [ ] Test 2: Presence text (recent)
- [ ] Test 3: Presence text (long ago)
- [ ] Test 4: Firestore conversion
- [ ] Test 5: Typing debounce
- [ ] Test 6: Typing expiration

**Integration Tests (5):**
- [ ] Test 7: App lifecycle
- [ ] Test 8: Presence in chat list
- [ ] Test 9: Typing real-time
- [ ] Test 10: Typing expires
- [ ] Test 11: Multiple users typing

**Edge Cases (9):**
- [ ] Test 12: Force quit presence
- [ ] Test 13: Typing offline
- [ ] Test 14: Typing backgrounded
- [ ] Test 15: Missing presence
- [ ] Test 16: Typing + send
- [ ] Test 17: Rapid typing
- [ ] Test 18: Group typing overload
- [ ] Test 19: Poor network
- [ ] Test 20: Memory leaks

**Performance (4):**
- [ ] Test 21: Presence latency
- [ ] Test 22: Typing latency
- [ ] Test 23: Debounce effectiveness
- [ ] Test 24: Animation FPS

**Acceptance (2):**
- [ ] Test 25: Full presence flow
- [ ] Test 26: Full typing flow

**Total Tests:** 26  
**Tests Passed:** ___ / 26  
**Pass Rate:** ___ %

---

## Performance Benchmarks

| Metric | Target | Actual | Pass/Fail |
|--------|--------|--------|-----------|
| Presence update latency | <2s | _____ | _____ |
| Typing indicator latency | <1s | _____ | _____ |
| Typing debounce writes/sec | <3 | _____ | _____ |
| Memory usage (10 iterations) | <50MB | _____ | _____ |
| Animation FPS | 60fps | _____ | _____ |
| App launch overhead | <500ms | _____ | _____ |

---

## Known Issues / Limitations

### Documented Limitations:
1. **Force quit stale presence:** Shows "Active now" for up to 5 minutes (iOS limitation)
2. **Group typing overflow:** Shows max 3 names + "X others are typing"
3. **Firestore free tier:** Typing uses ~2 writes/second (acceptable for MVP)

### Bugs Found During Testing:
1. _____________________________________
2. _____________________________________
3. _____________________________________

---

## Sign-Off

**Tested By:** ___________________  
**Date:** ___________________  
**Build Version:** ___________________  
**Test Environment:** Simulator / Device (circle one)  
**Result:** PASS / FAIL (circle one)

**Notes:**
_____________________________________
_____________________________________
_____________________________________

**Ready for Production:** YES / NO (circle one)

---

**Testing Complete!** ✅

Next: Update PR_PARTY README with test results

