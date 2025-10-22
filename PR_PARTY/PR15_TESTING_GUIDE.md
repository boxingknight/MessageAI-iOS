# PR#15: Calendar Extraction - Testing Guide

**Feature:** AI-powered calendar event extraction from messages  
**Scope:** Cloud Functions + iOS integration + EventKit  
**Test Coverage:** Unit, Integration, Edge Cases, Performance, Acceptance

---

## Test Categories

### 1. Cloud Function Unit Tests (TypeScript)
Test the `calendarExtraction.ts` function in isolation

### 2. iOS Unit Tests (Swift)
Test CalendarEvent model and AIService methods

### 3. Integration Tests (End-to-End)
Test full flow: message → Cloud Function → iOS → Calendar app

### 4. Edge Case Tests
Test unusual scenarios, ambiguous messages, error conditions

### 5. Performance Tests
Measure extraction time, accuracy, cost

### 6. Acceptance Criteria
Final checklist before declaring feature complete

---

## 1. Cloud Function Unit Tests

### Test Setup

```bash
# In functions/ directory
npm install --save-dev jest @types/jest ts-jest
npx ts-jest config:init
```

### Test 1.1: Extract Explicit Date and Time

**Input:** "Soccer practice Thursday at 4pm"  
**Expected:**
```json
{
  "events": [
    {
      "title": "Soccer practice",
      "date": "2025-10-24",  // Next Thursday
      "time": "16:00",
      "isAllDay": false,
      "confidence": > 0.9
    }
  ]
}
```

**Test Code:**
```typescript
describe('calendarExtraction', () => {
  it('should extract explicit date and time', async () => {
    const result = await extractCalendarEvents(
      'test_message_id',
      'test_user_id',
      false  // No context needed for explicit dates
    );
    
    expect(result).toHaveLength(1);
    expect(result[0].title).toBe('Soccer practice');
    expect(result[0].time).toBe('16:00');
    expect(result[0].isAllDay).toBe(false);
    expect(result[0].confidence).toBeGreaterThan(0.9);
    
    // Verify date is next Thursday
    const eventDate = new Date(result[0].date);
    expect(eventDate.getDay()).toBe(4);  // Thursday
  });
});
```

---

### Test 1.2: Extract Relative Date (Today/Tomorrow)

**Input:** "Doctor appointment tomorrow at 10am"  
**Expected:**
```json
{
  "events": [
    {
      "title": "Doctor appointment",
      "date": "2025-10-23",  // Tomorrow's date
      "time": "10:00",
      "confidence": > 0.9
    }
  ]
}
```

**Test Code:**
```typescript
it('should extract relative date (tomorrow)', async () => {
  const result = await extractCalendarEvents('msg', 'user', false);
  
  expect(result).toHaveLength(1);
  expect(result[0].title).toContain('Doctor');
  
  // Verify date is tomorrow
  const tomorrow = new Date();
  tomorrow.setDate(tomorrow.getDate() + 1);
  const tomorrowStr = tomorrow.toISOString().split('T')[0];
  expect(result[0].date).toBe(tomorrowStr);
});
```

---

### Test 1.3: Extract All-Day Event

**Input:** "School half day Friday"  
**Expected:**
```json
{
  "events": [
    {
      "title": "School half day",
      "date": "2025-10-25",  // Next Friday
      "time": null,
      "isAllDay": true,
      "confidence": > 0.7
    }
  ]
}
```

**Test Code:**
```typescript
it('should extract all-day event', async () => {
  const result = await extractCalendarEvents('msg', 'user', false);
  
  expect(result).toHaveLength(1);
  expect(result[0].title).toContain('School');
  expect(result[0].time).toBeNull();
  expect(result[0].isAllDay).toBe(true);
  expect(result[0].confidence).toBeGreaterThan(0.7);
});
```

---

### Test 1.4: Extract Location When Mentioned

**Input:** "Piano recital at community center 6pm Saturday"  
**Expected:**
```json
{
  "events": [
    {
      "title": "Piano recital",
      "location": "community center",
      "date": "2025-10-26",
      "time": "18:00"
    }
  ]
}
```

