# PR#15: Calendar Extraction - Implementation Checklist

**Use this as your daily todo list.** Check off items as you complete them.

**Estimated Total Time:** 3-4 hours  
**Current Status:** ⏳ Not Started

---

## ⚠️ Pre-Implementation Checklist (15 minutes)

### Prerequisites Verification

- [ ] **PR#14 is COMPLETE** (Cloud Functions base infrastructure)
  - `functions/src/index.ts` exists and exports `processAI`
  - `functions/src/middleware/auth.ts` exists (authentication)
  - `functions/src/middleware/rateLimit.ts` exists (rate limiting)
  - `Services/AIService.swift` exists (iOS wrapper)
  - `Models/AIMetadata.swift` exists (AI result models)
  - OpenAI API key configured in Firebase: `firebase functions:config:get openai.key`
  - Cloud Functions deployed: `firebase deploy --only functions`

- [ ] Read Planning Documents (~45 minutes)
  - [ ] Read `PR15_CALENDAR_EXTRACTION.md` (main spec) - 30 min
  - [ ] Read `PR15_README.md` (quick start) - 10 min
  - [ ] Read this checklist (you are here!) - 5 min

- [ ] Development Environment Ready
  - [ ] Xcode 15+ open with messAI project
  - [ ] Firebase CLI installed: `firebase --version`
  - [ ] Node.js 18+ installed: `node --version`
  - [ ] OpenAI API key available (from platform.openai.com)
  - [ ] iOS Simulator running OR physical device connected

- [ ] Git Branch Created
  ```bash
  cd /Users/ijaramil/Documents/GauntletAI/Week2/messAI
  git checkout main
  git pull origin main
  git checkout -b feature/pr15-calendar-extraction
  ```

**Checkpoint:** All prerequisites verified, ready to start! ✅

---

## Phase 1: Cloud Function - Calendar Extraction Logic (1 hour)

### 1.1: Create Calendar Extraction Function (30 minutes)

#### Create File
- [ ] Create `functions/src/ai/calendarExtraction.ts`

#### Add Imports
- [ ] Add imports to top of file:
  ```typescript
  import * as admin from 'firebase-admin';
  import { OpenAI } from 'openai';
  import { HttpsError } from 'firebase-functions/v1/https';
  ```

#### Define Interfaces
- [ ] Add CalendarEvent interface:
  ```typescript
  interface CalendarEvent {
    id: string;
    title: string;
    date: string;  // ISO 8601: "YYYY-MM-DD"
    time?: string;  // "HH:MM" or null
    isAllDay: boolean;
    location?: string;
    notes?: string;
    confidence: number;  // 0.0-1.0
  }
  ```

#### Implement Core Function
- [ ] Create `extractCalendarEvents` function signature:
  ```typescript
  export async function extractCalendarEvents(
    messageId: string,
    userId: string,
    includeContext: boolean = true
  ): Promise<CalendarEvent[]>
  ```

#### Step 1: Fetch Message from Firestore
- [ ] Implement message fetch:
  ```typescript
  // Fetch message document
  const messageDoc = await admin.firestore()
    .collection('messages')
    .doc(messageId)
    .get();
  
  if (!messageDoc.exists) {
    throw new HttpsError('not-found', 'Message not found');
  }
  
  const messageData = messageDoc.data()!;
  const messageText = messageData.text;
  ```

#### Step 2: Build Conversation Context
- [ ] Fetch last 5 messages for context (if includeContext = true):
  ```typescript
  let context: string[] = [];
  if (includeContext && messageData.conversationId) {
    const contextDocs = await admin.firestore()
      .collection('conversations')
      .doc(messageData.conversationId)
      .collection('messages')
      .orderBy('sentAt', 'desc')
      .limit(5)
      .get();
    
    context = contextDocs.docs
      .reverse()
      .map(doc => {
        const data = doc.data();
        return `${data.senderName || 'User'}: ${data.text}`;
      });
  }
  ```

#### Step 3: Call OpenAI GPT-4
- [ ] Initialize OpenAI client:
  ```typescript
  const openai = new OpenAI({
    apiKey: process.env.OPENAI_API_KEY
  });
  ```

- [ ] Create system prompt:
  ```typescript
  const systemPrompt = `You are a calendar extraction assistant for busy parents managing family schedules.

