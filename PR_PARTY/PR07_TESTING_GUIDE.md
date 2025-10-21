# PR#7: Chat List View - Testing Guide

**Last Updated:** October 20, 2025  
**Status:** Ready for implementation

---

## Test Categories

### 1. Unit Tests - DateFormatter+Extensions
### 2. Unit Tests - ChatListViewModel  
### 3. Integration Tests - Full Flows
### 4. Edge Cases
### 5. Performance Tests
### 6. Acceptance Criteria

**Total Test Cases:** 24

---

## 1. Unit Tests - DateFormatter+Extensions

### Test 1.1: "Just now" for recent dates
**Purpose:** Verify very recent dates display as "Just now"

**Input:**
```swift
let date = Date().addingTimeInterval(-30) // 30 seconds ago
```

**Expected Output:**
```swift
date.relativeDateString() == "Just now"
```

**Test Code:**
```swift
func testJustNow() {
    let date = Date().addingTimeInterval(-30)
    XCTAssertEqual(date.relativeDateString(), "Just now")
}
```

**Status:** ⏳ Not tested

---

### Test 1.2: Minutes ago format
**Purpose:** Verify minutes display correctly

**Input:**
```swift
let date = Date().addingTimeInterval(-300) // 5 minutes ago
```

**Expected Output:**
```swift
date.relativeDateString() == "5m ago"
```

**Test Code:**
```swift
func testMinutesAgo() {
    let date = Date().addingTimeInterval(-300)
    XCTAssertEqual(date.relativeDateString(), "5m ago")
}
```

**Status:** ⏳ Not tested

---

### Test 1.3: Hours ago format
**Purpose:** Verify hours display correctly

**Input:**
```swift
let date = Date().addingTimeInterval(-10800) // 3 hours ago
```

**Expected Output:**
```swift
date.relativeDateString() == "3h ago"
```

**Test Code:**
```swift
func testHoursAgo() {
    let date = Date().addingTimeInterval(-10800)
    XCTAssertEqual(date.relativeDateString(), "3h ago")
}
```

**Status:** ⏳ Not tested

---

### Test 1.4: Yesterday format
**Purpose:** Verify yesterday dates display as "Yesterday"

**Input:**
```swift
let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
```

**Expected Output:**
```swift
yesterday.relativeDateString() == "Yesterday"
```

**Test Code:**
```swift
func testYesterday() {
    let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
    XCTAssertEqual(yesterday.relativeDateString(), "Yesterday")
}
```

**Status:** ⏳ Not tested

---

### Test 1.5: Day of week for recent dates
**Purpose:** Verify dates within last week show day name

**Input:**
```swift
let monday = Calendar.current.date(byAdding: .day, value: -3, to: Date())! // 3 days ago
```

**Expected Output:**
```swift
// Assuming today is Thursday
monday.relativeDateString() == "Mon"
```

**Test Code:**
```swift
func testDayOfWeek() {
    let threeDaysAgo = Calendar.current.date(byAdding: .day, value: -3, to: Date())!
    let formatter = DateFormatter()
    formatter.dateFormat = "EEE"
    let expected = formatter.string(from: threeDaysAgo)
    
    XCTAssertEqual(threeDaysAgo.relativeDateString(), expected)
}
```

**Status:** ⏳ Not tested

---

### Test 1.6: Date format for older dates
**Purpose:** Verify dates older than 1 week show "MMM d" format

**Input:**
```swift
let oldDate = Calendar.current.date(byAdding: .day, value: -30, to: Date())! // 30 days ago
```

**Expected Output:**
```swift
oldDate.relativeDateString() == "Sep 20" // Example
```

**Test Code:**
```swift
func testOlderDate() {
    let oldDate = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
    let formatter = DateFormatter()
    formatter.dateFormat = "MMM d"
    let expected = formatter.string(from: oldDate)
    
    XCTAssertEqual(oldDate.relativeDateString(), expected)
}
```

**Status:** ⏳ Not tested

---

## 2. Unit Tests - ChatListViewModel

### Test 2.1: Load conversations from local storage
**Purpose:** Verify local conversations load correctly