**Test Code:**
```typescript
it('should extract location if mentioned', async () => {
  const result = await extractCalendarEvents('msg', 'user', false);
  
  expect(result).toHaveLength(1);
  expect(result[0].title).toContain('Piano');
  expect(result[0].location).toContain('community center');
  expect(result[0].time).toBe('18:00');
});
```

---

### Test 1.5: Return Empty Array for Non-Event Messages

**Input:** "How are you doing?"  
**Expected:**
```json
{
  "events": []
}
```

**Test Code:**
```typescript
it('should return empty array for non-event messages', async () => {
  const result = await extractCalendarEvents('msg', 'user', false);
  
  expect(result).toHaveLength(0);
});
```

---

### Test 1.6: Skip Past Events (>1 Day Ago)

**Input:** "Yesterday's meeting was great"  
**Expected:**
```json
{
  "events": []  // Past events should be filtered out
}
```

**Test Code:**
```typescript
it('should skip past events', async () => {
  const result = await extractCalendarEvents('msg', 'user', false);
  
  // Should either return empty or mark event as past
  expect(result.every(e => new Date(e.date) >= oneDayAgo)).toBe(true);
});
```

---

### Test 1.7: Extract Multiple Events from One Message

**Input:** "Meeting at 2pm, then dinner at 7pm"  
**Expected:**
```json
{
  "events": [
    {
      "title": "Meeting",
      "time": "14:00"
    },
    {
      "title": "dinner",
      "time": "19:00"
    }
  ]
}
```

**Test Code:**
```typescript
it('should extract multiple events', async () => {
  const result = await extractCalendarEvents('msg', 'user', false);
  
  expect(result).toHaveLength(2);
  expect(result[0].title).toContain('Meeting');
  expect(result[0].time).toBe('14:00');
  expect(result[1].title).toContain('dinner');
  expect(result[1].time).toBe('19:00');
});
```

---

### Test 1.8: Use Context for Ambiguous Messages

**Input (with context):**
- Context Message 1: "We should meet next week"
- Context Message 2: "How about Thursday?"
- Current Message: "4pm works for me"

**Expected:**
```json
{
  "events": [
    {
      "title": "meeting",
      "date": "2025-10-24",  // Next Thursday
      "time": "16:00",
      "confidence": > 0.7  // Medium confidence due to ambiguity
    }
  ]
}
```

**Test Code:**
```typescript
it('should use context for ambiguous messages', async () => {
  // Mock context messages in Firestore
  const context = [
    'User1: We should meet next week',
    'User2: How about Thursday?',
  ];
  
  const result = await extractCalendarEvents('msg', 'user', true);
  
  expect(result).toHaveLength(1);
  expect(result[0].time).toBe('16:00');
  expect(result[0].confidence).toBeGreaterThan(0.6);
});
```

---

## 2. iOS Unit Tests (Swift)

### Test 2.1: CalendarEvent Date Parsing

**Goal:** Verify startDate computed property correctly parses ISO 8601 dates

**Test Code:**
```swift
import XCTest
@testable import messAI

class CalendarEventTests: XCTestCase {
    
    func testDateParsing_TimedEvent() {
        let event = CalendarEvent(
            id: "test",
            title: "Test Event",
            date: "2025-10-24",
            time: "16:00",
            isAllDay: false,
            location: nil,
            notes: nil,
            confidence: 0.95,
            extractedAt: Date()
        )
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour], from: event.startDate)
        
        XCTAssertEqual(components.year, 2025)
        XCTAssertEqual(components.month, 10)
        XCTAssertEqual(components.day, 24)
        XCTAssertEqual(components.hour, 16)
    }
    
    func testDateParsing_AllDayEvent() {
        let event = CalendarEvent(
            id: "test",
            title: "Test Event",
            date: "2025-10-25",
            time: nil,
            isAllDay: true,
            location: nil,
            notes: nil,
            confidence: 0.85,
            extractedAt: Date()
        )
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: event.startDate)
        
        XCTAssertEqual(components.year, 2025)
        XCTAssertEqual(components.month, 10)
        XCTAssertEqual(components.day, 25)
        XCTAssertTrue(event.isAllDay)
    }
}
```

---

### Test 2.2: CalendarEvent isPast Property

**Goal:** Verify isPast correctly identifies past events