Extract dates, times, and events from messages. Be especially accurate with:
- School events (pickup changes, half days, conferences)
- Activities (practice times, recitals, games)
- Family plans (dinners, playdates, appointments)

Today's date: ${new Date().toISOString().split('T')[0]}
Current time: ${new Date().toISOString().split('T')[1].substring(0, 5)}

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
- Time in 24-hour format (16:00 not 4:00 PM)
- Confidence: 0.9+ for explicit dates, 0.7-0.9 for relative, <0.7 for ambiguous
- Extract multiple events if mentioned separately
- Include location if clearly stated
- Add notes for important details (e.g., "bring snack", "pickup change")
- For recurring patterns, extract only next occurrence`;
  ```

- [ ] Make API call:
  ```typescript
  const completion = await openai.chat.completions.create({
    model: 'gpt-4',
    messages: [
      { role: 'system', content: systemPrompt },
      {
        role: 'user',
        content: includeContext
          ? `Context (recent messages):\n${context.join('\n')}\n\nCurrent message:\n${messageText}`
          : `Message:\n${messageText}`
      }
    ],
    response_format: { type: 'json_object' },
    temperature: 0.3,
    max_tokens: 500
  });
  ```

#### Step 4: Parse and Validate Response
- [ ] Parse JSON response:
  ```typescript
  const response = JSON.parse(completion.choices[0].message.content || '{"events":[]}');
  const events: CalendarEvent[] = [];
  ```

- [ ] Validate each event:
  ```typescript
  for (const event of response.events || []) {
    // Validate required fields
    if (!event.title || !event.date) {
      console.log('Skipping event with missing title or date:', event);
      continue;
    }
    
    // Validate date format (YYYY-MM-DD)
    if (!/^\d{4}-\d{2}-\d{2}$/.test(event.date)) {
      console.log('Skipping event with invalid date format:', event.date);
      continue;
    }
    
    // Validate time format (HH:MM) if present
    if (event.time && !/^\d{2}:\d{2}$/.test(event.time)) {
      console.log('Skipping event with invalid time format:', event.time);
      continue;
    }
    
    // Ensure date is not in the past (more than 1 day ago)
    const eventDate = new Date(event.date);
    const oneDayAgo = new Date();
    oneDayAgo.setDate(oneDayAgo.getDate() - 1);
    
    if (eventDate < oneDayAgo) {
      console.log('Skipping past event:', event.date);
      continue;
    }
    
    // Add validated event
    events.push({
      id: `${messageId}_${events.length}`,
      title: event.title.trim(),
      date: event.date,
      time: event.time?.trim() || null,
      isAllDay: event.isAllDay !== false && !event.time,
      location: event.location?.trim() || null,
      notes: event.notes?.trim() || null,
      confidence: Math.max(0, Math.min(1, event.confidence || 0.5))
    });
  }
  ```

#### Step 5: Save to Firestore
- [ ] Update message with extracted events:
  ```typescript
  if (events.length > 0) {
    await messageDoc.ref.update({
      'aiMetadata.calendarEvents': events,
      'aiMetadata.processedAt': admin.firestore.FieldValue.serverTimestamp(),
      'aiMetadata.feature': 'calendar'
    });
    
    console.log(`Extracted ${events.length} calendar event(s) from message ${messageId}`);
  }
  
  return events;
  ```

#### Add Export
- [ ] Export function at end of file:
  ```typescript
  export { extractCalendarEvents };
  ```

**Checkpoint:** `calendarExtraction.ts` complete (~250 lines) ✓

**Test:**
```bash
# In functions/ directory
npm run build
# Should compile without errors
```

**Commit:**
```bash
git add functions/src/ai/calendarExtraction.ts
git commit -m "feat(pr15): Add calendar extraction Cloud Function"
```

---

### 1.2: Wire Up to processAI Router (15 minutes)

#### Update processAI Router
- [ ] Open `functions/src/ai/processAI.ts`

- [ ] Add import at top:
  ```typescript
  import { extractCalendarEvents } from './calendarExtraction';
  ```

- [ ] Add case to feature router (inside processAI function):
  ```typescript
  // ... existing code

  case 'calendar': {
    const { messageId, includeContext } = data;
    
    if (!messageId) {
      throw new HttpsError('invalid-argument', 'Missing messageId');
    }
    
    const events = await extractCalendarEvents(
      messageId,
      context.auth.uid,
      includeContext !== false
    );
    
    return {
      success: true,
      feature: 'calendar',
      data: { events },
      processedAt: Date.now()
    };
  }
  
  // ... other cases
  ```

