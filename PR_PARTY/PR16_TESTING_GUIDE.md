# PR#16: Decision Summarization - Testing Guide

**Feature:** AI-powered conversation summaries with GPT-4  
**Test Coverage:** 30+ comprehensive scenarios  
**Test Types:** Unit, Integration, Edge Cases, Performance, Acceptance

---

## Test Categories

### 1. Unit Tests (Cloud Function)
### 2. Unit Tests (iOS Models)
### 3. Integration Tests (End-to-End)
### 4. Edge Case Tests
### 5. Performance Tests
### 6. Acceptance Criteria

---

## 1. Unit Tests (Cloud Function)

### Test 1.1: decisionSummary() - Valid Conversation

**Setup:**
- Conversation with 10 messages containing clear decision
- Example: "Let's have the party on Saturday at 3pm"

**Test:**
```typescript
const result = await summarizeConversation(
  'test-conversation-id',
  'test-user-id',
  openai
);
```

**Expected Result:**
- summary: Non-empty string (2-3 sentences)
- decisions: Array with at least 1 item ("Party on Saturday at 3pm")
- actionItems: May be empty or contain items
- keyPoints: May contain "3pm", "Saturday"
- messageCount: 10

**Validation:**
```typescript
assert(result.summary.length > 0);
assert(result.decisions.length >= 1);
assert(result.messageCount === 10);
```

**Status:** ⏳ To test

---

### Test 1.2: decisionSummary() - Empty Conversation

**Setup:**
- Conversation with 0 messages

**Test:**
```typescript
const result = await summarizeConversation(
  'empty-conversation-id',
  'test-user-id',
  openai
);
```

**Expected Result:**
- summary: "No messages to summarize."
- decisions: []
- actionItems: []
- keyPoints: []
- messageCount: 0

**Validation:**
```typescript
assert(result.summary === "No messages to summarize.");
assert(result.decisions.length === 0);
assert(result.messageCount === 0);
```

**Status:** ⏳ To test

---

### Test 1.3: decisionSummary() - Unauthorized User

**Setup:**
- Conversation exists
- User is NOT a participant

**Test:**
```typescript
try {
  await summarizeConversation(
    'test-conversation-id',
    'non-participant-user-id',
    openai
  );
  assert.fail('Should have thrown error');
} catch (error) {
  assert(error.message === 'User not authorized to summarize this conversation');
}
```

**Expected Result:**
- Throws error: "User not authorized..."

**Status:** ⏳ To test

---

### Test 1.4: decisionSummary() - Conversation Not Found

**Setup:**
- Conversation ID that doesn't exist

**Test:**
```typescript
try {
  await summarizeConversation(
    'non-existent-id',
    'test-user-id',
    openai
  );
  assert.fail('Should have thrown error');
} catch (error) {
  assert(error.message === 'Conversation not found');
}
```

**Expected Result:**
- Throws error: "Conversation not found"

**Status:** ⏳ To test

---

### Test 1.5: decisionSummary() - 50 Message Conversation

**Setup:**
- Conversation with 50 messages (max scope)
- Mix of decisions, action items, casual chat

**Test:**
```typescript
const result = await summarizeConversation(
  'large-conversation-id',
  'test-user-id',
  openai
);
```

**Expected Result:**
- summary: Non-empty, concise (2-3 sentences)
- decisions: 2-5 items
- actionItems: 1-3 items
- keyPoints: 2-4 items
- messageCount: 50

**Performance:**
- Execution time: <5 seconds (cold start)

**Status:** ⏳ To test

---

### Test 1.6: processAI Router - decision_summary Route

**Setup:**
- Valid request with feature: "decision_summary"

**Test:**
```typescript
const result = await processAI({
  feature: 'decision_summary',
  conversationId: 'test-conversation-id'
}, context);
```

**Expected Result:**
- feature: "decision_summary"
- result: ConversationSummary object
- timestamp: number (unix timestamp)

**Status:** ⏳ To test

---

## 2. Unit Tests (iOS Models)

### Test 2.1: ConversationSummary - Firestore Round-Trip

