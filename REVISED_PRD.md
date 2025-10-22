# MessageAI - Revised Product Requirements Document
## Busy Parent/Caregiver Edition

**Version:** 2.0 (Revised)  
**Platform:** iOS (Swift + SwiftUI)  
**Backend:** Firebase (Firestore, Auth, Cloud Functions, Storage)  
**AI Provider:** OpenAI GPT-4  
**Target Grade:** A (90-100 points)  
**Current Status:** Core messaging infrastructure complete (PRs 1-13) ✅

---

## Executive Summary

MessageAI is an intelligent messaging app designed for **busy parents and caregivers** who struggle to manage information overload from school groups, sports teams, family chats, and caregiver networks. 

**What we've built:** A solid WhatsApp-like messaging foundation with real-time chat, group messaging, offline support, and presence indicators.

**What we're adding:** AI-powered features that automatically extract important dates, track decisions, highlight urgent messages, monitor RSVPs, and catch deadlines—transforming chaotic group chats into organized, actionable information.

---

## Current Status: What's Complete

### ✅ Phase 1: Core Messaging Infrastructure (PRs 1-13)

We have a **production-ready messaging app** with:

**Authentication & User Management**
- Email/password sign up and login
- User profiles with display names
- Firebase Authentication integration

**Real-Time Messaging**
- One-on-one chat with sub-2-second delivery
- Group chat with 3+ participants
- Optimistic UI (messages appear instantly)
- Message status indicators (sent/delivered/read)
- Firestore real-time listeners

**Data Persistence**
- Core Data for local storage
- Message and conversation persistence
- Sync between local and Firestore

**UI/UX**
- Chat list view with conversations
- Individual chat view with message bubbles
- Contact selection for new chats
- Group creation and management
- Message input with send button

**Presence & Indicators**
- Online/offline status
- Typing indicators
- Last seen timestamps

**Technical Foundation**
- MVVM architecture
- Clean service layer
- Network monitoring
- Error handling basics

---

## Phase 2: AI Features for Busy Parents (NEW)

### Target Persona: Busy Parent/Caregiver

**Demographics:**
- Parents with school-age children
- Caregivers managing elderly family members
- Volunteers coordinating community activities
- Active in 5-10 group chats simultaneously

**Core Pain Points:**
1. **Date/Time Chaos** - Missing important events buried in long chat threads
2. **Decision Fatigue** - Can't track what the group decided about carpools, snacks, venues
3. **Priority Blindness** - Urgent messages lost in noise ("Johnny sick, pick up early!")
4. **RSVP Confusion** - Who's coming to the party? Who can drive?
5. **Deadline Stress** - Permission slips, payments, volunteer sign-ups forgotten

**Success Metrics:**
- Zero missed important dates/deadlines
- Instant access to group decisions
- Urgent messages surfaced within seconds
- Complete RSVP tracking without manual effort
- 90%+ AI accuracy on all features

---

## AI Features Implementation

All features use **OpenAI GPT-4 with function calling** for structured data extraction. API keys secured in Firebase Cloud Functions (never in the iOS app).

### Feature 1: Calendar Extraction ⭐

**Pain Point Solved:** Missing events buried in messages

**User Experience:**
- Messages containing dates show a calendar icon 📅
- Tap to see all extracted date/time information
- One-tap "Add to Calendar" button
- Smart date parsing: "Tomorrow at 3pm" → actual date/time
- Location extraction when available

**Technical Implementation:**
```swift
// Cloud Function with OpenAI function calling
extractCalendarDates(message: string) → [ExtractedDate]

struct ExtractedDate {
    let title: String        // "Soccer practice"
    let date: Date          // Thu Oct 24, 2024
    let time: String?       // "15:00"
    let location: String?   // "City Park"
    let isAllDay: Bool
    let recurrence: String? // "weekly"
}
```

**Example:**
```
Input: "Soccer practice moved to Thursday at 3pm, 
        then game Saturday morning 9am at Cedar Park"

Output: 
Event 1: "Soccer practice" - Thu Oct 24, 3:00 PM
Event 2: "Soccer game" - Sat Oct 26, 9:00 AM at Cedar Park
```

