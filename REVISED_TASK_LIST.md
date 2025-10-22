# MessageAI - Revised Task List & PR Breakdown
## Busy Parent/Caregiver Edition

**Version:** 2.0 (Revised)  
**Current Status:** Core Messaging Complete (PRs 1-13) ✅  
**Next Phase:** AI Features Implementation (PRs 14-20) 🎯  
**Target Grade:** A (90-100 points)

---

## Progress Overview

### ✅ Phase 1: Core Messaging Infrastructure (COMPLETE)
**PRs 1-13 | ~30 hours | 100% Complete**

- [x] Project Setup & Firebase Configuration
- [x] Authentication (Models, Services, UI)
- [x] Core Data Models
- [x] Chat Service & Firestore Integration
- [x] Local Persistence (Core Data)
- [x] Chat List View
- [x] Contact Selection & New Chat
- [x] Chat View - UI Components
- [x] Real-Time Messaging & Optimistic UI
- [x] Message Status Indicators
- [x] Presence & Typing Indicators
- [x] Group Chat Functionality

**What We Have:**
- Production-ready messaging app
- Real-time chat (sub-2-second delivery)
- Group chat (3+ users)
- Offline persistence
- Message status indicators
- Presence & typing indicators
- Clean MVVM architecture

---

### 🎯 Phase 2: AI Features (PRIORITY)
**PRs 14-20 | ~21-28 hours | 0% Complete**

This is our **main focus** - implementing AI features for busy parents.

- [ ] PR #14: Cloud Functions Setup & AI Service Base (2-3 hrs)
- [ ] PR #15: Calendar Extraction Feature (3-4 hrs)
- [ ] PR #16: Decision Summarization Feature (3-4 hrs)
- [ ] PR #17: Priority Highlighting Feature (2-3 hrs)
- [ ] PR #18: RSVP Tracking Feature (3-4 hrs)
- [ ] PR #19: Deadline Extraction Feature (3-4 hrs)
- [ ] PR #20: Multi-Step Event Planning Agent (5-6 hrs)

**Value Delivered:**
- 5 AI features solving real parent pain points
- Advanced multi-step agent (10 bonus points)
- 30 points toward final grade

---

### 📱 Phase 3: Essential Polish
**PRs 21-25 | ~10-15 hours | 0% Complete**

Features needed to complete the app but **secondary to AI**.

- [ ] PR #21: Offline Support & Network Monitoring (2-3 hrs)
- [ ] PR #22: Push Notifications Integration (3-4 hrs)
- [ ] PR #23: Image Sharing (2-3 hrs)
- [ ] PR #24: Profile Management (1-2 hrs)
- [ ] PR #25: Error Handling & Loading States (2-3 hrs)

---

### 🎨 Phase 4: Final Polish & Deployment
**PRs 26-28 | ~8-11 hours | 0% Complete**

Final touches and submission requirements.

- [ ] PR #26: UI Polish & Animations (2-3 hrs)
- [ ] PR #27: Testing & Bug Fixes (3-4 hrs)
- [ ] PR #28: Documentation & Demo Video (3-4 hrs)

---

## Completed PRs (Phase 1) ✅

### PR #1: Project Setup & Firebase Configuration ✅
**Completed** | 1.5 hours actual

**What Was Built:**
- Xcode project created
- Firebase project configured
- Authentication, Firestore, Storage enabled
- GoogleService-Info.plist added
- Basic file structure created
- Constants file added
- README created

**Files:**
- `MessageAIApp.swift`
- `GoogleService-Info.plist`
- `Utilities/Constants.swift`
- `README.md`

---

### PR #2: Authentication - Models & Services ✅
**Completed** | 2.5 hours actual

**What Was Built:**
- User model with Firestore codable
- AuthService (signup, login, logout)
- FirebaseService base class
- AuthViewModel with state management
- Error handling for auth

**Files:**
- `Models/User.swift`
- `Services/AuthService.swift`
- `Services/FirebaseService.swift`
- `ViewModels/AuthViewModel.swift`

---

### PR #3: Authentication - UI Views ✅
**Completed** | 2 hours actual

**What Was Built:**
- Login screen
- Sign up screen
- Profile setup screen
- Form validation
- Navigation flow

**Files:**
- `Views/Auth/LoginView.swift`
- `Views/Auth/SignUpView.swift`
- `Views/Auth/ProfileSetupView.swift`

---

### PR #4: Core Models & Data Structure ✅
**Completed** | 1.5 hours actual

**What Was Built:**
- Message model
- Conversation model
- MessageStatus enum
- TypingStatus model
- Codable conformance

**Files:**
- `Models/Message.swift`
- `Models/Conversation.swift`
- `Models/MessageStatus.swift`
- `Models/TypingStatus.swift`

---