**Checkpoint:** Calendar feature wired to router ✓

**Test:**
```bash
cd functions
npm run build
# Should compile without errors
```

**Commit:**
```bash
git add functions/src/ai/processAI.ts
git commit -m "feat(pr15): Wire calendar extraction to processAI router"
```

---

### 1.3: Deploy Cloud Functions (15 minutes)

#### Build Functions
- [ ] Build TypeScript to JavaScript:
  ```bash
  cd functions
  npm run build
  ```

#### Deploy to Firebase
- [ ] Deploy functions:
  ```bash
  firebase deploy --only functions
  ```

- [ ] Wait for deployment to complete (~2-3 minutes)

- [ ] Verify deployment success in terminal output:
  ```
  ✔  functions: Finished running predeploy script.
  ✔  functions[processAI(us-central1)]: Successful update operation.
  ```

#### Test Cloud Function
- [ ] Test via curl (replace with your project ID and auth token):
  ```bash
  # Get auth token from Firebase console or iOS simulator
  curl -X POST \
    https://us-central1-YOUR_PROJECT_ID.cloudfunctions.net/processAI \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer YOUR_AUTH_TOKEN" \
    -d '{
      "feature": "calendar",
      "data": {
        "messageId": "test_message_id",
        "includeContext": false
      }
    }'
  ```

- [ ] Verify response contains `success: true` and `data.events` array

**Checkpoint:** Cloud Functions deployed and working ✓

**Commit:**
```bash
git add -A
git commit -m "feat(pr15): Deploy calendar extraction Cloud Function"
git push origin feature/pr15-calendar-extraction
```

---

## Phase 2: iOS Data Models (30 minutes)

### 2.1: Create CalendarEvent Model (20 minutes)

#### Create File
- [ ] Create `Models/CalendarEvent.swift` in Xcode:
  - Right-click `Models/` folder
  - New File → Swift File
  - Name: `CalendarEvent.swift`

#### Add Imports
- [ ] Add imports at top:
  ```swift
  import Foundation
  import EventKit
  ```

#### Define Struct
- [ ] Implement CalendarEvent struct:
  ```swift
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
      
      // MARK: - Computed Properties
      
      var startDate: Date {
          let formatter = ISO8601DateFormatter()
          formatter.formatOptions = [.withFullDate]
          
          if let time = time {
              formatter.formatOptions.insert(.withTime)
              let dateString = "\(date)T\(time):00Z"
              return formatter.date(from: dateString) ?? Date()
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
          return startDate > Date() && startDate < dayAway
      }
      
      var confidenceLevel: ConfidenceLevel {
          if confidence >= 0.9 { return .high }
          if confidence >= 0.7 { return .medium }
          return .low
      }
      
      // MARK: - EventKit Conversion
      
      func toEKEvent(eventStore: EKEventStore) -> EKEvent {
          let event = EKEvent(eventStore: eventStore)
          event.title = title
          event.startDate = startDate
          
          // Default duration: 1 hour for timed events, all day otherwise
          let duration: TimeInterval = isAllDay ? 86400 : 3600
          event.endDate = startDate.addingTimeInterval(duration)
          
          event.isAllDay = isAllDay
          event.location = location
          event.notes = notes
          event.calendar = eventStore.defaultCalendarForNewEvents
          
          return event
      }
      
      // MARK: - Confidence Level
      
      enum ConfidenceLevel {
          case high, medium, low
          
          var color: String {
              switch self {
              case .high: return "green"
              case .medium: return "orange"
              case .low: return "red"
              }
          }
          
          var icon: String {
              switch self {
              case .high: return "checkmark.circle.fill"
              case .medium: return "questionmark.circle.fill"
              case .low: return "exclamationmark.triangle.fill"
              }
          }
      }
  }
  ```

**Checkpoint:** CalendarEvent model complete (~120 lines) ✓

**Build Test:**
- [ ] Build project (Cmd+B)
- [ ] Should compile without errors

**Commit:**
```bash
git add messAI/Models/CalendarEvent.swift
git commit -m "feat(pr15): Add CalendarEvent model with EventKit conversion"
```

---

