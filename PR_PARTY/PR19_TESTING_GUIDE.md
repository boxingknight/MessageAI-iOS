# PR#19: Deadline Extraction - Testing Guide

**Feature**: AI-Powered Deadline Detection & Tracking  
**Estimated Testing Time**: 30-45 minutes  
**Priority**: 🔴 CRITICAL - Must work reliably (prevents missed deadlines)

---

## Testing Overview

### What We're Testing

1. **Cloud Function**: Keyword filter + GPT-4 extraction
2. **iOS Models**: Deadline data structure + computed properties
3. **Detection Logic**: Automatic detection on new messages
4. **In-Chat Display**: Deadline cards below messages
5. **Global View**: Deadline list with filtering
6. **Real-Time Updates**: Status changes (upcoming → today → overdue)
7. **Actions**: Mark complete, delete, dismiss
8. **Performance**: Speed (<3s) and cost (<$0.005/detection)

### Test Categories

- **Unit Tests** (15 tests): Individual components
- **Integration Tests** (10 tests): End-to-end flows
- **Edge Case Tests** (8 tests): Unusual inputs
- **Performance Tests** (4 tests): Speed and cost
- **User Acceptance Tests** (8 tests): Real-world scenarios

**Total**: 45 test scenarios

---

## Test Environment Setup

### Prerequisites

- [ ] iOS Simulator or physical device running
- [ ] Firebase project connected
- [ ] Cloud Functions deployed
- [ ] 2+ test users in Firestore
- [ ] Test conversations created

### Test Data Setup

```swift
// Create test users
let testUsers = [
    User(id: "user1", email: "parent1@test.com", displayName: "Sarah"),
    User(id: "user2", email: "parent2@test.com", displayName: "Mike"),
    User(id: "user3", email: "teacher@test.com", displayName: "Mrs. Johnson")
]

// Create test conversation
let testConversation = Conversation(
    id: "conv_school_group",
    participants: ["user1", "user2", "user3"],
    isGroup: true,
    groupName: "School Parent Group"
)
```

### Test Messages (Save these for copy-paste)

```
Explicit deadlines:
- "Permission slip due Wednesday by 3pm"
- "RSVP by next Friday"
- "Registration closes March 15th"
- "Submit forms before Monday 5pm"
- "Deadline: Thursday at noon"

Relative dates:
- "Due tomorrow at 2pm"
- "Closes this Friday"
- "Must turn in by end of week"
- "Deadline next Monday"

All-day deadlines:
- "Forms due March 20th"
- "Last day to register: Friday"
- "Payment deadline Wednesday"

Ambiguous:
- "Due soon"
- "Deadline approaching"
- "Need this by Friday" (Which Friday?)

Non-deadlines:
- "Hey, how are you?"
- "Thanks for the update!"
- "See you Friday!" (No deadline context)
```

---

## Unit Tests

### Test Suite 1: Cloud Function - Keyword Filter (5 tests)

#### Test 1.1: Detects Explicit Deadline Keywords
```typescript
Input: "Permission slip due Wednesday by 3pm"
Expected: containsDeadlineKeywords() returns true
Reason: Contains "due" + "Wednesday"
```

**Steps**:
1. Call `containsDeadlineKeywords("Permission slip due Wednesday by 3pm")`
2. Verify returns `true`

**Pass Criteria**: ✅ Returns true

---

#### Test 1.2: Filters Non-Deadline Messages
```typescript
Input: "Hey, how are you doing today?"
Expected: containsDeadlineKeywords() returns false
Reason: No deadline keywords or date patterns
```

**Steps**:
1. Call `containsDeadlineKeywords("Hey, how are you doing today?")`
2. Verify returns `false`

**Pass Criteria**: ✅ Returns false

---

#### Test 1.3: Requires Both Keyword AND Date
```typescript
Input: "This is due" (has keyword, no date)
Expected: containsDeadlineKeywords() returns false
Reason: Missing date pattern
```

**Steps**:
1. Call `containsDeadlineKeywords("This is due")`
2. Verify returns `false`

**Pass Criteria**: ✅ Returns false (both required)

---