**Setup:**
- Create ConversationSummary instance

**Test:**
```swift
let summary = ConversationSummary(
    id: "test-id",
    summary: "Test summary",
    decisions: ["Decision 1", "Decision 2"],
    actionItems: [
        ActionItem(id: "1", text: "Task 1", assignedTo: "Alice", dueDate: Date(), priority: .high)
    ],
    keyPoints: ["Point 1"],
    messageCount: 10,
    createdAt: Date(),
    createdBy: "user123"
)

// Convert to Firestore
let firestoreData = summary.toFirestore()

// Convert back
let restored = ConversationSummary.fromFirestore(firestoreData, id: "test-id")
```

**Expected Result:**
- restored equals summary (no data loss)
- All fields match original

**Validation:**
```swift
XCTAssertEqual(summary, restored)
XCTAssertEqual(summary.decisions, restored?.decisions)
XCTAssertEqual(summary.actionItems.count, restored?.actionItems.count)
```

**Status:** ⏳ To test

---

### Test 2.2: ConversationSummary - Computed Properties

**Test:**
```swift
let emptySummary = ConversationSummary(
    id: "test",
    summary: "Empty",
    decisions: [],
    actionItems: [],
    keyPoints: [],
    messageCount: 0,
    createdAt: Date(),
    createdBy: "user"
)

XCTAssertTrue(emptySummary.isEmpty)
XCTAssertFalse(emptySummary.hasDecisions)
XCTAssertFalse(emptySummary.hasActionItems)
XCTAssertFalse(emptySummary.hasKeyPoints)

let fullSummary = ConversationSummary(
    id: "test",
    summary: "Full",
    decisions: ["Decision"],
    actionItems: [ActionItem(id: "1", text: "Task", assignedTo: nil, dueDate: nil, priority: .medium)],
    keyPoints: ["Point"],
    messageCount: 10,
    createdAt: Date(),
    createdBy: "user"
)

XCTAssertFalse(fullSummary.isEmpty)
XCTAssertTrue(fullSummary.hasDecisions)
XCTAssertTrue(fullSummary.hasActionItems)
XCTAssertTrue(fullSummary.hasKeyPoints)
```

**Status:** ⏳ To test

---

### Test 2.3: ActionItem - Priority Colors and Emojis

**Test:**
```swift
let highPriority = ActionItem.Priority.high
XCTAssertEqual(highPriority.emoji, "🔴")
XCTAssertEqual(highPriority.color, .red)

let mediumPriority = ActionItem.Priority.medium
XCTAssertEqual(mediumPriority.emoji, "🟡")
XCTAssertEqual(mediumPriority.color, .orange)

let lowPriority = ActionItem.Priority.low
XCTAssertEqual(lowPriority.emoji, "⚪")
XCTAssertEqual(lowPriority.color, .gray)
```

**Status:** ⏳ To test

---

### Test 2.4: ActionItem - Overdue Detection

**Test:**
```swift
let overdueItem = ActionItem(
    id: "1",
    text: "Overdue task",
    assignedTo: nil,
    dueDate: Date().addingTimeInterval(-86400), // Yesterday
    priority: .high
)

XCTAssertTrue(overdueItem.isOverdue)

let futureItem = ActionItem(
    id: "2",
    text: "Future task",
    assignedTo: nil,
    dueDate: Date().addingTimeInterval(86400), // Tomorrow
    priority: .medium
)

XCTAssertFalse(futureItem.isOverdue)
```

**Status:** ⏳ To test

---

## 3. Integration Tests (End-to-End)

### Test 3.1: Complete Flow - Generate Summary

**Setup:**
- iOS app running on simulator
- Logged in as test user
- Group conversation with 20+ messages

**Test Steps:**
1. Navigate to conversation (ChatView)
2. Tap "Summarize" button (doc.text.magnifyingglass icon)
3. Observe loading state (ProgressView)
4. Wait 2-3 seconds
5. Verify summary card appears

**Expected Result:**
- Loading spinner appears immediately
- Summary card displays after 2-3 seconds
- Card contains:
  - Header with icon + message count
  - Summary text (2-3 sentences)
  - At least one section (Decisions/Action Items/Key Points)
  - Dismiss button (x)

