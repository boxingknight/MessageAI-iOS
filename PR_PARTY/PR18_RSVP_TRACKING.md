# PR #18: RSVP Tracking Feature - Main Specification

**Feature**: AI-Powered RSVP Detection & Tracking  
**Persona**: Busy Parent (Sarah, 34, working mom with 2 kids)  
**Estimated Time**: 3-4 hours  
**Complexity**: HIGH  
**Priority**: 🔴 CRITICAL - 4th of 5 required AI features  
**Depends on**: PR#14 (Cloud Functions) ✅, PR#15 (Calendar Extraction) ✅

---

## Overview

### What We're Building

AI-powered RSVP tracking that automatically detects yes/no/maybe responses in group chats and tracks who's attending events. When someone replies "I'll be there!" or "Can't make it, sorry" to an event, the AI:
1. Detects the response type (yes/no/maybe/pending)
2. Links it to the relevant calendar event (from PR#15)
3. Updates the RSVP tracking display
4. Shows aggregated status: "5 of 12 confirmed"

**Example Scenario**:
```
[School Parent Group]

Mom1: "Pizza party Friday at 6pm, who's coming?"
  📅 Calendar Card: Pizza party, Friday 6pm

Mom2: "We'll be there!"
  ✅ RSVP: Yes (1 of 12 confirmed)

Mom3: "Can't make it, sorry"
  ❌ RSVP: No (1 of 12 declined)

Dad1: "Maybe, depends on work"
  ❓ RSVP: Maybe (1 of 12 tentative)

RSVP Summary:
✅ Yes: 1 (Mom2)
❌ No: 1 (Mom3)  
❓ Maybe: 1 (Dad1)
⏳ Pending: 9 participants
```

### Why It Matters

**Sarah's Pain Point**: 
"I'm organizing a field trip for 12 kids. Parents keep responding in the group chat but I have to scroll through 50 messages to figure out who's actually coming. I made a spreadsheet but it's already out of date."

**How This Helps**:
- **Automatic tracking**: No manual spreadsheet needed
- **Real-time updates**: See responses as they come in
- **Visual clarity**: "5 of 12 confirmed" at a glance
- **Linked to events**: Each RSVP connected to specific calendar event
- **Export-ready**: Copy list of confirmed attendees

**Business Value**:
- **High utility**: Solves real coordination problem
- **Viral potential**: "This app tracked RSVPs automatically!"
- **Differentiator**: WhatsApp/iMessage don't have this
- **Foundation for PR#20**: Event planning agent will use RSVP data

### Success in One Sentence

"This PR is successful when Sarah can see '5 of 12 confirmed' for the field trip without manually tracking responses, and the list updates automatically as parents reply in the group chat."

---

## Technical Design

### Architecture Decisions

#### Decision 1: RSVP Detection Approach

**Options Considered:**
1. **Keyword-only** - Fast, free, but low accuracy (40-50%)
2. **GPT-4 only** - High accuracy (85-90%), but expensive (~$0.005/detection)
3. **Hybrid: Keyword filter → GPT-4** - Best of both (80% accuracy, <$0.002/detection)
4. **Function calling** - Most accurate (90-95%), moderate cost (~$0.003/detection)

**Chosen:** Hybrid with GPT-4 function calling

**Rationale:**
- Accuracy is critical (false negatives = missed responses)
- Hybrid reduces cost (skip obvious non-RSVP messages)
- Function calling provides structured output (easier parsing)
- Context-aware (knows which event the RSVP is for)

**Trade-offs:**
- **Gain**: 90%+ accuracy, structured data, event linking
- **Lose**: ~$0.003 per detection (vs free keyword-only)
- **Acceptable**: Cost is worth the accuracy for this feature

#### Decision 2: RSVP Storage Strategy

**Options Considered:**
1. **Embedded in message.aiMetadata** - Co-located, zero extra reads
2. **Separate /rsvps collection** - Queryable, aggregatable
3. **Sub-collection /events/{eventId}/rsvps** - Event-centric, scalable
4. **Firestore array in event document** - Simple, limited to 100 RSVPs

**Chosen:** Sub-collection `/events/{eventId}/rsvps/{userId}`

**Rationale:**
- Event-centric data model (natural for RSVP tracking)
- Scalable (no 100-item limit like arrays)
- Queryable (can filter by status, user, date)
- Supports aggregation (count by status)
- Clean separation (RSVPs independent of messages)

**Trade-offs:**
- **Gain**: Scalability, queryability, clean data model
- **Lose**: One extra Firestore read per event (acceptable)
- **Alternative**: If <20 RSVPs per event, could use array

#### Decision 3: Event Linking Strategy

**Options Considered:**
1. **Automatic (AI infers which event)** - Smart, but error-prone
2. **User selects event from dropdown** - Accurate, but friction
3. **Hybrid: AI suggests, user confirms** - Balanced approach
4. **Link to most recent event in conversation** - Simple heuristic

**Chosen:** Hybrid (AI suggests, user confirms for ambiguous cases)

**Rationale:**
- AI is good at obvious cases: "Yes!" after event mention
- User confirmation prevents wrong event linkage
- Ambiguous cases are rare (<10% of responses)
- Builds trust (users see AI reasoning)

**Trade-offs:**
- **Gain**: High accuracy (95%+), user trust
- **Lose**: Occasional confirmation needed (acceptable friction)

#### Decision 4: UI Pattern

**Options Considered:**
1. **Inline RSVP badges** - Next to calendar cards
2. **Dedicated RSVP view** - Separate tab/screen
3. **Collapsible RSVP section** - In chat, below calendar card
4. **Floating summary card** - Always visible, overlays chat

**Chosen:** Collapsible RSVP section below calendar card

**Rationale:**
- Co-located with event (context preserved)
- Non-intrusive (collapsed by default)
- Expandable (see full participant list)
- Works in chat flow (no navigation needed)

**Trade-offs:**
- **Gain**: Context, zero navigation, inline updates
- **Lose**: Slightly longer messages (acceptable)

---

## Data Model

### New Models

#### 1. RSVPResponse (Swift)

```swift
import Foundation
import FirebaseFirestore

enum RSVPStatus: String, Codable, CaseIterable {
    case yes = "yes"
    case no = "no"
    case maybe = "maybe"
    case pending = "pending"
    
    var displayText: String {
        switch self {
        case .yes: return "Yes"
        case .no: return "No"
        case .maybe: return "Maybe"
        case .pending: return "Pending"
        }
    }
    
    var icon: String {
        switch self {
        case .yes: return "checkmark.circle.fill"
        case .no: return "xmark.circle.fill"
        case .maybe: return "questionmark.circle.fill"
        case .pending: return "clock.circle.fill"
        }
    }
    
    var color: String {
        switch self {
        case .yes: return "green"
        case .no: return "red"
        case .maybe: return "orange"
        case .pending: return "gray"
        }
    }
}

struct RSVPResponse: Codable, Identifiable, Equatable {
    let id: String // userId
    let userId: String
    let userName: String
    let eventId: String
    let status: RSVPStatus
    let messageId: String // Message where RSVP was detected
    let detectedAt: Date
    let confidence: Double // 0.0-1.0, AI confidence score
    let responseText: String? // Original message text
    let notes: String? // Optional user-added notes
    
    // Firestore conversion
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "userId": userId,
            "userName": userName,
            "eventId": eventId,
            "status": status.rawValue,
            "messageId": messageId,
            "detectedAt": Timestamp(date: detectedAt),
            "confidence": confidence
        ]
        if let text = responseText { dict["responseText"] = text }
        if let notes = notes { dict["notes"] = notes }
        return dict
    }
    
    static func fromDictionary(id: String, data: [String: Any]) -> RSVPResponse? {
        guard let userId = data["userId"] as? String,
              let userName = data["userName"] as? String,
              let eventId = data["eventId"] as? String,
              let statusRaw = data["status"] as? String,
              let status = RSVPStatus(rawValue: statusRaw),
              let messageId = data["messageId"] as? String,
              let timestamp = data["detectedAt"] as? Timestamp,
              let confidence = data["confidence"] as? Double else {
            return nil
        }
        
        return RSVPResponse(
            id: id,
            userId: userId,
            userName: userName,
            eventId: eventId,
            status: status,
            messageId: messageId,
            detectedAt: timestamp.dateValue(),
            confidence: confidence,
            responseText: data["responseText"] as? String,
            notes: data["notes"] as? String
        )
    }
}
```

#### 2. RSVPSummary (Swift)

```swift
struct RSVPSummary: Codable, Equatable {
    let eventId: String
    let totalParticipants: Int
    let yesCount: Int
    let noCount: Int
    let maybeCount: Int
    let pendingCount: Int
    let responses: [RSVPResponse]
    let lastUpdated: Date
    
    var confirmationRate: Double {
        guard totalParticipants > 0 else { return 0.0 }
        return Double(yesCount) / Double(totalParticipants)
    }
    
    var responseRate: Double {
        guard totalParticipants > 0 else { return 0.0 }
        let responded = yesCount + noCount + maybeCount
        return Double(responded) / Double(totalParticipants)
    }
    
    var statusText: String {
        let responded = yesCount + noCount + maybeCount
        return "\(responded) of \(totalParticipants) responded"
    }
    
    var confirmationText: String {
        return "\(yesCount) of \(totalParticipants) confirmed"
    }
    
    // Group responses by status
    var yesList: [RSVPResponse] { responses.filter { $0.status == .yes } }
    var noList: [RSVPResponse] { responses.filter { $0.status == .no } }
    var maybeList: [RSVPResponse] { responses.filter { $0.status == .maybe } }
    var pendingList: [RSVPResponse] { responses.filter { $0.status == .pending } }
}
```

### Firestore Collections

#### `/events/{eventId}/rsvps/{userId}`
```typescript
{
  userId: string           // User ID
  userName: string         // Display name
  eventId: string         // Calendar event ID (from PR#15)
  status: "yes"|"no"|"maybe"|"pending"
  messageId: string       // Message where RSVP detected
  detectedAt: Timestamp
  confidence: number      // 0.0-1.0
  responseText?: string   // Original message text
  notes?: string          // User-added notes
}
```

**Security Rules:**
```javascript
match /events/{eventId}/rsvps/{userId} {
  // Participants can read all RSVPs for their events
  allow read: if request.auth != null && 
    exists(/databases/$(database)/documents/events/$(eventId)) &&
    get(/databases/$(database)/documents/events/$(eventId)).data.participants.hasAny([request.auth.uid]);
  
  // Only the user can create/update their own RSVP
  allow create, update: if request.auth != null && 
    request.auth.uid == userId &&
    request.resource.data.userId == userId;
  
  // Users can delete their own RSVP
  allow delete: if request.auth != null && request.auth.uid == userId;
}
```

### AIMetadata Extension

Update `Message.aiMetadata` to include RSVP data:

```swift
// Add to AIMetadata.swift
struct AIMetadata: Codable {
    // ... existing fields (calendarEvents, decisions, etc.)
    
    // NEW: RSVP detection
    var rsvpResponse: RSVPResponse?
    
    // ... existing methods
}
```

---

## API Design

### Cloud Function: `detectRSVP`

```typescript
// functions/src/ai/rsvpTracking.ts

import { CallableContext } from 'firebase-functions/v1/https';
import { OpenAI } from 'openai';
import * as admin from 'firebase-admin';

interface DetectRSVPRequest {
  conversationId: string;
  messageId: string;
  messageText: string;
  senderId: string;
  senderName: string;
  recentEventIds?: string[]; // Events from last 10 messages
}

interface DetectRSVPResponse {
  detected: boolean;
  status?: 'yes' | 'no' | 'maybe';
  eventId?: string;
  confidence: number;
  reasoning?: string;
}

export async function detectRSVP(
  data: DetectRSVPRequest,
  context: CallableContext
): Promise<DetectRSVPResponse> {
  // 1. Validate authentication
  if (!context.auth) {
    throw new Error('Authentication required');
  }

  const { conversationId, messageId, messageText, senderId, senderName, recentEventIds } = data;

  // 2. Quick keyword filter (optimization)
  const rsvpKeywords = [
    'yes', 'no', 'maybe', 'count me in', 'i\'ll be there', 'can\'t make it',
    'probably', 'not sure', 'definitely', 'absolutely', 'unfortunately',
    'attending', 'coming', 'going', 'skip', 'pass', 'tentative'
  ];
  
  const hasKeyword = rsvpKeywords.some(keyword => 
    messageText.toLowerCase().includes(keyword)
  );
  
  if (!hasKeyword) {
    return { detected: false, confidence: 0.0 };
  }

  // 3. Fetch recent events if not provided
  let eventIds = recentEventIds || [];
  if (eventIds.length === 0) {
    const recentMessages = await admin.firestore()
      .collection('conversations')
      .doc(conversationId)
      .collection('messages')
      .where('aiMetadata.calendarEvents', '!=', null)
      .orderBy('sentAt', 'desc')
      .limit(5)
      .get();
    
    recentMessages.forEach(doc => {
      const events = doc.data().aiMetadata?.calendarEvents || [];
      eventIds.push(...events.map((e: any) => e.id));
    });
  }

  // 4. Build context for GPT-4
  const eventsContext = eventIds.length > 0 
    ? `Recent events: ${eventIds.slice(0, 3).join(', ')}`
    : 'No recent events';

  // 5. Call GPT-4 with function calling
  const openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });
  
  const completion = await openai.chat.completions.create({
    model: 'gpt-4',
    messages: [
      {
        role: 'system',
        content: `You are an RSVP detection assistant for busy parents managing group chats.
Analyze the message and determine if it contains an RSVP response (yes/no/maybe) to an event.

Rules:
- YES: Affirmative responses ("yes", "count me in", "we'll be there", "definitely")
- NO: Negative responses ("no", "can't make it", "sorry, we can't", "not attending")
- MAYBE: Uncertain responses ("maybe", "not sure", "possibly", "tentative")
- Return confidence 0.0-1.0 based on clarity
- Link to most recent event if mentioned within last 5 messages

Context: ${eventsContext}`
      },
      {
        role: 'user',
        content: `Message from ${senderName}: "${messageText}"
        
Is this an RSVP response? If yes, classify as yes/no/maybe and link to event ID if possible.`
      }
    ],
    functions: [
      {
        name: 'detect_rsvp',
        description: 'Detect RSVP response in message',
        parameters: {
          type: 'object',
          properties: {
            detected: {
              type: 'boolean',
              description: 'Whether message contains RSVP response'
            },
            status: {
              type: 'string',
              enum: ['yes', 'no', 'maybe'],
              description: 'RSVP status if detected'
            },
            eventId: {
              type: 'string',
              description: 'Event ID this RSVP is for (if clear from context)'
            },
            confidence: {
              type: 'number',
              description: 'Confidence score 0.0-1.0'
            },
            reasoning: {
              type: 'string',
              description: 'Brief explanation of classification'
            }
          },
          required: ['detected', 'confidence']
        }
      }
    ],
    function_call: { name: 'detect_rsvp' },
    temperature: 0.2,
    max_tokens: 200
  });

  // 6. Parse response
  const functionCall = completion.choices[0]?.message?.function_call;
  if (!functionCall || !functionCall.arguments) {
    return { detected: false, confidence: 0.0 };
  }

  const result = JSON.parse(functionCall.arguments);

  // 7. Save RSVP if detected with high confidence
  if (result.detected && result.confidence > 0.7 && result.status) {
    const eventId = result.eventId || eventIds[0]; // Use most recent if not specified
    
    if (eventId) {
      await admin.firestore()
        .collection('events')
        .doc(eventId)
        .collection('rsvps')
        .doc(senderId)
        .set({
          userId: senderId,
          userName: senderName,
          eventId: eventId,
          status: result.status,
          messageId: messageId,
          detectedAt: admin.firestore.FieldValue.serverTimestamp(),
          confidence: result.confidence,
          responseText: messageText
        }, { merge: true });
    }
  }

  return result;
}
```

### iOS AIService Extension

```swift
// Services/AIService.swift extension

extension AIService {
    /// Detect RSVP response in message
    func detectRSVP(
        conversationId: String,
        messageId: String,
        messageText: String,
        senderId: String,
        senderName: String,
        recentEventIds: [String] = []
    ) async throws -> RSVPDetectionResult {
        let cacheKey = "rsvp_\(messageId)"
        
        // Check cache (1-minute TTL for RSVP detection)
        if let cached = cache[cacheKey],
           Date().timeIntervalSince(cached.timestamp) < 60 {
            if let result = cached.value as? RSVPDetectionResult {
                print("✅ AIService: RSVP detection cache hit for message \(messageId)")
                return result
            }
        }
        
        // Call Cloud Function
        let request: [String: Any] = [
            "feature": "rsvp_detection",
            "conversationId": conversationId,
            "messageId": messageId,
            "messageText": messageText,
            "senderId": senderId,
            "senderName": senderName,
            "recentEventIds": recentEventIds
        ]
        
        let result = try await callFunction(data: request)
        
        guard let detected = result["detected"] as? Bool,
              let confidence = result["confidence"] as? Double else {
            throw AIError.invalidResponse
        }
        
        let status: RSVPStatus?
        if let statusStr = result["status"] as? String {
            status = RSVPStatus(rawValue: statusStr)
        } else {
            status = nil
        }
        
        let detectionResult = RSVPDetectionResult(
            detected: detected,
            status: status,
            eventId: result["eventId"] as? String,
            confidence: confidence,
            reasoning: result["reasoning"] as? String
        )
        
        // Cache result
        cache[cacheKey] = CachedValue(value: detectionResult, timestamp: Date())
        
        return detectionResult
    }
    
    /// Fetch RSVP summary for event
    func fetchRSVPSummary(eventId: String) async throws -> RSVPSummary {
        let db = Firestore.firestore()
        let snapshot = try await db.collection("events")
            .document(eventId)
            .collection("rsvps")
            .getDocuments()
        
        let responses = snapshot.documents.compactMap { doc in
            RSVPResponse.fromDictionary(id: doc.documentID, data: doc.data())
        }
        
        // Get event participants count
        let eventDoc = try await db.collection("events").document(eventId).getDocument()
        let participantIds = eventDoc.data()?["participants"] as? [String] ?? []
        
        let yesCount = responses.filter { $0.status == .yes }.count
        let noCount = responses.filter { $0.status == .no }.count
        let maybeCount = responses.filter { $0.status == .maybe }.count
        let pendingCount = participantIds.count - (yesCount + noCount + maybeCount)
        
        return RSVPSummary(
            eventId: eventId,
            totalParticipants: participantIds.count,
            yesCount: yesCount,
            noCount: noCount,
            maybeCount: maybeCount,
            pendingCount: pendingCount,
            responses: responses,
            lastUpdated: Date()
        )
    }
}

struct RSVPDetectionResult: Codable {
    let detected: Bool
    let status: RSVPStatus?
    let eventId: String?
    let confidence: Double
    let reasoning: String?
}
```

---

## Component Hierarchy

### UI Components

```
ChatView
├── ScrollView
│   ├── MessageBubbleView (existing)
│   └── CalendarCardView (from PR#15)
│       └── RSVPSectionView 🆕
│           ├── RSVPHeaderView
│           │   ├── Summary stats ("5 of 12 confirmed")
│           │   ├── Expand/collapse button
│           │   └── Quick actions (copy list, export)
│           └── RSVPDetailView (when expanded)
│               ├── RSVPListItem (Yes section)
│               ├── RSVPListItem (No section)
│               ├── RSVPListItem (Maybe section)
│               └── RSVPListItem (Pending section)
```

---

## Implementation Details

### File Structure

**New Files (6 new files, ~850 lines):**

```
messAI/
├── Models/
│   └── RSVPResponse.swift (~180 lines) 🆕
│       - RSVPStatus enum
│       - RSVPResponse struct
│       - RSVPSummary struct
│       - Firestore conversion
│
├── Views/Chat/
│   ├── RSVPSectionView.swift (~220 lines) 🆕
│   │   - Collapsible RSVP display
│   │   - Attached to calendar card
│   │
│   ├── RSVPHeaderView.swift (~120 lines) 🆕
│   │   - Summary stats display
│   │   - Expand/collapse control
│   │
│   ├── RSVPDetailView.swift (~180 lines) 🆕
│   │   - Full participant list
│   │   - Grouped by status
│   │   - User avatars
│   │
│   └── RSVPListItemView.swift (~90 lines) 🆕
│       - Individual RSVP row
│       - Status icon + name
│       - Confidence indicator
│
└── functions/src/ai/
    └── rsvpTracking.ts (~300 lines) 🆕
        - detectRSVP function
        - GPT-4 integration
        - Firestore writes
```

**Modified Files (+~320 lines):**

```
messAI/
├── Models/
│   └── AIMetadata.swift (+30 lines)
│       - Add rsvpResponse field
│
├── Services/
│   └── AIService.swift (+120 lines)
│       - detectRSVP() method
│       - fetchRSVPSummary() method
│       - RSVP caching
│
├── ViewModels/
│   └── ChatViewModel.swift (+90 lines)
│       - RSVP detection trigger
│       - RSVP summary loading
│       - State management
│
├── Views/Chat/
│   ├── CalendarCardView.swift (+50 lines)
│   │   - Integrate RSVPSectionView
│   │   - Pass event data
│   │
│   └── ChatView.swift (+30 lines)
│       - Auto-detect RSVPs
│       - Update RSVP displays
│
└── functions/src/ai/
    └── processAI.ts (+20 lines)
        - Add rsvp_detection route
```

---

## Implementation Phases

### Phase 1: Cloud Function (1 hour)

**Goal**: RSVP detection working on backend

**Tasks**:
1. Create `functions/src/ai/rsvpTracking.ts`
2. Implement keyword filter (optimization)
3. Build GPT-4 function calling integration
4. Add Firestore writes for detected RSVPs
5. Test with sample messages

**Testing Checkpoints**:
- ✅ Function responds to valid requests
- ✅ Detects "Yes!" as yes status
- ✅ Detects "Can't make it" as no status
- ✅ Returns confidence scores
- ✅ Links to correct event ID

**Commit**: `feat(pr18): implement RSVP detection Cloud Function`

### Phase 2: iOS Models (45 minutes)

**Goal**: RSVP data structures ready

**Tasks**:
1. Create `Models/RSVPResponse.swift`
2. Define RSVPStatus enum with icons/colors
3. Create RSVPResponse struct
4. Create RSVPSummary struct
5. Add Firestore conversion methods

**Testing Checkpoints**:
- ✅ All models compile
- ✅ Firestore conversion round-trip works
- ✅ Enum cases match Cloud Function
- ✅ Summary calculations correct

**Commit**: `feat(pr18): add RSVP data models`

### Phase 3: AIService Integration (45 minutes)

**Goal**: iOS can call RSVP detection

**Tasks**:
1. Extend `AIService.swift`
2. Add `detectRSVP()` method
3. Add `fetchRSVPSummary()` method
4. Implement caching (1-minute TTL)
5. Add error handling

**Testing Checkpoints**:
- ✅ Can detect RSVP from iOS
- ✅ Returns RSVPDetectionResult
- ✅ Caching reduces duplicate calls
- ✅ Errors handled gracefully

**Commit**: `feat(pr18): integrate RSVP detection in AIService`

### Phase 4: ChatViewModel Logic (30 minutes)

**Goal**: Automatic RSVP detection on messages

**Tasks**:
1. Update `ChatViewModel.swift`
2. Add RSVP detection trigger (when message sent)
3. Add RSVP summary loading
4. Add @Published state for RSVP data
5. Handle updates on new RSVPs

**Testing Checkpoints**:
- ✅ New messages trigger RSVP detection
- ✅ RSVP summaries load for events
- ✅ UI updates when RSVP added
- ✅ No duplicate detections

**Commit**: `feat(pr18): add RSVP detection to ChatViewModel`

### Phase 5: UI Components (1.5 hours)

**Goal**: Beautiful RSVP display

**Tasks**:
1. Create `RSVPSectionView.swift` (collapsible section)
2. Create `RSVPHeaderView.swift` (summary stats)
3. Create `RSVPDetailView.swift` (participant list)
4. Create `RSVPListItemView.swift` (individual row)
5. Integrate into `CalendarCardView.swift`

**Testing Checkpoints**:
- ✅ RSVP section appears below calendar card
- ✅ Expand/collapse animation smooth
- ✅ Summary stats display correctly
- ✅ Participant list grouped by status
- ✅ Icons and colors match status

**Commit**: `feat(pr18): add RSVP UI components`

### Phase 6: Testing & Polish (30 minutes)

**Goal**: Production-ready RSVP tracking

**Tasks**:
1. Test with real group chat
2. Test all RSVP statuses (yes/no/maybe)
3. Test event linking accuracy
4. Test edge cases (ambiguous responses)
5. Performance testing (detection speed)

**Testing Checkpoints**:
- ✅ All test scenarios pass (see Testing Guide)
- ✅ Detection <2s (warm), <5s (cold)
- ✅ Accuracy >85% on test set
- ✅ No crashes or errors
- ✅ UI responsive and smooth

**Commit**: `test(pr18): comprehensive RSVP tracking tests`

---

## Testing Strategy

### Test Categories

**1. Unit Tests (Cloud Function)**

**Test Case: Detect YES response**
```typescript
Input: "Yes, I'll be there!"
Expected: { detected: true, status: 'yes', confidence: >0.9 }

Input: "Count me in!"
Expected: { detected: true, status: 'yes', confidence: >0.8 }
```

**Test Case: Detect NO response**
```typescript
Input: "Can't make it, sorry"
Expected: { detected: true, status: 'no', confidence: >0.9 }

Input: "Unfortunately we can't come"
Expected: { detected: true, status: 'no', confidence: >0.8 }
```

**Test Case: Detect MAYBE response**
```typescript
Input: "Maybe, depends on work"
Expected: { detected: true, status: 'maybe', confidence: >0.8 }

Input: "Tentative yes"
Expected: { detected: true, status: 'maybe', confidence: >0.7 }
```

**Test Case: No RSVP detected**
```typescript
Input: "What time is the party?"
Expected: { detected: false, confidence: 0.0 }

Input: "See you soon!"
Expected: { detected: false, confidence: <0.5 }
```

**2. Integration Tests (End-to-End)**

**Test Scenario 1: RSVP to calendar event**
```
1. User A creates event: "Pizza party Friday 6pm"
2. Calendar card appears
3. User B replies: "We'll be there!"
4. RSVP detected as YES
5. RSVP section shows: "1 of 3 confirmed"
6. User B listed under "Yes (1)"
```

**Test Scenario 2: Multiple RSVPs**
```
1. Event exists in chat
2. User A: "Yes!" → RSVP summary: 1 yes
3. User B: "Can't make it" → RSVP summary: 1 yes, 1 no
4. User C: "Maybe" → RSVP summary: 1 yes, 1 no, 1 maybe
5. All users appear in correct sections
```

**Test Scenario 3: Change RSVP**
```
1. User A RSVPs "Yes"
2. RSVP section shows: 1 yes
3. User A changes to "Actually, no"
4. RSVP updates: 0 yes, 1 no
5. User A moves to "No" section
```

**3. Edge Case Tests**

**Test Case: Ambiguous response**
```
Input: "I'll try to come"
Expected: Status = maybe, confidence = 0.6-0.8
Behavior: May prompt user to confirm status
```

**Test Case: Multiple events**
```
Scenario: Two events in last 10 messages
User replies: "Yes to the first one"
Expected: Links to earlier event, confidence >0.8
```

**Test Case: No recent events**
```
Scenario: RSVP message but no calendar events in chat
Expected: detected = true, but eventId = null
Behavior: Creates "orphan" RSVP (can link manually)
```

**Test Case: Sarcastic response**
```
Input: "Oh yeah, I'll definitely be there... NOT"
Expected: Confidence <0.5 (GPT-4 detects sarcasm)
Behavior: Not saved as RSVP
```

**4. Performance Tests**

**Benchmark 1: Detection latency**
- Target: <2s (warm), <5s (cold start)
- Measure: Time from message send to RSVP displayed
- Test on: WiFi and 4G

**Benchmark 2: RSVP summary load**
- Target: <1s for 50 participants
- Measure: Time to fetch and display full RSVP list
- Test with: 10, 25, 50 participants

**Benchmark 3: Keyword filter optimization**
- Target: >80% of messages filtered out (no GPT-4 call)
- Measure: Percentage of messages that skip GPT-4
- Test on: Real group chat data (100+ messages)

**5. Accuracy Tests**

**Test Set: Real parent group chat messages**

Sample messages (20 test cases):
```
1. "Yes!" → Expected: YES, 0.95
2. "Count me in" → Expected: YES, 0.90
3. "We'll be there!" → Expected: YES, 0.95
4. "Can't make it" → Expected: NO, 0.90
5. "Sorry, we can't come" → Expected: NO, 0.90
6. "Maybe" → Expected: MAYBE, 0.85
7. "Depends on work" → Expected: MAYBE, 0.70
8. "Not sure yet" → Expected: MAYBE, 0.75
9. "What time?" → Expected: NOT DETECTED
10. "Looking forward to it!" → Expected: YES, 0.70
11. "Absolutely!" → Expected: YES, 0.85
12. "No way" → Expected: NO, 0.80
13. "I'll try" → Expected: MAYBE, 0.65
14. "We'll pass" → Expected: NO, 0.85
15. "Definitely coming" → Expected: YES, 0.90
16. "Probably not" → Expected: NO, 0.75
17. "Sounds good!" → Expected: YES, 0.60 (ambiguous)
18. "Can't commit yet" → Expected: MAYBE, 0.70
19. "We're in!" → Expected: YES, 0.90
20. "Have to skip" → Expected: NO, 0.85
```

**Target Accuracy:**
- True Positive (detect RSVP when present): >90%
- False Positive (detect RSVP when absent): <5%
- Status accuracy (yes/no/maybe correct): >85%
- Event linking accuracy (correct event): >90%

---

## Success Criteria

### Feature Complete When:

- [x] Cloud Function deployed and responding
- [x] Can detect yes/no/maybe responses with >85% accuracy
- [x] RSVPs stored in Firestore subcollections
- [x] RSVP summary displays below calendar card
- [x] Expand/collapse animation smooth (60fps)
- [x] Participant list grouped by status
- [x] Real-time updates when new RSVPs detected
- [x] Works in group chats (3+ participants)
- [x] Links RSVPs to correct events >90% of time
- [x] All test scenarios pass
- [x] No crashes or errors
- [x] Performance targets met
- [x] Documentation complete

### Performance Targets

- **Detection latency**: <2s (warm), <5s (cold start)
- **RSVP summary load**: <1s for 50 participants
- **Keyword filter**: >80% messages skip GPT-4
- **API cost**: <$0.003 per detection (~$3-6/month/user)

### Quality Gates

- **Accuracy**: >85% on test set (20 real messages)
- **Event linking**: >90% correct event
- **False positives**: <5% (don't detect RSVP in non-RSVP messages)
- **UI responsiveness**: 60fps animations, <100ms tap response
- **No critical bugs**: Zero crashes, zero data loss

---

## Risk Assessment

### Risk 1: Low Detection Accuracy 🟡 MEDIUM

**Issue**: AI misclassifies RSVP status (thinks "maybe" is "yes")

**Likelihood**: MEDIUM (GPT-4 is good, but ambiguous language is hard)

**Impact**: HIGH (false RSVPs frustrate users)

**Mitigation**:
1. Show confidence score to users
2. Allow manual correction ("This isn't right" button)
3. Test with 100+ real parent messages before launch
4. Iteratively improve prompts based on failures

**Status**: 🟡 Acceptable (can improve post-launch)

### Risk 2: Wrong Event Linkage 🟡 MEDIUM

**Issue**: RSVP linked to wrong event (two events in same conversation)

**Likelihood**: MEDIUM (10-20% of group chats have multiple events)

**Impact**: MEDIUM (confusing, but not breaking)

**Mitigation**:
1. Hybrid approach: AI suggests, user confirms if ambiguous
2. Show "Responding to: Pizza Party Friday" in RSVP confirmation
3. Allow manual event selection from dropdown
4. Use recency heuristic (most recent event mentioned)

**Status**: 🟡 Acceptable (user confirmation available)

### Risk 3: High API Costs 🟢 LOW

**Issue**: Too many GPT-4 calls, high OpenAI bill

**Likelihood**: LOW (keyword filter removes 80% of messages)

**Impact**: MEDIUM ($20-50/month vs $5-10/month)

**Mitigation**:
1. Keyword filter reduces calls by 80%
2. 1-minute caching per message
3. Rate limiting from PR#14 (100 req/hour/user)
4. Monitor costs, adjust if needed

**Status**: 🟢 Low risk (hybrid approach works)

### Risk 4: Firestore Query Performance 🟢 LOW

**Issue**: Fetching RSVPs slow for large events (50+ participants)

**Likelihood**: LOW (most events <20 participants)

**Impact**: LOW (1-2s delay acceptable)

**Mitigation**:
1. Firestore subcollections are fast (<1s for 100 docs)
2. Cache RSVP summary for 5 minutes
3. Show cached data while refreshing
4. Progressive loading (show summary, then details)

**Status**: 🟢 Low risk (Firestore handles it)

---

## Timeline

### Total Estimate: 3-4 hours

| Phase | Task | Time | Dependencies |
|-------|------|------|--------------|
| 1 | Cloud Function (rsvpTracking.ts) | 1h | PR#14 ✅ |
| 2 | iOS Models (RSVPResponse.swift) | 45m | None |
| 3 | AIService Integration | 45m | Phase 2 |
| 4 | ChatViewModel Logic | 30m | Phase 3 |
| 5 | UI Components (4 views) | 1.5h | Phase 4 |
| 6 | Testing & Polish | 30m | Phase 5 |

**Critical Path**: Phase 1 → 2 → 3 → 4 → 5 → 6 (sequential)

**Earliest Start**: After PR#15 (Calendar Extraction) complete ✅

**Recommended Start**: After PR#16 or #17 (Decision/Priority) to have more AI features in place

---

## Dependencies

### Hard Dependencies (Must Be Complete)

- [x] **PR #14: Cloud Functions Setup** ✅ COMPLETE
  - Need: AI infrastructure, OpenAI integration
  - Status: Deployed and tested
  
- [x] **PR #15: Calendar Extraction** ✅ COMPLETE
  - Need: CalendarEvent model, event creation flow
  - Status: Working perfectly

### Soft Dependencies (Nice to Have)

- [ ] **PR #16: Decision Summarization** (Recommended)
  - Why: Provides more context for RSVP detection
  - Can work without it: Yes (just less accurate event linking)

- [ ] **PR #17: Priority Highlighting** (Optional)
  - Why: Could mark "RSVP needed" messages as high priority
  - Can work without it: Yes (independent features)

### Blocks

**This PR blocks:**
- PR #20: Multi-Step Event Planning Agent (will use RSVP data for coordination)

---

## Open Questions

### Question 1: Should we support emoji RSVPs?

**Context**: Some users reply with 👍 (yes) or ❌ (no) or 🤷 (maybe)

**Options**:
- A) Detect emoji RSVPs (add emoji parsing to keyword filter)
- B) Text-only for MVP (add emoji later)
- C) Hybrid (detect obvious emojis, prompt for unclear ones)