#### Test 1.4: Detects Various Date Formats
```typescript
Inputs:
- "Due 3/15" (MM/DD)
- "Due March 15" (Month Day)
- "Due Friday" (Day name)
- "Due tomorrow" (Relative)

Expected: All return true
```

**Steps**:
1. Test each format
2. Verify all return `true`

**Pass Criteria**: ✅ All 4 formats detected

---

#### Test 1.5: Performance <100ms
```typescript
Input: 100 messages (mix of deadline/non-deadline)
Expected: Filter 100 messages in <100ms total
```

**Steps**:
1. Create array of 100 test messages
2. Time keyword filter on all 100
3. Calculate average per message

**Pass Criteria**: ✅ Average <1ms per message, total <100ms

---

### Test Suite 2: Cloud Function - GPT-4 Extraction (5 tests)

#### Test 2.1: Extracts Explicit Deadline
```typescript
Input: "Permission slip due Wednesday by 3pm"
Expected: 
{
  hasDeadline: true,
  title: "Permission slip",
  dueDate: "2025-03-15T15:00:00Z", // Next Wednesday
  isAllDay: false,
  priority: "high",
  confidence: > 0.8
}
```

**Steps**:
1. Call `extractDeadline("Permission slip due Wednesday by 3pm")`
2. Verify all fields present
3. Check date is correct (next Wednesday at 3pm)
4. Verify confidence > 0.8

**Pass Criteria**: ✅ Structured deadline returned with all fields

---

#### Test 2.2: Handles Relative Dates
```typescript
Input: "RSVP by next Friday"
Expected:
{
  hasDeadline: true,
  title: "RSVP",
  dueDate: [7 days from now], // Next Friday
  isAllDay: true,
  confidence: > 0.7
}
```

**Steps**:
1. Call `extractDeadline("RSVP by next Friday")`
2. Calculate expected date (next Friday)
3. Verify extracted date matches

**Pass Criteria**: ✅ Date calculated correctly from "next Friday"

---

#### Test 2.3: Returns No Deadline for Non-Deadline
```typescript
Input: "Hey, how are you?"
Expected: { hasDeadline: false }
```

**Steps**:
1. Call `extractDeadline("Hey, how are you?")`
2. Verify `hasDeadline: false`

**Pass Criteria**: ✅ No deadline returned

---

#### Test 2.4: Assigns Appropriate Priority
```typescript
Inputs:
- "Due today at 2pm" → priority: "high"
- "Due next week" → priority: "medium"
- "Due next month" → priority: "low"
```

**Steps**:
1. Extract deadline from each
2. Verify priority matches urgency

**Pass Criteria**: ✅ Priorities match deadline urgency

---

#### Test 2.5: Performance <3s
```typescript
Input: "Permission slip due Wednesday by 3pm"
Expected: Extraction completes in <3 seconds
```

**Steps**:
1. Time `extractDeadline()` call
2. Verify cold start <3s, warm <1s

**Pass Criteria**: ✅ Cold <3s, warm <1s

---

### Test Suite 3: iOS Models (5 tests)

#### Test 3.1: Deadline Computed Properties
```swift
Input: Deadline with dueDate = 3 days from now
Expected:
- daysRemaining = 3
- isOverdue = false
- isToday = false
- status = .upcoming
```

**Steps**:
1. Create Deadline with future date (3 days)
2. Verify computed properties
3. Check countdownText = "3 days remaining"

**Pass Criteria**: ✅ All computed properties correct

---

#### Test 3.2: Overdue Deadline
```swift
Input: Deadline with dueDate = 1 day ago
Expected:
- isOverdue = true
- status = .overdue
- statusColor = .red
```

**Steps**:
1. Create Deadline with past date
2. Verify overdue status
3. Check color coding

**Pass Criteria**: ✅ Overdue status and visual indicators correct

---

#### Test 3.3: Today Deadline
```swift
Input: Deadline with dueDate = today at 3pm
Expected:
- isToday = true
- hoursRemaining = [hours until 3pm]
- countdownText = "X hours remaining"
```

**Steps**:
1. Create Deadline for today
2. Verify isToday = true
3. Check hours calculation

**Pass Criteria**: ✅ Today deadline correctly identified