**Setup:**
```swift
// Create mock LocalDataManager with test conversations
let mockLocalData = [testConversationEntity1, testConversationEntity2]
let mockManager = MockLocalDataManager(conversations: mockLocalData)
let viewModel = ChatListViewModel(
    chatService: mockChatService,
    localDataManager: mockManager,
    currentUserId: "user123"
)
```

**Action:**
```swift
await viewModel.loadConversations()
```

**Expected:**
```swift
XCTAssertEqual(viewModel.conversations.count, 2)
XCTAssertFalse(viewModel.isLoading)
```

**Status:** ⏳ Not tested

---

### Test 2.2: Conversations sorted by most recent
**Purpose:** Verify sortedConversations returns correct order

**Setup:**
```swift
let old = Conversation(id: "1", ..., lastMessageAt: Date().addingTimeInterval(-3600))
let recent = Conversation(id: "2", ..., lastMessageAt: Date())
viewModel.conversations = [old, recent]
```

**Action:**
```swift
let sorted = viewModel.sortedConversations
```

**Expected:**
```swift
XCTAssertEqual(sorted.first?.id, "2") // Recent conversation first
XCTAssertEqual(sorted.last?.id, "1") // Old conversation last
```

**Status:** ⏳ Not tested

---

### Test 2.3: Start real-time listener
**Purpose:** Verify Firestore listener starts correctly

**Setup:**
```swift
let mockChatService = MockChatService()
let viewModel = ChatListViewModel(
    chatService: mockChatService,
    localDataManager: mockLocalData,
    currentUserId: "user123"
)
```

**Action:**
```swift
await viewModel.loadConversations()
```

**Expected:**
```swift
XCTAssertNotNil(viewModel.firestoreTask) // Task created
XCTAssertTrue(mockChatService.listenerStarted) // Listener active
```

**Status:** ⏳ Not tested

---

### Test 2.4: Stop listener on view disappear
**Purpose:** Verify listener cleanup prevents memory leaks

**Setup:**
```swift
await viewModel.loadConversations() // Start listener
```

**Action:**
```swift
viewModel.stopListening()
```

**Expected:**
```swift
XCTAssertNil(viewModel.firestoreTask) // Task cancelled
// Verify with Instruments: No memory leak
```

**Status:** ⏳ Not tested

---

### Test 2.5: Get conversation name for 1-on-1 chat
**Purpose:** Verify correct name extraction for 1-on-1

**Setup:**
```swift
let conversation = Conversation(
    id: "1",
    participants: ["user123", "user456"],
    isGroup: false,
    ...
)
viewModel.currentUserId = "user123"
```

**Action:**
```swift
let name = viewModel.getConversationName(conversation)
```

**Expected:**
```swift
// Until PR #8: Returns other user's ID
XCTAssertEqual(name, "user456")
```

**Status:** ⏳ Not tested

---

### Test 2.6: Get conversation name for group chat
**Purpose:** Verify group name or fallback

**Setup:**
```swift
let conversation = Conversation(
    id: "1",
    participants: ["user123", "user456", "user789"],
    isGroup: true,
    groupName: "Weekend Plans",
    ...
)
```

**Action:**
```swift
let name = viewModel.getConversationName(conversation)
```

**Expected:**
```swift
XCTAssertEqual(name, "Weekend Plans")

// Test fallback for missing group name
let noName = Conversation(..., isGroup: true, groupName: nil, ...)
XCTAssertEqual(viewModel.getConversationName(noName), "Unnamed Group")
```

**Status:** ⏳ Not tested

---

## 3. Integration Tests - Full Flows

### Test 3.1: Full load flow (local → Firestore)
**Purpose:** Verify complete data loading sequence

**Steps:**
1. Open ChatListView
2. Verify loading indicator shows
3. Verify local conversations display immediately (<1s)
4. Verify Firestore listener starts
5. Verify UI updates with Firestore data (within 2s)

**Expected:**
- Conversations from Core Data appear instantly
- Firestore sync completes within 2 seconds
- UI updates automatically (no manual action)
- No errors in console

**Status:** ⏳ Not tested

---

### Test 3.2: Empty state display
**Purpose:** Verify empty state shown correctly

**Setup:**
- User account with zero conversations

**Steps:**
1. Open ChatListView
2. Wait for loading to complete