**Performance:**
- Total time: <5 seconds (cold start)

**Status:** ⏳ To test

---

### Test 3.2: Complete Flow - Cached Summary

**Setup:**
- Summary generated in Test 3.1 (cache populated)

**Test Steps:**
1. Stay in same conversation
2. Tap "x" to dismiss summary
3. Immediately tap "Summarize" button again
4. Observe NO loading state
5. Verify summary appears instantly

**Expected Result:**
- Summary displays in <1 second (instant)
- Same summary as Test 3.1
- Console log: "✅ AIService: Using cached summary"

**Performance:**
- Total time: <1 second

**Status:** ⏳ To test

---

### Test 3.3: Complete Flow - Collapse/Expand Sections

**Setup:**
- Summary displayed (from Test 3.1)

**Test Steps:**
1. Tap "Decisions Made" header
2. Verify section collapses (smooth animation)
3. Tap again
4. Verify section expands (smooth animation)
5. Repeat for "Action Items" and "Key Points"

**Expected Result:**
- Each section collapses/expands independently
- Smooth spring animation (60fps)
- Chevron icon rotates (down → up → down)

**Status:** ⏳ To test

---

### Test 3.4: Complete Flow - Firestore Persistence

**Setup:**
- Summary generated (from Test 3.1)

**Test Steps:**
1. Open Firebase Console → Firestore
2. Navigate to /summaries collection
3. Find document with conversationId
4. Verify fields:
   - id (string)
   - summary (string)
   - decisions (array)
   - actionItems (array of objects)
   - keyPoints (array)
   - messageCount (number)
   - createdAt (timestamp)
   - createdBy (string - userId)

**Expected Result:**
- Document exists
- All fields present and correct types
- actionItems have nested structure (text, priority, assignedTo, dueDate)

**Status:** ⏳ To test

---

### Test 3.5: Complete Flow - Dismiss and Regenerate

**Setup:**
- Summary displayed (from Test 3.1)

**Test Steps:**
1. Tap "x" to dismiss summary
2. Wait 6 minutes (cache expires - 5 min TTL + 1 min buffer)
3. Tap "Summarize" button again
4. Observe loading state (re-generating)
5. Wait 2-3 seconds
6. Verify new summary appears

**Expected Result:**
- Loading state appears (cache expired)
- Summary regenerates (2-3 seconds)
- Summary may differ slightly (GPT-4 variance)
- Console log: "📊 AIService: Requesting summary..." (cache miss)

**Status:** ⏳ To test

---

## 4. Edge Case Tests

### Test 4.1: Empty Conversation (0 Messages)

**Setup:**
- New conversation with 0 messages

**Test Steps:**
1. Open conversation
2. Tap "Summarize" button
3. Observe error state

**Expected Result:**
- Error message: "No messages to summarize"
- OR: Empty summary card with message "No decisions or action items found"
- No crash

**Status:** ⏳ To test

---

### Test 4.2: Conversation with No Decisions

**Setup:**
- Conversation with 20 messages of casual chat (no decisions)
- Example: "Hi!", "How are you?", "Good!", etc.

**Test Steps:**
1. Generate summary

**Expected Result:**
- summary: "The conversation consisted of casual greetings and small talk."
- decisions: []
- actionItems: []
- keyPoints: [] or ["Casual conversation"]
- No crash, graceful handling

**Status:** ⏳ To test

---

### Test 4.3: Very Long Messages (Edge of Token Limit)

**Setup:**
- Conversation with 50 messages, each 100+ words (near 8k token limit)

**Test Steps:**
1. Generate summary

**Expected Result:**
- GPT-4 processes successfully (within 8k context window)
- Summary is concise despite long input
- OR: Error if exceeds limit (handled gracefully)
- No crash

**Status:** ⏳ To test

---

### Test 4.4: Messages with Emojis and Special Characters

**Setup:**
- Messages with emojis: "🎉 Party time! 🥳"
- Messages with special chars: "Let's meet @ 3pm! $50 budget"

