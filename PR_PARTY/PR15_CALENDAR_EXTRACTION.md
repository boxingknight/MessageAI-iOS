# PR#15: Calendar Extraction Feature - AI-Powered Date/Time Detection

**Status:** 📋 PLANNED (Documentation complete, ready to implement!)  
**Branch:** `feature/pr15-calendar-extraction` (to be created)  
**Timeline:** 3-4 hours estimated  
**Priority:** 🟡 HIGH - First AI feature for busy parents  
**Depends on:** PR#14 (Cloud Functions Setup) - MUST BE COMPLETE FIRST  
**Created:** October 22, 2025

---

## Overview

### What We're Building

An AI-powered feature that **automatically detects dates, times, and events** mentioned in messages and extracts them as structured calendar data. When users chat about "Soccer practice Thursday at 4pm" or "Piano recital Friday 6pm", the app will:

1. **Detect** the calendar-related information using GPT-4
2. **Extract** structured data (date, time, title, location)
3. **Display** as actionable calendar cards in the chat
4. **Allow confirmation** with one tap to add to iOS Calendar

**Target User:** Sarah, busy parent who receives "School pickup change - 2:30pm today!" buried in 50+ messages.

**Value Proposition:** Never miss important events hidden in group chats. Automatic calendar extraction saves 10-15 minutes per day of manually tracking dates/times.

### Why It Matters

**The Problem:**
- Important events get buried in conversation noise
- Parents miss schedule changes (school pickups, practice times)
- Manually copying dates/times to calendar is tedious
- Searching through message history for "when was that thing?" wastes time

**The Solution:**
- AI automatically finds and extracts calendar information
- Events appear as visual cards (impossible to miss)
- One-tap confirmation to add to iOS Calendar
- Searchable history of all detected events

**Business Impact:**
- 🎯 First AI feature users see (sets expectations)
- 🎯 High visibility (visual cards in chat)
- 🎯 Clear value (saves time, prevents missed events)
- 🎯 Foundation for PR#18 (RSVP Tracking)

### Success in One Sentence

"Sarah can glance at any conversation and instantly see all upcoming events extracted as calendar cards, with one-tap confirmation to add to her iOS Calendar."

---

## Technical Design

### Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                         iOS App (SwiftUI)                        │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ ChatView (Message Display)                                │  │
│  │  ├─ MessageBubbleView (text message)                      │  │
│  │  └─ CalendarCardView (extracted event) ← NEW!            │  │
│  └──────────────────────────────────────────────────────────┘  │
│                           │                                      │
│                           ▼                                      │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ ChatViewModel                                             │  │
│  │  ├─ messages: [Message] (includes aiMetadata)            │  │
│  │  └─ processMessageForCalendar(messageId) → CalendarEvent │  │
│  └──────────────────────────────────────────────────────────┘  │
│                           │                                      │
│                           ▼                                      │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ AIService.extractCalendarEvents(messageId)                │  │
│  │  - Calls Cloud Functions                                  │  │
│  │  - Returns CalendarEvent data                             │  │
│  └──────────────────────────────────────────────────────────┘  │
│                           │                                      │
└───────────────────────────┼──────────────────────────────────────┘
                            │ HTTPS Request
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│              Firebase Cloud Functions (Node.js)                  │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ processAI (Router)                                        │  │
│  │  ├─ auth middleware (verify user)                         │  │
│  │  ├─ rate limit (100 req/hour)                             │  │
│  │  ├─ route to: calendarExtraction()                        │  │
│  │  └─ return CalendarEvent[]                                │  │
│  └──────────────────────────────────────────────────────────┘  │
│                           │                                      │
│                           ▼                                      │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ calendarExtraction.ts (NEW!)                              │  │
│  │  1. Fetch message from Firestore                          │  │
│  │  2. Build context (last 5 messages for thread)            │  │
│  │  3. Call OpenAI GPT-4 with extraction prompt              │  │
│  │  4. Parse structured response (JSON)                      │  │
│  │  5. Validate and return CalendarEvent[]                   │  │
│  └──────────────────────────────────────────────────────────┘  │
│                           │                                      │
│                           ▼                                      │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ OpenAI GPT-4 API                                          │  │
│  │  - System: "Extract calendar events as JSON"              │  │
│  │  - User: Message text + context                           │  │
│  │  - Response: Structured CalendarEvent JSON                │  │
│  └──────────────────────────────────────────────────────────┘  │
│                           │                                      │
└───────────────────────────┼──────────────────────────────────────┘
                            │
                            ▼ Save to Firestore
