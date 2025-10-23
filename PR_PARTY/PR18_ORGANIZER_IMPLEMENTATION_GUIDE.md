# PR#18 Organizer Fix - Implementation Guide

**Estimated Time:** 1-2 hours  
**Difficulty:** MEDIUM  
**Files to Modify:** 3-4 files  
**Files to Create:** 0 files (model updates only)

---

## 📋 Quick Checklist

- [ ] **Phase 1:** Update EventDocument model (15 min)
- [ ] **Phase 2:** Update RSVPStatus enum (10 min)
- [ ] **Phase 3:** Add conversation fetching (15 min)
- [ ] **Phase 4:** Update event creation logic (30 min)
- [ ] **Phase 5:** Update UI display (20 min)
- [ ] **Phase 6:** Test thoroughly (30 min)

**Total:** ~2 hours

---

## Phase 1: Update EventDocument Model (15 minutes)

### File: `messAI/Models/EventDocument.swift`

**Current structure:**
```swift
struct EventDocument: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let title: String
    let date: Date
    let time: Date?
    let endTime: Date?
    let location: String?
    let isAllDay: Bool
    let confidence: Double
    let conversationId: String
    let createdBy: String
    let createdAt: Date
    let sourceMessageId: String
    var rsvpSummary: RSVPSummary?
}
```

**Add these fields:**
```swift
// NEW: Organizer tracking
let organizerId: String           // User who sent the original message
let organizerName: String          // Display name of organizer
let participantIds: [String]       // All conversation members
let sourceMessageSenderId: String  // Same as organizerId (for consistency)
```

**Update init():**
```swift
init(
    id: String,
    title: String,
    date: Date,
    time: Date? = nil,
    endTime: Date? = nil,
    location: String? = nil,
    isAllDay: Bool = false,
    confidence: Double,
    conversationId: String,
    createdBy: String,
    createdAt: Date,
    sourceMessageId: String,
    
    // NEW parameters
    organizerId: String,
    organizerName: String,
    participantIds: [String],
    sourceMessageSenderId: String,
    
    rsvpSummary: RSVPSummary? = nil
) {
    self.id = id
    self.title = title
    self.date = date
    self.time = time
    self.endTime = endTime
    self.location = location
    self.isAllDay = isAllDay
    self.confidence = confidence
    self.conversationId = conversationId
    self.createdBy = createdBy
    self.createdAt = createdAt
    self.sourceMessageId = sourceMessageId
    
    // NEW assignments
    self.organizerId = organizerId
    self.organizerName = organizerName
    self.participantIds = participantIds
    self.sourceMessageSenderId = sourceMessageSenderId
    
    self.rsvpSummary = rsvpSummary
}
```

**Update toDictionary():**
```swift
func toDictionary() -> [String: Any] {
    var dict: [String: Any] = [
        "id": id,
        "title": title,
        "date": Timestamp(date: date),
        "isAllDay": isAllDay,
        "confidence": confidence,
        "conversationId": conversationId,
        "createdBy": createdBy,
        "createdAt": Timestamp(date: createdAt),
        "sourceMessageId": sourceMessageId,
        
        // NEW fields
        "organizerId": organizerId,
        "organizerName": organizerName,
        "participantIds": participantIds,
        "sourceMessageSenderId": sourceMessageSenderId
    ]
    
    // Optional fields
    if let time = time {
        dict["time"] = Timestamp(date: time)
    }
    if let endTime = endTime {
        dict["endTime"] = Timestamp(date: endTime)
    }
    if let location = location {
        dict["location"] = location
    }
    
    return dict
}
```

**Test:**
- [ ] Code compiles
- [ ] No breaking changes to existing EventDocument usage

---

## Phase 2: Update RSVPStatus Enum (10 minutes)

### File: `messAI/Models/RSVPStatus.swift`