### PR #5: Chat Service & Firestore Integration ✅
**Completed** | 2.5 hours actual

**What Was Built:**
- ChatService for message operations
- Firestore listeners for real-time updates
- Send/receive message methods
- Conversation creation
- Error handling

**Files:**
- `Services/ChatService.swift`

---

### PR #6: Local Persistence with Core Data ✅
**Completed** | 3 hours actual

**What Was Built:**
- Core Data model (MessageEntity, ConversationEntity)
- PersistenceController
- LocalDataManager for CRUD
- SyncManager for Firestore ↔ Core Data sync
- Message queue for offline

**Files:**
- `Persistence/MessageEntity.swift`
- `Persistence/ConversationEntity.swift`
- `Persistence/PersistenceController.swift`
- `Persistence/LocalDataManager.swift`
- `Persistence/SyncManager.swift`
- `MessageAI.xcdatamodeld`

---

### PR #7: Chat List View ✅
**Completed** | 2 hours actual

**What Was Built:**
- ChatListView with conversation rows
- Search functionality
- Last message preview
- Timestamp display
- Unread count badges
- Pull to refresh

**Files:**
- `Views/Chat/ChatListView.swift`
- `Views/Chat/ConversationRowView.swift`
- `ViewModels/ChatListViewModel.swift`

---

### PR #8: Contact Selection & New Chat ✅
**Completed** | 2 hours actual

**What Was Built:**
- Contacts list view
- User search
- Contact selection
- Start new conversation
- Navigation to chat

**Files:**
- `Views/Contacts/ContactsListView.swift`
- `Views/Contacts/ContactRowView.swift`
- `ViewModels/ContactsViewModel.swift`

---

### PR #9: Chat View - UI Components ✅
**Completed** | 3 hours actual

**What Was Built:**
- ChatView with message list
- MessageBubbleView (sender/receiver styles)
- MessageInputView with text field
- Scroll to bottom
- Keyboard handling

**Files:**
- `Views/Chat/ChatView.swift`
- `Views/Chat/MessageBubbleView.swift`
- `Views/Chat/MessageInputView.swift`

---

### PR #10: Real-Time Messaging & Optimistic UI ✅
**Completed** | 3 hours actual

**What Was Built:**
- Real-time Firestore listeners
- Optimistic UI (instant message display)
- Send message with local-first approach
- Message deduplication
- Connection state handling

**Files:**
- `ViewModels/ChatViewModel.swift` (enhanced)
- `Services/ChatService.swift` (enhanced)

---

### PR #11: Message Status Indicators ✅
**Completed** | 2 hours actual

**What Was Built:**
- Message status tracking (sent/delivered/read)
- Checkmark indicators in UI
- Read receipt updates
- Status color coding

**Files:**
- `Models/MessageStatus.swift` (enhanced)
- `Views/Chat/MessageBubbleView.swift` (enhanced)

---

### PR #12: Presence & Typing Indicators ✅
**Completed** | 2.5 hours actual

**What Was Built:**
- PresenceService for online/offline status
- Typing indicator detection
- TypingIndicatorView component
- Real-time presence updates
- Last seen timestamps

**Files:**
- `Services/PresenceService.swift`
- `Services/TypingService.swift`
- `Views/Chat/TypingIndicatorView.swift`

---

### PR #13: Group Chat Functionality ✅
**Completed** | 3 hours actual

**What Was Built:**
- Group chat creation flow
- Participant selection (multi-select)
- Group info view
- Member list display
- Message attribution for groups

**Files:**
- `Views/Group/NewGroupView.swift`
- `Views/Group/GroupInfoView.swift`
- `Views/Group/ParticipantSelectionView.swift`
- `ViewModels/GroupViewModel.swift`

---

## AI Features PRs (Phase 2) 🎯

### PR #14: Cloud Functions Setup & AI Service Base
**Branch**: `feature/ai-infrastructure`  
**Goal**: Set up secure AI processing infrastructure  
**Estimated Time**: 2-3 hours  
**Priority**: 🔴 CRITICAL - Everything depends on this

#### Tasks:

**1. Initialize Cloud Functions Project (30 min)**
- [ ] Navigate to project root
- [ ] Run `firebase init functions`
  - Choose TypeScript
  - Install dependencies
  - Set up ESLint
- [ ] Create `functions/.env` for API keys
- [ ] Add `.env` to `.gitignore`
- [ ] Install additional packages:
  ```bash
  cd functions
  npm install openai@^4.0.0
  npm install @langchain/langgraph
  ```

**2. Set Up Environment Variables (15 min)**
- [ ] Get OpenAI API key from platform.openai.com
- [ ] Create `functions/.env`:
  ```env
  OPENAI_API_KEY=sk-proj-your-key-here
  OPENAI_MODEL=gpt-4
  RATE_LIMIT_PER_HOUR=100
  ```