### 2.2: Update AIMetadata Model (10 minutes)

#### Open Existing File
- [ ] Open `Models/AIMetadata.swift` (created in PR#14)

#### Add calendarEvents Field
- [ ] Update AIMetadata struct to include calendar events:
  ```swift
  // Models/AIMetadata.swift
  
  struct AIMetadata: Codable, Equatable {
      var calendarEvents: [CalendarEvent]?  // NEW for PR#15
      var decisionSummary: DecisionSummary?  // PR#16
      var priorityLevel: PriorityLevel?  // PR#17
      var rsvpStatus: RSVPStatus?  // PR#18
      var deadlines: [Deadline]?  // PR#19
      
      var processedAt: Date
      var feature: String  // "calendar", "decision", "priority", etc.
  }
  ```

**Checkpoint:** AIMetadata updated ✓

**Build Test:**
- [ ] Build project (Cmd+B)
- [ ] Should compile without errors

**Commit:**
```bash
git add messAI/Models/AIMetadata.swift
git commit -m "feat(pr15): Add calendarEvents field to AIMetadata"
```

---

## Phase 3: iOS AIService Extension (30 minutes)

### 3.1: Add Calendar Extraction Method (20 minutes)

#### Open Existing File
- [ ] Open `Services/AIService.swift` (created in PR#14)

#### Add Extension
- [ ] Add extension at bottom of file:
  ```swift
  // MARK: - Calendar Extraction (PR#15)
  
  extension AIService {
      /// Extract calendar events from a message using AI
      /// - Parameters:
      ///   - messageId: ID of message to process
      ///   - includeContext: Whether to include conversation context (default: true)
      /// - Returns: Array of extracted CalendarEvent objects
      func extractCalendarEvents(
          messageId: String,
          includeContext: Bool = true
      ) async throws -> [CalendarEvent] {
          let request = AIRequest(
              feature: "calendar",
              data: [
                  "messageId": messageId,
                  "includeContext": includeContext
              ]
          )
          
          let response: AIResponse<CalendarEventsData> = try await callAIFunction(request: request)
          
          guard response.success else {
              throw AIError.extractionFailed(response.error ?? "Unknown error")
          }
          
          return response.data?.events ?? []
      }
  }
  
  // MARK: - Calendar Response Models
  
  private struct CalendarEventsData: Codable {
      let events: [CalendarEvent]
  }
  ```

**Checkpoint:** AIService calendar extension complete ✓

**Build Test:**
- [ ] Build project (Cmd+B)
- [ ] Should compile without errors

**Commit:**
```bash
git add messAI/Services/AIService.swift
git commit -m "feat(pr15): Add extractCalendarEvents method to AIService"
```

---

### 3.2: Update Info.plist for Calendar Permission (10 minutes)

#### Open Info.plist
- [ ] Open `messAI/Info.plist` in Xcode

#### Add Calendar Permission Description
- [ ] Right-click in property list → Add Row
- [ ] Key: `Privacy - Calendars Usage Description`
- [ ] Type: String
- [ ] Value: `MessageAI needs calendar access to add detected events from your conversations.`

**Visual format (if editing as XML):**
```xml
<key>NSCalendarsUsageDescription</key>
<string>MessageAI needs calendar access to add detected events from your conversations.</string>
```

**Checkpoint:** Calendar permission configured ✓

**Build Test:**
- [ ] Build project (Cmd+B)
- [ ] Should compile without errors

**Commit:**
```bash
git add messAI/Info.plist
git commit -m "feat(pr15): Add calendar permission description to Info.plist"
```

---

## Phase 4: SwiftUI Calendar Card View (45 minutes)

### 4.1: Create CalendarCardView (40 minutes)

#### Create File
- [ ] Create `Views/Chat/CalendarCardView.swift` in Xcode:
  - Right-click `Views/Chat/` folder
  - New File → SwiftUI View
  - Name: `CalendarCardView.swift`

#### Add Imports
- [ ] Add imports at top:
  ```swift
  import SwiftUI
  import EventKit
  ```

#### Define View
- [ ] Implement CalendarCardView:

```swift
struct CalendarCardView: View {
    let event: CalendarEvent
    let onConfirm: () -> Void
    let onDismiss: () -> Void
    
    @State private var isConfirming = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isConfirmed = false
    
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
                
                // Confidence indicator
                if event.confidence < 0.8 {
                    HStack(spacing: 4) {
                        Image(systemName: event.confidenceLevel.icon)
                            .foregroundColor(Color(event.confidenceLevel.color))
                            .font(.caption)
                        Text("Low confidence")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Divider()
            
            // Event details
            VStack(alignment: .leading, spacing: 8) {
                Text(event.title)
                    .font(.headline)
                    .foregroundColor(event.isPast ? .secondary : .primary)
                
                HStack {
                    Image(systemName: event.isAllDay ? "sun.max" : "clock")
                        .foregroundColor(.secondary)
                        .frame(width: 20)
                    Text(event.displayDate)
                        .font(.subheadline)
                        .foregroundColor(event.isPast ? .secondary : .primary)
                }
                
                if let location = event.location {
                    HStack {
                        Image(systemName: "mappin.circle")
                            .foregroundColor(.secondary)
                            .frame(width: 20)
                        Text(location)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
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
                
                // Past event warning
                if event.isPast {
                    HStack {
                        Image(systemName: "clock.arrow.circlepath")
                            .foregroundColor(.orange)
                        Text("This event is in the past")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }
            
            // Actions
            if !isConfirmed {
                HStack(spacing: 12) {
                    if !event.isPast {
                        Button(action: confirmEvent) {
                            HStack {
                                if isConfirming {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "checkmark.circle.fill")
                                }
                                Text("Add to Calendar")
                            }
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.blue)
                            .cornerRadius(20)
                        }
                        .disabled(isConfirming)
                    }
                    
                    Button(action: onDismiss) {
                        HStack {
                            Image(systemName: "xmark.circle")
                            Text("Dismiss")
                        }
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }
                    .disabled(isConfirming)
                    
                    Spacer()
                }
            } else {
                // Confirmed state
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Added to Calendar")
                        .font(.subheadline)
                        .foregroundColor(.green)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(event.isUpcoming ? Color.orange : Color.clear, lineWidth: 2)
        )
        .alert("Calendar Error", isPresented: $showError) {
            Button("Settings", action: openSettings)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }
    
    // MARK: - Actions
    
    private func confirmEvent() {
        isConfirming = true
        
        Task {
            do {
                try await addToCalendar()
                await MainActor.run {
                    isConfirmed = true
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
    
    private func openSettings() {
        if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsURL)
        }
    }
}

// MARK: - Calendar Error

enum CalendarError: LocalizedError {
    case accessDenied
    
    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Calendar access denied. Please enable in Settings > MessageAI > Calendars to add events."
        }
    }
}

// MARK: - Preview

struct CalendarCardView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // High confidence, upcoming event
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
            
            // Low confidence, all-day event
            CalendarCardView(
                event: CalendarEvent(
                    id: "2",
                    title: "School half day",
                    date: "2025-10-25",
                    time: nil,
                    isAllDay: true,
                    location: nil,
                    notes: nil,
                    confidence: 0.65,
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

**Checkpoint:** CalendarCardView complete (~200 lines) ✓

**Build Test:**
- [ ] Build project (Cmd+B)
- [ ] Should compile without errors
- [ ] View SwiftUI preview in canvas (Cmd+Opt+Return)

**Commit:**
```bash
git add messAI/Views/Chat/CalendarCardView.swift
git commit -m "feat(pr15): Add CalendarCardView with EventKit integration"
```

---

## Phase 5: ChatViewModel Integration (30 minutes)

### 5.1: Add Calendar Processing Methods (25 minutes)

#### Open Existing File
- [ ] Open `ViewModels/ChatViewModel.swift`

#### Add State Properties
- [ ] Add state property to class:
  ```swift
  @Published var isProcessingAI: Bool = false
  ```

#### Add Calendar Extraction Method
- [ ] Add method to class:
  ```swift
  // MARK: - Calendar Extraction (PR#15)
  
  /// Process a message for calendar extraction
  @MainActor
  func extractCalendarEvents(for messageId: String) async {
      guard let index = messages.firstIndex(where: { $0.id == messageId }) else {
          print("Message not found: \(messageId)")
          return
      }
      
      // Prevent double-processing
      if messages[index].aiMetadata?.calendarEvents != nil {
          print("Message already has calendar events")
          return
      }
      
      isProcessingAI = true
      
      do {
          // Call AI service
          let events = try await aiService.extractCalendarEvents(messageId: messageId)
          
          print("Extracted \(events.count) calendar event(s)")
          
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
          
          // Firestore will be updated via Cloud Function's update
          // Real-time listener will sync the change back
          
      } catch {
          // Show error to user
          print("Calendar extraction error: \(error)")
          errorMessage = "Failed to extract calendar events: \(error.localizedDescription)"
          showError = true
      }
      
      isProcessingAI = false
  }
  
  /// Confirm calendar event and mark as added
  @MainActor
  func confirmCalendarEvent(messageId: String, eventId: String) async {
      guard let messageIndex = messages.firstIndex(where: { $0.id == messageId }),
            let eventIndex = messages[messageIndex].aiMetadata?.calendarEvents?.firstIndex(where: { $0.id == eventId }) else {
          return
      }
      
      // Mark event as confirmed in local state
      // (In future, could save to Firestore to track user engagement)
      print("Calendar event confirmed: \(eventId)")
  }
  
  /// Dismiss calendar event card
  @MainActor
  func dismissCalendarEvent(messageId: String, eventId: String) async {
      guard let messageIndex = messages.firstIndex(where: { $0.id == messageId }) else {
          return
      }
      
      // Remove event from local state
      messages[messageIndex].aiMetadata?.calendarEvents?.removeAll { $0.id == eventId }
      
      print("Calendar event dismissed: \(eventId)")
  }
  ```

**Checkpoint:** ChatViewModel calendar methods complete ✓

**Build Test:**
- [ ] Build project (Cmd+B)
- [ ] Should compile without errors

**Commit:**
```bash
git add messAI/ViewModels/ChatViewModel.swift
git commit -m "feat(pr15): Add calendar extraction methods to ChatViewModel"
```

---

## Phase 6: ChatView UI Integration (30 minutes)

### 6.1: Display Calendar Cards in ChatView (20 minutes)

#### Open Existing File
- [ ] Open `Views/Chat/ChatView.swift`

#### Update Message Display
- [ ] Modify message loop to include calendar cards:
  ```swift
  // Inside ForEach(viewModel.messages)
  ForEach(viewModel.messages) { message in
      VStack(alignment: message.senderId == currentUserId ? .trailing : .leading, spacing: 8) {
          // Message bubble (existing from PR#9)
          MessageBubbleView(
              message: message,
              currentUserId: currentUserId
          )
          
          // Calendar cards (NEW!)
          if let events = message.aiMetadata?.calendarEvents, !events.isEmpty {
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
                          Task {
                              await viewModel.dismissCalendarEvent(
                                  messageId: message.id,
                                  eventId: event.id
                              )
                          }
                      }
                  )
                  .padding(.horizontal, message.senderId == currentUserId ? 60 : 0)
                  .transition(.scale.combined(with: .opacity))
              }
          }
      }
      .id(message.id)
  }
  ```

**Checkpoint:** Calendar cards display in ChatView ✓

**Build Test:**
- [ ] Build project (Cmd+B)
- [ ] Should compile without errors

**Commit:**
```bash
git add messAI/Views/Chat/ChatView.swift
git commit -m "feat(pr15): Display calendar cards in ChatView"
```

---

### 6.2: Add Context Menu for Manual Extraction (10 minutes)

#### Add Context Menu
- [ ] Add context menu to MessageBubbleView tap gesture:
  ```swift
  // In ChatView, add .contextMenu to message bubble
  MessageBubbleView(message: message, currentUserId: currentUserId)
      .contextMenu {
          // Extract calendar events
          Button {
              Task {
                  await viewModel.extractCalendarEvents(for: message.id)
              }
          } label: {
              Label("Extract Calendar Events", systemImage: "calendar.badge.plus")
          }
          .disabled(viewModel.isProcessingAI)
          
          // Copy text (existing functionality if you have it)
          Button {
              UIPasteboard.general.string = message.text
          } label: {
              Label("Copy Text", systemImage: "doc.on.doc")
          }
      }
  ```

**Checkpoint:** Context menu for extraction complete ✓

**Build Test:**
- [ ] Build project (Cmd+B)
- [ ] Run on simulator (Cmd+R)
- [ ] Long-press message → "Extract Calendar Events" appears

**Commit:**
```bash
git add messAI/Views/Chat/ChatView.swift
git commit -m "feat(pr15): Add context menu for manual calendar extraction"
```

---

## Phase 7: Testing & Verification (45 minutes)

### 7.1: Unit Tests (10 minutes)

#### Test CalendarEvent Model
- [ ] Test date parsing:
  ```swift
  // In a test file (or manually verify)
  let event = CalendarEvent(
      id: "test",
      title: "Soccer practice",
      date: "2025-10-24",
      time: "16:00",
      isAllDay: false,
      location: nil,
      notes: nil,
      confidence: 0.95,
      extractedAt: Date()
  )
  
  // Verify computed properties
  print(event.displayDate)  // Should show formatted date
  print(event.isPast)  // Should be false
  print(event.isUpcoming)  // Depends on current date
  ```

---

### 7.2: Integration Tests (35 minutes)

#### Test 1: Extract Explicit Date/Time (5 minutes)
- [ ] Run app on simulator
- [ ] Login as test user
- [ ] Open a conversation
- [ ] Send message: "Soccer practice Thursday at 4pm"
- [ ] Long-press message → "Extract Calendar Events"
- [ ] Wait 2-3 seconds for AI processing
- [ ] Verify calendar card appears with:
  - ✅ Title: "Soccer practice"
  - ✅ Date: Next Thursday's date
  - ✅ Time: 4:00 PM
  - ✅ High confidence indicator (>0.9)

#### Test 2: Extract All-Day Event (5 minutes)
- [ ] Send message: "School half day Friday"
- [ ] Extract events
- [ ] Verify calendar card shows:
  - ✅ Title: "School half day"
  - ✅ Date: Next Friday
  - ✅ isAllDay: true (no time shown)
  - ✅ Medium confidence (~0.8)

#### Test 3: Extract with Location (5 minutes)
- [ ] Send message: "Piano recital at community center 6pm Saturday"
- [ ] Extract events
- [ ] Verify calendar card shows:
  - ✅ Title: "Piano recital"
  - ✅ Location: "community center"
  - ✅ Date/Time: Saturday 6pm
  - ✅ Location icon and text displayed

#### Test 4: Add to iOS Calendar (10 minutes)
- [ ] Extract event from message
- [ ] Tap "Add to Calendar" button
- [ ] Grant calendar permission if prompted
- [ ] Verify:
  - ✅ Permission dialog appears (first time only)
  - ✅ Button shows loading spinner
  - ✅ Card changes to "Added to Calendar" state
  - ✅ Open iOS Calendar app → event is there

#### Test 5: Past Event Handling (5 minutes)
- [ ] Send message: "Yesterday's meeting was great"
- [ ] Extract events
- [ ] Verify calendar card shows:
  - ✅ Event displayed but grayed out
  - ✅ "This event is in the past" warning
  - ✅ No "Add to Calendar" button

#### Test 6: Low Confidence Warning (5 minutes)
- [ ] Send message: "Let's meet sometime next week"
- [ ] Extract events
- [ ] Verify calendar card shows:
  - ✅ Low confidence warning icon (questionmark or triangle)
  - ✅ "Low confidence" label visible
  - ✅ Event still extractable but marked as uncertain

**Checkpoint:** All integration tests pass ✓

---

### 7.3: Edge Case Tests (Optional, 15 minutes if time)

#### Test: No Events in Message
- [ ] Send: "How are you doing?"
- [ ] Extract events
- [ ] Verify: No calendar cards appear (empty array)

#### Test: Multiple Events in One Message
- [ ] Send: "Meeting at 2pm, then dinner at 7pm"
- [ ] Extract events
- [ ] Verify: Two separate calendar cards appear

#### Test: Context-Dependent Extraction
- [ ] Send multiple messages building context:
  - Message 1: "We should meet next week"
  - Message 2: "How about Thursday?"
  - Message 3: "4pm works for me"
- [ ] Extract from Message 3 (with context enabled)
- [ ] Verify: Event extracted as "Thursday at 4pm"

**Checkpoint:** All tests complete! ✓

---

## Phase 8: Documentation & Deployment (15 minutes)

### 8.1: Update Documentation

#### Update Memory Bank
- [ ] Open `memory-bank/activeContext.md`
- [ ] Add to "What Just Happened" section:
  ```markdown
  ### ✅ Just Completed: PR #15 - Calendar Extraction Feature 🎉
  
  **Completion Date**: [Today's date]
  **Time Taken**: X hours (3-4 hours estimated)
  **Status**: COMPLETE
  
  **What Was Built**:
  - Cloud Function: calendarExtraction.ts with GPT-4 integration
  - iOS Model: CalendarEvent with EventKit conversion
  - iOS Service: AIService.extractCalendarEvents() method
  - SwiftUI: CalendarCardView with confirmation flow
  - ChatViewModel: extraction + confirmation methods
  - ChatView: calendar card display + context menu
  
  **Key Achievements**:
  - First AI feature visible to users!
  - Calendar events extracted from natural language
  - One-tap confirmation to add to iOS Calendar
  - Handles explicit dates, relative dates, all-day events
  - Visual confidence indicators
  - Past event warnings
  ```

#### Update PR_PARTY README
- [ ] Open `PR_PARTY/README.md`
- [ ] Mark PR#15 as complete:
  ```markdown
  ### PR #15: Calendar Extraction Feature
  **Status**: ✅ COMPLETE
  **Timeline**: X hours actual (3-4 hours estimated)
  **Completed**: [Today's date]
  
  **Summary**: First AI feature! Auto-detects dates, times, events in messages using GPT-4. Displays calendar cards with one-tap confirmation to add to iOS Calendar. Handles explicit dates, relative dates, all-day events, and shows confidence indicators.
  ```

---

### 8.2: Final Commit & Push

#### Commit All Changes
- [ ] Stage all changes:
  ```bash
  git add -A
  ```

- [ ] Create final commit:
  ```bash
  git commit -m "feat(pr15): Complete calendar extraction feature

  - Add calendarExtraction.ts Cloud Function with GPT-4
  - Create CalendarEvent model with EventKit integration
  - Implement AIService.extractCalendarEvents() method
  - Build CalendarCardView with confirmation flow
  - Integrate calendar cards in ChatView
  - Add context menu for manual extraction
  - Update memory bank and documentation
  
  Time: X hours
  Status: All tests passing, ready for use!"
  ```

- [ ] Push to GitHub:
  ```bash
  git push origin feature/pr15-calendar-extraction
  ```

---

### 8.3: Merge to Main (if tests pass)

#### Final Verification
- [ ] All tests passed above
- [ ] Build successful (0 errors, 0 warnings)
- [ ] Calendar extraction works end-to-end
- [ ] iOS Calendar integration works
- [ ] Cloud Functions deployed

#### Merge
- [ ] Checkout main:
  ```bash
  git checkout main
  git pull origin main
  ```

- [ ] Merge feature branch:
  ```bash
  git merge feature/pr15-calendar-extraction
  ```

- [ ] Push to GitHub:
  ```bash
  git push origin main
  ```

- [ ] Delete feature branch (optional):
  ```bash
  git branch -d feature/pr15-calendar-extraction
  git push origin --delete feature/pr15-calendar-extraction
  ```

**Checkpoint:** PR#15 COMPLETE! 🎉📅

---

## Celebration! 🎉

**You've just built the FIRST AI feature for MessageAI!**

### What You Accomplished
- ✅ GPT-4 integration for natural language date/time extraction
- ✅ Structured calendar data with confidence scoring
- ✅ Beautiful SwiftUI calendar cards
- ✅ One-tap iOS Calendar integration
- ✅ Context-aware extraction (conversation history)
- ✅ Past event handling and confidence warnings
- ✅ Production-ready Cloud Functions deployment

### What's Next
- **PR#16:** Decision Summarization (group decisions & action items)
- **PR#17:** Priority Highlighting (urgent/important detection)
- **PR#18:** RSVP Tracking (yes/no/maybe responses)
- **PR#19:** Deadline Extraction (deadline detection & tracking)
- **PR#20:** Multi-Step Event Planning Agent (advanced!) **+10 bonus!**

### Success Metrics Achieved
- ⏱️ Extraction time: <2 seconds
- 🎯 Accuracy: >90% on explicit dates
- 💰 Cost: ~$0.02 per extraction
- 🎨 UX: Beautiful, intuitive calendar cards
- ✅ Quality: Zero critical bugs

---

**Take a moment to appreciate what you've built! This is a genuine AI-powered feature that saves busy parents time every day.** 💪📅✨

---

*Checklist complete! Ready to implement PR#16 next.*