**Add organizer case:**
```swift
enum RSVPStatus: String, Codable, CaseIterable, Equatable, Hashable, Comparable {
    case yes
    case no
    case maybe
    case organizer  // NEW
    case pending
    
    // ... existing code ...
}
```

**Update display properties:**
```swift
extension RSVPStatus {
    /// User-facing display text
    var displayText: String {
        switch self {
        case .yes: return "Going"
        case .no: return "Not Going"
        case .maybe: return "Maybe"
        case .organizer: return "Organizing"  // NEW
        case .pending: return "Pending"
        }
    }
    
    /// Emoji representation
    var emoji: String {
        switch self {
        case .yes: return "✅"
        case .no: return "❌"
        case .maybe: return "❓"
        case .organizer: return "📋"  // NEW
        case .pending: return "⏳"
        }
    }
    
    /// Color for UI display
    var color: Color {
        switch self {
        case .yes: return .green
        case .no: return .red
        case .maybe: return .orange
        case .organizer: return .blue  // NEW
        case .pending: return .gray
        }
    }
    
    /// Whether this status counts as "confirmed" attendance
    var isConfirmed: Bool {
        return self == .yes || self == .organizer  // NEW: organizer counts as confirmed
    }
}
```

**Update sorting (organizer should be first):**
```swift
static func < (lhs: RSVPStatus, rhs: RSVPStatus) -> Bool {
    let order: [RSVPStatus] = [.organizer, .yes, .maybe, .pending, .no]  // organizer first!
    guard let lhsIndex = order.firstIndex(of: lhs),
          let rhsIndex = order.firstIndex(of: rhs) else {
        return false
    }
    return lhsIndex < rhsIndex
}
```

**Add isOrganizer flag to RSVPParticipant:**
```swift
struct RSVPParticipant: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let userId: String
    let userName: String
    let status: RSVPStatus
    let respondedAt: Date
    let messageId: String?
    let isOrganizer: Bool  // NEW field
}
```

**Test:**
- [ ] All RSVPStatus cases compile
- [ ] Sorting puts organizer first
- [ ] `isConfirmed` includes organizer

---

## Phase 3: Add Conversation Fetching (15 minutes)

### File: `messAI/ViewModels/ChatViewModel.swift`

**Add new method:**
```swift
/// Fetch conversation document to get participant list
/// Used when creating event documents to include all members
private func fetchConversation(_ conversationId: String) async throws -> Conversation {
    print("🔍 Fetching conversation: \(conversationId)")
    
    let doc = try await Firestore.firestore()
        .collection("conversations")
        .document(conversationId)
        .getDocument()
    
    guard doc.exists else {
        print("❌ Conversation not found: \(conversationId)")
        throw NSError(domain: "ChatViewModel", code: 404, userInfo: [
            NSLocalizedDescriptionKey: "Conversation not found"
        ])
    }
    
    guard let data = doc.data(),
          let participantIds = data["participantIds"] as? [String] else {
        print("❌ Invalid conversation data")
        throw NSError(domain: "ChatViewModel", code: 400, userInfo: [
            NSLocalizedDescriptionKey: "Invalid conversation data"
        ])
    }
    
    print("✅ Fetched conversation with \(participantIds.count) participants")
    
    // Create minimal Conversation object (only need participantIds)
    return Conversation(
        id: conversationId,
        participantIds: participantIds,
        createdAt: data["createdAt"] as? Timestamp ?? Timestamp(date: Date()),
        lastMessage: nil,
        lastMessageTimestamp: data["lastMessageTimestamp"] as? Timestamp ?? Timestamp(date: Date())
    )
}
```

