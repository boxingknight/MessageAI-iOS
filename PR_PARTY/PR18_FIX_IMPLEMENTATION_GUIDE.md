# PR#18 Architecture Fix - Implementation Guide

**Quick Reference**: Step-by-step guide for implementing Solution 1

---

## 🎯 What We're Fixing

**Problem**: Event documents don't exist in `/events` collection  
**Solution**: Create event documents when calendar events are extracted  
**Impact**: Enables proper RSVP display and real-time updates

---

## 📝 Files to Create/Modify

### Create (1 file):
1. ✨ `messAI/Models/EventDocument.swift` (~120 lines)

### Modify (2 files):
2. ✏️ `messAI/ViewModels/ChatViewModel.swift` (~280 lines added)
3. ✏️ `messAI/Views/Chat/ChatView.swift` (~50 lines added)

---

## 🔨 Implementation Steps

### Step 1: Create EventDocument Model (20 min)

**File**: `messAI/Models/EventDocument.swift` (NEW)

```swift
import Foundation
import FirebaseFirestore

struct EventDocument: Identifiable, Codable, Equatable, Hashable {
    // Core fields from CalendarEvent
    let id: String
    let title: String
    let date: Date
    let time: Date?
    let endTime: Date?
    let location: String?
    let isAllDay: Bool
    let confidence: Double
    
    // Firestore relationship fields
    let conversationId: String
    let createdBy: String
    let createdAt: Date
    let sourceMessageId: String
    let participantIds: [String]
    
    // Initializer from CalendarEvent
    init(from event: CalendarEvent, 
         conversationId: String,
         createdBy: String,
         sourceMessageId: String,
         participantIds: [String])
    
    // Firestore conversion
    func toDictionary() -> [String: Any]
    static func fromDictionary(_ data: [String: Any]) throws -> EventDocument
}
```

**Testing**: Build project (Cmd+B) - should compile

---

### Step 2: Modify Calendar Extraction (20 min)

**File**: `messAI/ViewModels/ChatViewModel.swift`

**Location**: Update `updateMessageWithCalendarEvents()` method (~line 493)

**Add at end of method**:
```swift
// Create event documents in Firestore
for event in events {
    await createEventDocument(from: event, message: message)
}
```

**Add new method after `updateMessageWithCalendarEvents()`**:
```swift
/// Create Firestore event document from CalendarEvent
private func createEventDocument(
    from event: CalendarEvent, 
    message: Message
) async {
    // Implementation here
}
```

**Testing**: 
- Extract calendar event
- Check Firebase Console for `/events/{id}` document

---

### Step 3: Add RSVP Fetching Methods (20 min)

**File**: `messAI/ViewModels/ChatViewModel.swift`

**Add new state at top of class**:
```swift
// RSVP State (PR #18 Fix)
@Published var eventRSVPs: [String: RSVPData] = [:]

struct RSVPData {
    var summary: RSVPSummary
    var participants: [RSVPParticipant]
    var listener: ListenerRegistration?
}
```

**Add new methods** (before closing brace):
```swift
// MARK: - RSVP Display (PR #18 Fix)

func loadRSVPsForEvent(_ eventId: String) async {
    // Fetch and cache RSVP data
}

func fetchEventDetails(eventId: String) async throws -> EventDocument? {
    // Read event document
}

func fetchEventRSVPs(eventId: String) async throws -> [RSVPParticipant] {
    // Query RSVP subcollection
}

func buildRSVPSummary(
    eventId: String, 
    participants: [RSVPParticipant]
) -> RSVPSummary {
    // Build summary from participants
}

func observeEventRSVPs(eventId: String) {
    // Real-time listener
}
```

**Testing**:
- Call `loadRSVPsForEvent()` in console
- Verify `eventRSVPs` dictionary populates

---

### Step 4: Integrate UI Display (20 min)

**File**: `messAI/Views/Chat/ChatView.swift`

**Location**: Find where CalendarCardView is displayed

**Replace**:
```swift
// Current code
if let events = message.aiMetadata?.calendarEvents {
    ForEach(events) { event in
        CalendarCardView(event: event)
    }
}
```

**With**:
```swift
// New code with RSVP display
if let events = message.aiMetadata?.calendarEvents {
    ForEach(events) { event in
        VStack(alignment: .leading, spacing: 8) {
            CalendarCardView(event: event)
            
            // RSVP Section
            if let rsvpData = viewModel.eventRSVPs[event.id] {
                RSVPSectionView(
                    summary: rsvpData.summary,
                    participants: rsvpData.participants
                )
            }
        }
        .task {
            await viewModel.loadRSVPsForEvent(event.id)
        }
    }
}
```

**Testing**:
- Launch app
- View message with calendar card
- Should see RSVP section below

---

## ✅ Testing Checklist

After each step, verify:

### After Step 1:
- [ ] Project builds (Cmd+B)
- [ ] No compilation errors

### After Step 2:
- [ ] Extract calendar event
- [ ] Firebase Console shows `/events/{id}` document
- [ ] Document has: title, date, conversationId, participantIds

### After Step 3:
- [ ] Console: `await loadRSVPsForEvent("event_id")`
- [ ] Returns summary and participants
- [ ] `eventRSVPs` dictionary populated

### After Step 4:
- [ ] Extract calendar event
- [ ] Send RSVP: "Yes!"
- [ ] See RSVPSectionView below calendar card
- [ ] Shows "1 of X confirmed"
- [ ] Expand to see participant list

---

## 🚨 Common Issues

### Issue: "Cannot find EventDocument in scope"
**Fix**: Ensure EventDocument.swift is added to target

### Issue: "Event document not created"
**Fix**: Check `createEventDocument()` is called and has no errors

### Issue: "RSVPs not displaying"
**Fix**: Check `loadRSVPsForEvent()` is called in `.task` modifier

### Issue: "Real-time updates not working"
**Fix**: Ensure `observeEventRSVPs()` is called and listener registered

---

## 📊 Expected Code Changes

| File | Lines Added | Lines Modified | Complexity |
|------|-------------|----------------|------------|
| EventDocument.swift | +120 | 0 | Low |
| ChatViewModel.swift | +280 | ~20 | Medium |
| ChatView.swift | +50 | ~10 | Low |
| **Total** | **+450** | **~30** | **Medium** |

---

## 🎯 Success Criteria

Implementation complete when:
1. ✅ Event documents created on calendar extraction
2. ✅ RSVPs stored in `/events/{id}/rsvps/{userId}`
3. ✅ RSVP section displays below calendar cards
4. ✅ Participant list shows all RSVPs grouped by status
5. ✅ Real-time updates work (new RSVP appears automatically)

---

**Ready to implement!** Follow steps 1-4 in order, testing after each step.

**Estimated Time**: ~1.5 hours  
**Difficulty**: Medium  
**Prerequisites**: PR#15 (Calendar Extraction) and PR#18 (RSVP Tracking) complete