**Expected:**
- Empty state view displays
- Shows icon, title, message
- "New Chat" button visible
- No loading indicator

**Status:** ⏳ Not tested

---

### Test 3.3: Navigation to ChatView
**Purpose:** Verify navigation structure works

**Steps:**
1. Open ChatListView with conversations
2. Tap first conversation row

**Expected:**
- Navigate to ChatView (or placeholder)
- Navigation title shows conversation name
- Back button returns to list
- List state preserved on return

**Status:** ⏳ Not tested

---

### Test 3.4: Pull-to-refresh
**Purpose:** Verify manual refresh works

**Steps:**
1. Open ChatListView
2. Pull down on list
3. Release to trigger refresh

**Expected:**
- Refresh indicator appears
- Firestore sync triggered
- UI updates with latest data
- Refresh indicator dismisses

**Status:** ⏳ Not tested

---

### Test 3.5: Real-time update
**Purpose:** Verify automatic updates on Firestore change

**Setup:**
- ChatListView open on Device A
- Firestore Console open on computer

**Steps:**
1. Add new conversation in Firestore Console
2. Observe Device A

**Expected:**
- New conversation appears in list within 2 seconds
- No manual action required
- Conversation inserted in correct sorted position
- No UI glitches or errors

**Status:** ⏳ Not tested

---

### Test 3.6: Offline mode
**Purpose:** Verify offline functionality

**Steps:**
1. Ensure conversations exist locally
2. Enable airplane mode
3. Force quit app
4. Relaunch app
5. Open ChatListView

**Expected:**
- Conversations load from Core Data
- List displays normally
- No error messages
- Timestamps display correctly
- No crashes

**Status:** ⏳ Not tested

---

## 4. Edge Cases

### Test 4.1: Zero conversations
**Purpose:** Verify no crashes with empty state

**Setup:**
- Fresh user account, no conversations

**Action:**
- Open ChatListView

**Expected:**
- Empty state displays
- No crashes
- No console errors

**Status:** ⏳ Not tested

---

### Test 4.2: 100+ conversations
**Purpose:** Verify performance at scale

**Setup:**
- Create 100+ test conversations in Firestore

**Action:**
- Open ChatListView
- Scroll through entire list

**Expected:**
- Smooth 60fps scrolling
- No lag or stuttering
- Memory usage <50MB
- Initial load <2s

**Status:** ⏳ Not tested

---

### Test 4.3: Very long last message
**Purpose:** Verify text truncation

**Setup:**
- Conversation with 500+ character last message

**Action:**
- Display conversation in list

**Expected:**
- Text truncates with ellipsis
- No layout issues
- Row height reasonable (~70pt)

**Status:** ⏳ Not tested

---

### Test 4.4: Missing group name
**Purpose:** Verify fallback for nil group name

**Setup:**
- Group conversation with nil groupName

**Action:**
- Display conversation in list

**Expected:**
- Shows "Unnamed Group"
- No crashes
- Icon displays (person.3.fill)

**Status:** ⏳ Not tested

---

### Test 4.5: Rapid navigation
**Purpose:** Verify stability with quick taps

**Setup:**
- ChatListView with multiple conversations

**Action:**
- Tap 5+ conversation rows rapidly

**Expected:**
- No crashes
- Navigation stack behaves correctly
- Back button always works
- No memory leaks

**Status:** ⏳ Not tested

---

### Test 4.6: Listener cleanup on backgrounding
**Purpose:** Verify no memory leaks

**Setup:**
- ChatListView open with active listener

**Action:**
1. Background app (home button)
2. Wait 30 seconds
3. Open Xcode Instruments (Leaks)
4. Return to app

**Expected:**
- Listener stopped on background
- Listener restarted on foreground
- No memory leaks detected
- No zombie listeners

**Status:** ⏳ Not tested

---

## 5. Performance Tests

### Test 5.1: Initial load from Core Data
**Target:** <1 second

**Setup:**
- 50 conversations in Core Data

**Measurement:**
```swift
let start = Date()
await viewModel.loadConversationsFromLocal()
let duration = Date().timeIntervalSince(start)

XCTAssertLessThan(duration, 1.0)
```

**Actual:** _____ seconds

**Status:** ⏳ Not tested

---

### Test 5.2: Firestore sync time
**Target:** <2 seconds