**Optional: Add caching for performance:**
```swift
// At top of ChatViewModel class
private var conversationCache: Conversation?

// In fetchConversation(), check cache first
private func fetchConversation(_ conversationId: String) async throws -> Conversation {
    // Check cache
    if let cached = conversationCache, cached.id == conversationId {
        print("✅ Using cached conversation")
        return cached
    }
    
    // Fetch from Firestore
    print("🔍 Fetching conversation: \(conversationId)")
    let doc = try await Firestore.firestore()
        .collection("conversations")
        .document(conversationId)
        .getDocument()
    
    // ... existing fetch logic ...
    
    // Cache result
    conversationCache = conversation
    return conversation
}
```

**Test:**
- [ ] Method fetches conversation successfully
- [ ] Returns participantIds array
- [ ] Handles missing conversation gracefully
- [ ] Cache works (optional)

---

## Phase 4: Update Event Creation Logic (30 minutes)

### File: `messAI/ViewModels/ChatViewModel.swift`

**Find the `createEventDocument()` method and replace it:**

```swift
/// Create an event document in Firestore when calendar event is detected
/// Now includes organizer tracking and auto-RSVP for the sender
private func createEventDocument(from event: CalendarEvent, message: Message) async {
    do {
        print("📅 Creating event document for: \(event.title)")
        
        // STEP 1: Fetch conversation to get ALL participants
        let conversation = try await fetchConversation(conversationId)
        
        print("   - Organizer: \(message.senderName) (\(message.senderId))")
        print("   - Participants: \(conversation.participantIds.count) members")
        
        // STEP 2: Convert CalendarConfidence enum to numeric score
        let confidenceScore: Double
        switch event.confidence {
        case .high:
            confidenceScore = 0.9
        case .medium:
            confidenceScore = 0.7
        case .low:
            confidenceScore = 0.5
        }
        
        // STEP 3: Create EventDocument with organizer and participants
        let eventDoc = EventDocument(
            id: event.id,
            title: event.title,
            date: event.date,
            time: event.time,
            endTime: event.endTime,
            location: event.location,
            isAllDay: event.isAllDay,
            confidence: confidenceScore,
            conversationId: conversationId,
            createdBy: currentUser?.id ?? "unknown",  // Who did the extraction
            createdAt: Date(),
            sourceMessageId: message.id,
            
            // NEW: Organizer tracking
            organizerId: message.senderId,              // The person who sent the message
            organizerName: message.senderName,
            participantIds: conversation.participantIds, // All group members
            sourceMessageSenderId: message.senderId
        )
        
        // STEP 4: Save event document to Firestore
        try await Firestore.firestore()
            .collection("events")
            .document(event.id)
            .setData(eventDoc.toDictionary(), merge: true)
        
        print("✅ Event document created: \(event.id)")
        
        // STEP 5: Auto-create organizer RSVP
        await createOrganizerRSVP(
            eventId: event.id,
            organizerId: message.senderId,
            organizerName: message.senderName,
            messageId: message.id
        )
        
    } catch {
        print("❌ Failed to create event document: \(error)")
        print("   Error: \(error.localizedDescription)")
    }
}
```

**Add new method for organizer RSVP:**

```swift
/// Auto-create RSVP for event organizer
/// Called when event document is created to ensure organizer is included in tracking
private func createOrganizerRSVP(
    eventId: String,
    organizerId: String,
    organizerName: String,
    messageId: String
) async {
    do {
        print("📋 Creating organizer RSVP for: \(organizerName)")
        
        let organizerRSVP: [String: Any] = [
            "userId": organizerId,
            "userName": organizerName,
            "status": RSVPStatus.organizer.rawValue,
            "isOrganizer": true,
            "respondedAt": Timestamp(date: Date()),
            "messageId": messageId  // Link to the original event message
        ]
        
        // Use merge: true to avoid overwriting if organizer already RSVP'd
        try await Firestore.firestore()
            .collection("events")
            .document(eventId)
            .collection("rsvps")
            .document(organizerId)
            .setData(organizerRSVP, merge: true)
        
        print("✅ Organizer RSVP created: \(eventId) → \(organizerName)")
        
    } catch {
        print("❌ Failed to create organizer RSVP: \(error)")
        print("   Error: \(error.localizedDescription)")
    }
}
```