**Test Code:**
```swift
func testIsPast_PastEvent() {
    let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
    let dateString = ISO8601DateFormatter().string(from: yesterday).prefix(10)
    
    let event = CalendarEvent(
        id: "test",
        title: "Past Event",
        date: String(dateString),
        time: nil,
        isAllDay: true,
        location: nil,
        notes: nil,
        confidence: 0.9,
        extractedAt: Date()
    )
    
    XCTAssertTrue(event.isPast)
}

func testIsPast_FutureEvent() {
    let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
    let dateString = ISO8601DateFormatter().string(from: tomorrow).prefix(10)
    
    let event = CalendarEvent(
        id: "test",
        title: "Future Event",
        date: String(dateString),
        time: nil,
        isAllDay: true,
        location: nil,
        notes: nil,
        confidence: 0.9,
        extractedAt: Date()
    )
    
    XCTAssertFalse(event.isPast)
}
```

---

### Test 2.3: CalendarEvent isUpcoming Property

**Goal:** Verify isUpcoming identifies events within next 24 hours

**Test Code:**
```swift
func testIsUpcoming_WithinDay() {
    let tomorrow = Calendar.current.date(byAdding: .hour, value: 12, to: Date())!
    let dateString = ISO8601DateFormatter().string(from: tomorrow).prefix(10)
    let timeString = ISO8601DateFormatter().string(from: tomorrow).suffix(8).prefix(5)
    
    let event = CalendarEvent(
        id: "test",
        title: "Upcoming Event",
        date: String(dateString),
        time: String(timeString),
        isAllDay: false,
        location: nil,
        notes: nil,
        confidence: 0.9,
        extractedAt: Date()
    )
    
    XCTAssertTrue(event.isUpcoming)
}

func testIsUpcoming_MoreThanDayAway() {
    let nextWeek = Calendar.current.date(byAdding: .day, value: 7, to: Date())!
    let dateString = ISO8601DateFormatter().string(from: nextWeek).prefix(10)
    
    let event = CalendarEvent(
        id: "test",
        title: "Future Event",
        date: String(dateString),
        time: nil,
        isAllDay: true,
        location: nil,
        notes: nil,
        confidence: 0.9,
        extractedAt: Date()
    )
    
    XCTAssertFalse(event.isUpcoming)
}
```

---

### Test 2.4: CalendarEvent toEKEvent Conversion

**Goal:** Verify CalendarEvent correctly converts to EKEvent

**Test Code:**
```swift
func testToEKEvent_Conversion() {
    let eventStore = EKEventStore()
    
    let calendarEvent = CalendarEvent(
        id: "test",
        title: "Test Event",
        date: "2025-10-24",
        time: "16:00",
        isAllDay: false,
        location: "Test Location",
        notes: "Test Notes",
        confidence: 0.95,
        extractedAt: Date()
    )
    
    let ekEvent = calendarEvent.toEKEvent(eventStore: eventStore)
    
    XCTAssertEqual(ekEvent.title, "Test Event")
    XCTAssertEqual(ekEvent.location, "Test Location")
    XCTAssertEqual(ekEvent.notes, "Test Notes")
    XCTAssertFalse(ekEvent.isAllDay)
    
    // Verify date/time
    let calendar = Calendar.current
    let components = calendar.dateComponents([.year, .month, .day, .hour], from: ekEvent.startDate)
    XCTAssertEqual(components.year, 2025)
    XCTAssertEqual(components.month, 10)
    XCTAssertEqual(components.day, 24)
    XCTAssertEqual(components.hour, 16)
    
    // Verify duration (default 1 hour for timed events)
    let duration = ekEvent.endDate.timeIntervalSince(ekEvent.startDate)
    XCTAssertEqual(duration, 3600, accuracy: 1)
}
```

---

## 3. Integration Tests (End-to-End)

### Test 3.1: Complete Extraction Flow

**Setup:**
1. Run app on simulator
2. Login as test user
3. Open conversation with another test user

**Steps:**
1. Send message: "Soccer practice Thursday at 4pm"
2. Long-press message
3. Tap "Extract Calendar Events"
4. Wait 2-3 seconds for AI processing

**Expected:**
- [ ] Calendar card appears below message
- [ ] Title: "Soccer practice"
- [ ] Date: Next Thursday's date (e.g., "Thursday, Oct 24 at 4:00 PM")
- [ ] Time: 4:00 PM
- [ ] isAllDay: false
- [ ] High confidence indicator (green checkmark or >0.9)
- [ ] "Add to Calendar" button visible and enabled