**Setup:**
- Fresh app launch, no local data
- 50 conversations in Firestore

**Measurement:**
```swift
let start = Date()
await viewModel.startRealtimeListener()
// Wait for first update
let duration = Date().timeIntervalSince(start)

XCTAssertLessThan(duration, 2.0)
```

**Actual:** _____ seconds

**Status:** ⏳ Not tested

---

### Test 5.3: Scroll performance
**Target:** 60fps (16.67ms per frame)

**Setup:**
- 100+ conversations in list

**Measurement:**
- Use Xcode Instruments (Core Animation)
- Record during fast scroll
- Check frame rate

**Expected:**
- Average FPS ≥ 58
- No dropped frames
- Smooth animation

**Actual:** _____ fps average

**Status:** ⏳ Not tested

---

### Test 5.4: Real-time update latency
**Target:** <2 seconds from Firestore write to UI display

**Setup:**
- ChatListView open on Device A
- Firestore Console on computer

**Measurement:**
1. Note timestamp before Firestore write
2. Add new conversation in Firestore
3. Note timestamp when appears on Device A
4. Calculate difference

**Expected:** <2 seconds

**Actual:** _____ seconds

**Status:** ⏳ Not tested

---

### Test 5.5: Memory usage
**Target:** <30MB for 100 conversations

**Setup:**
- 100 conversations loaded

**Measurement:**
- Check Xcode Debug Navigator
- Note memory footprint

**Expected:** <30MB

**Actual:** _____ MB

**Status:** ⏳ Not tested

---

## 6. Acceptance Criteria

### Feature Completeness

- [ ] **1. ChatListView displays all user's conversations**
  - Test: Open app → See conversation list
  - Expected: All conversations visible

- [ ] **2. Conversations load instantly from local storage**
  - Test: Launch app → Measure time to display
  - Expected: <1 second

- [ ] **3. Real-time updates work automatically**
  - Test: Add conversation in Firestore → Check device
  - Expected: Appears within 2 seconds

- [ ] **4. List sorted by most recent conversation first**
  - Test: Check order of conversations
  - Expected: Newest at top

- [ ] **5. Each row shows: name, last message, timestamp**
  - Test: Visual inspection of rows
  - Expected: All fields visible

- [ ] **6. Profile pictures display (placeholder OK)**
  - Test: Check each row
  - Expected: Circle image (AsyncImage or placeholder)

- [ ] **7. Empty state when no conversations**
  - Test: Fresh user account
  - Expected: Icon + message + CTA button

- [ ] **8. Tap conversation navigates to ChatView**
  - Test: Tap any row
  - Expected: Navigation occurs (placeholder OK)

- [ ] **9. Pull-to-refresh works**
  - Test: Pull down on list
  - Expected: Refresh indicator + data sync

- [ ] **10. Offline mode shows local conversations**
  - Test: Enable airplane mode → Open app
  - Expected: Conversations display, no errors

- [ ] **11. All tests passing**
  - Run test suite
  - Expected: 0 failures

- [ ] **12. Performance targets met**
  - Check benchmarks
  - Expected: All <target times

- [ ] **13. No memory leaks**
  - Test: Instruments (Leaks)
  - Expected: Clean report

- [ ] **14. Documentation complete**
  - Check: All 5 planning docs exist
  - Expected: Comprehensive coverage

---

## Manual Testing Checklist

### Scenario A: First-Time User
**Goal:** Verify empty state and first conversation experience