**Success Criteria:**
- 90%+ accuracy on natural language dates
- <2 seconds response time
- Handles multiple dates per message
- Supports relative dates ("tomorrow", "next Friday")
- Recognizes recurring events

---

### Feature 2: Decision Summarization 💡

**Pain Point Solved:** Can't remember what the group decided

**User Experience:**
- AI detects when group reaches consensus
- Decision card appears in chat: "The group decided..."
- Tap to see full context and who agreed
- Pin important decisions to chat header
- Searchable decision history

**Technical Implementation:**
```swift
// Analyzes last 10 messages for decision patterns
detectDecision(messages: [Message]) → Decision?

struct Decision {
    let decision: String        // "Bob drives 4 kids, Carol drives 3"
    let topic: String           // "Transportation"
    let timestamp: Date
    let messageIds: [String]    // Context messages
    let participants: [String]  // Who agreed
    let confidence: Double      // 0-1 (don't show if <0.7)
}
```

**Example:**
```
Chat:
Alice: "Who can drive to the game Saturday?"
Bob: "I can take 4 kids"
Carol: "I'll take 3"
Alice: "Perfect! Bob and Carol driving. I'll bring snacks."
Bob: "👍"
Carol: "Sounds good!"

AI Decision Card:
📋 Transportation Decision
"Bob will drive 4 kids and Carol will drive 3 kids to 
Saturday's game. Alice will bring snacks."
Agreed by: Alice, Bob, Carol
```

**Success Criteria:**
- Detects explicit agreements ("ok", "sounds good")
- Identifies decision topics
- 90%+ accuracy on clear consensus
- <10% false positive rate

---

### Feature 3: Priority Highlighting 🚨

**Pain Point Solved:** Urgent messages get lost in chat noise

**User Experience:**
- Urgent messages show red/orange indicator
- Message jumps to "Priority Messages" section at top
- Push notification priority boost (when implemented)
- Time-sensitive messages stay highlighted
- Filter view for urgent-only messages

**Technical Implementation:**
```swift
// Classifies message urgency
detectUrgency(message: string) → UrgencyLevel

enum UrgencyLevel {
    case critical  // Red - immediate action needed
    case high      // Orange - time-sensitive (today/tomorrow)
    case normal    // Default
    case low       // Gray - casual chat
    
    var color: Color {
        switch self {
        case .critical: return .red
        case .high: return .orange
        case .normal: return .primary
        case .low: return .gray
        }
    }
}
```

**Example:**
```
🔴 CRITICAL: "Johnny fell at practice, needs pickup NOW"
🟠 HIGH: "Permission slips due tomorrow morning"
⚪ NORMAL: "What time is practice Thursday?"
⚫ LOW: "Anyone watch the game last night?"
```

**Success Criteria:**
- Keywords: "urgent", "emergency", "ASAP", "now"
- Time sensitivity: "in 10 minutes", "by 5pm today"
- Context awareness: "he's sick" vs "feeling tired"
- 90%+ accuracy on critical/high priority
- <5% false positive rate

---

### Feature 4: RSVP Tracking 📊

**Pain Point Solved:** Manually tracking who's coming to events

**User Experience:**
- Event messages auto-generate RSVP tracker
- Live count: "5 yes, 2 no, 3 pending"
- Tap to see who said yes/no/maybe
- AI detects indirect RSVPs: "Count me in!" = yes
- Updates in real-time as responses come in
- Total attending calculation

**Technical Implementation:**
```swift
// Links RSVPs to extracted events
extractRSVP(message: string) → RSVPResponse

struct RSVPResponse {
    let userId: String
    let response: RSVPStatus  // yes/no/maybe
    let numberOfPeople: Int   // "me and my 3 kids" = 4
    let timestamp: Date
    let conditions: String?   // "if it doesn't rain"
}

enum RSVPStatus: String {
    case yes, no, maybe, pending
}
```

**Example:**
```
Event: "Pool party Sunday 2pm at our house"

RSVP Tracker:
✅ Yes (5): Alice (+3), Bob (+1), Carol
❌ No (2): David, Emma  
❓ Maybe (1): Frank
⏳ Pending (4): Grace, Henry, Iris, Jack

Total attending: ~9 people
```