┌─────────────────────────────────────────────────────────────────┐
│  Firestore: messages/{messageId}                                │
│    - text: "Soccer practice Thursday at 4pm"                    │
│    - aiMetadata: {                                              │
│        calendarEvents: [{                                       │
│          title: "Soccer practice",                              │
│          date: "2025-10-24",                                    │
│          time: "16:00",                                         │
│          isAllDay: false,                                       │
│          confidence: 0.95                                       │
│        }]                                                       │
│      }                                                          │
└─────────────────────────────────────────────────────────────────┘
```

### Data Flow: Message → Calendar Event

**Step 1: User sends message**
```swift
// User types: "Don't forget - soccer practice Thursday at 4pm!"
chatViewModel.sendMessage("Don't forget - soccer practice Thursday at 4pm!")
```

**Step 2: Message saved to Firestore (PR#10)**
```
messages/{messageId}:
  text: "Don't forget - soccer practice Thursday at 4pm!"
  senderId: "user123"
  sentAt: Timestamp(2025-10-22 10:00:00)
  aiMetadata: null  // Will be populated by AI processing
```

**Step 3: Recipient receives message in real-time**
```swift
// ChatViewModel real-time listener (from PR#10)
// Message appears in chat with text content
```

**Step 4: AI processing triggered (automatic or manual)**
```swift
// Option A: Automatic (background processing)
// - Cloud Functions Firestore trigger on message create
// - Processes all new messages automatically

// Option B: Manual (user taps "Extract Events")
// - User taps button on message bubble
// - ChatViewModel calls AIService.extractCalendarEvents(messageId)
```

**Step 5: Cloud Function extracts calendar data**
```javascript
// functions/src/ai/calendarExtraction.ts
export async function extractCalendarEvents(messageText: string, context: string[]) {
  const completion = await openai.chat.completions.create({
    model: "gpt-4",
    messages: [
      {
        role: "system",
        content: `You are a calendar extraction assistant for busy parents.
Extract dates, times, and events from messages.
Return JSON array of events.
Format: [{ title, date, time, isAllDay, location, confidence }]`
      },
      {
        role: "user",
        content: `Context (last 5 messages):\n${context.join('\n')}\n\nCurrent message:\n${messageText}`
      }
    ],
    response_format: { type: "json_object" }
  });
  
  return JSON.parse(completion.choices[0].message.content);
}
```

**Step 6: AI response parsed and validated**
```json
{
  "events": [
    {
      "title": "Soccer practice",
      "date": "2025-10-24",
      "time": "16:00",
      "isAllDay": false,
      "location": null,
      "confidence": 0.95
    }
  ]
}
```

**Step 7: aiMetadata saved to Firestore**
```
messages/{messageId}:
  text: "Don't forget - soccer practice Thursday at 4pm!"
  aiMetadata: {
    calendarEvents: [{ title: "Soccer practice", date: "2025-10-24", ... }],
    processedAt: Timestamp(2025-10-22 10:00:05),
    feature: "calendar"
  }
```

**Step 8: iOS app displays calendar card**
```swift
// ChatView displays MessageBubbleView + CalendarCardView
if let events = message.aiMetadata?.calendarEvents, !events.isEmpty {
  ForEach(events) { event in
    CalendarCardView(event: event, onConfirm: { addToCalendar(event) })
  }
}
```

---

## Key Design Decisions

### Decision 1: Processing Model - Automatic vs Manual

**Options Considered:**

**Option A: Fully Automatic (Background)**
- Pros: Zero user effort, all events extracted automatically
- Cons: High API costs, processes irrelevant messages, privacy concerns
- Cost: ~$0.02 per message × 100 messages/day/user = $2/day/user = $60/month/user

**Option B: Manual Trigger Only**
- Pros: Low cost, user controls what gets processed, privacy-conscious
- Cons: User must remember to tap, may miss events, extra friction
- Cost: ~$0.02 per extraction × 5-10/day = $0.10-0.20/day/user = $3-6/month/user

**Option C: Hybrid Smart (MVP Choice)** ✅
- Automatic: Process messages from known calendars sources (school groups)
- Manual: User can tap any message to extract events
- Smart sampling: Process 1 random message per conversation per day for hints
- Pros: Balances automation with cost control
- Cons: Requires conversation classification
- Cost: ~$0.02 × 20/day/user = $0.40/day/user = $12/month/user (manageable)

**Chosen:** Option C (Hybrid Smart) for MVP

**Rationale:**
- Sarah gets automatic extraction where it matters most (school/family groups)
- Manual fallback for edge cases
- Cost-effective at scale (~$12/month/user vs $60)
- Privacy-conscious (user controls sensitive conversations)

**Implementation Path:**
- PR#15: Manual trigger only (simplest, immediate value)
- PR#20: Add automatic processing for specific conversations (advanced agent)

### Decision 2: Data Model - aiMetadata Structure

**Options Considered:**

**Option A: Separate Collection**
```
/calendar_events/{eventId}
  messageId: "msg123"
  conversationId: "conv456"
  title: "Soccer practice"
  date: "2025-10-24"
```
- Pros: Easy queries, independent lifecycle
- Cons: Extra Firestore reads, sync complexity, duplicate data

**Option B: Embedded in Message** ✅
```
/messages/{messageId}
  text: "..."
  aiMetadata: {
    calendarEvents: [{ title, date, time, ... }]
  }