- [ ] Set environment config in Firebase:
  ```bash
  firebase functions:config:set openai.key="sk-proj-..."
  ```

**3. Create Base AI Cloud Function (45 min)**
- [ ] **File**: `functions/src/ai/processAI.ts`
- [ ] Create main function with authentication check
- [ ] Implement rate limiting (100 req/hour/user)
- [ ] Add request validation
- [ ] Create feature router (calendar, decision, urgency, rsvp, deadline)
- [ ] Add error handling
- [ ] Add logging for debugging

**Code Template**:
```typescript
import * as functions from 'firebase-functions';
import OpenAI from 'openai';

const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY
});

export const processAI = functions
  .runWith({ 
    memory: '512MB',
    timeoutSeconds: 30 
  })
  .https.onCall(async (data, context) => {
    // 1. Require authentication
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'Must be authenticated'
      );
    }
    
    const userId = context.auth.uid;
    
    // 2. Rate limiting
    const rateLimitKey = `rateLimit:${userId}:${Math.floor(Date.now() / 3600000)}`;
    // ... implement rate limit check ...
    
    // 3. Route to appropriate feature
    switch (data.feature) {
      case 'calendar':
        return await extractCalendarDates(data.message);
      case 'decision':
        return await detectDecision(data.messages);
      case 'urgency':
        return await detectUrgency(data.message);
      case 'rsvp':
        return await extractRSVP(data.message);
      case 'deadline':
        return await extractDeadlines(data.message);
      default:
        throw new functions.https.HttpsError('invalid-argument', 'Unknown feature');
    }
  });

// Placeholder functions (implement in next PRs)
async function extractCalendarDates(message: string) {
  // TODO: PR #15
  return { events: [] };
}

async function detectDecision(messages: any[]) {
  // TODO: PR #16
  return { hasDecision: false };
}

async function detectUrgency(message: string) {
  // TODO: PR #17
  return { urgencyLevel: 'normal' };
}

async function extractRSVP(message: string) {
  // TODO: PR #18
  return { response: 'pending' };
}

async function extractDeadlines(message: string) {
  // TODO: PR #19
  return { deadlines: [] };
}
```

**4. Create iOS AIService (45 min)**
- [ ] **File**: `Services/AIService.swift`
- [ ] Create service class
- [ ] Add enum for AI features
- [ ] Implement function to call Cloud Function
- [ ] Add response parsing
- [ ] Add error handling
- [ ] Add loading states

**Code Template**:
```swift
import Foundation
import FirebaseFunctions

enum AIFeature: String {
    case calendar
    case decision
    case urgency
    case rsvp
    case deadline
    case agent
}

struct AIResponse: Codable {
    // Feature-specific response structures
}

class AIService {
    static let shared = AIService()
    private let functions = Functions.functions()
    
    func processMessage(
        _ message: String,
        feature: AIFeature,
        context: [Message]? = nil
    ) async throws -> AIResponse {
        let callable = functions.httpsCallable("processAI")
        
        let data: [String: Any] = [
            "message": message,
            "feature": feature.rawValue,
            "context": context?.map { $0.toDictionary() } ?? []
        ]
        
        do {
            let result = try await callable.call(data)
            guard let resultData = result.data as? [String: Any] else {
                throw AIError.invalidResponse
            }
            
            return try parseResponse(resultData, for: feature)
        } catch {
            throw AIError.from(error)
        }
    }
    
    private func parseResponse(_ data: [String: Any], for feature: AIFeature) throws -> AIResponse {
        // Parse based on feature type
        // TODO: Implement in feature PRs
        return AIResponse()
    }
}

enum AIError: Error {
    case unauthenticated
    case rateLimitExceeded
    case invalidResponse
    case networkError
    case serverError(String)
    
    static func from(_ error: Error) -> AIError {
        // Convert Firebase errors to AIError
        return .serverError(error.localizedDescription)
    }
}
```

**5. Deploy and Test (15 min)**
- [ ] Deploy Cloud Functions:
  ```bash
  firebase deploy --only functions
  ```
- [ ] Test from iOS app with dummy call
- [ ] Verify authentication requirement
- [ ] Verify rate limiting works
- [ ] Check Firebase Console for logs

**6. Update Models for AI (15 min)**
- [ ] **File**: `Models/AIMetadata.swift` (NEW)
- [ ] Create AIMetadata struct
- [ ] Add to Message model
- [ ] Update Firestore schema

```swift
struct AIMetadata: Codable {
    var extractedDates: [ExtractedDate]?
    var isUrgent: Bool?
    var urgencyLevel: UrgencyLevel?
    var isDecision: Bool?
    var decision: Decision?
    var rsvpInfo: RSVPResponse?
    var deadlines: [Deadline]?
    var processedAt: Date
}

// Update Message model
struct Message {
    // ... existing properties ...
    var aiMetadata: AIMetadata?
}
```