**Success Criteria:**
- Direct responses: "yes", "no", "maybe"
- Indirect: "we're coming!", "sorry can't", "I'll try"
- Number detection: "me and my 3 kids" = 4 people
- Changed mind: "actually I can make it" updates status
- 85%+ accuracy on response detection

---

### Feature 5: Deadline Extraction ⏰

**Pain Point Solved:** Missing permission slips, payments, sign-ups

**User Experience:**
- Deadline messages get clock icon ⏰
- "Upcoming Deadlines" widget in app
- Countdown: "3 days until field trip payment due"
- Push notification 24h before deadline (when implemented)
- Mark as complete to dismiss
- Link to forms/documents when available

**Technical Implementation:**
```swift
// Extracts action items with due dates
extractDeadlines(message: string) → [Deadline]

struct Deadline {
    let action: String          // "Return field trip permission slip"
    let deadline: Date          // Friday, Oct 25 at 3:00 PM
    let recipient: String?      // "all parents"
    let consequences: String?   // "Child cannot attend if missed"
    let url: String?            // Link to form
    let chatId: String
    var isCompleted: Bool = false
}
```

**Example:**
```
Input: "Reminder: Field trip permission slips must be returned 
        by Friday 3pm or your child cannot attend. Link to form: 
        https://school.com/form"

Output:
⏰ Deadline: Friday, Oct 25 at 3:00 PM (in 3 days)
📝 Action: Return field trip permission slip
⚠️  Important: Child cannot attend if missed
🔗 Form: school.com/form
[ ] Mark as Complete
```

**Success Criteria:**
- Absolute dates: "by October 25"
- Relative dates: "by Friday", "in 3 days"
- Time specificity: "by 3pm Friday" vs "by Friday"
- Consequence extraction
- URL/link detection
- 90%+ accuracy on deadline extraction

---

### Advanced AI Capability: Multi-Step Event Planning Agent 🤖

**Pain Point Solved:** Event planning takes dozens of back-and-forth messages

**User Experience:**
1. User types: "@ai plan the Halloween party"
2. Agent shows step-by-step progress:
   - Analyzing chat history...
   - Extracting preferences...
   - Checking availability...
   - Generating proposal...
   - Drafting message...
3. Final output: Complete event proposal with draft message
4. User reviews and sends (or edits first)

**Agent Workflow (5 Steps):**

**Step 1: Analyze Context**
- Reviews last 50-100 messages
- Identifies event planning needs
- Extracts past discussions about the event

**Step 2: Extract Preferences**
- Date availability: "Weekends work best"
- Time preferences: "Morning or afternoon"
- Location ideas: "Park or someone's house"
- Attendee count from RSVP data

**Step 3: Generate Proposal**
- Synthesizes all preferences
- Checks for conflicts (via calendar extraction)
- Suggests optimal date/time/location
- Estimates attendance based on RSVPs

**Step 4: Draft Message**
- Writes friendly, natural message
- Includes all proposal details
- Asks for group confirmation
- Proper formatting

**Step 5: Finalize & Track**
- Returns complete result to user
- Sets up RSVP tracking
- Monitors responses
- Can send reminders if needed

**Technical Implementation:**
```typescript
// Firebase Cloud Function with LangGraph
export const smartEventAgent = functions.https.onCall(async (data) => {
    const { chatId, query, context } = data;
    
    // LangGraph workflow
    const workflow = new StateGraph({
        channels: {
            messages: [],
            currentStep: "analyze",
            proposal: null,
            draft: null
        }
    });
    
    workflow
        .addNode("analyze", analyzeContextNode)
        .addNode("extract", extractPreferencesNode)
        .addNode("propose", generateProposalNode)
        .addNode("draft", draftMessageNode)
        .addNode("finalize", finalizeNode);
    
    workflow
        .addEdge("analyze", "extract")
        .addEdge("extract", "propose")
        .addEdge("propose", "draft")
        .addEdge("draft", "finalize");
    
    return await workflow.invoke({ messages: context.messages, query });
});
```