```
- Pros: Single read, co-located data, simpler sync
- Cons: Message doc size grows, harder to query all events

**Chosen:** Option B (Embedded in Message)

**Rationale:**
- Messages already fetched for display (zero extra reads)
- Calendar events are display-only metadata (not searchable in MVP)
- Simpler implementation (no sync logic needed)
- Can migrate to separate collection later if needed

**Trade-offs:**
- ✅ Gain: Simpler code, faster display, zero extra cost
- ❌ Lose: Can't query "all events next week" without scanning messages
- 📝 Note: If querying becomes important, add PR#21: Calendar Events Collection

### Decision 3: UI Pattern - In-Chat Cards vs Separate View

**Options Considered:**

**Option A: Separate Calendar Tab**
- Like iOS Calendar app with extracted events list
- Pros: Focused view, familiar pattern, easy to browse
- Cons: Context loss, extra navigation, hidden from chat

**Option B: In-Chat Calendar Cards** ✅
- Events appear as cards directly below message
- Pros: Zero context loss, highly visible, one-tap action
- Cons: Clutters chat, takes vertical space

**Chosen:** Option B (In-Chat Calendar Cards)

**Rationale:**
- Events stay in conversation context (crucial for busy parents)
- Zero navigation friction (see and act immediately)
- Visual prominence (impossible to miss)
- Matches WhatsApp/Telegram poll pattern (proven UX)

**Visual Design:**
```
┌────────────────────────────────────┐
│ Sarah: Don't forget - soccer      │
│ practice Thursday at 4pm!          │
│                            10:15am │
└────────────────────────────────────┘
         ↓
┌────────────────────────────────────┐
│ 📅 Calendar Event Detected         │
│ ─────────────────────────────────  │
│ Soccer practice                    │
│ Thursday, Oct 24 at 4:00 PM        │
│                                    │
│ [✓ Add to Calendar]  [✕ Dismiss]  │
└────────────────────────────────────┘
```

### Decision 4: Confirmation Flow - Automatic vs Manual Add

**Options Considered:**

**Option A: Automatic Add to Calendar**
- AI extracts → immediately adds to iOS Calendar
- Pros: Zero friction, fully automated
- Cons: Calendar pollution, no user control, trust issues

**Option B: Confirmation Required** ✅
- AI extracts → shows card → user taps to confirm
- Pros: User control, prevents errors, builds trust
- Cons: Extra tap, may be ignored

**Chosen:** Option B (Confirmation Required)

**Rationale:**
- AI accuracy is 90-95% (5-10% false positives unacceptable)
- User trust is essential for AI adoption
- Confirmation builds confidence in AI accuracy
- One tap is acceptable friction for important events

**Implementation:**
```swift
CalendarCardView(event: event) {
  // User taps "Add to Calendar"
  eventStore.requestAccess { granted in
    if granted {
      let ekEvent = EKEvent(eventStore: eventStore)
      ekEvent.title = event.title
      ekEvent.startDate = event.startDate
      // ... configure event
      try? eventStore.save(ekEvent, span: .thisEvent)
      
      // Mark as confirmed in Firestore
      updateMessage(messageId, confirmedEvent: event.id)
    }
  }
}
```

---

## Data Models

### CalendarEvent (Swift)

```swift
// Models/CalendarEvent.swift
import Foundation

struct CalendarEvent: Codable, Identifiable, Equatable {
    let id: String
    let title: String
    let date: String  // ISO 8601: "2025-10-24"
    let time: String?  // "16:00" (24-hour) or nil if all-day
    let isAllDay: Bool
    let location: String?
    let notes: String?
    let confidence: Double  // 0.0-1.0
    let extractedAt: Date
    
    // Computed properties
    var startDate: Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        if let time = time {
            formatter.formatOptions.insert(.withTime)
            return formatter.date(from: "\(date)T\(time):00Z") ?? Date()
        }
        return formatter.date(from: date) ?? Date()
    }
    
    var displayDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = time == nil ? .none : .short
        return formatter.string(from: startDate)
    }
    
    var isPast: Bool {
        startDate < Date()
    }
    
    var isUpcoming: Bool {
        let dayAway = Date().addingTimeInterval(86400)
        return startDate < dayAway && !isPast
    }
    
    // EventKit conversion
    func toEKEvent(eventStore: EKEventStore) -> EKEvent {
        let event = EKEvent(eventStore: eventStore)
        event.title = title
        event.startDate = startDate
        event.endDate = startDate.addingTimeInterval(isAllDay ? 86400 : 3600)
        event.isAllDay = isAllDay
        event.location = location
        event.notes = notes
        event.calendar = eventStore.defaultCalendarForNewEvents
        return event
    }
}
```

### AIMetadata Extension (Message model)

```swift
// Models/Message.swift (extension from PR#14)

struct Message: Codable, Identifiable, Equatable {
    // ... existing fields from PR#4
    var aiMetadata: AIMetadata?  // From PR#14
}

struct AIMetadata: Codable, Equatable {
    var calendarEvents: [CalendarEvent]?  // NEW in PR#15
    var decisionSummary: DecisionSummary?  // PR#16
    var priorityLevel: PriorityLevel?  // PR#17
    var rsvpStatus: RSVPStatus?  // PR#18
    var deadlines: [Deadline]?  // PR#19
    var processedAt: Date
    var feature: String  // "calendar", "decision", "priority", etc.
}
```

### Cloud Function Request/Response

```typescript
// functions/src/ai/calendarExtraction.ts