**Steps:**
1. [ ] Create new Firebase user account
2. [ ] Log in to app
3. [ ] Verify empty state displays
4. [ ] Tap "New Chat" button
5. [ ] Verify placeholder sheet appears
6. [ ] Dismiss sheet
7. [ ] (After PR #8: Create first conversation)

---

### Scenario B: Returning User
**Goal:** Verify normal conversation list experience

**Steps:**
1. [ ] Log in with existing user (has conversations)
2. [ ] Verify conversations load immediately
3. [ ] Check sorting (most recent first)
4. [ ] Verify timestamps display correctly
5. [ ] Tap conversation
6. [ ] Verify navigation works
7. [ ] Tap back
8. [ ] Verify list preserved

---

### Scenario C: Real-Time Updates
**Goal:** Verify live updates without refresh

**Steps:**
1. [ ] Open ChatListView on Device A
2. [ ] Send message from Device B
3. [ ] Observe Device A
4. [ ] Verify conversation moves to top
5. [ ] Verify last message updates
6. [ ] Verify timestamp updates
7. [ ] Measure latency (<2s)

---

### Scenario D: Offline/Online
**Goal:** Verify offline resilience and sync

**Steps:**
1. [ ] Open app online (load conversations)
2. [ ] Enable airplane mode
3. [ ] Verify conversations still visible
4. [ ] Force quit app
5. [ ] Relaunch app (still offline)
6. [ ] Verify conversations load from local
7. [ ] Disable airplane mode
8. [ ] Verify sync occurs automatically
9. [ ] Verify no data loss

---

### Scenario E: Performance Under Load
**Goal:** Verify smooth performance with many conversations

**Steps:**
1. [ ] Create 100+ test conversations
2. [ ] Open ChatListView
3. [ ] Measure initial load time
4. [ ] Scroll rapidly through list
5. [ ] Verify smooth 60fps
6. [ ] Check memory usage
7. [ ] Verify no lag or stuttering

---

### Scenario F: Lifecycle Management
**Goal:** Verify proper listener cleanup

**Steps:**
1. [ ] Open ChatListView
2. [ ] Verify listener active (check logs)
3. [ ] Background app (home button)
4. [ ] Check logs: listener stopped
5. [ ] Foreground app
6. [ ] Check logs: listener restarted
7. [ ] Run Instruments (Leaks)
8. [ ] Verify no memory leaks

---

## Success Criteria Summary

**PR #7 is complete when:**
1. ✅ All 24 test cases pass
2. ✅ All 5 performance benchmarks met
3. ✅ All 14 acceptance criteria satisfied
4. ✅ All 6 manual scenarios tested
5. ✅ Zero memory leaks detected
6. ✅ Zero compiler warnings
7. ✅ Zero console errors during testing

**Quality Gates:**
- Load time: <1s local, <2s Firestore
- Scroll: 60fps with 100+ conversations
- Memory: <30MB for 100 conversations
- Real-time: <2s update latency
- Offline: Works without internet
- Leaks: None detected

---

## Testing Tools

### Xcode Instruments
```bash
# Run Instruments for memory leaks
1. Product → Profile (Cmd+I)
2. Choose "Leaks" template
3. Click Record
4. Use app (open/close ChatListView multiple times)
5. Check for leaks in timeline
```

### Xcode Debug Navigator
```bash
# Monitor memory usage
1. Run app (Cmd+R)
2. Open Debug Navigator (Cmd+7)
3. Select "Memory" row
4. Note memory footprint
5. Use app and watch for increases
```

### Network Link Conditioner
```bash
# Simulate poor network
1. System Settings → Developer
2. Enable "Network Link Conditioner"
3. Choose "3G" or "LTE" profile
4. Test app behavior
```

---

## Test Reporting Template

```markdown
# PR #7 Test Results

**Date:** [Date]
**Tester:** [Name]
**Device:** [iPhone model, iOS version]

## Unit Tests
- DateFormatter: ✅ 6/6 passed
- ChatListViewModel: ✅ 6/6 passed

## Integration Tests
- Full flows: ✅ 6/6 passed

## Edge Cases
- Edge scenarios: ✅ 6/6 passed

## Performance Tests
- Initial load: ✅ 0.8s (target: <1s)
- Firestore sync: ✅ 1.5s (target: <2s)
- Scroll: ✅ 60fps (target: 60fps)
- Real-time: ✅ 1.8s (target: <2s)
- Memory: ✅ 25MB (target: <30MB)

## Acceptance Criteria
- [✅] All 14 criteria met

## Manual Scenarios
- [✅] Scenario A: First-time user
- [✅] Scenario B: Returning user
- [✅] Scenario C: Real-time updates
- [✅] Scenario D: Offline/online
- [✅] Scenario E: Performance
- [✅] Scenario F: Lifecycle

## Issues Found
1. [None / Description of issues]

## Overall Status
✅ PASS - Ready to merge

**Notes:** [Any additional observations]
```

---

**Status:** Ready for testing after implementation ✓