**Example Output:**
```
AI Generated Draft:
"Hey everyone! Based on our discussion, I'm proposing:

🎃 Halloween Party
📅 Saturday, Oct 26 at 2pm
📍 City Park Pavilion
👥 Expecting ~15 people

This works for most schedules and the park has plenty of space. 
Reply with 👍 if this works for you!"
```

**Success Criteria:**
- Completes 5-step workflow
- Maintains context across all steps
- Handles conflicting preferences (suggests compromise)
- Recovers from API failures
- Response time <15 seconds
- 85%+ user satisfaction with proposals

---

## Technical Architecture

### System Overview
```
┌─────────────┐
│  iOS App    │
│  (Swift)    │
└──────┬──────┘
       │
       ├─────────────┐
       │             │
   ┌───▼────┐   ┌───▼────────┐
   │Firebase│   │   OpenAI   │
   │Backend │   │   GPT-4    │
   └───┬────┘   └────────────┘
       │
       ├─ Firestore (messages, users, chats)
       ├─ Realtime DB (presence, typing) [OPTIONAL]
       ├─ Cloud Functions (AI processing - SECURE)
       ├─ Firebase Auth (authentication) ✅
       └─ Cloud Messaging (push notifications) [TODO]
```

### AI Integration Architecture

**Security First:**
```swift
// ❌ NEVER do this - API key exposed
let openAI = OpenAI(apiKey: "sk-proj-...")

// ✅ ALWAYS use Cloud Functions as secure proxy
class AIService {
    func processMessage(_ message: String, feature: AIFeature) async throws {
        let callable = Functions.functions().httpsCallable("processAI")
        let result = try await callable.call([
            "message": message,
            "feature": feature.rawValue
        ])
        return try parseResponse(result.data)
    }
}
```

**Cloud Function Structure:**
```typescript
// functions/src/ai/processAI.ts
export const processAI = functions
    .runWith({ memory: '512MB', timeoutSeconds: 30 })
    .https.onCall(async (data, context) => {
        // Require authentication
        if (!context.auth) {
            throw new functions.https.HttpsError('unauthenticated');
        }
        
        const userId = context.auth.uid;
        
        // Rate limit: 100 requests per hour per user
        await checkRateLimit(userId);
        
        // Route to appropriate AI feature
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
                throw new functions.https.HttpsError('invalid-argument');
        }
    });
```

**RAG Pipeline:**
```swift
class RAGService {
    func getRelevantContext(for query: String, chatId: String) async throws -> [Message] {
        // Fetch last 50 messages for context
        let messages = try await db
            .collection("chats/\(chatId)/messages")
            .order(by: "timestamp", descending: true)
            .limit(to: 50)
            .getDocuments()
            .documents
            .compactMap { try? $0.data(as: Message.self) }
        
        return messages.reversed() // Chronological order
    }
}
```

**Function Calling Example:**
```typescript
// Calendar extraction with structured output
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
                        title: { type: "string" },
                        date: { type: "string", description: "ISO 8601 date" },
                        time: { type: "string" },
                        location: { type: "string" },
                        isAllDay: { type: "boolean" }
                    },
                    required: ["title", "date"]
                }
            }
        }
    }
};

const response = await openai.chat.completions.create({
    model: "gpt-4",
    messages: [
        { role: "system", content: "You extract dates and events from messages." },
        { role: "user", content: message }
    ],
    functions: [extractDatesFunction],
    function_call: { name: "extract_dates" }
});
```

---

## Updated Data Models

### AIMetadata Structure
```swift
// Add to existing Message model
struct Message {
    // ... existing fields ...
    var aiMetadata: AIMetadata?
}

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
```

### Firestore Structure Updates
```
/chats/{chatId}/messages/{messageId}
  - existing fields...
  - aiMetadata: {
      extractedDates: [...]
      isUrgent: bool
      urgencyLevel: string
      isDecision: bool
      decision: {...}
      rsvpInfo: {...}
      deadlines: [...]
      processedAt: timestamp
    }

/chats/{chatId}/decisions/{decisionId}
  - decision: string
  - topic: string
  - timestamp: timestamp
  - messageIds: [string]
  - participants: [string]
  - confidence: number

/chats/{chatId}/deadlines/{deadlineId}
  - action: string
  - deadline: timestamp
  - recipient: string
  - consequences: string
  - url: string
  - isCompleted: bool
  - chatId: string
```