**Test Steps:**
1. Generate summary

**Expected Result:**
- Emojis preserved or stripped gracefully
- Special characters handled correctly
- No encoding errors
- Summary readable and accurate

**Status:** ⏳ To test

---

### Test 4.5: Network Failure During Generation

**Setup:**
- Start summary generation
- Disable network mid-request (airplane mode)

**Test Steps:**
1. Tap "Summarize"
2. Immediately enable airplane mode
3. Wait for timeout

**Expected Result:**
- Error state after 30 seconds (timeout)
- Error message: "Network error. Please check your connection."
- Can retry (tap "Summarize" again)
- No crash

**Status:** ⏳ To test

---

### Test 4.6: OpenAI API Error (Rate Limit)

**Setup:**
- Exhaust OpenAI API rate limit (429 error)

**Test Steps:**
1. Generate 100+ summaries rapidly (exceed rate limit)
2. Observe error

**Expected Result:**
- Error state
- Error message: "Rate limit exceeded. Please try again later."
- App doesn't crash
- Can retry after cooldown

**Status:** ⏳ To test

---

### Test 4.7: User Not Participant (Unauthorized)

**Setup:**
- User A logged in
- Try to summarize conversation where User A is NOT a participant

**Test Steps:**
1. Attempt to generate summary (should fail in Cloud Function)

**Expected Result:**
- Error state
- Error message: "You are not authorized to summarize this conversation"
- No crash
- Security enforced

**Status:** ⏳ To test

---

### Test 4.8: Concurrent Summary Requests (Race Condition)

**Setup:**
- Tap "Summarize" button 5 times rapidly

**Test Steps:**
1. Rapid tap "Summarize" button
2. Observe behavior

**Expected Result:**
- First request proceeds normally
- Subsequent requests either:
  - Ignored (button disabled during loading)
  - OR: Queued (only one active request)
- No duplicate summaries
- No crash

**Status:** ⏳ To test

---

## 5. Performance Tests

### Test 5.1: Summary Generation Latency

**Measurement:**
- Time from button tap to summary display

**Scenarios:**
- 10 messages: <2 seconds (cold start), <1 second (warm)
- 50 messages: <5 seconds (cold start), <2 seconds (warm)

**Test:**
```swift
let startTime = Date()
let summary = try await AIService.shared.summarizeConversation(conversationId: "test")
let duration = Date().timeIntervalSince(startTime)
XCTAssertLessThan(duration, 5.0) // Cold start
```

**Target:** <5s (cold), <1s (cached)

**Status:** ⏳ To test

---

### Test 5.2: Cache Hit Rate

**Measurement:**
- Percentage of requests served from cache

**Test:**
1. Generate summary
2. Request 10 times within 5 minutes
3. Count cache hits

**Expected Result:**
- First request: Cache miss (generates new)
- Next 9 requests: Cache hits (instant)
- Cache hit rate: 90% (9/10)

**Target:** >60% cache hit rate in typical usage

**Status:** ⏳ To test

---

### Test 5.3: Memory Usage

**Measurement:**
- Memory consumption during summary generation and display

**Test:**
1. Record baseline memory
2. Generate summary
3. Display summary card
4. Dismiss summary
5. Record peak and final memory

**Expected Result:**
- Peak memory increase: <50MB
- Memory released after dismiss (no leaks)

**Target:** <50MB increase, no leaks

**Status:** ⏳ To test

---

### Test 5.4: UI Responsiveness (Animation Frame Rate)

**Measurement:**
- FPS during collapse/expand animations

**Test:**
1. Display summary card
2. Rapidly toggle sections (collapse/expand)
3. Measure FPS

**Expected Result:**
- Smooth animations: 60fps consistently
- No dropped frames
- Responsive to taps

**Target:** 60fps, no jank

**Status:** ⏳ To test

---

### Test 5.5: Cost Estimation

**Measurement:**
- OpenAI API cost per summary