**Recommendation**: B (Text-only for MVP)
- Reason: Emoji meaning is ambiguous (👍 could be "like" not "yes")
- Can add in PR#18.1 if user feedback requests it

### Question 2: Should we support "on behalf of" RSVPs?

**Context**: "Mark us down as yes for both families"

**Options**:
- A) Detect multi-person RSVPs (parse "us", "both")
- B) One RSVP per message for MVP
- C) Let user manually add multiple people

**Recommendation**: B (One per message for MVP)
- Reason: AI parsing of "us" is unreliable (which people?)
- Can add manual multi-person RSVP in future

### Question 3: Should we support RSVP deadlines?

**Context**: "Please respond by Friday"

**Options**:
- A) Extract deadline and show countdown
- B) Let PR#19 (Deadline Extraction) handle it
- C) Manual deadline setting only

**Recommendation**: B (Defer to PR#19)
- Reason: PR#19 specifically built for deadline extraction
- This PR focuses on response detection and tracking

---

## References

### Related PRs
- **PR #14**: Cloud Functions Setup & AI Service Base ✅ (Infrastructure)
- **PR #15**: Calendar Extraction Feature ✅ (Event creation)
- **PR #16**: Decision Summarization (Group decision tracking)
- **PR #17**: Priority Highlighting (Urgent message detection)
- **PR #19**: Deadline Extraction (RSVP deadline tracking)
- **PR #20**: Multi-Step Event Planning Agent (Uses RSVP data)

### External Resources
- OpenAI Function Calling: https://platform.openai.com/docs/guides/function-calling
- Firestore Subcollections: https://firebase.google.com/docs/firestore/data-model#subcollections
- SwiftUI Animations: https://developer.apple.com/documentation/swiftui/animation

### Similar Implementations
- Google Calendar: Event guest responses
- Facebook Events: Going/Not Going/Maybe
- Doodle Polls: Participant tracking

---

## Success Metrics

### Quantitative

- **Detection accuracy**: >85% on test set
- **False positive rate**: <5%
- **Event linking accuracy**: >90%
- **Detection latency**: <2s warm, <5s cold
- **RSVP load time**: <1s for 50 participants
- **API cost**: <$0.003 per detection

### Qualitative

- **User feedback**: "This saved me so much time!"
- **Viral potential**: Users share screenshots of RSVP tracking
- **Confidence**: Users trust RSVP counts (>80% accuracy)
- **Adoption**: >50% of group conversations use RSVP tracking

### Business Value

- **Time saved**: 5-10 minutes per event organized
- **Error reduction**: No more "I thought you said yes?"
- **Engagement**: Users open app more to check RSVP status
- **Differentiation**: Feature not in WhatsApp/iMessage
- **Foundation**: Enables PR#20 (Event Planning Agent)

---

**This is the 4th of 5 required AI features for busy parents. After this PR, we'll have:**
1. ✅ Calendar Extraction (PR#15)
2. ✅ Decision Summarization (PR#16)
3. ⏳ Priority Highlighting (PR#17) - documented
4. 🎯 **RSVP Tracking (PR#18)** ← YOU ARE HERE
5. ⏳ Deadline Extraction (PR#19) - next!

**Plus advanced feature:**
6. ⏳ Multi-Step Event Planning Agent (PR#20) - uses all above features!

---

*Last Updated: October 22, 2025*  
*Ready for Implementation: YES*  
*Dependencies Met: PR#14 ✅, PR#15 ✅*