**Pass Criteria:** All expected elements present and correct ✅

---

### Test 3.2: Add to iOS Calendar

**Setup:** Continue from Test 3.1 (calendar card visible)

**Steps:**
1. Tap "Add to Calendar" button

**Expected (First Time):**
- [ ] iOS Calendar permission dialog appears
- [ ] Dialog text: "MessageAI would like to access your calendar"
- [ ] Grant permission

**Expected (Every Time):**
- [ ] Button shows loading spinner
- [ ] After 1-2 seconds, button changes to "Added to Calendar" with green checkmark
- [ ] Card remains visible but button is replaced with success state

**Steps:**
1. Open iOS Calendar app
2. Navigate to October 24 (next Thursday)
3. Look for event at 4:00 PM

**Expected:**
- [ ] Event "Soccer practice" exists in calendar
- [ ] Date: Thursday, Oct 24
- [ ] Time: 4:00 PM - 5:00 PM (default 1 hour duration)
- [ ] Calendar: Default calendar (usually "Calendar" or iCloud)

**Pass Criteria:** Event successfully added to iOS Calendar ✅

---

### Test 3.3: All-Day Event Extraction

**Setup:** Fresh message in conversation

**Steps:**
1. Send message: "School half day Friday"
2. Extract calendar events
3. Wait for calendar card

**Expected:**
- [ ] Calendar card appears
- [ ] Title: "School half day"
- [ ] Date: Next Friday (e.g., "Friday, Oct 25")
- [ ] NO time shown (all-day event)
- [ ] isAllDay icon (sun.max instead of clock)
- [ ] Medium confidence indicator (~0.7-0.9)
- [ ] "Add to Calendar" button visible

**Steps:**
1. Tap "Add to Calendar"
2. Open iOS Calendar app
3. Check Friday, Oct 25

**Expected:**
- [ ] Event exists as all-day event
- [ ] No specific time (appears at top of day)
- [ ] Duration: All day

**Pass Criteria:** All-day event correctly extracted and added ✅

---

### Test 3.4: Event with Location

**Setup:** Fresh message in conversation

**Steps:**
1. Send message: "Piano recital at community center 6pm Saturday"
2. Extract calendar events
3. Wait for calendar card

**Expected:**
- [ ] Calendar card appears
- [ ] Title: "Piano recital"
- [ ] Date: Saturday, Oct 26 at 6:00 PM
- [ ] Location: "community center" (with mappin icon)
- [ ] Location text visible in card

**Steps:**
1. Tap "Add to Calendar"
2. Open iOS Calendar app
3. Tap event to view details

**Expected:**
- [ ] Event location field populated: "community center"
- [ ] Can tap location to open Maps

**Pass Criteria:** Location correctly extracted and stored ✅

---

### Test 3.5: Past Event Handling

**Setup:** Fresh message in conversation

**Steps:**
1. Send message: "Yesterday's meeting was great"
2. Extract calendar events
3. Wait for calendar card

**Expected:**
- [ ] Calendar card appears (event still extracted)
- [ ] Title: "meeting" or "Yesterday's meeting"
- [ ] Date: Yesterday's date
- [ ] Event details grayed out (secondary color)
- [ ] Warning icon + text: "This event is in the past"
- [ ] NO "Add to Calendar" button (only "Dismiss")

**Steps:**
1. Try tapping where "Add" button would be

**Expected:**
- [ ] Nothing happens (button not present)
- [ ] Can only dismiss the card

**Pass Criteria:** Past events shown but not addable ✅

---

### Test 3.6: Low Confidence Event

**Setup:** Fresh message in conversation

**Steps:**
1. Send message: "We should meet sometime next week"
2. Extract calendar events
3. Wait for calendar card