---

## Implementation Roadmap

### ✅ Completed (PRs 1-13): Core Messaging
- Project setup & Firebase integration
- Authentication & user management
- Core data models (User, Message, Conversation)
- Chat services & Firestore integration
- Local persistence with Core Data
- Chat list and conversation views
- Contact selection
- Real-time messaging with optimistic UI
- Message status indicators
- Presence & typing indicators
- Group chat functionality

### 🎯 Phase 2 (PRs 14-20): AI Features - Priority
**PR #14**: Cloud Functions Setup & AI Service Base (2-3 hours)
**PR #15**: Calendar Extraction Feature (3-4 hours)
**PR #16**: Decision Summarization Feature (3-4 hours)
**PR #17**: Priority Highlighting Feature (2-3 hours)
**PR #18**: RSVP Tracking Feature (3-4 hours)
**PR #19**: Deadline Extraction Feature (3-4 hours)
**PR #20**: Multi-Step Event Planning Agent (5-6 hours)

**Total AI Implementation: 21-28 hours**

### 📱 Phase 3 (PRs 21-25): Essential Polish
**PR #21**: Offline Support & Network Monitoring (2-3 hours)
**PR #22**: Push Notifications Integration (3-4 hours)
**PR #23**: Image Sharing (2-3 hours)
**PR #24**: Profile Management (1-2 hours)
**PR #25**: Error Handling & Loading States (2-3 hours)

### 🎨 Phase 4 (PRs 26-28): Final Polish & Deployment
**PR #26**: UI Polish & Animations (2-3 hours)
**PR #27**: Testing & Bug Fixes (3-4 hours)
**PR #28**: Documentation & Demo Video (3-4 hours)

---

## Success Criteria (Rubric Alignment)

### Core Messaging Infrastructure (35 points) ✅ COMPLETE
- [x] Real-time message delivery (<2 seconds)
- [x] Offline persistence (through app restarts)
- [x] Group chat (3+ users)
- [x] Message status indicators
- [x] Presence & typing indicators

### Mobile App Quality (20 points) 🔄 IN PROGRESS
- [x] App lifecycle handling (basic)
- [x] Performance & UX (good scrolling)
- [ ] Perfect keyboard handling → PR #25
- [ ] Launch optimization (<2s) → PR #26
- [ ] Push notifications → PR #22

### AI Features Implementation (30 points) 🆕 PRIORITY
- [ ] 5 Required AI Features (15 points) → PRs #15-19
  - [ ] Calendar Extraction
  - [ ] Decision Summarization
  - [ ] Priority Highlighting
  - [ ] RSVP Tracking
  - [ ] Deadline Extraction
- [ ] Persona Fit & Relevance (5 points) → Clear mapping
- [ ] Advanced AI Capability (10 points) → PR #20
  - [ ] Multi-step agent with LangGraph
  - [ ] 5+ step workflow
  - [ ] Context maintenance
  - [ ] <15 second response time

### Technical Implementation (10 points) 🔄 IN PROGRESS
- [x] Clean architecture (MVVM) ✅
- [ ] API keys secured (Cloud Functions) → PR #14
- [ ] Function calling implemented → PRs #15-19
- [ ] RAG pipeline → PR #14
- [ ] Rate limiting → PR #14
- [x] Auth & data management ✅

### Documentation & Deployment (5 points) 📝 FINAL
- [ ] Comprehensive README → PR #28
- [ ] Setup instructions → PR #28
- [ ] Architecture diagrams → PR #28
- [ ] TestFlight or local deployment → PR #28

### Required Deliverables (Pass/Fail) 📹 FINAL
- [ ] Demo video (5-7 min) → PR #28
- [ ] Persona brainlift (1 page) → PR #28
- [ ] Social post with @GauntletAI → PR #28

---