**Files Created/Modified:**
- `functions/src/ai/processAI.ts` ➕
- `functions/package.json` ✏️
- `functions/.env` ➕ (NOT in git)
- `Services/AIService.swift` ➕
- `Models/AIMetadata.swift` ➕
- `Models/Message.swift` ✏️

**Testing Checklist:**
- [ ] Cloud Function deploys successfully
- [ ] Can call function from iOS app
- [ ] Authentication is required
- [ ] Rate limiting works (try 101 calls)
- [ ] Error messages are user-friendly

**Success Criteria:**
- ✅ Cloud Functions deployed and callable
- ✅ API keys secured (never in iOS app)
- ✅ Rate limiting functional
- ✅ Base infrastructure ready for AI features

---

### PR #15: Calendar Extraction Feature ⭐
**Branch**: `feature/calendar-extraction`  
**Goal**: Automatically detect and extract dates/times from messages  
**Estimated Time**: 3-4 hours  
**Priority**: 🔴 CRITICAL - Highest value feature

#### Tasks:

**1. Implement OpenAI Function Calling (60 min)**
- [ ] **File**: `functions/src/ai/calendarExtraction.ts`
- [ ] Define function schema for date extraction
- [ ] Create system prompt for calendar context
- [ ] Implement extractCalendarDates function
- [ ] Handle multiple dates per message
- [ ] Parse ISO 8601 dates
- [ ] Extract time, location, recurrence

**Code Template**:
```typescript
const extractDatesFunction = {
  name: "extract_dates",
  description: "Extract all dates, times, and events from a message",
  parameters: {
    type: "object",
    properties: {
      events: {
        type: "array",
        items: {
          type: "object",
          properties: {
            title: { type: "string", description: "Event name" },
            date: { type: "string", description: "ISO 8601 date" },
            time: { type: "string", description: "Time in HH:MM format" },
            location: { type: "string", description: "Location if mentioned" },
            isAllDay: { type: "boolean" },
            recurrence: { type: "string", description: "weekly, monthly, etc." }
          },
          required: ["title", "date"]
        }
      }
    },
    required: ["events"]
  }
};

export async function extractCalendarDates(message: string) {
  try {
    const response = await openai.chat.completions.create({
      model: "gpt-4",
      messages: [
        {
          role: "system",
          content: `You extract dates and events from casual messages. 
                   Parse natural language dates like "tomorrow", "next Friday".
                   Current date: ${new Date().toISOString()}`
        },
        {
          role: "user",
          content: message
        }
      ],
      functions: [extractDatesFunction],
      function_call: { name: "extract_dates" }
    });
    
    const functionCall = response.choices[0].message.function_call;
    if (functionCall && functionCall.arguments) {
      return JSON.parse(functionCall.arguments);
    }
    
    return { events: [] };
  } catch (error) {
    console.error('Calendar extraction error:', error);
    throw new functions.https.HttpsError('internal', 'Failed to extract dates');
  }
}
```

**2. Create iOS Model (30 min)**
- [ ] **File**: `Models/ExtractedDate.swift`
- [ ] Define ExtractedDate struct
- [ ] Add Codable conformance
- [ ] Add date formatting utilities
- [ ] Add display properties

```swift
struct ExtractedDate: Codable, Identifiable {
    let id: String
    let title: String
    let date: Date
    let time: String?
    let location: String?
    let isAllDay: Bool
    let recurrence: String?
    let sourceMessageId: String
    
    var displayDate: String {
        // "Thu Oct 24, 3:00 PM" or "Tomorrow at 3pm"
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = time != nil ? .short : .none
        return formatter.string(from: date)
    }
    
    var isUpcoming: Bool {
        date > Date()
    }
}
```

**3. Update AIService (15 min)**
- [ ] **File**: `Services/AIService.swift`
- [ ] Add parseCalendarResponse method
- [ ] Convert dates from ISO 8601
- [ ] Handle parsing errors

**4. Create Calendar UI Component (60 min)**
- [ ] **File**: `Views/AI/DateExtractionCard.swift`
- [ ] Display extracted dates
- [ ] Show event details (title, date, time, location)
- [ ] "Add to Calendar" button
- [ ] Loading state
- [ ] Error state