**Update the calendar extraction flow to ensure createEventDocument is called:**

Find the `updateMessageWithCalendarEvents()` method and verify it calls `createEventDocument()`:

```swift
private func updateMessageWithCalendarEvents(message: Message, events: [CalendarEvent]) async {
    // ... existing code to update message metadata ...
    
    // Create event documents for each extracted event
    for event in events {
        await createEventDocument(from: event, message: message)  // ✅ This should be here
    }
}
```

**Test:**
- [ ] Event document created with organizer fields
- [ ] Organizer RSVP auto-created
- [ ] Console logs show success
- [ ] No errors thrown

---

## Phase 5: Update UI Display (20 minutes)

### File: `messAI/Views/AI/RSVPSectionView.swift`

**Add organizer display:**

```swift
struct RSVPSectionView: View {
    let summary: RSVPSummary
    let participants: [RSVPParticipant]
    let organizerName: String?  // NEW parameter
    
    @State private var isExpanded: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // NEW: Organizer header
            if let organizer = organizerName {
                HStack(spacing: 6) {
                    Image(systemName: "person.badge.shield.checkmark.fill")
                        .foregroundColor(.blue)
                        .font(.caption)
                    Text("Organized by \(organizer)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 4)
            }
            
            // RSVP Summary (existing code)
            HStack {
                Image(systemName: "person.3.fill")
                    .foregroundColor(.blue)
                
                Text("RSVPs: \(summary.confirmedCount) of \(summary.totalCount) confirmed")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Button(action: { isExpanded.toggle() }) {
                    Image(systemName: isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                        .foregroundColor(.blue)
                }
            }
            .padding(.vertical, 4)
            
            // Participant List (expanded)
            if isExpanded {
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    // Sort: organizer first, then by status
                    ForEach(participants.sorted { p1, p2 in
                        if p1.isOrganizer != p2.isOrganizer {
                            return p1.isOrganizer  // Organizer first
                        }
                        return p1.status < p2.status  // Then by status
                    }) { participant in
                        HStack {
                            Text(participant.status.emoji)
                                .font(.body)
                            
                            Text(participant.userName)
                                .font(.subheadline)
                            
                            // NEW: Show organizer label
                            if participant.isOrganizer {
                                Text("(Organizer)")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(4)
                            }
                            
                            Spacer()
                            
                            Text(participant.status.displayText)
                                .font(.caption)
                                .foregroundColor(participant.status.color)
                        }
                        .padding(.vertical, 2)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}
```

**Update ChatView to pass organizerName:**

Find where `RSVPSectionView` is used and add the `organizerName` parameter:

```swift
// In ChatView.swift or wherever RSVPSectionView is called:

// You'll need to fetch the event document to get the organizer name
// This might require adding a method to fetch event details

RSVPSectionView(
    summary: rsvpSummary,
    participants: rsvpParticipants,
    organizerName: eventOrganizerName  // NEW parameter
)
```

**Note:** You may need to add a method to fetch the event document and extract the organizer name. For now, you can pass `nil` and add this enhancement later.

**Test:**
- [ ] UI compiles
- [ ] Organizer header displays when name provided
- [ ] Organizer badge shows on participant
- [ ] Organizer sorted first in list

---

## Phase 6: Test Thoroughly (30 minutes)

### Test Case 1: Basic 3-Person Flow

**Setup:**
1. Open app with User1
2. Create group chat with User2 and User3
3. Send as User1: "Soccer Practice at 4PM tomorrow"

**Test Steps:**
1. Switch to User2's device/account
2. Open conversation
3. Wait for calendar extraction (should happen automatically)
4. Check Xcode console for:
   ```
   📅 Creating event document for: Soccer Practice
      - Organizer: User1 (user1_id)
      - Participants: 3 members
   ✅ Event document created: evt_xxx
   📋 Creating organizer RSVP for: User1
   ✅ Organizer RSVP created: evt_xxx → User1
   ```