**Calculation:**
- Input tokens: ~2,000 (50 messages)
- Output tokens: ~300 (summary)
- GPT-4 pricing: $0.03/1K input, $0.06/1K output
- Cost = (2000/1000 × $0.03) + (300/1000 × $0.06) = $0.078 ≈ $0.08

**Test:**
1. Generate 10 summaries
2. Check OpenAI usage dashboard
3. Calculate actual cost

**Expected Result:**
- Cost per summary: ~$0.06-0.08
- Monthly (30 summaries): ~$2-3
- Annual (365 summaries): ~$25-30

**Target:** <$0.10 per summary

**Status:** ⏳ To test

---

## 6. Acceptance Criteria

### Feature is COMPLETE when:

**Functional Requirements:**
- [ ] ✅ User can tap "Summarize" button in any conversation
- [ ] ✅ Loading state displays immediately (ProgressView)
- [ ] ✅ Summary generates in <5 seconds (cold), <1 second (cached)
- [ ] ✅ Summary card displays at top of chat
- [ ] ✅ Summary includes:
  - [ ] Main summary text (2-3 sentences)
  - [ ] Decisions section (if any)
  - [ ] Action Items section (if any)
  - [ ] Key Points section (if any)
- [ ] ✅ Sections collapse/expand smoothly (spring animation)
- [ ] ✅ Action items show priority emoji (🔴/🟡/⚪)
- [ ] ✅ Action items show assignedTo and dueDate (if available)
- [ ] ✅ User can dismiss summary (tap "x")
- [ ] ✅ Summary saved to Firestore (/summaries collection)
- [ ] ✅ Caching works (5-minute TTL)
- [ ] ✅ All error states handled gracefully

**Performance Requirements:**
- [ ] ✅ Generation time: <5s (cold), <1s (cached)
- [ ] ✅ Cache hit rate: >60% (in typical usage)
- [ ] ✅ Memory usage: <50MB increase
- [ ] ✅ UI animations: 60fps consistently
- [ ] ✅ Cost: ~$0.06-0.08 per summary

**Quality Requirements:**
- [ ] ✅ All 30+ test scenarios pass
- [ ] ✅ No critical bugs
- [ ] ✅ No console errors or warnings
- [ ] ✅ Code documented (comments, JSDoc, Swift docs)
- [ ] ✅ SwiftUI previews working

**Edge Cases Handled:**
- [ ] ✅ Empty conversations (0 messages)
- [ ] ✅ Conversations with no decisions
- [ ] ✅ Network failures (timeout, retry)
- [ ] ✅ Unauthorized users (security enforced)
- [ ] ✅ Concurrent requests (race conditions)

**Documentation:**
- [ ] ✅ Planning documents complete (5 files)
- [ ] ✅ Code comments added
- [ ] ✅ Testing results documented

---

## Test Execution Checklist

### Before Testing:
- [ ] All code implemented (6 phases complete)
- [ ] Project builds successfully (0 errors)
- [ ] Firebase deployed (Cloud Functions live)
- [ ] OpenAI credits available ($5+)

### During Testing:
- [ ] Follow test order (Unit → Integration → Edge → Performance)
- [ ] Document failures (screenshots, console logs)
- [ ] Re-test after fixes
- [ ] Check all acceptance criteria

### After Testing:
- [ ] All tests passing (or documented as deferred)
- [ ] Performance targets met
- [ ] No critical bugs remaining
- [ ] Write complete summary document

---

## Test Results Summary

**Total Tests:** 30+  
**Tests Passed:** _____ / 30  
**Tests Failed:** _____  
**Tests Deferred:** _____

**Performance:**
- Summary generation (cold): _____ seconds (target: <5s)
- Summary generation (cached): _____ seconds (target: <1s)
- Cache hit rate: _____% (target: >60%)
- Cost per summary: $_____  (target: <$0.10)

**Quality:**
- Critical bugs: _____ (target: 0)
- Memory leaks: _____ (target: 0)
- Console errors: _____ (target: 0)

**Recommendation:** ✅ READY FOR PRODUCTION / ⏳ NEEDS FIXES

---

**Testing Complete!** 🎉

Next: Write `PR16_COMPLETE_SUMMARY.md` with retrospective.