```swift
struct DateExtractionCard: View {
    let dates: [ExtractedDate]
    @State private var isAddingToCalendar = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(.blue)
                Text("Events Detected")
                    .font(.headline)
                Spacer()
            }
            
            ForEach(dates) { date in
                VStack(alignment: .leading, spacing: 4) {
                    Text(date.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    HStack {
                        Image(systemName: "clock")
                            .font(.caption)
                        Text(date.displayDate)
                            .font(.caption)
                    }
                    
                    if let location = date.location {
                        HStack {
                            Image(systemName: "location")
                                .font(.caption)
                            Text(location)
                                .font(.caption)
                        }
                    }
                    
                    Button {
                        addToCalendar(date)
                    } label: {
                        Label("Add to Calendar", systemImage: "plus.circle")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.vertical, 4)
                
                if date != dates.last {
                    Divider()
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    private func addToCalendar(_ date: ExtractedDate) {
        // Use EventKit to add to iOS Calendar
        // TODO: Implement
    }
}
```

**5. Integrate into ChatView (30 min)**
- [ ] **File**: `Views/Chat/MessageBubbleView.swift`
- [ ] Add calendar icon for messages with dates
- [ ] Show DateExtractionCard when tapped
- [ ] Add calendar processing indicator

**6. Add EventKit Integration (30 min)**
- [ ] **File**: `Services/CalendarService.swift` (NEW)
- [ ] Request calendar permissions
- [ ] Create EKEvent from ExtractedDate
- [ ] Add to user's default calendar
- [ ] Handle permission denied

```swift
import EventKit

class CalendarService {
    static let shared = CalendarService()
    private let eventStore = EKEventStore()
    
    func requestAccess() async throws -> Bool {
        if #available(iOS 17.0, *) {
            return try await eventStore.requestFullAccessToEvents()
        } else {
            return try await eventStore.requestAccess(to: .event)
        }
    }
    
    func addEvent(_ extractedDate: ExtractedDate) async throws {
        let hasAccess = try await requestAccess()
        guard hasAccess else {
            throw CalendarError.permissionDenied
        }
        
        let event = EKEvent(eventStore: eventStore)
        event.title = extractedDate.title
        event.startDate = extractedDate.date
        event.endDate = extractedDate.date.addingTimeInterval(3600) // 1 hour default
        event.isAllDay = extractedDate.isAllDay
        event.location = extractedDate.location
        event.calendar = eventStore.defaultCalendarForNewEvents
        
        // Handle recurrence
        if let recurrence = extractedDate.recurrence {
            event.addRecurrenceRule(makeRecurrenceRule(from: recurrence))
        }
        
        try eventStore.save(event, span: .thisEvent)
    }
    
    private func makeRecurrenceRule(from: String) -> EKRecurrenceRule? {
        // Parse recurrence string (weekly, monthly, etc.)
        // TODO: Implement
        return nil
    }
}

enum CalendarError: Error {
    case permissionDenied
    case failedToSave
}
```

**7. Testing (30 min)**
- [ ] Test with various date formats:
  - "Tomorrow at 3pm"
  - "Next Friday 2:30 PM"
  - "October 24th at 3:00pm"
  - "Every Tuesday at 4pm"
  - "Halloween party Oct 31"
- [ ] Test multiple dates in one message
- [ ] Test with locations
- [ ] Test Add to Calendar flow
- [ ] Test permissions handling

**Files Created/Modified:**
- `functions/src/ai/calendarExtraction.ts` ➕
- `Models/ExtractedDate.swift` ➕
- `Services/CalendarService.swift` ➕
- `Services/AIService.swift` ✏️
- `Views/AI/DateExtractionCard.swift` ➕
- `Views/Chat/MessageBubbleView.swift` ✏️

**Testing Checklist:**
- [ ] Natural language dates work (90%+ accuracy)
- [ ] Multiple dates detected correctly
- [ ] Times parsed correctly (AM/PM)
- [ ] Locations extracted when mentioned
- [ ] Add to Calendar works
- [ ] Permissions handled gracefully
- [ ] Response time <2 seconds

**Success Criteria:**
- ✅ 90%+ accuracy on common date formats
- ✅ UI is intuitive and fast
- ✅ Calendar integration works
- ✅ Handles edge cases gracefully

---

### PR #16: Decision Summarization Feature 💡
**Branch**: `feature/decision-summarization`  
**Goal**: Automatically detect and summarize group decisions  
**Estimated Time**: 3-4 hours  
**Priority**: 🟡 HIGH - Unique and valuable

#### Tasks:

**1. Implement Decision Detection (60 min)**
- [ ] **File**: `functions/src/ai/decisionDetection.ts`
- [ ] Create function schema
- [ ] Analyze message thread for consensus
- [ ] Extract decision text
- [ ] Identify participants
- [ ] Calculate confidence score

**2. Create iOS Models (30 min)**
- [ ] **File**: `Models/Decision.swift`
- [ ] Define Decision struct
- [ ] Add confidence threshold constant
- [ ] Store in Firestore subcollection