interface CalendarExtractionRequest {
  messageId: string;
  includeContext?: boolean;  // Include previous messages for accuracy
}

interface CalendarExtractionResponse {
  success: boolean;
  events: CalendarEvent[];
  processedAt: number;
  error?: string;
}

interface CalendarEvent {
  id: string;
  title: string;
  date: string;  // ISO 8601: "2025-10-24"
  time?: string;  // "16:00" or null
  isAllDay: boolean;
  location?: string;
  notes?: string;
  confidence: number;  // 0.0-1.0
}
```

---

## Implementation Plan

### Files to Create (5 new files, ~850 lines)

#### 1. Cloud Function: Calendar Extraction Logic
**File:** `functions/src/ai/calendarExtraction.ts` (~250 lines)

```typescript
import * as admin from 'firebase-admin';
import { OpenAI } from 'openai';

interface CalendarEvent {
  id: string;
  title: string;
  date: string;
  time?: string;
  isAllDay: boolean;
  location?: string;
  notes?: string;
  confidence: number;
}

export async function extractCalendarEvents(
  messageId: string,
  includeContext: boolean = true
): Promise<CalendarEvent[]> {
  // 1. Fetch message from Firestore
  const messageDoc = await admin.firestore()
    .collection('messages')
    .doc(messageId)
    .get();
  
  if (!messageDoc.exists) {
    throw new Error('Message not found');
  }
  
  const message = messageDoc.data();
  const messageText = message.text;
  
  // 2. Build context (last 5 messages in conversation)
  let context: string[] = [];
  if (includeContext) {
    const contextDocs = await admin.firestore()
      .collection('conversations')
      .doc(message.conversationId)
      .collection('messages')
      .orderBy('sentAt', 'desc')
      .limit(5)
      .get();
    
    context = contextDocs.docs
      .reverse()
      .map(doc => `${doc.data().senderName}: ${doc.data().text}`);
  }
  
  // 3. Call OpenAI GPT-4 with extraction prompt
  const openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });
  
  const completion = await openai.chat.completions.create({
    model: 'gpt-4',
    messages: [
      {
        role: 'system',
        content: `You are a calendar extraction assistant for busy parents managing family schedules.

Extract dates, times, and events from messages. Be especially accurate with:
- School events (pickup changes, half days, conferences)
- Activities (practice times, recitals, games)
- Family plans (dinners, playdates, appointments)

Today's date: ${new Date().toISOString().split('T')[0]}

Return JSON:
{
  "events": [
    {
      "title": "Event name",
      "date": "YYYY-MM-DD",
      "time": "HH:MM" or null,
      "isAllDay": boolean,
      "location": "Place" or null,
      "notes": "Additional info" or null,
      "confidence": 0.0-1.0
    }
  ]
}

Rules:
- If no clear date/time, return empty array
- For relative dates ("Thursday"), use this week unless past, then next week
- For "today"/"tomorrow", calculate exact date
- Time in 24-hour format
- Confidence: 0.9+ for explicit dates, 0.7-0.9 for relative, <0.7 for ambiguous
- Extract multiple events if mentioned
- Include location if clearly stated
- Add notes for important details (e.g., "bring snack")`,
      },
      {
        role: 'user',
        content: includeContext
          ? `Context (recent messages):\n${context.join('\n')}\n\nCurrent message:\n${messageText}`
          : `Message:\n${messageText}`,
      },
    ],
    response_format: { type: 'json_object' },
    temperature: 0.3,  // Lower temperature for more consistent extraction
  });
  
  // 4. Parse and validate response
  const response = JSON.parse(completion.choices[0].message.content);
  const events: CalendarEvent[] = [];
  
  for (const event of response.events || []) {
    // Validate required fields
    if (!event.title || !event.date) continue;
    
    // Validate date format (YYYY-MM-DD)
    if (!/^\d{4}-\d{2}-\d{2}$/.test(event.date)) continue;
    
    // Validate time format (HH:MM) if present
    if (event.time && !/^\d{2}:\d{2}$/.test(event.time)) continue;
    
    // Add validated event
    events.push({
      id: `${messageId}_${events.length}`,
      title: event.title,
      date: event.date,
      time: event.time || null,
      isAllDay: event.isAllDay || !event.time,
      location: event.location || null,
      notes: event.notes || null,
      confidence: Math.max(0, Math.min(1, event.confidence || 0.5)),
    });
  }
  
  // 5. Save to Firestore (update message aiMetadata)
  if (events.length > 0) {
    await messageDoc.ref.update({
      'aiMetadata.calendarEvents': events,
      'aiMetadata.processedAt': admin.firestore.FieldValue.serverTimestamp(),
      'aiMetadata.feature': 'calendar',
    });
  }
  
  return events;
}
```

#### 2. iOS Service: AIService Calendar Extension
**File:** `Services/AIService.swift` (add +80 lines to existing)

```swift
// Services/AIService.swift (extension from PR#14)