5. Check Firestore console:
   - `/events/{eventId}` should exist
   - Should have `organizerId: "user1_id"`
   - Should have `participantIds: ["user1", "user2", "user3"]`
6. Check `/events/{eventId}/rsvps/user1` exists with:
   - `status: "organizer"`
   - `isOrganizer: true`
7. User2 says "Yes!" - check RSVP tracked
8. User3 says "I'll be there!" - check RSVP tracked
9. Verify RSVP summary shows "3 of 3 confirmed"
10. Verify UI shows User1 as organizer

**Expected Result:** ✅ All 3 users in RSVP list, User1 marked as organizer

---

### Test Case 2: Race Condition

**Setup:**
- Group chat with User1, User2, User3
- User1 sends event message

**Test Steps:**
1. User2 and User3 both receive message at same time
2. Both trigger calendar extraction simultaneously
3. Check console for any errors
4. Check Firestore - should only have ONE event document
5. Check RSVPs - organizer RSVP should exist (not duplicated)

**Expected Result:** ✅ No errors, single event, single organizer RSVP

---

### Test Case 3: Organizer Changes RSVP

**Setup:**
- Event created with User1 as organizer
- Organizer RSVP auto-created with status "organizer"

**Test Steps:**
1. User1 says "Actually I can't make it"
2. RSVP should update to status "no"
3. Check Firestore: `status` should be "no" but `isOrganizer` still `true`
4. UI should show: "❌ User1 (Organizer) - Not Going"

**Expected Result:** ✅ Status updates but organizer flag preserved

---

### Test Case 4: Large Group

**Setup:**
- Group chat with 10 participants
- User1 sends event message

**Test Steps:**
1. User2 receives and extracts
2. Check event document has 10 participant IDs
3. Check organizer RSVP created for User1
4. Each user RSVP's
5. Verify count shows correct total

**Expected Result:** ✅ All 10 participants tracked correctly

---

### Test Case 5: Conversation Not Found

**Setup:**
- Simulate error by using invalid conversation ID

**Test Steps:**
1. Trigger event extraction with bad conversation ID
2. Check console for error handling
3. App should not crash

**Expected Result:** ✅ Graceful error, logged to console, no crash

---

## 🐛 Debugging Tips

### Issue: Event document not being created
**Check:**
- Is `updateMessageWithCalendarEvents()` being called?
- Is `createEventDocument()` being called inside the loop?
- Are there any errors in the console?

### Issue: Organizer RSVP not appearing
**Check:**
- Is `createOrganizerRSVP()` being called after event creation?
- Check Firestore rules - does the user have permission to write to `/events/{id}/rsvps`?
- Is `merge: true` being used?

### Issue: Conversation fetch failing
**Check:**
- Does conversation document exist in Firestore?
- Does it have a `participantIds` field?
- Is the conversation ID correct?

### Issue: UI not showing organizer
**Check:**
- Is `organizerName` being passed to RSVPSectionView?
- Is the organizer's RSVP marked with `isOrganizer: true`?
- Is the sorting logic correct?

---

## 🎯 Success Checklist

- [ ] EventDocument model updated with new fields
- [ ] RSVPStatus has `organizer` case
- [ ] `fetchConversation()` method working
- [ ] `createEventDocument()` includes organizer
- [ ] `createOrganizerRSVP()` auto-creates RSVP
- [ ] UI shows organizer prominently
- [ ] All tests pass
- [ ] No console errors
- [ ] Firestore data looks correct
- [ ] RSVP counts are accurate

---

## 🚀 You're Done!

Once all checkboxes are complete, the organizer fix is fully implemented!

**Next steps:**
- Deploy to TestFlight for beta testing
- Gather feedback on organizer display
- Consider adding "Edit Event" feature for organizers