**3. Build Decision UI (60 min)**
- [ ] **File**: `Views/AI/DecisionCard.swift`
- [ ] Display decision text
- [ ] Show participants who agreed
- [ ] Pin/unpin functionality
- [ ] View context messages

**4. Integrate into ChatView (30 min)**
- [ ] Trigger decision analysis after group messages
- [ ] Show decision cards in timeline
- [ ] Add to pinned section

**5. Testing (30 min)**
- [ ] Test explicit agreements
- [ ] Test implicit consensus
- [ ] Test confidence scoring
- [ ] Test multiple decisions

**Files Created/Modified:**
- `functions/src/ai/decisionDetection.ts` ➕
- `Models/Decision.swift` ➕
- `Views/AI/DecisionCard.swift` ➕
- `ViewModels/ChatViewModel.swift` ✏️

---

### PR #17: Priority Highlighting Feature 🚨
**Branch**: `feature/priority-highlighting`  
**Goal**: Surface urgent messages automatically  
**Estimated Time**: 2-3 hours  
**Priority**: 🟡 HIGH - Safety feature

#### Tasks:

**1. Implement Urgency Detection (45 min)**
- [ ] **File**: `functions/src/ai/urgencyDetection.ts`
- [ ] Create urgency classifier
- [ ] Keywords: "urgent", "emergency", "ASAP", "now"
- [ ] Context analysis for time sensitivity
- [ ] Return urgency level + reason

**2. Create iOS Model (15 min)**
- [ ] **File**: `Models/UrgencyLevel.swift`
- [ ] Define UrgencyLevel enum
- [ ] Add color coding
- [ ] Add icon mapping

**3. Update Message UI (45 min)**
- [ ] **File**: `Views/Chat/MessageBubbleView.swift`
- [ ] Add urgency indicator (colored border/badge)
- [ ] Show urgency level icon
- [ ] Highlight critical messages

**4. Create Priority Section (45 min)**
- [ ] **File**: `Views/Chat/PriorityMessagesView.swift`
- [ ] Filter for urgent messages
- [ ] Show at top of chat list
- [ ] Dismiss functionality

**5. Testing (15 min)**
- [ ] Test urgency keywords
- [ ] Test time-sensitive phrases
- [ ] Test false positive rate

**Files Created/Modified:**
- `functions/src/ai/urgencyDetection.ts` ➕
- `Models/UrgencyLevel.swift` ➕
- `Views/AI/PriorityMessagesView.swift` ➕
- `Views/Chat/MessageBubbleView.swift` ✏️

---

### PR #18: RSVP Tracking Feature 📊
**Branch**: `feature/rsvp-tracking`  
**Goal**: Automatically track who's coming to events  
**Estimated Time**: 3-4 hours  
**Priority**: 🟡 HIGH - Very practical

#### Tasks:

**1. Implement RSVP Extraction (60 min)**
- [ ] **File**: `functions/src/ai/rsvpExtraction.ts`
- [ ] Detect yes/no/maybe responses
- [ ] Handle indirect responses ("count me in")
- [ ] Extract number of people
- [ ] Link to extracted events

**2. Create iOS Models (30 min)**
- [ ] **File**: `Models/RSVPResponse.swift`
- [ ] Define RSVPResponse struct
- [ ] RSVPStatus enum
- [ ] Link to ExtractedDate

**3. Build RSVP Tracker UI (60 min)**
- [ ] **File**: `Views/AI/RSVPTrackerCard.swift`
- [ ] Live count display
- [ ] List responders by category
- [ ] Total attending calculation
- [ ] Update in real-time

**4. Integrate with Calendar Feature (30 min)**
- [ ] Link RSVPs to extracted dates
- [ ] Show tracker when event detected
- [ ] Update as responses come in

**5. Testing (30 min)**
- [ ] Test direct responses
- [ ] Test indirect phrasing
- [ ] Test number extraction
- [ ] Test changed responses

**Files Created/Modified:**
- `functions/src/ai/rsvpExtraction.ts` ➕
- `Models/RSVPResponse.swift` ➕
- `Views/AI/RSVPTrackerCard.swift` ➕

---

### PR #19: Deadline Extraction Feature ⏰
**Branch**: `feature/deadline-extraction`  
**Goal**: Never miss permission slips, payments, sign-ups  
**Estimated Time**: 3-4 hours  
**Priority**: 🟡 HIGH - High anxiety reducer

#### Tasks:

**1. Implement Deadline Detection (60 min)**
- [ ] **File**: `functions/src/ai/deadlineExtraction.ts`
- [ ] Extract action items
- [ ] Parse due dates (absolute & relative)
- [ ] Extract consequences
- [ ] Find URLs/links

**2. Create iOS Models (30 min)**
- [ ] **File**: `Models/Deadline.swift`
- [ ] Define Deadline struct
- [ ] Completion tracking
- [ ] Store in Firestore