extension AIService {
    /// Extract calendar events from a message using AI
    func extractCalendarEvents(messageId: String, includeContext: Bool = true) async throws -> [CalendarEvent] {
        let url = functionsURL.appendingPathComponent("processAI")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add Firebase auth token
        if let idToken = try? await Auth.auth().currentUser?.getIDToken() {
            request.addValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        }
        
        let body = AIRequest(
            feature: "calendar",
            data: [
                "messageId": messageId,
                "includeContext": includeContext
            ]
        )
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(CalendarExtractionResponse.self, from: data)
        
        if !response.success {
            throw AIError.extractionFailed(response.error ?? "Unknown error")
        }
        
        return response.events
    }
}

struct CalendarExtractionResponse: Codable {
    let success: Bool
    let events: [CalendarEvent]
    let processedAt: Date
    let error: String?
}
```

#### 3. SwiftUI View: CalendarCardView
**File:** `Views/Chat/CalendarCardView.swift` (~200 lines)

```swift
import SwiftUI
import EventKit

struct CalendarCardView: View {
    let event: CalendarEvent
    let onConfirm: () -> Void
    let onDismiss: () -> Void
    
    @State private var isConfirming = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(.blue)
                Text("Calendar Event Detected")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                if event.confidence < 0.8 {
                    Image(systemName: "questionmark.circle")
                        .foregroundColor(.orange)
                        .help("Low confidence - please verify")
                }
            }
            
            Divider()
            
            // Event details
            VStack(alignment: .leading, spacing: 8) {
                Text(event.title)
                    .font(.headline)
                
                HStack {
                    Image(systemName: event.isAllDay ? "sun.max" : "clock")
                        .foregroundColor(.secondary)
                        .frame(width: 20)
                    Text(event.displayDate)
                        .font(.subheadline)
                }
                
                if let location = event.location {
                    HStack {
                        Image(systemName: "mappin.circle")
                            .foregroundColor(.secondary)
                            .frame(width: 20)
                        Text(location)
                            .font(.subheadline)
                    }
                }
                
                if let notes = event.notes {
                    HStack(alignment: .top) {
                        Image(systemName: "note.text")
                            .foregroundColor(.secondary)
                            .frame(width: 20)
                        Text(notes)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Actions
            HStack(spacing: 12) {
                Button(action: confirmEvent) {
                    Label("Add to Calendar", systemImage: "checkmark.circle.fill")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.blue)
                        .cornerRadius(20)
                }
                .disabled(isConfirming || event.isPast)
                
                Button(action: onDismiss) {
                    Label("Dismiss", systemImage: "xmark.circle")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                }
                .disabled(isConfirming)
                
                Spacer()
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(event.isUpcoming ? Color.orange : Color.clear, lineWidth: 2)
        )
        .alert("Error", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
    }
    
    private func confirmEvent() {
        isConfirming = true
        
        Task {
            do {
                try await addToCalendar()
                await MainActor.run {
                    onConfirm()
                    isConfirming = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                    isConfirming = false
                }
            }
        }
    }
    
    private func addToCalendar() async throws {
        let eventStore = EKEventStore()
        
        // Request calendar access
        let granted = try await eventStore.requestAccess(to: .event)
        guard granted else {
            throw CalendarError.accessDenied
        }
        
        // Create EKEvent
        let ekEvent = event.toEKEvent(eventStore: eventStore)
        
        // Save to calendar
        try eventStore.save(ekEvent, span: .thisEvent)
    }
}

enum CalendarError: LocalizedError {
    case accessDenied
    
    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Calendar access denied. Please enable in Settings > MessageAI > Calendars."
        }
    }
}

// MARK: - Preview
struct CalendarCardView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            CalendarCardView(
                event: CalendarEvent(
                    id: "1",
                    title: "Soccer practice",
                    date: "2025-10-24",
                    time: "16:00",
                    isAllDay: false,
                    location: "West Field",
                    notes: "Bring water bottle",
                    confidence: 0.95,
                    extractedAt: Date()
                ),
                onConfirm: {},
                onDismiss: {}
            )
            
            CalendarCardView(
                event: CalendarEvent(
                    id: "2",
                    title: "School half day",
                    date: "2025-10-25",
                    time: nil,
                    isAllDay: true,
                    location: nil,
                    notes: nil,
                    confidence: 0.85,
                    extractedAt: Date()
                ),
                onConfirm: {},
                onDismiss: {}
            )
        }
        .padding()
    }
}
```

#### 4. ChatViewModel Extension: Calendar Processing
**File:** `ViewModels/ChatViewModel.swift` (add +60 lines to existing)

```swift
// ViewModels/ChatViewModel.swift (extension from PR#10)