---

#### Test 3.4: Firestore Conversion
```swift
Input: Deadline object
Expected: 
- toFirestore() produces valid dict
- init(from: dict) recreates identical deadline
```

**Steps**:
1. Create Deadline
2. Convert to Firestore dict
3. Recreate from dict
4. Verify all fields match

**Pass Criteria**: ✅ Round-trip conversion lossless

---

#### Test 3.5: Status Enum Display Properties
```swift
Input: DeadlineStatus values
Expected: Each has correct color, icon, displayName
```

**Steps**:
1. Test each status (.upcoming, .today, .overdue, .completed)
2. Verify color coding
3. Verify SF Symbol names

**Pass Criteria**: ✅ All display properties correct

---

## Integration Tests

### Test Suite 4: End-to-End Detection Flow (5 tests)

#### Test 4.1: Message → Detection → Display (Happy Path)
```
Steps:
1. User A sends: "Permission slip due Wednesday by 3pm"
2. ChatViewModel receives message
3. detectMessageDeadline() triggered automatically
4. Cloud Function extracts deadline
5. Saved to Firestore /deadlines collection
6. Deadline card appears in chat
7. Deadline appears in global Deadlines tab
```

**Verification**:
- [ ] Message sent successfully
- [ ] Cloud Function called (check console logs)
- [ ] Deadline saved to Firestore
- [ ] Card displays below message
- [ ] Deadline in global tab
- [ ] Badge count updated

**Pass Criteria**: ✅ Complete flow works end-to-end in <5s

---

#### Test 4.2: Keyword Filter Prevents GPT-4 Call
```
Steps:
1. User A sends: "Hey, how are you?"
2. ChatViewModel receives message
3. Keyword filter returns false
4. No Cloud Function call
5. No deadline created
```

**Verification**:
- [ ] No API call logged
- [ ] No deadline card appears
- [ ] No Firestore write
- [ ] Fast response (<100ms)

**Pass Criteria**: ✅ Non-deadline message filtered without API call

---

#### Test 4.3: Multiple Deadlines in Conversation
```
Steps:
1. Send "Permission slip due Wednesday"
2. Send "RSVP by Friday"
3. Send "Registration closes Monday"
4. Open Deadlines tab
5. Verify all 3 deadlines present
```

**Verification**:
- [ ] 3 separate deadline cards in chat
- [ ] 3 deadlines in global tab
- [ ] All sorted by due date
- [ ] Badge shows "3"

**Pass Criteria**: ✅ Multiple deadlines tracked independently

---

#### Test 4.4: Real-Time Status Update
```
Steps:
1. Create deadline for "tomorrow at 3pm"
2. Wait until tomorrow
3. Verify status auto-updates from .upcoming → .today
4. Next day, verify .today → .overdue
```

**Verification**:
- [ ] Status changes automatically
- [ ] Color coding updates
- [ ] Countdown text updates
- [ ] Urgency level changes

**Pass Criteria**: ✅ Status updates automatically at correct times

---

#### Test 4.5: Cross-Device Sync
```
Steps:
1. User A (Device 1) sends deadline message
2. User B (Device 2) receives message
3. Deadline extracted on B's device
4. B marks deadline complete
5. Verify completion syncs to A's device
```

**Verification**:
- [ ] Deadline appears on both devices
- [ ] Real-time sync working
- [ ] Actions sync across devices
- [ ] No data loss

**Pass Criteria**: ✅ Cross-device sync works correctly

---

### Test Suite 5: UI & User Actions (5 tests)

#### Test 5.1: Deadline Card Display
```
Steps:
1. Send message with deadline
2. Verify card appears below message
3. Check all elements present:
   - Title
   - Due date
   - Countdown text
   - Priority indicator
   - Action buttons
```

**Verification**:
- [ ] Card visible in chat
- [ ] All elements displayed
- [ ] Visual hierarchy clear
- [ ] Color coding correct

**Pass Criteria**: ✅ Card displays all information clearly

---

#### Test 5.2: Mark Complete Action
```
Steps:
1. Tap "Complete" button on deadline card
2. Verify deadline removed from active list
3. Check appears in "Completed" filter
4. Verify status = .completed in Firestore
```

