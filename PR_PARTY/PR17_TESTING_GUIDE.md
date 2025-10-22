# PR#17: Priority Highlighting - Testing Guide

**Feature:** AI-Powered Urgent Message Detection  
**Goal:** Never miss critical messages buried in group chats  
**Test Focus:** Classification accuracy, UI visibility, performance

---

## Test Categories

### 1. Unit Tests (Cloud Function Logic)
### 2. Integration Tests (iOS → Cloud Function → UI)
### 3. Accuracy Tests (Classification Performance)
### 4. UI/UX Tests (Visual Hierarchy)
### 5. Performance Tests (Speed & Cost)
### 6. Acceptance Tests (End-to-End Scenarios)

---

## 1. Unit Tests (Cloud Function Logic)

### Test 1.1: Critical Keywords Detection
**Function:** `keywordBasedDetection()`  
**Goal:** Verify critical keywords trigger critical level

| Test Case | Input | Expected Priority | Expected Confidence |
|-----------|-------|-------------------|-------------------|
| 1.1.1 | "urgent pickup change" | critical | >0.6 |
| 1.1.2 | "emergency school closed" | critical | >0.6 |
| 1.1.3 | "asap need form" | critical | >0.6 |
| 1.1.4 | "immediately pickup Noah" | critical | >0.6 |
| 1.1.5 | "right now payment due" | critical | >0.6 |

**How to Test:**
```typescript
// In Node.js console or test file
import { keywordBasedDetection } from './priorityDetection';

const result = await keywordBasedDetection("urgent pickup change");
console.log(result);
// Expected: { priorityLevel: 'critical', confidence: 0.7, keywords: ['urgent'], ... }
```

**Pass Criteria:**
- [ ] All 5 test cases return priorityLevel = "critical"
- [ ] Confidence >0.6 for all cases
- [ ] Keywords array includes detected keyword

---

### Test 1.2: High Priority Keywords Detection
**Function:** `keywordBasedDetection()`  
**Goal:** Verify high priority keywords trigger high level

| Test Case | Input | Expected Priority | Expected Confidence |
|-----------|-------|-------------------|-------------------|
| 1.2.1 | "important reminder tomorrow" | high | >0.5 |
| 1.2.2 | "soon need permission slip" | high | >0.5 |
| 1.2.3 | "today pickup at 3pm" | critical | >0.6 |
| 1.2.4 | "deadline Friday" | high | >0.5 |
| 1.2.5 | "don't forget snacks tomorrow" | high | >0.5 |

**Pass Criteria:**
- [ ] Test cases 1.2.1, 1.2.2, 1.2.4, 1.2.5 return "high"
- [ ] Test case 1.2.3 returns "critical" (time-sensitive pattern)
- [ ] Confidence >0.5 for high, >0.6 for critical

---

### Test 1.3: Normal Messages (No Keywords)
**Function:** `keywordBasedDetection()`  
**Goal:** Verify normal messages return normal level

| Test Case | Input | Expected Priority | Expected Confidence |
|-----------|-------|-------------------|-------------------|
| 1.3.1 | "thanks everyone" | normal | >0.8 |
| 1.3.2 | "sounds good" | normal | >0.8 |
| 1.3.3 | "anyone bringing cookies Friday?" | normal | >0.8 |
| 1.3.4 | "great idea!" | normal | >0.8 |
| 1.3.5 | "I can help with setup" | normal | >0.8 |