**3. Build Deadline UI (60 min)**
- [ ] **File**: `Views/AI/DeadlineCard.swift`
- [ ] Countdown display
- [ ] Action description
- [ ] Mark complete button
- [ ] Link button

**4. Create Deadlines Dashboard (45 min)**
- [ ] **File**: `Views/AI/DeadlinesListView.swift`
- [ ] All upcoming deadlines
- [ ] Sort by date
- [ ] Filter by chat

**5. Testing (15 min)**
- [ ] Test various date formats
- [ ] Test with amounts/fees
- [ ] Test URL extraction

**Files Created/Modified:**
- `functions/src/ai/deadlineExtraction.ts` ➕
- `Models/Deadline.swift` ➕
- `Views/AI/DeadlineCard.swift` ➕
- `Views/AI/DeadlinesListView.swift` ➕

---

### PR #20: Multi-Step Event Planning Agent 🤖
**Branch**: `feature/event-planning-agent`  
**Goal**: Autonomous workflow for event coordination  
**Estimated Time**: 5-6 hours  
**Priority**: 🟠 MEDIUM - Bonus points (10 pts)

#### Tasks:

**1. Set Up LangGraph (60 min)**
- [ ] Install LangGraph in Cloud Functions
- [ ] Create state graph structure
- [ ] Define workflow nodes
- [ ] Configure node connections

**2. Implement Agent Nodes (120 min)**
- [ ] **Node 1**: Analyze Context (gather requirements)
- [ ] **Node 2**: Extract Preferences (dates, times, locations)
- [ ] **Node 3**: Generate Proposal (synthesize info)
- [ ] **Node 4**: Draft Message (write friendly proposal)
- [ ] **Node 5**: Finalize (return result)

**3. Create iOS Agent Service (45 min)**
- [ ] **File**: `Services/EventPlanningAgent.swift`
- [ ] Trigger agent workflow
- [ ] Display step progress
- [ ] Handle agent response

**4. Build Agent UI (60 min)**
- [ ] **File**: `Views/AI/EventAgentView.swift`
- [ ] "@ai plan [event]" trigger
- [ ] Step-by-step animation
- [ ] Result card
- [ ] Send draft button

**5. Testing (45 min)**
- [ ] Test simple events
- [ ] Test complex constraints
- [ ] Test edge cases
- [ ] Performance (<15s)

**Files Created/Modified:**
- `functions/src/ai/eventPlanningAgent.ts` ➕
- `Services/EventPlanningAgent.swift` ➕
- `Views/AI/EventAgentView.swift` ➕

---

## Essential Polish PRs (Phase 3) 📱

### PR #21: Offline Support & Network Monitoring
**Branch**: `feature/offline-support`  
**Goal**: Robust offline message handling  
**Estimated Time**: 2-3 hours

#### Tasks:
- [ ] Enable Firestore offline persistence
- [ ] Implement message queue for offline sends
- [ ] Add NetworkMonitor service
- [ ] Build connection status UI banner
- [ ] Auto-sync on reconnection
- [ ] Test offline scenarios

---

### PR #22: Push Notifications Integration
**Branch**: `feature/push-notifications`  
**Goal**: Receive notifications for new messages  
**Estimated Time**: 3-4 hours

#### Tasks:
- [ ] Configure Firebase Cloud Messaging
- [ ] Set up APNs certificates
- [ ] Implement notification handling
- [ ] Create Cloud Function to send notifications
- [ ] Add notification customization
- [ ] Test foreground/background notifications

---

### PR #23: Image Sharing
**Branch**: `feature/image-sharing`  
**Goal**: Send and receive images in chat  
**Estimated Time**: 2-3 hours

#### Tasks:
- [ ] Integrate UIImagePickerController
- [ ] Implement image compression
- [ ] Upload to Firebase Storage
- [ ] Display images in message bubbles
- [ ] Full-screen image viewer
- [ ] Test upload/download

---

### PR #24: Profile Management
**Branch**: `feature/profile-management`  
**Goal**: View and edit user profile  
**Estimated Time**: 1-2 hours

#### Tasks:
- [ ] Build ProfileView
- [ ] Build EditProfileView
- [ ] Upload profile picture
- [ ] Update display name
- [ ] Test profile updates

---

### PR #25: Error Handling & Loading States
**Branch**: `feature/error-handling`  
**Goal**: Comprehensive error handling  
**Estimated Time**: 2-3 hours

#### Tasks:
- [ ] Add loading indicators
- [ ] Create error message toast
- [ ] Implement retry mechanisms
- [ ] Add empty states
- [ ] Handle edge cases
- [ ] Test error scenarios

---

## Final Polish PRs (Phase 4) 🎨