extension ChatViewModel {
    /// Process a message for calendar extraction
    @MainActor
    func extractCalendarEvents(for messageId: String) async {
        guard let index = messages.firstIndex(where: { $0.id == messageId }) else { return }
        
        // Set loading state
        isProcessingAI = true
        
        do {
            // Call AI service
            let events = try await aiService.extractCalendarEvents(messageId: messageId)
            
            // Update message with extracted events
            var message = messages[index]
            if message.aiMetadata == nil {
                message.aiMetadata = AIMetadata(
                    processedAt: Date(),
                    feature: "calendar"
                )
            }
            message.aiMetadata?.calendarEvents = events
            
            // Update local array
            messages[index] = message
            
            // Update Firestore (will sync via real-time listener)
            try await chatService.updateMessageMetadata(messageId: messageId, metadata: message.aiMetadata!)
            
        } catch {
            // Show error to user
            errorMessage = "Failed to extract calendar events: \(error.localizedDescription)"
            showError = true
        }
        
        isProcessingAI = false
    }
    
    /// Confirm and add calendar event to iOS Calendar
    @MainActor
    func confirmCalendarEvent(messageId: String, eventId: String) async {
        guard let message = messages.first(where: { $0.id == messageId }),
              let event = message.aiMetadata?.calendarEvents?.first(where: { $0.id == eventId }) else {
            return
        }
        
        // Mark event as confirmed in Firestore
        // (prevents showing again, tracks user engagement)
        try? await chatService.markEventConfirmed(messageId: messageId, eventId: eventId)
    }
}
```

#### 5. ChatView Integration: Display Calendar Cards
**File:** `Views/Chat/ChatView.swift` (add +40 lines to existing)

```swift
// Views/Chat/ChatView.swift (modifications)

struct ChatView: View {
    // ... existing code from PR#9
    