**Pass Criteria:**
- [ ] All 5 test cases return priorityLevel = "normal"
- [ ] Confidence >0.8 (high confidence it's normal)
- [ ] Keywords array is empty

---

### Test 1.4: Time-Sensitive Patterns
**Function:** `keywordBasedDetection()`  
**Goal:** Verify regex patterns catch time-sensitive messages

| Test Case | Input | Expected Priority | Expected timeContext |
|-----------|-------|-------------------|---------------------|
| 1.4.1 | "pickup at 2pm today" | critical | isToday: true, isImmediate: false |
| 1.4.2 | "meeting at 3pm" | critical | - |
| 1.4.3 | "due by tonight" | critical | isToday: true |
| 1.4.4 | "canceled this morning" | critical | - |
| 1.4.5 | "pickup changed to 4pm" | critical | - |

**Pass Criteria:**
- [ ] All test cases return priorityLevel = "critical"
- [ ] timeContext populated correctly
- [ ] Keywords include "time-sensitive-pattern"

---

### Test 1.5: GPT-4 Context Analysis
**Function:** `gpt4BasedDetection()`  
**Goal:** Verify GPT-4 analyzes ambiguous messages with context

**Test Case 1.5.1: Ambiguous Message with Urgent Context**
```typescript
const messageText = "Noah needs something by this afternoon";
const recentMessages = [
  { senderName: "Sarah", text: "Does anyone have extra permission slips?" },
  { senderName: "Mike", text: "I have one" },
  { senderName: "Sarah", text: "Noah needs something by this afternoon" }
];

const result = await gpt4BasedDetection(messageText, recentMessages, []);
```

**Expected:**
- priorityLevel: "high" or "critical" (based on "this afternoon" time constraint)
- confidence: >0.7
- reason: Mentions time constraint and action required

**Test Case 1.5.2: Normal Message Misclassified by Keywords**
```typescript
const messageText = "Thanks for the urgent help yesterday!";
const recentMessages = [
  { senderName: "Sarah", text: "Can someone help with the poster?" },
  { senderName: "Mike", text: "I can do it" },
  { senderName: "Sarah", text: "Thanks for the urgent help yesterday!" }
];

const result = await gpt4BasedDetection(messageText, recentMessages, ['urgent']);
```

**Expected:**
- priorityLevel: "normal" (GPT-4 overrides keyword due to past tense "yesterday")
- confidence: >0.7
- reason: Refers to past event, not current urgency

**Pass Criteria:**
- [ ] GPT-4 returns valid JSON with all required fields
- [ ] Context-aware classification (considers conversation flow)
- [ ] Overrides keyword detection when appropriate

---

## 2. Integration Tests (iOS → Cloud Function → UI)

### Test 2.1: End-to-End Priority Detection
**Goal:** Verify full flow from new message to UI update

**Steps:**
1. User A sends message: "urgent pickup at 2pm today"
2. iOS detects new message via Firestore listener
3. ChatViewModel triggers `detectPriorityIfNeeded(message)`
4. AIService calls Cloud Function `processAI(feature: "priority_detection")`
5. Cloud Function returns: `{ priorityLevel: "critical", confidence: 0.92, ... }`
6. ChatViewModel updates Firestore: `aiMetadata.priorityLevel = "critical"`
7. Firestore listener fires with updated message
8. UI updates: Message bubble gets red border + 🚨 badge
9. Priority banner appears with 1 urgent message

**Expected Timeline:**
- Message appears immediately (<100ms)
- Priority detection completes (1-3s)
- UI updates with border/badge (<500ms after detection)

**Pass Criteria:**
- [ ] Message displays immediately (optimistic UI)
- [ ] Priority detection completes within 3 seconds
- [ ] Firestore updated with priority metadata
- [ ] UI shows red border (3pt) around message
- [ ] UI shows 🚨 badge below message
- [ ] Priority banner appears at top of chat
- [ ] No console errors during flow

---

### Test 2.2: Cache Behavior
**Goal:** Verify 5-minute cache reduces duplicate API calls

**Steps:**
1. User A sends message: "important reminder for Friday"
2. AIService detects priority (Cloud Function called)
3. User B views message (triggers detection check)
4. AIService checks cache (should hit, no Cloud Function call)
5. Wait 6 minutes
6. User C views message (triggers detection check)
7. AIService cache expired (Cloud Function called again)

**Expected:**
- First detection: Cloud Function called (~2s)
- Second detection (within 5 min): Cache hit (<10ms)
- Third detection (after 6 min): Cloud Function called again (~2s)

**Pass Criteria:**
- [ ] First call takes 1-3 seconds
- [ ] Cached call takes <50ms
- [ ] Cache expires after 5 minutes
- [ ] Firebase logs show 2 Cloud Function calls (not 3)

---

### Test 2.3: Rate Limiting
**Goal:** Verify rate limiting prevents abuse

**Steps:**
1. Send 100 messages rapidly (simulate spam)
2. Verify first 100 requests succeed
3. Send 101st request
4. Verify rate limit error returned
5. Wait 1 hour
6. Verify requests work again

**Expected:**
- First 100 requests: Success
- Request 101: Error "Rate limit exceeded"
- After 1 hour: Requests work again

**Pass Criteria:**
- [ ] Rate limiting enforced at 100 requests/hour/user
- [ ] Error message clear: "Rate limit exceeded. Try again in X minutes."
- [ ] Rate limit resets after 1 hour

---

## 3. Accuracy Tests (Classification Performance)

### Test 3.1: True Positive Rate (Urgent Messages Correctly Flagged)
**Goal:** Measure what % of urgent messages are correctly classified as critical or high

**Test Set:** 25 Real Urgent Messages

| # | Message | Expected Level | Actual Level | Correct? |
|---|---------|----------------|--------------|----------|
| 1 | "Pickup changed to 2pm TODAY" | critical | ___ | ___ |
| 2 | "Emergency - school closed due to weather" | critical | ___ | ___ |
| 3 | "Payment due by 5pm today or late fee" | critical | ___ | ___ |
| 4 | "URGENT: Noah forgot medication at home" | critical | ___ | ___ |
| 5 | "Pickup at 3pm today instead of 4pm" | critical | ___ | ___ |
| 6 | "Permission slip due Friday" | high | ___ | ___ |
| 7 | "Important: Bring snacks tomorrow" | high | ___ | ___ |
| 8 | "Reminder - field trip Wednesday" | high | ___ | ___ |
| 9 | "Don't forget costume for play Thursday" | high | ___ | ___ |
| 10 | "Meeting moved to 2pm this afternoon" | critical | ___ | ___ |
| 11 | "Last day to sign up is tonight" | critical | ___ | ___ |
| 12 | "Canceled - no practice today" | high | ___ | ___ |
| 13 | "Need volunteers ASAP for event" | critical | ___ | ___ |
| 14 | "Noah needs $20 for lunch by Friday" | high | ___ | ___ |
| 15 | "Important update: New drop-off location" | high | ___ | ___ |
| 16 | "Pickup at main entrance today only" | critical | ___ | ___ |
| 17 | "Final notice: Permission slip required" | high | ___ | ___ |
| 18 | "Emergency contact needed immediately" | critical | ___ | ___ |
| 19 | "School closes early today at 1pm" | critical | ___ | ___ |
| 20 | "Deadline extended to Monday" | high | ___ | ___ |
| 21 | "Urgent change: Practice at 5pm not 6pm" | critical | ___ | ___ |
| 22 | "Important: Water bottles required tomorrow" | high | ___ | ___ |
| 23 | "Field trip payment due by Wednesday" | high | ___ | ___ |
| 24 | "Noah sick - pickup requested" | critical | ___ | ___ |
| 25 | "Bus delayed - pickup at 4:30pm" | critical | ___ | ___ |

**Calculate Metrics:**
- True Positive Rate = (Correctly flagged as critical/high) / (Total urgent messages)
- Target: >80%

**Pass Criteria:**
- [ ] True positive rate >80% (at least 20 of 25 correct)
- [ ] Critical messages (15) flagged with >90% accuracy
- [ ] High priority messages (10) flagged with >70% accuracy

---

### Test 3.2: True Negative Rate (Normal Messages Correctly Classified)
**Goal:** Measure what % of normal messages are correctly classified as normal

**Test Set:** 25 Real Normal Messages

| # | Message | Expected Level | Actual Level | Correct? |
|---|---------|----------------|--------------|----------|
| 1 | "Thanks everyone!" | normal | ___ | ___ |
| 2 | "Sounds good" | normal | ___ | ___ |
| 3 | "Anyone bringing cookies Friday?" | normal | ___ | ___ |
| 4 | "Great idea!" | normal | ___ | ___ |
| 5 | "I can help with setup" | normal | ___ | ___ |
| 6 | "Looking forward to it" | normal | ___ | ___ |
| 7 | "Count me in" | normal | ___ | ___ |
| 8 | "What time is the party?" | normal | ___ | ___ |
| 9 | "Noah had a great day today" | normal | ___ | ___ |
| 10 | "Thanks for organizing this!" | normal | ___ | ___ |
| 11 | "Anyone know the dress code?" | normal | ___ | ___ |
| 12 | "I'll bring chips" | normal | ___ | ___ |
| 13 | "See you all Friday!" | normal | ___ | ___ |
| 14 | "Great job on the project!" | normal | ___ | ___ |
| 15 | "Who's picking up after practice?" | normal | ___ | ___ |
| 16 | "Have a great weekend!" | normal | ___ | ___ |
| 17 | "Thanks for the info" | normal | ___ | ___ |
| 18 | "Love this group!" | normal | ___ | ___ |
| 19 | "Noah said thank you!" | normal | ___ | ___ |
| 20 | "Perfect, see you there" | normal | ___ | ___ |
| 21 | "Anyone need extra supplies?" | normal | ___ | ___ |
| 22 | "What's the weather forecast?" | normal | ___ | ___ |
| 23 | "Looks fun!" | normal | ___ | ___ |
| 24 | "I missed the last message, what did I miss?" | normal | ___ | ___ |
| 25 | "Thanks again for everything" | normal | ___ | ___ |

**Calculate Metrics:**
- True Negative Rate = (Correctly classified as normal) / (Total normal messages)
- Target: >85%

**Pass Criteria:**
- [ ] True negative rate >85% (at least 21 of 25 correct)
- [ ] False positives <15% (acceptable)

---

### Test 3.3: False Negative Rate (Urgent Messages Missed)
**Goal:** Measure what % of urgent messages are incorrectly classified as normal (MOST CRITICAL)

**Metric:** False Negative Rate = (Urgent messages classified as normal) / (Total urgent messages)

**Target:** <5% (no more than 1 in 20 urgent messages missed)

**Why Critical:** Missing an urgent message ("Pickup changed to 2pm TODAY") causes real-world problems (late pickup, angry parent). False negatives are NOT acceptable.

**Pass Criteria:**
- [ ] False negative rate <5%
- [ ] Zero false negatives for critical messages (pickup changes, emergencies)
- [ ] All time-sensitive messages detected

**If Test Fails:**
- Broaden keyword list (add variations, synonyms)
- Lower threshold for "normal" classification (require confidence >0.85 instead of >0.8)
- Tune GPT-4 prompt to be more sensitive to urgency

---

### Test 3.4: Ambiguous Messages (GPT-4 Context Analysis)
**Goal:** Verify GPT-4 correctly classifies ambiguous messages using context

| Test Case | Message | Context | Expected Level |
|-----------|---------|---------|----------------|
| 3.4.1 | "Noah needs it by this afternoon" | Previous: "Does anyone have permission slip?" | high |
| 3.4.2 | "Can someone help?" | Previous: "We need volunteers for tomorrow's event" | high |
| 3.4.3 | "That was urgent!" | Previous: "Thanks for helping yesterday" | normal (past tense) |
| 3.4.4 | "We should do something soon" | Previous: "Field trip in 2 weeks" | normal (vague) |
| 3.4.5 | "This needs attention" | Previous: "Payment portal not working" | high |

**Pass Criteria:**
- [ ] All ambiguous messages analyzed with GPT-4 (not keyword filter)
- [ ] Context considered in classification (check reason field)
- [ ] Past tense messages not flagged as urgent (3.4.3)
- [ ] Vague messages not flagged as urgent (3.4.4)

---

## 4. UI/UX Tests (Visual Hierarchy)

### Test 4.1: Priority Border Display
**Goal:** Verify colored borders display correctly for each priority level

| Priority | Expected Border | Border Width | Test Result |
|----------|----------------|--------------|-------------|
| Critical | Red (#FF0000) | 3pt | ___ |
| High | Orange (#FF9500) | 2pt | ___ |
| Normal | None | 0pt | ___ |

**How to Test:**
1. Create test messages with each priority level
2. View in ChatView
3. Visually inspect border color and width
4. Test in light and dark mode

**Pass Criteria:**
- [ ] Critical messages have thick red border (3pt)
- [ ] High messages have thin orange border (2pt)
- [ ] Normal messages have no border
- [ ] Borders clearly visible in both light and dark mode
- [ ] Borders don't interfere with message text readability

---

### Test 4.2: Priority Badge Display
**Goal:** Verify emoji badges display correctly for each priority level

| Priority | Expected Badge | Icon | Text |
|----------|---------------|------|------|
| Critical | 🚨 Critical | exclamationmark.triangle.fill | "Critical" |
| High | ⚠️ High Priority | exclamationmark.circle.fill | "High Priority" |
| Normal | None | - | - |

**How to Test:**
1. View messages with each priority level
2. Check badge appears below message bubble
3. Verify icon and text correct
4. Check confidence percentage displayed (if available)

**Pass Criteria:**
- [ ] Critical badge shows 🚨 + "Critical" + confidence %
- [ ] High badge shows ⚠️ + "High Priority" + confidence %
- [ ] Normal messages show no badge
- [ ] Badge readable and visually distinct
- [ ] Badge background color matches priority (red for critical, orange for high)

---

### Test 4.3: Priority Banner Display
**Goal:** Verify in-chat urgent message banner works correctly

**Test 4.3.1: Banner Appears When Urgent Messages Exist**
- [ ] Send critical message
- [ ] Verify banner appears at top of chat
- [ ] Verify banner shows "1 urgent message"
- [ ] Verify red warning icon displayed

**Test 4.3.2: Banner Expand/Collapse**
- [ ] Tap banner header
- [ ] Verify banner expands smoothly (animation)
- [ ] Verify urgent messages listed in banner
- [ ] Tap banner header again
- [ ] Verify banner collapses smoothly

**Test 4.3.3: Tap Message in Banner**
- [ ] Expand banner
- [ ] Tap on urgent message in list
- [ ] Verify chat scrolls to that message
- [ ] Verify message highlighted or centered
- [ ] Verify banner collapses after tap

**Test 4.3.4: Mark All as Seen**
- [ ] Expand banner with 3 urgent messages
- [ ] Tap "Mark all as seen" button
- [ ] Verify banner disappears
- [ ] Verify messages still have borders (not dismissed permanently)
- [ ] Verify priorityDismissed = true in Firestore

**Pass Criteria:**
- [ ] Banner appears/disappears correctly
- [ ] Expand/collapse animation smooth
- [ ] Tap message scrolls to it in chat
- [ ] Mark as seen works correctly

---

### Test 4.4: Accessibility
**Goal:** Verify priority indicators work for colorblind users

**Test Case 4.4.1: Color + Icon (Redundant Encoding)**
- Critical messages: Red border + 🚨 icon (triangle shape)
- High messages: Orange border + ⚠️ icon (circle shape)
- Verify: Users can distinguish levels without seeing colors (icon shape different)

**Test Case 4.4.2: VoiceOver Support**
- Enable VoiceOver (iOS accessibility)
- Tap on critical message
- Verify VoiceOver reads: "Critical priority message: [message text]"
- Tap on high message
- Verify VoiceOver reads: "High priority message: [message text]"

**Pass Criteria:**
- [ ] Icon shapes different (triangle vs circle)
- [ ] VoiceOver announces priority level
- [ ] Border width different (3pt vs 2pt) for tactile feedback

---

## 5. Performance Tests (Speed & Cost)

### Test 5.1: Keyword Detection Speed
**Goal:** Verify keyword filter fast enough (<100ms)

**Method:**
```typescript
const startTime = Date.now();
const result = await keywordBasedDetection("urgent pickup at 2pm");
const endTime = Date.now();
const duration = endTime - startTime;
console.log(`Keyword detection took ${duration}ms`);
```

**Test Cases:**
- [ ] Test 1: Short message (5 words) - Target: <50ms
- [ ] Test 2: Medium message (20 words) - Target: <100ms
- [ ] Test 3: Long message (100 words) - Target: <200ms

**Pass Criteria:**
- [ ] 95% of keyword detections complete in <100ms
- [ ] No keyword detection >500ms

---

### Test 5.2: GPT-4 Detection Speed
**Goal:** Verify GPT-4 analysis acceptable speed (<3s)

**Method:**
```typescript
const startTime = Date.now();
const result = await gpt4BasedDetection(messageText, recentMessages, []);
const endTime = Date.now();
const duration = endTime - startTime;
console.log(`GPT-4 detection took ${duration}ms`);
```

**Test Cases:**
- [ ] Cold start (first call) - Target: <5s
- [ ] Warm call (subsequent calls) - Target: <2s
- [ ] With context (10 messages) - Target: <3s

**Pass Criteria:**
- [ ] 95% of GPT-4 calls complete in <3 seconds
- [ ] No GPT-4 call >10 seconds (timeout should trigger)

---

### Test 5.3: Fast Path vs Slow Path Ratio
**Goal:** Verify 80% of messages use keyword filter (fast path), 20% use GPT-4 (slow path)

**Method:**
1. Send 100 diverse messages (mix of urgent and normal)
2. Check Firebase Functions logs
3. Count "FAST PATH" vs "SLOW PATH" log entries

**Expected Ratio:**
- FAST PATH: ~80 of 100 (80%)
- SLOW PATH: ~20 of 100 (20%)

**Pass Criteria:**
- [ ] At least 70% of messages use FAST PATH (keyword filter)
- [ ] No more than 30% use SLOW PATH (GPT-4)
- [ ] If >50% use SLOW PATH, keyword threshold too strict (adjust confidence requirement)

---

### Test 5.4: Cache Hit Rate
**Goal:** Verify 5-minute cache reduces duplicate API calls

**Method:**
1. Send same message 10 times within 5 minutes
2. Check Firebase Functions logs
3. Count actual Cloud Function invocations

**Expected:**
- Cloud Function called: 1 time (first message)
- Cache hits: 9 times (subsequent messages within 5 min)
- Cache hit rate: 90%

**Pass Criteria:**
- [ ] Cache hit rate >60% in real-world usage
- [ ] No duplicate API calls for same message within 5 minutes

---

### Test 5.5: Cost Estimation
**Goal:** Verify cost within budget (<$2/month/user)

**Assumptions:**
- User receives 100 messages/day
- 80% use keyword filter (free)
- 20% use GPT-4 (~$0.002/call)

**Calculation:**
- Messages/day: 100
- GPT-4 calls/day: 20 (20% of 100)
- GPT-4 cost/day: 20 × $0.002 = $0.04
- GPT-4 cost/month: $0.04 × 30 = $1.20/user

**Pass Criteria:**
- [ ] Estimated cost <$2/month/user
- [ ] If cost >$2, increase keyword filter threshold (reduce GPT-4 calls)

---

## 6. Acceptance Tests (End-to-End Scenarios)

### Test 6.1: Critical Pickup Change (Most Important Use Case)
**Scenario:** Sarah receives urgent message about pickup time change

**Steps:**
1. User A (teacher) sends: "Pickup changed to 2pm TODAY due to weather"
2. Sarah's phone receives message
3. AI detects critical urgency (time-sensitive + today + consequences)
4. Message displays with red border + 🚨 badge
5. Priority banner appears: "1 urgent message"
6. Sarah taps banner → scrolls to message
7. Sarah reads message and picks up on time

**Expected:**
- [ ] Message classified as "critical"
- [ ] Red border (3pt) clearly visible
- [ ] 🚨 badge confirms urgency
- [ ] Priority banner shows at top
- [ ] Tap banner scrolls to message
- [ ] Detection completes <3 seconds

**Pass Criteria:** Sarah sees urgent message before it's too late (this is the ENTIRE POINT of the feature!)

---

### Test 6.2: False Positive Handling (Normal Message Flagged)
**Scenario:** AI incorrectly flags normal message as urgent

**Steps:**
1. User A sends: "Thanks for the urgent help yesterday!"
2. Keyword filter detects "urgent" → triggers GPT-4
3. GPT-4 analyzes context: "yesterday" = past tense
4. GPT-4 overrides: Returns "normal" level
5. Message displays without indicators

**Alternative (if GPT-4 fails):**
6. Message incorrectly flagged as "high" (worst case)
7. Sarah sees orange border
8. Sarah dismisses as false positive
9. Sarah long-presses → "Mark as normal" (future feature)

**Pass Criteria:**
- [ ] Past tense messages not flagged as urgent
- [ ] If incorrectly flagged, user can dismiss
- [ ] False positive rate <20%

---

### Test 6.3: Multiple Urgent Messages (Banner Functionality)
**Scenario:** Sarah has 3 urgent messages in one conversation

**Steps:**
1. Send 3 critical messages:
   - "Pickup changed to 2pm TODAY"
   - "Payment due by 5pm today"
   - "Noah forgot lunch money"
2. Priority banner appears: "3 urgent messages"
3. Sarah taps banner → expands
4. Banner shows all 3 messages with preview
5. Sarah taps first message → scrolls to it in chat
6. Sarah addresses all 3 urgent items
7. Sarah taps "Mark all as seen"
8. Banner disappears

**Pass Criteria:**
- [ ] Banner counts correct (3 urgent messages)
- [ ] All 3 messages listed in banner
- [ ] Tap each message scrolls correctly
- [ ] Mark all as seen works
- [ ] Banner disappears when all seen

---

### Test 6.4: Urgent Message in Background (Notification Use Case)
**Scenario:** Sarah receives urgent message while app backgrounded

**Steps:**
1. Background MessageAI app
2. User A sends: "URGENT: Noah needs pickup at 2pm"
3. AI detects critical urgency
4. (Future PR#22) Push notification sent with "Critical" priority
5. Sarah sees notification on lock screen
6. Sarah taps notification → opens to chat
7. Message has red border + 🚨 badge
8. Priority banner shows at top

**Pass Criteria (Current PR#17):**
- [ ] AI detects urgency even when app backgrounded
- [ ] Priority saved to Firestore
- [ ] When app opened, message has red border
- [ ] Priority banner shows urgent message

**Note:** Enhanced notifications require PR#22

---

### Test 6.5: Global Urgent Tab (All Chats)
**Scenario:** Sarah has urgent messages across multiple conversations

**Steps:**
1. Conversation A: "Pickup changed to 2pm"
2. Conversation B: "Payment due by 5pm"
3. Conversation C: "Noah forgot lunch money"
4. Sarah opens Priority Tab
5. All 3 urgent messages displayed
6. Sorted by time (most recent first)
7. Sarah taps message → navigates to conversation
8. Sarah addresses all urgent items
9. Mark all as seen → tab empty

**Pass Criteria:**
- [ ] Priority tab shows all urgent messages across all chats
- [ ] Messages sorted by time
- [ ] Tap message navigates to correct conversation
- [ ] Mark all as seen works globally

**Note:** Priority tab implementation may be deferred to future PR if time-constrained

---

## Acceptance Criteria Summary

**Feature is COMPLETE when:**

### Functional Requirements
- [ ] ✅ Cloud Function classifies messages as critical/high/normal
- [ ] ✅ Keyword detection works (<100ms)
- [ ] ✅ GPT-4 fallback works for ambiguous messages (<3s)
- [ ] ✅ iOS calls Cloud Function and parses response correctly
- [ ] ✅ Message bubbles display priority borders (red 3pt, orange 2pt)
- [ ] ✅ Message bubbles display priority badges (🚨, ⚠️)
- [ ] ✅ Priority banner appears when urgent messages exist
- [ ] ✅ Banner expands/collapses smoothly
- [ ] ✅ Tap message in banner scrolls to message in chat
- [ ] ✅ Mark as seen dismisses urgent indicators
- [ ] ✅ Firestore schema updated (aiMetadata.priorityLevel)

### Accuracy Requirements
- [ ] ✅ True positive rate >80% (urgent messages flagged)
- [ ] ✅ False negative rate <5% (urgent messages not missed)
- [ ] ✅ False positive rate <20% (normal messages wrongly flagged)
- [ ] ✅ Time-sensitive messages detected with >90% accuracy

### Performance Requirements
- [ ] ✅ Keyword detection <100ms (95th percentile)
- [ ] ✅ GPT-4 detection <3s (95th percentile)
- [ ] ✅ 80% of messages use keyword filter (fast path)
- [ ] ✅ Cache hit rate >60% (5-minute TTL)
- [ ] ✅ Cost <$2/month/user at 100 messages/day

### Quality Requirements
- [ ] ✅ UI works in light and dark mode
- [ ] ✅ Accessibility: Border + icon (colorblind friendly)
- [ ] ✅ VoiceOver support (announces priority level)
- [ ] ✅ No console errors or warnings
- [ ] ✅ Smooth animations (60fps)
- [ ] ✅ All builds successful (0 errors, 0 warnings)

---

## Test Execution Checklist

### Phase 1: Unit Tests (Cloud Function)
- [ ] Run keyword detection tests (10 min)
- [ ] Run time pattern tests (5 min)
- [ ] Run GPT-4 tests with mock context (10 min)
- [ ] All unit tests passing

### Phase 2: Integration Tests
- [ ] Test end-to-end flow (iOS → Cloud Function → UI) (10 min)
- [ ] Test cache behavior (5 min)
- [ ] Test rate limiting (5 min)

### Phase 3: Accuracy Tests
- [ ] Test 25 urgent messages, calculate true positive rate (15 min)
- [ ] Test 25 normal messages, calculate true negative rate (15 min)
- [ ] Calculate false negative rate (must be <5%)
- [ ] Test ambiguous messages with GPT-4 (10 min)

### Phase 4: UI/UX Tests
- [ ] Visual inspection (borders, badges, colors) (5 min)
- [ ] Priority banner functionality (expand, collapse, tap, dismiss) (10 min)
- [ ] Accessibility testing (VoiceOver, colorblind) (10 min)

### Phase 5: Performance Tests
- [ ] Measure keyword detection speed (5 min)
- [ ] Measure GPT-4 detection speed (5 min)
- [ ] Check fast path vs slow path ratio in logs (5 min)
- [ ] Estimate cost (calculate from logs) (5 min)

### Phase 6: Acceptance Tests
- [ ] Run critical pickup change scenario (5 min)
- [ ] Run false positive handling scenario (5 min)
- [ ] Run multiple urgent messages scenario (5 min)

**Total Testing Time:** ~2.5 hours (comprehensive) or 30 min (smoke tests only)

---

## Pass/Fail Criteria

**PASS if:**
- ✅ All critical tests passing (accuracy >80%, false negatives <5%)
- ✅ Performance within targets (keyword <100ms, GPT-4 <3s)
- ✅ Cost within budget (<$2/month/user)
- ✅ UI clearly shows urgent messages (red border stands out)
- ✅ No critical bugs (no crashes, no data loss)

**FAIL if:**
- ❌ False negative rate >5% (missing urgent messages)
- ❌ GPT-4 detection >10 seconds (unacceptable delay)
- ❌ Cost >$5/month/user (unsustainable)
- ❌ UI unclear (users can't distinguish urgent from normal)
- ❌ Critical bugs (app crashes, Firestore errors)

**Conditional PASS (tune and retest):**
- ⚠️ True positive rate 70-80% (acceptable but should improve)
- ⚠️ False positive rate 20-30% (acceptable for safety feature)
- ⚠️ Cost $2-3/month/user (slightly over budget, tune threshold)

---

## Bug Reporting Template

**If you find a bug during testing:**

```markdown
## Bug #X: [Descriptive Title]

**Severity:** CRITICAL / HIGH / MEDIUM / LOW
**Test Case:** [Which test case failed]

**Observed Behavior:**
[What actually happened]

**Expected Behavior:**
[What should have happened]

**Steps to Reproduce:**
1. [Step 1]
2. [Step 2]
3. [Step 3]

**Error Messages:**
```
[Paste error logs here]
```

**Root Cause Analysis:**
[Why this happened - investigate and document]

**Proposed Fix:**
[How to fix this]

**Prevention:**
[How to prevent this in future]
```

---

**Remember:** "False positives OK (extra red borders), false negatives NOT OK (missing urgent messages)." Tune for safety, not perfection. 🎯