**Verification**:
- [ ] Card removed from chat (or visually marked complete)
- [ ] Removed from Upcoming/Today filters
- [ ] Appears in Completed filter
- [ ] Firestore updated

**Pass Criteria**: ✅ Mark complete works and syncs

---

#### Test 5.3: Global Deadline List Filtering
```
Steps:
1. Create deadlines: 1 upcoming, 1 today, 1 overdue, 1 completed
2. Open Deadlines tab
3. Test each filter:
   - Upcoming: shows 1
   - Today: shows 1
   - Overdue: shows 1
   - Completed: shows 1
```

**Verification**:
- [ ] Each filter shows correct deadlines
- [ ] Counts match badge
- [ ] Empty states show when appropriate
- [ ] Sorting by due date works

**Pass Criteria**: ✅ All filters work correctly

---

#### Test 5.4: Tap Deadline → Navigate to Conversation
```
Steps:
1. Open Deadlines tab
2. Tap a deadline
3. Verify navigation to source conversation
4. Verify message with deadline visible
```

**Verification**:
- [ ] Navigation works
- [ ] Correct conversation opens
- [ ] Scroll position at/near deadline message

**Pass Criteria**: ✅ Navigation to source conversation works

---

#### Test 5.5: Swipe Actions
```
Steps:
1. In Deadlines tab, swipe deadline right
2. Tap "Complete" action
3. Swipe another deadline left
4. Tap "Delete" action
```

**Verification**:
- [ ] Swipe reveals actions
- [ ] Complete action marks deadline complete
- [ ] Delete action removes deadline
- [ ] Animations smooth

**Pass Criteria**: ✅ Swipe actions work correctly

---

## Edge Case Tests

### Test Suite 6: Unusual Inputs (8 tests)

#### Test 6.1: Ambiguous Date - "Next Friday" on Friday
```
Input: "Due next Friday" sent on a Friday
Expected: Extracts date for Friday one week from now (not today)
```

**Steps**:
1. On Friday, send "Due next Friday"
2. Verify extracted date is 7 days ahead
3. Not same day

**Pass Criteria**: ✅ Correctly interprets "next Friday" as +7 days

---

#### Test 6.2: Past Deadline
```
Input: "Was due yesterday"
Expected: Status = .overdue immediately
```

**Steps**:
1. Send "Was due yesterday"
2. Verify deadline created with past date
3. Status = .overdue
4. Color = red

**Pass Criteria**: ✅ Past deadline correctly marked overdue

---

#### Test 6.3: Multiple Deadlines in One Message
```
Input: "Permission slip due Wednesday and RSVP by Friday"
Expected: 2 separate deadlines extracted
```

**Steps**:
1. Send message with 2 deadlines
2. Verify 2 deadline cards appear
3. Both with correct dates

**Pass Criteria**: ✅ Multiple deadlines extracted (if GPT-4 supports)

**Note**: May require GPT-4 prompt tuning to handle multiple deadlines

---

#### Test 6.4: Very Long Message (500+ chars)
```
Input: Long message with deadline buried in middle
Expected: Deadline still extracted
```

**Steps**:
1. Send 500+ char message with "due Wednesday" in middle
2. Verify deadline extracted
3. Check extractedFrom field truncated appropriately

**Pass Criteria**: ✅ Works with long messages

---

#### Test 6.5: Non-English Deadline (Optional)
```
Input: "Fecha límite: viernes" (Spanish: "Deadline: Friday")
Expected: Extracts deadline (if GPT-4 supports)
```

**Steps**:
1. Send non-English deadline message
2. Check if GPT-4 extracts
3. Document behavior

**Pass Criteria**: ⚠️ Document behavior (not required for MVP)

---

#### Test 6.6: Deadline with No Specific Time
```
Input: "Due Friday" (no time specified)
Expected: isAllDay = true
```

**Steps**:
1. Send "Due Friday" (no time)
2. Verify isAllDay = true
3. Countdown shows "X days remaining" not hours

**Pass Criteria**: ✅ All-day deadline handled correctly

---