**Expected:**
- [ ] Calendar card appears (event extracted despite low confidence)
- [ ] Title: "meeting" or "meet"
- [ ] Date: Sometime next week (AI's best guess)
- [ ] Low confidence warning:
  - Orange or red warning icon (questionmark.circle or triangle)
  - Text: "Low confidence - please verify"
- [ ] "Add to Calendar" button still visible (user can decide)

**Pass Criteria:** Low confidence events flagged with warning ✅

---

### Test 3.7: Multiple Events in One Message

**Setup:** Fresh message in conversation

**Steps:**
1. Send message: "Meeting at 2pm, then dinner at 7pm"
2. Extract calendar events
3. Wait for calendar cards

**Expected:**
- [ ] TWO calendar cards appear
- [ ] Card 1: "Meeting" at 2:00 PM
- [ ] Card 2: "dinner" at 7:00 PM
- [ ] Both on same date (today or contextual date)
- [ ] Both have separate "Add to Calendar" buttons

**Steps:**
1. Tap "Add to Calendar" on first card
2. Tap "Add to Calendar" on second card
3. Open iOS Calendar app

**Expected:**
- [ ] Both events added to calendar
- [ ] 2:00 PM - 3:00 PM: Meeting
- [ ] 7:00 PM - 8:00 PM: dinner

**Pass Criteria:** Multiple events extracted and added independently ✅

---

### Test 3.8: Context-Dependent Extraction

**Setup:** Fresh conversation with 3 messages

**Steps:**
1. Send Message 1: "We should meet to discuss the project"
2. Send Message 2: "How about Thursday?"
3. Send Message 3: "4pm works for me"
4. Long-press Message 3 → Extract calendar events (with context enabled)
5. Wait for calendar card

**Expected:**
- [ ] Calendar card appears with context-aware extraction
- [ ] Title: "meeting" or "meet to discuss the project"
- [ ] Date: Next Thursday
- [ ] Time: 4:00 PM
- [ ] Confidence: Medium (~0.7-0.8) due to context dependency

**Pass Criteria:** AI uses conversation context to extract complete event ✅

---

## 4. Edge Case Tests

### Test 4.1: No Events in Message

**Input:** "How are you doing?"  
**Expected:** No calendar cards appear (empty array from API)

**Steps:**
1. Send message: "How are you doing?"
2. Extract calendar events
3. Wait 2-3 seconds

**Expected:**
- [ ] No calendar cards appear
- [ ] Message displays normally (no error)
- [ ] Can try extracting again (idempotent)

**Pass Criteria:** Non-event messages handled gracefully ✅

---

### Test 4.2: Ambiguous Time Without Context

**Input:** "Let's meet"  
**Expected:** No event extracted OR very low confidence

**Steps:**
1. Send message: "Let's meet"
2. Extract calendar events (without context)
3. Wait 2-3 seconds

**Expected (Option A):**
- [ ] No calendar cards (too ambiguous, AI returns empty array)

**Expected (Option B):**
- [ ] Calendar card with very low confidence (<0.5)
- [ ] Red warning triangle
- [ ] Generic title like "meeting"
- [ ] Date/time missing or placeholder

**Pass Criteria:** Ambiguous messages don't produce false positives ✅

---

### Test 4.3: Complex Date Expression

**Input:** "Parent-teacher conference second Tuesday of next month at 3:30pm"  
**Expected:** Correctly calculates specific date

**Steps:**
1. Send message with complex date
2. Extract calendar events
3. Verify calculated date

**Expected:**
- [ ] Calendar card appears
- [ ] Title: "Parent-teacher conference"
- [ ] Date: Correct second Tuesday of next month
- [ ] Time: 3:30 PM
- [ ] High confidence (explicit despite complexity)

**Pass Criteria:** Complex date expressions parsed correctly ✅

---

### Test 4.4: Multiple Time Zones (Out of Scope for MVP)

**Input:** "Call at 2pm EST" (while device is in PST)  
**Expected:** MVP - Use device time zone (no conversion)

**Steps:**
1. Set device to PST time zone
2. Send message: "Call at 2pm EST"
3. Extract calendar events

**Expected (MVP Behavior):**
- [ ] Event at 2:00 PM PST (no timezone conversion)
- [ ] Note in event: "EST" (preserved in notes field)

**Future Enhancement:** Convert to device time zone

**Pass Criteria:** Time zones handled (even if not converted) ✅

---

### Test 4.5: Typos and Misspellings

**Input:** "Meetng tomorow at 3pm"  
**Expected:** GPT-4 handles typos gracefully

**Steps:**
1. Send message with typos
2. Extract calendar events

**Expected:**
- [ ] Calendar card appears
- [ ] Title: "meeting" (typo corrected or close enough)
- [ ] Date: Tomorrow
- [ ] Time: 3:00 PM
- [ ] High confidence (despite typos)

**Pass Criteria:** Common typos don't break extraction ✅

---

### Test 4.6: Non-English Messages (Future Enhancement)

**Input:** "Rendez-vous demain à 15h" (French)  
**Expected:** GPT-4 handles multilingual input

**Steps:**
1. Send message in French
2. Extract calendar events

**Expected (GPT-4 Capability):**
- [ ] Calendar card appears
- [ ] Title: "Rendez-vous" or "meeting"
- [ ] Date: Tomorrow
- [ ] Time: 3:00 PM (15h converted to 24-hour)
- [ ] Medium-high confidence

**Pass Criteria:** Multilingual extraction works (bonus feature) ✅

---

### Test 4.7: Very Long Message (>500 chars)

**Input:** Long message with event buried inside  
**Expected:** GPT-4 extracts relevant parts

**Steps:**
1. Send 500+ character message with "soccer practice Thursday 4pm" buried in middle
2. Extract calendar events

**Expected:**
- [ ] Calendar card appears
- [ ] Event correctly extracted despite noise
- [ ] Title, date, time accurate

**Pass Criteria:** Long messages don't break extraction ✅

---

### Test 4.8: Duplicate Extraction Request

**Input:** Extract events from same message twice  
**Expected:** Idempotent (same result, no duplicates)

**Steps:**
1. Extract events from message (first time)
2. Wait for card to appear
3. Extract events from same message again (second time)

**Expected:**
- [ ] Second extraction returns same data
- [ ] No duplicate calendar cards appear
- [ ] API call may be cached (implementation detail)

**Pass Criteria:** Multiple extractions don't create duplicates ✅

---

## 5. Performance Tests

### Test 5.1: Extraction Speed (Warm)

**Goal:** Measure AI processing time after cold start

**Steps:**
1. Extract events from first message (cold start, ignore this)
2. Extract events from second message (warm, measure this)
3. Start timer when "Extract" tapped
4. Stop timer when calendar card appears

**Target:** <2 seconds (warm request)  
**Acceptable:** <3 seconds  
**Excellent:** <1.5 seconds

**Pass Criteria:** 90% of warm extractions complete in <2 seconds ✅

---

### Test 5.2: Extraction Speed (Cold Start)

**Goal:** Measure first API call (Cloud Function cold start)

**Steps:**
1. Wait 5 minutes (Cloud Function goes cold)
2. Extract events from message
3. Start timer when "Extract" tapped
4. Stop timer when calendar card appears

**Target:** <5 seconds (cold start)  
**Acceptable:** <8 seconds  
**Excellent:** <4 seconds

**Pass Criteria:** Cold starts complete in <5 seconds ✅

---

### Test 5.3: Extraction Accuracy (Explicit Dates)

**Goal:** Measure AI accuracy on clear, explicit dates

**Test Set (20 messages):**
1. "Meeting Tuesday at 3pm"
2. "Soccer practice Thursday 4pm"
3. "Doctor appointment Friday 10am"
4. "Dinner Saturday 7pm"
5. "Brunch Sunday 11am"
... (15 more explicit date/time messages)

**Measurement:**
- Extract events from all 20 messages
- Manually verify each extraction
- Count correct vs incorrect

**Target:** >90% accuracy (18/20 correct)  
**Acceptable:** >85% accuracy (17/20 correct)  
**Excellent:** >95% accuracy (19/20 correct)

**Pass Criteria:** Explicit dates extracted with >90% accuracy ✅

---

### Test 5.4: Extraction Accuracy (Relative Dates)

**Goal:** Measure AI accuracy on relative dates (today/tomorrow/next week)

**Test Set (20 messages):**
1. "Meeting tomorrow at 2pm"
2. "Call later today at 5pm"
3. "Lunch next Tuesday"
4. "Appointment next week"
5. "Conference next month"
... (15 more relative date messages)

**Target:** >70% accuracy (14/20 correct)  
**Acceptable:** >60% accuracy (12/20 correct)  
**Excellent:** >80% accuracy (16/20 correct)

**Pass Criteria:** Relative dates extracted with >70% accuracy ✅

---

### Test 5.5: API Cost Per Extraction

**Goal:** Verify cost per extraction matches estimates

**Steps:**
1. Extract 10 events
2. Check OpenAI API usage: https://platform.openai.com/usage
3. Calculate cost per extraction

**Expected:** ~$0.02 per extraction (GPT-4 pricing)  
**Calculation:**
- GPT-4 input: ~500 tokens (system prompt + message + context) × $0.03/1K = $0.015
- GPT-4 output: ~200 tokens (JSON response) × $0.06/1K = $0.012
- **Total:** ~$0.027 per extraction

**Pass Criteria:** Cost per extraction is $0.015-$0.03 (within expected range) ✅

---

### Test 5.6: Daily Usage Per Active User

**Goal:** Estimate typical usage and monthly cost

**Measurement Period:** 1 week  
**Test Users:** 5-10 users with real usage patterns

**Track:**
- Number of extractions per user per day
- Types of messages extracted (explicit vs relative dates)
- Confirmation rate (events added to calendar vs dismissed)

**Expected:**
- 5-10 extractions per active user per day
- ~$0.10-0.20 per user per day
- ~$3-6 per user per month

**Pass Criteria:** Usage patterns match estimates (5-10 extractions/day) ✅

---

## 6. Acceptance Criteria

Feature is **COMPLETE** when ALL of the following are true:

### Core Functionality
- [ ] **✅ User can long-press message** → "Extract Calendar Events" appears in context menu
- [ ] **✅ AI extracts structured event data** → title, date, time from natural language
- [ ] **✅ Calendar card appears below message** → Beautiful SwiftUI card with event details
- [ ] **✅ User can confirm and add to Calendar** → Tap "Add to Calendar" → Event added to iOS Calendar app
- [ ] **✅ Events persist in message aiMetadata** → Stored in Firestore, syncs across devices
- [ ] **✅ Multiple events in one message handled** → Separate calendar cards for each event

### Data Accuracy
- [ ] **✅ Explicit dates extracted correctly** → "Thursday 4pm" → Next Thursday at 4:00 PM (>90% accuracy)
- [ ] **✅ Relative dates calculated** → "tomorrow" → Correct date (>70% accuracy)
- [ ] **✅ All-day events detected** → "Friday" → All-day event, no time
- [ ] **✅ Location extracted when mentioned** → "at community center" → Location field populated
- [ ] **✅ Confidence scoring working** → High (>0.9), Medium (0.7-0.9), Low (<0.7) with visual indicators

### Error Handling
- [ ] **✅ Past events handled gracefully** → Shown but grayed out, no "Add" button, warning displayed
- [ ] **✅ Low confidence events flagged** → Warning icon + text for confidence <0.8
- [ ] **✅ Non-event messages return empty** → "How are you?" → No calendar cards
- [ ] **✅ Calendar permission denied handled** → Clear error message, link to Settings
- [ ] **✅ API errors handled gracefully** → Network error → User-friendly message, can retry

### Performance
- [ ] **✅ Extraction time: <2 seconds** → Warm requests complete quickly (90% under target)
- [ ] **✅ Cold start: <5 seconds** → First request after idle acceptable (90% under target)
- [ ] **✅ Cost per extraction: ~$0.02** → Within expected range ($0.015-$0.03)
- [ ] **✅ Calendar add time: <2 seconds** → EventKit integration is fast

### Quality
- [ ] **✅ Zero critical bugs** → No crashes, data loss, or broken flows
- [ ] **✅ All unit tests passing** → CalendarEvent model, AIService methods
- [ ] **✅ All integration tests passing** → End-to-end flow works in all scenarios
- [ ] **✅ All edge cases handled** → Typos, long messages, ambiguous dates, etc.
- [ ] **✅ Works in light and dark mode** → UI looks good in both themes

### Documentation
- [ ] **✅ Memory bank updated** → activeContext.md reflects PR#15 completion
- [ ] **✅ PR_PARTY README updated** → PR#15 marked as complete with time/status
- [ ] **✅ Code comments added** → Key functions have clear documentation
- [ ] **✅ Testing results documented** → Test pass rates, performance metrics

### Deployment
- [ ] **✅ Cloud Functions deployed** → calendarExtraction live on Firebase
- [ ] **✅ iOS app builds successfully** → 0 errors, 0 warnings
- [ ] **✅ Feature works on simulator** → All tests pass on iOS Simulator
- [ ] **✅ Feature works on physical device** → Calendar integration tested on real iPhone

---

## Final Checklist (Before Declaring Complete)

### Critical Tests (MUST PASS)
- [ ] Test 3.1: Complete extraction flow (message → AI → card)
- [ ] Test 3.2: Add to iOS Calendar (EventKit integration)
- [ ] Test 3.3: All-day event extraction
- [ ] Test 3.5: Past event handling
- [ ] Test 3.7: Multiple events in one message

### Important Tests (Should Pass)
- [ ] Test 3.4: Event with location
- [ ] Test 3.6: Low confidence event warning
- [ ] Test 3.8: Context-dependent extraction
- [ ] Test 4.1: No events in message
- [ ] Test 4.5: Typos and misspellings

### Performance Benchmarks (Verify)
- [ ] Test 5.1: Warm extraction <2s
- [ ] Test 5.2: Cold start <5s
- [ ] Test 5.3: Explicit date accuracy >90%
- [ ] Test 5.4: Relative date accuracy >70%
- [ ] Test 5.5: API cost ~$0.02

### All Acceptance Criteria (Complete)
- [ ] All 26 acceptance criteria checked ✅
- [ ] Zero blocking bugs remaining
- [ ] Ready for production use

---

## Test Results Template

```markdown
## PR#15 Testing Results

**Date:** October XX, 2025  
**Tester:** [Your Name]  
**Environment:** iOS 16.0 Simulator / iPhone 14 Pro  
**Build:** messAI v1.0 (build XX)

### Unit Tests
- Cloud Function: X/8 passing (XXX%)
- iOS Models: X/4 passing (XXX%)
- Total: X/12 passing (XXX%)

### Integration Tests
- Core Flow: X/8 passing (XXX%)
- Edge Cases: X/8 passing (XXX%)
- Total: X/16 passing (XXX%)

### Performance Tests
- Warm Extraction: X.Xs avg (target: <2s) [PASS/FAIL]
- Cold Start: X.Xs avg (target: <5s) [PASS/FAIL]
- Explicit Accuracy: XX% (target: >90%) [PASS/FAIL]
- Relative Accuracy: XX% (target: >70%) [PASS/FAIL]
- Cost per Extraction: $X.XX (target: ~$0.02) [PASS/FAIL]

### Acceptance Criteria
- Core Functionality: X/6 complete
- Data Accuracy: X/5 complete
- Error Handling: X/5 complete
- Performance: X/4 complete
- Quality: X/5 complete
- Documentation: X/4 complete
- Deployment: X/4 complete

**Total: X/33 criteria met (XX%)**

### Bugs Found
1. [Bug description] - Severity: [CRITICAL/HIGH/MEDIUM/LOW] - Status: [FIXED/OPEN]
2. ...

### Conclusion
- [ ] ✅ READY FOR PRODUCTION (all critical tests pass, >95% acceptance criteria)
- [ ] 🟡 READY WITH ISSUES (critical tests pass, some minor issues)
- [ ] 🔴 NOT READY (critical bugs or <90% acceptance criteria)

**Recommendation:** [Deploy / Fix bugs first / More testing needed]
```

---

## Testing Tools & Resources

### Recommended Tools
- **Xcode Test Navigator** (⌘6) - Run unit/UI tests
- **Firebase Emulator Suite** - Local Cloud Functions testing
- **Charles Proxy** - Inspect API calls
- **Instruments** - Performance profiling
- **Console.app** - View iOS system logs

### Useful Commands
```bash
# Run Cloud Function unit tests
cd functions
npm test

# Run iOS unit tests
xcodebuild test -scheme messAI -destination 'platform=iOS Simulator,name=iPhone 14 Pro'

# Deploy to Firebase for integration testing
firebase deploy --only functions

# View Firebase logs
firebase functions:log --only calendarExtraction

# Check OpenAI API usage
open https://platform.openai.com/usage
```

---

**Testing complete = PR#15 complete!** 🎉📅✨

**Remember:** Test early, test often, test thoroughly. AI features require extra scrutiny because errors aren't always obvious!