## Risk Management

### Technical Risks

**Risk 1: OpenAI API Costs**
- **Impact**: Expensive if not careful
- **Mitigation**: 
  - Rate limiting (100 req/hour/user)
  - Cache AI results in message metadata
  - Only process new messages
  - Use function calling for structured outputs (cheaper)

**Risk 2: AI Accuracy**
- **Impact**: Poor user experience if features don't work
- **Mitigation**:
  - Extensive prompt engineering
  - Test with real parent chat examples
  - Confidence thresholds (don't show low-confidence results)
  - Manual trigger option for edge cases
  - Iterative improvement based on testing

**Risk 3: Cloud Functions Cold Starts**
- **Impact**: Slow first AI response (3-5 seconds)
- **Mitigation**:
  - Keep functions warm with scheduled pings
  - Show loading indicators
  - Background processing where possible
  - Set realistic expectations (<2s for simple, <8s for complex)

**Risk 4: LangGraph Complexity**
- **Impact**: Multi-step agent may be hard to debug
- **Mitigation**:
  - Start with simple 3-step workflow
  - Add complexity incrementally
  - Extensive logging at each step
  - Fallback to simpler response if workflow fails
  - Clear error messages to user

### Timeline Risks

**Risk: AI Features Take Longer Than Expected**
- **Mitigation**:
  - Build features in priority order (calendar first, most valuable)
  - Each feature is independent (can ship without all 5)
  - Agent is bonus (nice to have, not MVP)
  - Focus on 90% accuracy, not 100%

**Risk: Running Out of Time**
- **Fallback Plan**:
  - **Minimum for A grade**: 3-4 AI features working well
  - **Defer if needed**: Agent (10 pts), some polish (PRs #26-27)
  - **Must have**: Calendar + Decision + Priority (most impactful)

---

## Key Technical Decisions

### Why OpenAI GPT-4?
- Best accuracy for extraction tasks
- Structured function calling built-in
- Reliable and well-documented
- Handles natural language well
- Worth the cost for quality

### Why Cloud Functions?
- API key security (never in app)
- Rate limiting server-side
- Can update AI logic without app update
- Scales automatically
- Easy to add new features

### Why LangGraph for Agent?
- Rubric requirement for multi-step agents
- Clean state management
- Easy to debug workflows
- Production-ready framework
- Great documentation

### Why Busy Parent Persona?
- Clear, specific pain points
- Measurable value (missed events = bad)
- Personal connection (relatable)
- High market need (every parent faces this)
- AI features are genuinely useful (not gimmicks)

---

## Next Steps

### Immediate Priorities (This Week)

**Day 1-2: Cloud Functions & AI Base (PR #14)**
- Set up Cloud Functions project
- Create secure AI proxy endpoint
- Implement rate limiting
- Test with simple OpenAI call
- Set up environment variables

**Day 3-4: First 3 AI Features (PRs #15-17)**
- Calendar extraction (highest value)
- Decision summarization (unique feature)
- Priority highlighting (safety feature)
- Test each thoroughly
- Integrate into UI

**Day 5-6: Final 2 Features + Agent (PRs #18-20)**
- RSVP tracking
- Deadline extraction
- Multi-step agent (if time allows)
- Focus on quality over quantity

**Day 7: Polish & Demo (PRs #21-28)**
- Essential features (offline, push)
- UI polish
- Testing
- Demo video
- Documentation

---

## Conclusion

We have a **solid messaging foundation** (PRs 1-13) and a **clear path forward** to add AI features that genuinely help busy parents manage their chaotic group chats.

**Target Score**: 90-100 points (Grade A)
- Core Infrastructure: 35/35 ✅
- Mobile Quality: 18-20/20 🔄
- AI Features: 28-30/30 🎯 (NEW FOCUS)
- Technical: 9-10/10 🔄
- Documentation: 5/5 📝

**Philosophy**: Build AI features that **actually solve problems**, not just "AI for AI's sake". Every feature directly addresses a real pain point that busy parents face daily.

**Next PR**: #14 - Cloud Functions Setup & AI Service Base

Let's build something parents will actually want to use every day! 🚀