    var body: some View {
        VStack(spacing: 0) {
            // ... existing header
            
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.messages) { message in
                            VStack(alignment: .leading, spacing: 8) {
                                // Message bubble (existing from PR#9)
                                MessageBubbleView(
                                    message: message,
                                    currentUserId: currentUserId
                                )
                                
                                // Calendar cards (NEW!)
                                if let events = message.aiMetadata?.calendarEvents,
                                   !events.isEmpty {
                                    ForEach(events) { event in
                                        CalendarCardView(
                                            event: event,
                                            onConfirm: {
                                                Task {
                                                    await viewModel.confirmCalendarEvent(
                                                        messageId: message.id,
                                                        eventId: event.id
                                                    )
                                                }
                                            },
                                            onDismiss: {
                                                // Optionally hide card (don't add to calendar)
                                            }
                                        )
                                        .transition(.scale.combined(with: .opacity))
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
            
            // ... existing message input
        }
        .contextMenu(forSelectionType: Message.ID.self) { messageIds in
            // Add context menu option to extract calendar events
            if let messageId = messageIds.first {
                Button {
                    Task {
                        await viewModel.extractCalendarEvents(for: messageId)
                    }
                } label: {
                    Label("Extract Calendar Events", systemImage: "calendar.badge.plus")
                }
            }
        }
    }
}
```

### Files to Modify (4 existing files, +~180 lines)

1. **`Models/CalendarEvent.swift`** (NEW, ~120 lines) - Already detailed above
2. **`Models/Message.swift`** (+20 lines) - AIMetadata with calendarEvents field
3. **`Services/ChatService.swift`** (+40 lines) - Methods to update aiMetadata, mark events confirmed
4. **`Info.plist`** (+2 lines) - Calendar permission description

```xml
<!-- Info.plist additions -->
<key>NSCalendarsUsageDescription</key>
<string>MessageAI needs calendar access to add detected events from your conversations.</string>
```

---

## Testing Strategy

### Test Categories

#### 1. Unit Tests (Cloud Functions)

**Test:** Event extraction accuracy
```javascript
describe('calendarExtraction', () => {
  it('should extract explicit date and time', async () => {
    const result = await extractCalendarEvents('Soccer practice Thursday at 4pm', []);
    expect(result.events).toHaveLength(1);
    expect(result.events[0].title).toBe('Soccer practice');
    expect(result.events[0].confidence).toBeGreaterThan(0.9);
  });
  
  it('should extract relative dates (today/tomorrow)', async () => {
    const result = await extractCalendarEvents('Doctor appointment tomorrow at 10am', []);
    expect(result.events[0].date).toBe(getTomorrowDate());
  });
  
  it('should extract all-day events', async () => {
    const result = await extractCalendarEvents('School half day Friday', []);
    expect(result.events[0].isAllDay).toBe(true);
  });
  
  it('should extract location if mentioned', async () => {
    const result = await extractCalendarEvents('Piano recital at community center 6pm', []);
    expect(result.events[0].location).toContain('community center');
  });
  
  it('should return empty array for non-event messages', async () => {
    const result = await extractCalendarEvents('How are you doing?', []);
    expect(result.events).toHaveLength(0);
  });
});
```

#### 2. Integration Tests (iOS + Cloud Functions)

**Test:** End-to-end extraction flow
```swift
func testCalendarExtractionEndToEnd() async throws {
    // 1. Send message with event
    let message = try await chatService.sendMessage(
        conversationId: testConversationId,
        text: "Don't forget - soccer practice Thursday at 4pm!"
    )
    
    // 2. Extract calendar events
    let events = try await aiService.extractCalendarEvents(messageId: message.id)
    
    // 3. Verify extraction
    XCTAssertEqual(events.count, 1)
    XCTAssertEqual(events[0].title, "Soccer practice")
    XCTAssertFalse(events[0].isAllDay)
    XCTAssertGreaterThan(events[0].confidence, 0.9)
}

func testCalendarCardDisplay() throws {
    // 1. Create message with calendar event
    let event = CalendarEvent(
        id: "test1",
        title: "Soccer practice",
        date: "2025-10-24",
        time: "16:00",
        isAllDay: false,
        location: nil,
        notes: nil,
        confidence: 0.95,
        extractedAt: Date()
    )
    
    var message = Message(...)
    message.aiMetadata = AIMetadata(
        calendarEvents: [event],
        processedAt: Date(),
        feature: "calendar"
    )
    
    // 2. Display in ChatView
    let view = CalendarCardView(event: event, onConfirm: {}, onDismiss: {})
    
    // 3. Verify UI elements present
    // (Use ViewInspector or UI tests)
}
```

#### 3. Edge Cases

**Test cases:**
- Multiple events in one message: "Meeting 2pm, then dinner 7pm"
- Ambiguous times: "practice this week" (should have low confidence)
- Past events: "yesterday's game" (should mark as past)
- Context-dependent: "same time as last week" (needs conversation context)
- Non-English: "Rendez-vous demain à 15h" (should work with GPT-4 multilingual)
- Typos: "meetng tomorow 3pm" (GPT-4 should handle)

#### 4. Performance Tests

**Targets:**
- Cold start (first request): <5 seconds
- Warm request: <2 seconds
- Cost per extraction: ~$0.02 (GPT-4 API)
- Accuracy: >90% for explicit dates/times

#### 5. Acceptance Criteria

✅ **Feature is complete when:**
- [ ] User can long-press message → "Extract Calendar Events"
- [ ] AI extracts structured event data (title, date, time)
- [ ] Calendar card appears below message
- [ ] User can tap "Add to Calendar" → adds to iOS Calendar
- [ ] Events persist in message aiMetadata
- [ ] Multiple events in one message handled correctly
- [ ] Past events marked visually (grayed out, no add button)
- [ ] Confidence level shown (low confidence gets warning icon)
- [ ] Works with relative dates ("tomorrow", "next Friday")
- [ ] Works with context ("same time as last week")
- [ ] Handles ambiguous messages gracefully (empty array if unclear)
- [ ] Respects rate limits (100 requests/hour/user)
- [ ] All tests passing (unit, integration, edge cases)
- [ ] Performance: <2s extraction, >90% accuracy

---

## Success Metrics

### User Experience Metrics
- **Discovery:** 80%+ of users find calendar card within first group chat with date/time
- **Adoption:** 50%+ of users tap "Extract Events" at least once
- **Confirmation Rate:** 70%+ of extracted events get added to calendar
- **False Positive Rate:** <10% (user dismisses without adding)
- **Time Saved:** 5-10 minutes per day (no manual calendar entry)

### Technical Metrics
- **Extraction Accuracy:** >90% for explicit dates, >70% for relative dates
- **Processing Time:** <2 seconds (warm), <5 seconds (cold start)
- **Cost per Extraction:** ~$0.02 (GPT-4 API call)
- **Daily Usage:** 5-10 extractions per active user
- **Monthly Cost:** ~$3-6 per active user (manageable)

### Quality Metrics
- **Zero critical bugs** in calendar extraction or iOS Calendar integration
- **Calendar permission** handling graceful (clear error if denied)
- **Past event handling** (no "add" button, visual indication)
- **Confidence thresholds** tuned (reject <0.5 confidence, warn 0.5-0.8, accept >0.8)

---

## Risk Assessment

### Risk 1: Low Extraction Accuracy (GPT-4 makes mistakes) 🟡 MEDIUM
**Likelihood:** MEDIUM (GPT-4 is 90-95% accurate, 5-10% errors expected)  
**Impact:** MEDIUM (false positives annoy users, false negatives miss events)  
**Mitigation:**
- Show confidence score (visual indicator for <0.8)
- Require user confirmation (never auto-add to calendar)
- Collect user feedback ("Was this correct? Yes/No")
- Fine-tune prompts based on error patterns
- Fall back to manual entry if confidence <0.5

**Status:** 🟢 Mitigated (confirmation flow prevents calendar pollution)

### Risk 2: High API Costs (GPT-4 is expensive) 🟡 MEDIUM
**Likelihood:** HIGH (GPT-4 costs ~$0.02 per extraction)  
**Impact:** MEDIUM ($6/month/user at 10 extractions/day)  
**Mitigation:**
- Start with manual trigger only (user-initiated, not automatic)
- Implement rate limiting (100 requests/hour/user)
- Cache results (same message not processed twice)
- Consider GPT-3.5-turbo for cost reduction ($0.002 vs $0.02 if needed)
- Monitor usage and adjust pricing or limits

**Status:** 🟡 Monitor (start conservative, scale if usage reasonable)

### Risk 3: Calendar Permission Denied 🟢 LOW
**Likelihood:** LOW (most users comfortable granting calendar access)  
**Impact:** LOW (feature simply doesn't work, graceful error)  
**Mitigation:**
- Clear permission prompt ("Add detected events to your calendar")
- Graceful error handling (show message, link to Settings)
- Fall back to display-only (show events, copy to clipboard)
- Don't require permission upfront (request on first "Add" tap)

**Status:** 🟢 Handled (standard iOS pattern, clear error messages)

### Risk 4: Complex Date/Time Parsing 🟡 MEDIUM
**Likelihood:** MEDIUM ("next Thursday" depends on current date, time zones tricky)  
**Impact:** MEDIUM (wrong date/time = missed event)  
**Mitigation:**
- Pass current date to GPT-4 prompt (for relative date calculation)
- Use ISO 8601 format (clear, unambiguous)
- Show calculated date in confirmation UI (user can verify)
- Add "Edit" button to fix extraction errors
- Collect edge cases and improve prompt iteratively

**Status:** 🟡 Monitor (will improve with real-world usage feedback)

---

## Timeline & Dependencies

### Estimated Time: 3-4 hours

| Phase | Task | Time | Dependencies |
|-------|------|------|--------------|
| 1 | Cloud Function: calendarExtraction.ts | 1h | PR#14 complete |
| 2 | iOS Models: CalendarEvent | 30min | None |
| 3 | iOS Service: AIService extension | 30min | PR#14 AIService |
| 4 | SwiftUI: CalendarCardView | 45min | CalendarEvent model |
| 5 | ChatViewModel: extraction logic | 30min | AIService |
| 6 | ChatView: display calendar cards | 30min | CalendarCardView |
| 7 | Testing: unit + integration | 45min | All above |
| 8 | Deploy & verify | 15min | Tests passing |

**Critical Path:** PR#14 (Cloud Functions base) → calendarExtraction.ts → iOS integration

### Dependencies

**Blocks:**
- No other PRs (first AI feature)

**Blocked By:**
- **PR#14 (Cloud Functions Setup)** - MUST BE COMPLETE FIRST
  - Requires: processAI router, OpenAI setup, auth middleware
  - Requires: AIService.swift base, AIMetadata models
  - Cannot proceed without PR#14 infrastructure

**Related:**
- PR#18 (RSVP Tracking) - Will reuse calendar extraction for event detection
- PR#20 (Event Planning Agent) - Will use calendar data as context

---

## Open Questions

### Question 1: Automatic vs Manual Processing?
**Options:**
- A) Manual only (user taps to extract) - Low cost, user control
- B) Automatic for all messages - High cost, zero friction
- C) Hybrid (auto for school groups, manual elsewhere) - Balanced

**Decision:** Start with manual (PR#15), add automatic in PR#20 agent
**Rationale:** Prove value before incurring costs

### Question 2: Confidence Threshold for Display?
**Options:**
- A) Show all extractions (>0.0 confidence) - More results, more errors
- B) Only high confidence (>0.8) - Fewer results, fewer errors
- C) Show all, visually indicate low confidence - Balanced

**Decision:** Option C (show all, warn on <0.8)
**Rationale:** Let users decide, but flag uncertainty

### Question 3: EventKit vs Manual Copy?
**Options:**
- A) Direct EventKit integration (add to Calendar app) - Native, seamless
- B) Copy to clipboard only - No permissions needed
- C) Both options - Flexibility

**Decision:** Option A (EventKit)
**Rationale:** Native experience expected by users, clipboard is cumbersome

---

## Future Enhancements (Post-PR#15)

### PR#18: RSVP Tracking
- Extend calendar extraction to detect "yes/no/maybe" responses
- Track who's attending each event
- Show attendance summary on calendar cards

### PR#20: Event Planning Agent
- Automatic extraction for known calendar sources (school groups)
- Multi-turn conversation to clarify ambiguous events
- Suggest optimal times based on participant availability

### PR#21: Calendar View (New PR)
- Dedicated calendar view showing all extracted events
- Filter by conversation, date range
- Export to external calendar apps (Google Calendar, etc.)

### PR#22: Recurring Events
- Detect recurring patterns ("every Tuesday", "weekly practice")
- Create recurring calendar events automatically
- Handle exceptions ("no practice next week")

---

## References

- **PR#14:** Cloud Functions Setup & AI Service Base (prerequisite)
- **OpenAI Structured Outputs:** https://platform.openai.com/docs/guides/structured-outputs
- **EventKit Documentation:** https://developer.apple.com/documentation/eventkit
- **iOS Calendar Permissions:** NSCalendarsUsageDescription

---

**Next Steps:**
1. Complete PR#14 (Cloud Functions Setup) first
2. Review this specification (45 minutes)
3. Follow `PR15_IMPLEMENTATION_CHECKLIST.md` step-by-step
4. Test with real messages containing dates/times
5. Deploy and celebrate! 🎉

**This is the FIRST AI feature users will see - make it count!** 📅✨