### PR #26: UI Polish & Animations
**Branch**: `feature/ui-polish`  
**Goal**: Smooth animations and beautiful UI  
**Estimated Time**: 2-3 hours

#### Tasks:
- [ ] Add message send animations
- [ ] Add page transitions
- [ ] Implement haptic feedback
- [ ] Dark mode support
- [ ] Accessibility improvements
- [ ] Performance optimization

---

### PR #27: Testing & Bug Fixes
**Branch**: `bugfix/final-testing`  
**Goal**: Test all features and fix bugs  
**Estimated Time**: 3-4 hours

#### Tasks:
- [ ] Test all AI features
- [ ] Test offline scenarios
- [ ] Test group chat with 3+ users
- [ ] Test app lifecycle
- [ ] Fix critical bugs
- [ ] Performance testing

---

### PR #28: Documentation & Demo Video
**Branch**: `docs/final-docs`  
**Goal**: Complete submission requirements  
**Estimated Time**: 3-4 hours

#### Tasks:

**Documentation (90 min)**
- [ ] Update README with AI features
- [ ] Add setup instructions
- [ ] Document AI architecture
- [ ] Add screenshots
- [ ] Create architecture diagrams

**Demo Video (90 min)**
- [ ] Write script (5-7 minutes)
- [ ] Prepare demo environment (2 devices)
- [ ] Record:
  - Real-time messaging (1 min)
  - Group chat (1 min)
  - Offline scenario (1 min)
  - App lifecycle (45 sec)
  - All 5 AI features (3 min)
  - Advanced agent (1 min)
  - Technical architecture (30 sec)
- [ ] Edit video
- [ ] Upload to YouTube

**Persona Brainlift (30 min)**
- [ ] Write 1-page document
- [ ] Persona justification
- [ ] Pain points addressed
- [ ] Feature → problem mapping
- [ ] Technical decisions
- [ ] Convert to PDF

**Social Post (15 min)**
- [ ] Write LinkedIn post
- [ ] Write X/Twitter post
- [ ] Include demo video link
- [ ] Include GitHub link
- [ ] Tag @GauntletAI
- [ ] Post

---

## Quick Reference: What's Done, What's Next

### ✅ We Have (PRs 1-13):
- Solid messaging foundation
- Real-time chat
- Group messaging
- Local persistence
- Status indicators
- Presence & typing
- Clean architecture

### 🎯 Priority Next (PRs 14-20):
- Cloud Functions & AI base
- 5 AI features for busy parents
- Multi-step agent (bonus)
- **This is where we get 30 points**

### 📱 After AI (PRs 21-25):
- Offline support
- Push notifications
- Image sharing
- Profile management
- Error handling

### 🎨 Final Polish (PRs 26-28):
- UI animations
- Testing
- Documentation
- Demo video

---

## Time Budget

### Already Spent: ~30 hours (Phase 1) ✅

### Remaining Estimates:
- **Phase 2 (AI)**: 21-28 hours 🎯
- **Phase 3 (Polish)**: 10-15 hours 📱
- **Phase 4 (Final)**: 8-11 hours 🎨

### Total Project: ~69-84 hours

**Realistic Timeline**: 1-2 weeks for AI features + polish

---

## Success Metrics

### Rubric Alignment:
- Core Messaging: 35/35 ✅ (COMPLETE)
- Mobile Quality: 18-20/20 🔄 (Good, can improve)
- AI Features: 28-30/30 🎯 (MAIN FOCUS)
- Technical: 9-10/10 🔄 (Need Cloud Functions)
- Documentation: 5/5 📝 (Final PR)

**Target Score: 95-100/100** ⭐

---

## Next Steps

**Immediate Priorities:**
1. PR #14: Cloud Functions Setup (START HERE)
2. PR #15: Calendar Extraction (HIGHEST VALUE)
3. PR #16: Decision Summarization
4. Continue through AI features
5. Polish and deploy

**Success Strategy:**
- Focus on AI features first (30 points)
- Quality over quantity (90% accuracy)
- Test each feature thoroughly
- Keep code clean and documented
- Build for real parent use cases

---

## Notes

**Development Tips:**
- Test AI features with real parent chat examples
- Iterate on prompts for better accuracy
- Cache AI results to avoid repeat processing
- Show loading states for AI calls
- Handle errors gracefully

**Time Management:**
- Each AI feature is independent
- Can ship with 3-4 features if time is tight
- Agent is bonus (nice to have)
- Focus on accuracy over speed

**Quality Checklist:**
- 90%+ AI accuracy on each feature
- <2s response time for simple features
- <15s for agent workflow
- Clean, intuitive UI
- Error handling everywhere
- Documentation complete

---

**Let's build AI features that actually help busy parents! 🚀**

**Next PR: #14 - Cloud Functions Setup & AI Service Base**