#### Test 6.7: Ambiguous Deadline - "Due Soon"
```
Input: "Due soon"
Expected: No deadline created (too vague)
```

**Steps**:
1. Send "Due soon"
2. Verify GPT-4 returns hasDeadline: false
3. No deadline card appears

**Pass Criteria**: ✅ Vague deadlines filtered out (or low confidence rejected)

---

#### Test 6.8: Deadline in Question Form
```
Input: "Is the permission slip due Wednesday?"
Expected: Extracts deadline (with lower confidence)
```

**Steps**:
1. Send "Is the permission slip due Wednesday?"
2. Check if deadline extracted
3. Verify confidence score reflects uncertainty

**Pass Criteria**: ✅ Handles questions appropriately (extract or skip based on confidence)

---

## Performance Tests

### Test Suite 7: Speed & Cost (4 tests)

#### Test 7.1: Keyword Filter Speed
```
Input: 100 messages (mix of deadline/non-deadline)
Expected: <100ms total to filter all 100
```

**Steps**:
1. Create array of 100 test messages
2. Time keyword filter on all 100
3. Calculate total time

**Pass Criteria**: ✅ <100ms for 100 messages (<1ms each)

---

#### Test 7.2: GPT-4 Extraction Speed
```
Input: 10 deadline messages
Expected: 
- Cold start: <3s each
- Warm: <1s each
```

**Steps**:
1. Call extractDeadline() 10 times
2. Measure first call (cold start)
3. Measure subsequent calls (warm)

**Pass Criteria**: ✅ Cold <3s, warm <1s

---

#### Test 7.3: Firestore Query Performance
```
Input: User with 50 deadlines
Expected: Load all deadlines in <1s
```

**Steps**:
1. Create 50 test deadlines in Firestore
2. Open Deadlines tab
3. Time how long to load and display all 50

**Pass Criteria**: ✅ <1s to load and display 50 deadlines

---

#### Test 7.4: Cost per Deadline
```
Input: 20 messages (10 deadline, 10 non-deadline)
Expected: 
- Keyword filter: $0 (client-side)
- GPT-4 calls: 10 (50% pass rate)
- Cost: ~$0.03 total (~$0.003 per detection)
```

**Steps**:
1. Send 20 test messages
2. Count GPT-4 API calls
3. Calculate cost (check OpenAI dashboard)

**Pass Criteria**: ✅ <$0.005 average per deadline detected

---

## User Acceptance Tests

### Test Suite 8: Real-World Scenarios (8 tests)

#### Test 8.1: School Parent Group Scenario
```
Scenario: Sarah receives multiple school deadlines in group chat

Steps:
1. Create group chat "School Parent Group"
2. Send messages:
   - "Permission slip due Wednesday by 3pm"
   - "Bake sale signup closes Friday"
   - "Field trip payment deadline Monday"
3. Open Deadlines tab
4. Verify all 3 deadlines visible
5. Tap each to navigate to source
```

**User Experience**:
- Deadlines automatically detected
- Clear overview of all school obligations
- Easy navigation to source messages

**Pass Criteria**: ✅ Sarah can see all school deadlines at a glance

---

#### Test 8.2: RSVP Deadline Scenario
```
Scenario: Mike needs to RSVP by Friday

Steps:
1. Receive "Please RSVP by Friday 5pm"
2. Deadline card appears automatically
3. Shows countdown "2 days remaining"
4. Mike marks complete after RSVPing
5. Deadline removed from active list
```

**User Experience**:
- No manual reminder setting
- Visual countdown creates urgency
- Easy to mark complete

**Pass Criteria**: ✅ Mike successfully tracks and completes RSVP

---

#### Test 8.3: Overdue Deadline Alert
```
Scenario: Sarah missed a deadline (it's now overdue)

Steps:
1. Create deadline for "yesterday"
2. Open Deadlines tab
3. Check "Overdue" filter
4. Verify deadline shows in red
5. Countdown text = "Overdue"
```

**User Experience**:
- Clear visual indication of overdue status
- Deadline doesn't disappear (still visible)
- Can mark complete even if overdue

**Pass Criteria**: ✅ Overdue deadlines clearly visible

---

#### Test 8.4: Multiple Conversations with Deadlines
```
Scenario: Sarah has deadlines across 3 conversations

Steps:
1. Create deadlines in:
   - School group: "Permission slip due Wed"
   - Soccer team: "Uniform order by Fri"
   - Work group: "Report due Mon"
2. Open Deadlines tab
3. Verify all 3 visible
4. Sorted by due date (Wed, Fri, Mon)
```

**User Experience**:
- Single view of all deadlines
- Across all conversations
- Chronological order

**Pass Criteria**: ✅ Global view shows all deadlines from all chats

---

#### Test 8.5: Today's Deadlines
```
Scenario: Sarah checks what's due today

Steps:
1. Create 2 deadlines for today
2. Create 3 deadlines for future
3. Open Deadlines tab
4. Tap "Today" filter
5. Verify only today's 2 deadlines shown
6. Check badge shows "2"
```

**User Experience**:
- Focus on immediate deadlines
- Clear filtering
- Badge provides quick count

**Pass Criteria**: ✅ "Today" filter shows only today's deadlines

---

#### Test 8.6: Ambiguous Message - No False Positives
```
Scenario: User says "See you Friday!" (not a deadline)

Steps:
1. Send "See you Friday! Looking forward to it"
2. Verify NO deadline created
3. Keyword filter should pass
4. GPT-4 should return hasDeadline: false
```

**User Experience**:
- No annoying false detections
- Only real deadlines extracted
- High confidence threshold prevents errors

**Pass Criteria**: ✅ No deadline created for non-deadline message

---

#### Test 8.7: Deadline with Location
```
Scenario: Deadline includes location information

Steps:
1. Send "Drop-off at school by 8am Monday"
2. Verify deadline extracted
3. Description includes "at school"
4. Due time = 8am Monday
```

**User Experience**:
- Contextual information preserved
- Full details in description field

**Pass Criteria**: ✅ Location information captured in description

---

#### Test 8.8: Long-Term Deadline
```
Scenario: Deadline several weeks away

Steps:
1. Send "Registration closes March 31st" (3 weeks away)
2. Verify deadline created
3. Status = .upcoming
4. Priority = .low (not urgent yet)
5. Countdown shows "21 days remaining"
```

**User Experience**:
- Long-term deadlines tracked
- Not overly urgent visually
- Countdown provides awareness

**Pass Criteria**: ✅ Long-term deadlines tracked appropriately

---

## Acceptance Criteria

### Feature is complete when:

1. **Automatic Detection** ✅
   - [ ] Messages with deadlines auto-detected
   - [ ] Keyword filter screens 70-80% of messages
   - [ ] No user action required (fully automatic)
   - [ ] Works in 1-on-1 and group chats

2. **Cloud Function Performance** ✅
   - [ ] Keyword filter <100ms (95th percentile)
   - [ ] GPT-4 extraction <3s cold, <1s warm (95th percentile)
   - [ ] Cost <$0.005 per deadline detected
   - [ ] Handles 100+ messages/day per user

3. **Extraction Accuracy** ✅
   - [ ] >85% accuracy for explicit deadlines
   - [ ] <10% false positive rate
   - [ ] <5% false negative rate for urgent deadlines
   - [ ] Confidence scoring works (>0.7 threshold)

4. **In-Chat Display** ✅
   - [ ] Deadline card appears below message
   - [ ] All information visible (title, date, countdown)
   - [ ] Status color coding works
   - [ ] Actions functional (complete, remind, dismiss)

5. **Global Deadline List** ✅
   - [ ] All deadlines from all conversations visible
   - [ ] Filter tabs work (Upcoming/Today/Overdue/Completed)
   - [ ] Sorting by due date correct
   - [ ] Tap navigates to source conversation
   - [ ] Badge shows active deadline count

6. **Real-Time Updates** ✅
   - [ ] Status auto-updates (upcoming → today → overdue)
   - [ ] Countdown text updates
   - [ ] Cross-device sync working
   - [ ] No manual refresh needed

7. **User Actions** ✅
   - [ ] Mark complete removes from active lists
   - [ ] Delete removes permanently
   - [ ] Swipe actions work smoothly
   - [ ] Actions sync across devices

8. **Data Persistence** ✅
   - [ ] Deadlines saved to Firestore
   - [ ] Survive app restart
   - [ ] No data loss
   - [ ] Firestore queries optimized with indexes

9. **Performance** ✅
   - [ ] No UI lag when processing deadlines
   - [ ] Smooth animations
   - [ ] Fast loading (<1s for 50+ deadlines)
   - [ ] Responsive on poor networks

10. **Edge Cases Handled** ✅
    - [ ] Ambiguous dates resolved correctly
    - [ ] Past deadlines marked overdue
    - [ ] All-day vs time-specific handled
    - [ ] Long messages work
    - [ ] Non-deadline messages filtered

---

## Test Execution Checklist

### Pre-Testing
- [ ] All code implemented and compiles
- [ ] Cloud Function deployed
- [ ] Test data created
- [ ] 2+ test users logged in
- [ ] Firebase Console open (to verify Firestore writes)

### During Testing
- [ ] Run tests sequentially (don't skip)
- [ ] Document failures immediately
- [ ] Take screenshots of issues
- [ ] Check console logs for errors
- [ ] Verify Firestore data after each test

### Post-Testing
- [ ] All 45 tests executed
- [ ] Pass/fail recorded
- [ ] Bugs logged with reproduction steps
- [ ] Performance metrics documented
- [ ] Edge cases verified

---

## Bug Tracking Template

```
Bug #__: [Brief description]

Severity: CRITICAL / HIGH / MEDIUM / LOW
Test: [Test number that found the bug]

Steps to Reproduce:
1. [Step 1]
2. [Step 2]
3. [Step 3]

Expected Result:
[What should happen]

Actual Result:
[What actually happened]

Error Messages:
[Console logs, error alerts]

Screenshots:
[Attach screenshots]

Root Cause (if known):
[Analysis]

Fix:
[Code changes to resolve]

Verification:
- [ ] Fix implemented
- [ ] Test re-run and passing
- [ ] No regressions
```

---

## Performance Benchmarks

### Target Metrics

| Metric | Target | Acceptable | Unacceptable |
|--------|--------|------------|--------------|
| Keyword filter | <50ms | <100ms | >100ms |
| GPT-4 extraction (cold) | <2s | <3s | >3s |
| GPT-4 extraction (warm) | <0.5s | <1s | >1s |
| Firestore write | <200ms | <500ms | >500ms |
| UI update | <50ms | <100ms | >100ms |
| Load 50 deadlines | <500ms | <1s | >1s |
| Cost per deadline | <$0.003 | <$0.005 | >$0.005 |

### How to Measure

**Keyword Filter**:
```swift
let start = CFAbsoluteTimeGetCurrent()
let result = containsDeadlineKeywords(messageText)
let duration = (CFAbsoluteTimeGetCurrent() - start) * 1000
print("Keyword filter: \(duration)ms")
```

**GPT-4 Extraction**:
```swift
let start = CFAbsoluteTimeGetCurrent()
let result = try await aiService.extractDeadline(...)
let duration = (CFAbsoluteTimeGetCurrent() - start) * 1000
print("GPT-4 extraction: \(duration)ms")
```

**Cost**:
```
Check OpenAI dashboard:
- GPT-4 pricing: ~$0.03 per 1K tokens
- Average deadline extraction: ~100 tokens
- Cost: ~$0.003 per extraction
```

---

## Final Verification

### Before Declaring PR Complete

- [ ] All 45 test scenarios passing
- [ ] Performance within targets
- [ ] No critical or high-severity bugs
- [ ] Cross-device sync verified
- [ ] Cost per deadline <$0.005
- [ ] User experience smooth and intuitive
- [ ] Edge cases handled gracefully
- [ ] Documentation updated
- [ ] Demo video recorded (optional)

---

**Testing Status**: Ready to execute  
**Estimated Time**: 30-45 minutes for full test suite  
**Priority**: 🔴 CRITICAL - This feature prevents missed deadlines, must be reliable

**Remember**: Focus on real-world scenarios. The goal is to help busy parents never miss important deadlines buried in group chats. Test with that user in mind! 👨‍👩‍👧‍👦

