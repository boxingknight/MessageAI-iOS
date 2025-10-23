# PR#19: Deadline Extraction Feature - AI-Powered Deadline Detection

**Estimated Time**: 3-4 hours  
**Complexity**: MEDIUM-HIGH  
**Priority**: 🔴 CRITICAL - 5th of 5 required AI features  
**Dependencies**: PR#14 (Cloud Functions) ✅ COMPLETE, PR#15 (Calendar Extraction) ✅ COMPLETE  
**Status**: 📋 PLANNED (Documentation complete, ready to implement!)

---

## Overview

### What We're Building

AI-powered deadline detection and tracking that automatically extracts deadlines from messages using GPT-4 and displays them in an organized timeline. When users receive messages like "Permission slip due Wednesday" or "RSVP by Friday 5pm", the AI extracts the deadline and adds it to a visual deadline tracker.

**User Story**: Sarah (busy parent) is in a school parent group. She receives 50+ messages per day with various deadlines scattered throughout: "Field trip forms due Monday", "Bake sale signup closes Thursday", "Registration deadline Friday 5pm". Instead of manually tracking these in a separate app, MessageAI automatically detects and organizes all deadlines into a chronological list with visual indicators for urgency.

### Why It Matters

**The Problem**: 
- Deadlines get buried in long group chat threads
- Parents miss important deadlines (permission slips, registrations, RSVPs)
- Manual deadline tracking is tedious (write down, set reminder, etc.)
- No central view of all upcoming deadlines across conversations

**The Solution**: 
- Automatic deadline extraction from any message
- Visual deadline timeline (upcoming, today, overdue)
- In-chat deadline cards with countdown ("3 days remaining")
- Global deadline view across all conversations
- Push notification reminders (optional, PR#22)

**Impact**: Saves 10-15 minutes/day + prevents missed deadlines (real-world consequences: late fees, missed opportunities, embarrassment)

### Success in One Sentence

"This PR is successful when Sarah can see all her upcoming deadlines at a glance and never misses an important deadline buried in group chat."

---

## Technical Design

### Architecture Decisions

#### Decision 1: Detection Approach

**Options Considered**:
1. **Keyword filter only** (fast, free, simple)
2. **Pure GPT-4 detection** (accurate, expensive, slow)
3. **Hybrid: Keyword → GPT-4** (balanced)

**Chosen**: **Hybrid approach (keyword filter → GPT-4 function calling)**

**Rationale**:
- **Performance**: Keyword filter screens 70-80% of messages in <100ms
- **Cost**: Only call GPT-4 for messages with deadline keywords (~$0.003/detection vs ~$0.01 pure GPT-4)
- **Accuracy**: GPT-4 handles complex dates ("next Friday", "end of month"), keyword filter catches obvious ones
- **Scalability**: Can process 100+ messages/day per user without budget concerns

**Trade-offs**:
- **Gain**: 70% cost savings, <100ms response for most messages, high accuracy
- **Lose**: Slightly more complex logic, potential false negatives if keywords evolve

**Keyword Patterns**:
```typescript
const DEADLINE_KEYWORDS = [
  'due', 'deadline', 'by', 'before', 'closes', 'ends', 
  'submit', 'turn in', 'expires', 'last day', 'final day',
  'no later than', 'cut-off', 'must', 'need to', 'has to'
];

const DATE_PATTERNS = [
  /\b(monday|tuesday|wednesday|thursday|friday|saturday|sunday)\b/i,
  /\b(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\s+\d{1,2}/i,
  /\b\d{1,2}\/\d{1,2}\b/, // MM/DD or DD/MM
  /\b(today|tomorrow|tonight|this week|next week|this month)\b/i
];
```

---

#### Decision 2: Data Model

**Options Considered**:
1. **Embedded in message.aiMetadata** (simple, no extra reads)
2. **Separate /deadlines collection** (queryable, sortable)
3. **Hybrid: Both** (redundant but flexible)

**Chosen**: **Separate /deadlines collection with conversation reference**

**Rationale**:
- **Querying**: Need to query all deadlines across conversations, sort by date
- **Performance**: Can fetch upcoming deadlines without loading all messages
- **Real-time**: Can listen to `/deadlines` collection for updates
- **Scalability**: Doesn't pollute message documents, can have deadline-specific metadata

**Trade-offs**:
- **Gain**: Fast queries, global deadline view, real-time updates, scalable
- **Lose**: Extra Firestore reads (1 per deadline fetch), slightly more complex sync

**Firestore Structure**:
```javascript
/deadlines/{deadlineId}
  - id: string (auto-generated)
  - conversationId: string (reference)
  - messageId: string (source message)
  - extractedFrom: string (message text snippet)
  - title: string ("Permission slip", "RSVP", "Registration")
  - description: string? (optional details)
  - dueDate: Timestamp (deadline date/time)
  - isAllDay: boolean (time-specific vs all-day)
  - priority: 'high' | 'medium' | 'low'
  - status: 'upcoming' | 'today' | 'overdue' | 'completed'
  - reminderSent: boolean (for notifications)
  - extractedBy: string (userId who triggered extraction)
  - extractedAt: Timestamp
  - confidence: number (0.0-1.0, GPT-4 confidence score)
  - method: 'keyword' | 'gpt4' | 'hybrid'
```

---

#### Decision 3: UI Pattern

**Options Considered**:
1. **In-chat deadline cards only** (context-preserved)
2. **Global deadline tab only** (centralized view)
3. **Both: In-chat cards + Global tab** (best UX)

**Chosen**: **Both - In-chat cards + Global deadline tab**

**Rationale**:
- **In-chat cards**: Keep deadline in conversation context, easy to reference
- **Global tab**: See all deadlines across conversations at once
- **User flexibility**: Different users prefer different views
- **Complementary**: In-chat for context, global for overview

**Trade-offs**:
- **Gain**: Maximum flexibility, serves multiple use cases, power user feature
- **Lose**: More UI complexity, more code to maintain

**In-Chat Card Design**:
```
┌─────────────────────────────────────────┐
│ 📅 Deadline: Permission Slip Due        │
│ ⏰ Wednesday, March 15 by 3:00 PM       │
│ ⏳ 3 days remaining                      │
│ 📍 From: School Parent Group            │
│ ────────────────────────────────────────│
│ [Mark Complete] [Add Reminder] [Dismiss]│
└─────────────────────────────────────────┘
```

**Global Tab Design**:
```
📅 Deadlines

[Upcoming] [Today] [Overdue] [Completed]

TODAY
• 🔴 RSVP for field trip (3:00 PM) - School Group
• 🔴 Bake sale signup closes (5:00 PM) - PTA Group

THIS WEEK
• 🟡 Permission slip due (Wed 3:00 PM) - School
• 🟡 Registration closes (Fri) - Soccer Team

NEXT WEEK
• 🟢 Project deadline (Mon) - Work Group
```

---

#### Decision 4: Detection Trigger

**Options Considered**:
1. **Automatic on every message** (seamless, expensive)
2. **Manual trigger (button/long-press)** (cost-controlled, user friction)
3. **Smart automatic (keywords → auto-extract)** (balanced)

**Chosen**: **Smart automatic (hybrid keyword detection → GPT-4 confirmation)**

**Rationale**:
- **User Experience**: No manual action required, feels magical
- **Cost Control**: Keyword filter screens 70-80% of messages for free
- **Accuracy**: GPT-4 only processes messages likely to have deadlines
- **Scale**: Can handle 100+ messages/day without excessive API costs

**Trade-offs**:
- **Gain**: Zero user friction, automatic deadline tracking, production-ready UX
- **Lose**: Slightly higher costs than manual, potential false positives (mitigated by confidence scoring)

**Detection Flow**:
```
Message received
     ↓
Keyword filter (<100ms)
     ↓
Contains deadline keywords? ─NO→ Skip
     ↓ YES
GPT-4 extraction (~2s)
     ↓
Valid deadline? ─NO→ Skip
     ↓ YES
Save to /deadlines
     ↓
Display card + Update global tab
```

---

### Data Flow

**End-to-End Deadline Detection Flow**:

```
1. Message Received
   ├─ User A: "Permission slip due Wednesday by 3pm"
   ├─ ChatViewModel receives message
   └─ Triggers detectMessageDeadline() automatically

2. Keyword Pre-Filter (Client-side, <100ms)
   ├─ Check: Contains deadline keywords? ("due", "by", "deadline")
   ├─ Check: Contains date reference? ("Wednesday", "3pm")
   ├─ Match! → Proceed to GPT-4
   └─ No match → Skip processing

3. GPT-4 Extraction (Cloud Function, ~2s)
   ├─ Send message text to processAI function
   ├─ Feature: 'deadline_extraction'
   ├─ GPT-4 function calling:
   │  {
   │    "title": "Permission slip",
   │    "dueDate": "2025-03-15T15:00:00Z",
   │    "isAllDay": false,
   │    "priority": "high",
   │    "confidence": 0.92,
   │    "description": "School permission slip for field trip"
   │  }
   └─ Return structured deadline

4. Save to Firestore
   ├─ ChatViewModel receives deadline
   ├─ Create document in /deadlines collection
   ├─ Include conversationId, messageId, extractedBy
   └─ Status: 'upcoming' (auto-calculated)

5. Display Deadline
   ├─ In-chat: DeadlineCardView below message
   ├─ Global tab: Add to DeadlineListView
   ├─ Badge: Update deadline count
   └─ Real-time listener updates all views
```

---

### Component Architecture

**Cloud Functions** (1 new file, ~300 lines):
```typescript
// functions/src/ai/deadlineExtraction.ts
export async function extractDeadline(messageText: string, context: ConversationContext) {
  // 1. Keyword pre-filter (before GPT-4)
  if (!containsDeadlineKeywords(messageText)) {
    return { hasDeadline: false };
  }

  // 2. GPT-4 function calling
  const completion = await openai.chat.completions.create({
    model: "gpt-4",
    messages: [
      { role: "system", content: DEADLINE_EXTRACTION_PROMPT },
      { role: "user", content: `Extract deadline from: "${messageText}"` }
    ],
    functions: [DEADLINE_EXTRACTION_FUNCTION],
    function_call: { name: "extract_deadline" }
  });

  // 3. Parse and validate
  const deadline = parseDeadlineResponse(completion);
  
  // 4. Calculate status and priority
  deadline.status = calculateStatus(deadline.dueDate);
  deadline.priority = calculatePriority(deadline.dueDate, deadline.title);

  return deadline;
}
```

**iOS Models** (2 new files, ~300 lines):
```swift
// Models/Deadline.swift
struct Deadline: Codable, Identifiable {
    let id: String
    let conversationId: String
    let messageId: String
    let extractedFrom: String
    
    let title: String
    let description: String?
    let dueDate: Date
    let isAllDay: Bool
    
    var priority: PriorityLevel
    var status: DeadlineStatus
    
    let confidence: Double
    let method: String
    let extractedBy: String
    let extractedAt: Date
    
    var reminderSent: Bool
    
    // Computed properties
    var daysRemaining: Int { ... }
    var hoursRemaining: Int { ... }
    var isOverdue: Bool { ... }
    var isToday: Bool { ... }
    var urgencyLevel: UrgencyLevel { ... }
    var statusColor: Color { ... }
    var statusIcon: String { ... }
    
    // Display helpers
    var formattedDueDate: String { ... }
    var countdownText: String { ... } // "3 days remaining"
    var urgencyText: String { ... } // "Due in 3 hours!"
}

enum DeadlineStatus: String, Codable {
    case upcoming
    case today
    case overdue
    case completed
}

enum PriorityLevel: String, Codable {
    case high
    case medium
    case low
    
    var color: Color { ... }
    var icon: String { ... }
}
```

**SwiftUI Views** (3 new files, ~650 lines):
```swift
// Views/Deadline/DeadlineCardView.swift (~250 lines)
struct DeadlineCardView: View {
    let deadline: Deadline
    @ObservedObject var viewModel: ChatViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with icon and title
            HStack {
                Image(systemName: deadline.statusIcon)
                    .foregroundColor(deadline.statusColor)
                Text(deadline.title)
                    .font(.headline)
            }
            
            // Due date and countdown
            HStack {
                Text(deadline.formattedDueDate)
                Spacer()
                Text(deadline.countdownText)
                    .foregroundColor(deadline.urgencyLevel.color)
            }
            
            // Description (if present)
            if let description = deadline.description {
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Action buttons
            HStack {
                Button("Mark Complete") { ... }
                Button("Add Reminder") { ... }
                Button("Dismiss") { ... }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// Views/Deadline/DeadlineListView.swift (~300 lines)
struct DeadlineListView: View {
    @StateObject var viewModel: DeadlineViewModel
    @State private var selectedFilter: DeadlineFilter = .upcoming
    
    var body: some View {
        NavigationStack {
            VStack {
                // Filter tabs
                Picker("Filter", selection: $selectedFilter) {
                    Text("Upcoming").tag(DeadlineFilter.upcoming)
                    Text("Today").tag(DeadlineFilter.today)
                    Text("Overdue").tag(DeadlineFilter.overdue)
                    Text("Completed").tag(DeadlineFilter.completed)
                }
                .pickerStyle(.segmented)
                
                // Deadline list
                List {
                    ForEach(viewModel.filteredDeadlines) { deadline in
                        DeadlineRowView(deadline: deadline)
                            .onTapGesture {
                                viewModel.navigateToConversation(deadline.conversationId)
                            }
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("Deadlines")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Mark All Complete") { ... }
                        Button("Clear Completed") { ... }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
    }
}

// Views/Deadline/DeadlineRowView.swift (~100 lines)
struct DeadlineRowView: View {
    let deadline: Deadline
    
    var body: some View {
        HStack {
            // Status indicator
            Circle()
                .fill(deadline.statusColor)
                .frame(width: 8, height: 8)
            
            // Deadline info
            VStack(alignment: .leading, spacing: 4) {
                Text(deadline.title)
                    .font(.headline)
                Text(deadline.formattedDueDate)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Countdown
            Text(deadline.countdownText)
                .font(.caption)
                .foregroundColor(deadline.urgencyLevel.color)
        }
        .padding(.vertical, 8)
    }
}
```

---

## Implementation Details

### File Structure

**New Files** (7 files, ~1,150 lines):
```
functions/src/ai/
├── deadlineExtraction.ts         (~300 lines) - GPT-4 extraction logic

messAI/Models/
├── Deadline.swift                 (~200 lines) - Deadline data model
└── DeadlineStatus.swift           (~50 lines) - Status enum

messAI/ViewModels/
└── DeadlineViewModel.swift        (~200 lines) - Global deadline state

messAI/Views/Deadline/
├── DeadlineCardView.swift         (~250 lines) - In-chat deadline card
├── DeadlineListView.swift         (~300 lines) - Global deadline list
└── DeadlineRowView.swift          (~100 lines) - List row component

messAI/Services/
└── DeadlineService.swift          (~150 lines) - Firestore deadline CRUD
```

**Modified Files** (+~350 lines):
```
functions/src/ai/processAI.ts      (+20 lines) - Add deadline route
messAI/Services/AIService.swift    (+80 lines) - extractDeadline() method
messAI/ViewModels/ChatViewModel.swift (+100 lines) - Deadline detection logic
messAI/Views/Chat/ChatView.swift   (+80 lines) - Display deadline cards
messAI/Views/Chat/ChatListView.swift (+50 lines) - Deadline tab + badge
messAI/ContentView.swift            (+20 lines) - DeadlineListView integration
```

---

### Key Implementation Steps

#### Phase 1: Cloud Function (60-90 minutes)

**1.1: Create deadlineExtraction.ts** (30 min)
```typescript
// Keyword pre-filter
const DEADLINE_KEYWORDS = [
  'due', 'deadline', 'by', 'before', 'closes', 'ends',
  'submit', 'turn in', 'expires', 'last day'
];

function containsDeadlineKeywords(text: string): boolean {
  const lowerText = text.toLowerCase();
  return DEADLINE_KEYWORDS.some(keyword => lowerText.includes(keyword))
    && hasDateReference(lowerText);
}

function hasDateReference(text: string): boolean {
  const datePatterns = [
    /\b(mon|tue|wed|thu|fri|sat|sun)/,
    /\b\d{1,2}\/\d{1,2}\b/,
    /\b(today|tomorrow|this week|next)/
  ];
  return datePatterns.some(pattern => pattern.test(text));
}

// GPT-4 extraction
export async function extractDeadline(messageText: string) {
  if (!containsDeadlineKeywords(messageText)) {
    return { success: false, reason: 'no_deadline_keywords' };
  }

  const response = await openai.chat.completions.create({
    model: "gpt-4",
    messages: [
      {
        role: "system",
        content: "Extract deadline information. Be specific about dates and times. Return null if no clear deadline exists."
      },
      {
        role: "user",
        content: `Extract deadline from: "${messageText}"`
      }
    ],
    functions: [{
      name: "extract_deadline",
      description: "Extract deadline information from a message",
      parameters: {
        type: "object",
        properties: {
          hasDeadline: { type: "boolean" },
          title: { type: "string" },
          dueDate: { type: "string", format: "date-time" },
          isAllDay: { type: "boolean" },
          priority: { enum: ["high", "medium", "low"] },
          confidence: { type: "number", minimum: 0, maximum: 1 },
          description: { type: "string" }
        },
        required: ["hasDeadline"]
      }
    }],
    function_call: { name: "extract_deadline" }
  });

  return parseDeadlineResponse(response);
}
```

**1.2: Add route to processAI.ts** (10 min)
```typescript
case 'deadline_extraction':
  return await extractDeadline(messageText, conversationId);
```

**1.3: Deploy and test** (20 min)
```bash
firebase deploy --only functions
# Test with curl/Postman
```

---

#### Phase 2: iOS Models (45-60 minutes)

**2.1: Create Deadline.swift** (30 min)
```swift
struct Deadline: Codable, Identifiable {
    let id: String
    let conversationId: String
    let messageId: String
    let extractedFrom: String
    
    let title: String
    let description: String?
    let dueDate: Date
    let isAllDay: Bool
    
    var priority: PriorityLevel
    var status: DeadlineStatus
    
    let confidence: Double
    let method: String
    let extractedBy: String
    let extractedAt: Date
    
    var reminderSent: Bool
    
    // Computed properties
    var daysRemaining: Int {
        Calendar.current.dateComponents([.day], from: Date(), to: dueDate).day ?? 0
    }
    
    var hoursRemaining: Int {
        Calendar.current.dateComponents([.hour], from: Date(), to: dueDate).hour ?? 0
    }
    
    var isOverdue: Bool {
        dueDate < Date()
    }
    
    var isToday: Bool {
        Calendar.current.isDateInToday(dueDate)
    }
    
    var countdownText: String {
        if isOverdue {
            return "Overdue"
        } else if isToday {
            return "\(hoursRemaining) hours remaining"
        } else {
            return "\(daysRemaining) days remaining"
        }
    }
    
    var formattedDueDate: String {
        let formatter = DateFormatter()
        if isAllDay {
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
        } else {
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
        }
        return formatter.string(from: dueDate)
    }
    
    // Firestore conversion
    init(from dict: [String: Any]) throws { ... }
    func toFirestore() -> [String: Any] { ... }
}
```

**2.2: Create DeadlineStatus.swift** (15 min)
```swift
enum DeadlineStatus: String, Codable {
    case upcoming
    case today
    case overdue
    case completed
    
    var color: Color {
        switch self {
        case .upcoming: return .blue
        case .today: return .orange
        case .overdue: return .red
        case .completed: return .green
        }
    }
    
    var icon: String {
        switch self {
        case .upcoming: return "calendar"
        case .today: return "clock"
        case .overdue: return "exclamationmark.triangle"
        case .completed: return "checkmark.circle"
        }
    }
}

enum PriorityLevel: String, Codable {
    case high
    case medium
    case low
    
    var color: Color {
        switch self {
        case .high: return .red
        case .medium: return .orange
        case .low: return .gray
        }
    }
}
```

---

#### Phase 3: Deadline Service (30-45 minutes)

**3.1: Create DeadlineService.swift** (45 min)
```swift
class DeadlineService {
    private let db = Firestore.firestore()
    
    // CRUD operations
    func createDeadline(_ deadline: Deadline) async throws {
        try db.collection("deadlines")
            .document(deadline.id)
            .setData(deadline.toFirestore())
    }
    
    func fetchDeadlines(for userId: String) -> AsyncThrowingStream<[Deadline], Error> {
        AsyncThrowingStream { continuation in
            let listener = db.collection("deadlines")
                .whereField("extractedBy", isEqualTo: userId)
                .whereField("status", in: ["upcoming", "today", "overdue"])
                .order(by: "dueDate")
                .addSnapshotListener { snapshot, error in
                    if let error = error {
                        continuation.finish(throwing: error)
                        return
                    }
                    
                    guard let documents = snapshot?.documents else {
                        continuation.yield([])
                        return
                    }
                    
                    let deadlines = documents.compactMap { doc -> Deadline? in
                        try? Deadline(from: doc.data())
                    }
                    
                    continuation.yield(deadlines)
                }
            
            continuation.onTermination = { _ in
                listener.remove()
            }
        }
    }
    
    func markComplete(_ deadlineId: String) async throws {
        try await db.collection("deadlines")
            .document(deadlineId)
            .updateData(["status": "completed"])
    }
    
    func deleteDeadline(_ deadlineId: String) async throws {
        try await db.collection("deadlines")
            .document(deadlineId)
            .delete()
    }
}
```

---

#### Phase 4: ViewModels (45-60 minutes)

**4.1: Create DeadlineViewModel** (30 min)
```swift
@MainActor
class DeadlineViewModel: ObservableObject {
    @Published var deadlines: [Deadline] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let deadlineService: DeadlineService
    private let authService: AuthService
    
    init(deadlineService: DeadlineService, authService: AuthService) {
        self.deadlineService = deadlineService
        self.authService = authService
        
        loadDeadlines()
    }
    
    func loadDeadlines() {
        guard let userId = authService.currentUser?.id else { return }
        
        isLoading = true
        
        Task {
            do {
                for try await deadlines in deadlineService.fetchDeadlines(for: userId) {
                    self.deadlines = deadlines
                    self.isLoading = false
                }
            } catch {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    var upcomingDeadlines: [Deadline] {
        deadlines.filter { $0.status == .upcoming }
            .sorted { $0.dueDate < $1.dueDate }
    }
    
    var todayDeadlines: [Deadline] {
        deadlines.filter { $0.isToday && $0.status != .completed }
            .sorted { $0.dueDate < $1.dueDate }
    }
    
    var overdueDeadlines: [Deadline] {
        deadlines.filter { $0.isOverdue && $0.status != .completed }
            .sorted { $0.dueDate < $1.dueDate }
    }
    
    func markComplete(_ deadlineId: String) {
        Task {
            do {
                try await deadlineService.markComplete(deadlineId)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
```

**4.2: Update ChatViewModel** (30 min)
```swift
// Add to ChatViewModel.swift
@Published var extractedDeadlines: [Deadline] = []
@Published var isExtractingDeadline = false

func detectMessageDeadline(for message: Message) {
    // Keyword pre-filter (client-side)
    guard containsDeadlineKeywords(message.text) else { return }
    
    isExtractingDeadline = true
    
    Task {
        do {
            let result = try await aiService.extractDeadline(
                messageId: message.id,
                conversationId: conversationId,
                messageText: message.text
            )
            
            if let deadline = result.deadline {
                // Save to Firestore via DeadlineService
                try await deadlineService.createDeadline(deadline)
                
                // Update local state
                await MainActor.run {
                    extractedDeadlines.append(deadline)
                    isExtractingDeadline = false
                }
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to extract deadline: \(error.localizedDescription)"
                isExtractingDeadline = false
            }
        }
    }
}

private func containsDeadlineKeywords(_ text: String) -> Bool {
    let keywords = ["due", "deadline", "by", "before", "closes", "submit"]
    let lowerText = text.lowercased()
    return keywords.contains { lowerText.contains($0) }
}
```

---

#### Phase 5: SwiftUI Views (60-90 minutes)

**5.1: Create DeadlineCardView** (30 min)
```swift
struct DeadlineCardView: View {
    let deadline: Deadline
    @ObservedObject var viewModel: ChatViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: deadline.status.icon)
                    .foregroundColor(deadline.status.color)
                    .font(.title2)
                
                Text(deadline.title)
                    .font(.headline)
                
                Spacer()
                
                Image(systemName: deadline.priority.icon)
                    .foregroundColor(deadline.priority.color)
            }
            
            // Due date and countdown
            HStack {
                Text(deadline.formattedDueDate)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(deadline.countdownText)
                    .font(.caption)
                    .foregroundColor(deadline.urgencyLevel.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(deadline.urgencyLevel.color.opacity(0.2))
                    .cornerRadius(8)
            }
            
            // Description (if present)
            if let description = deadline.description {
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Divider()
            
            // Actions
            HStack(spacing: 12) {
                Button(action: { viewModel.markDeadlineComplete(deadline.id) }) {
                    Label("Complete", systemImage: "checkmark.circle")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                
                Button(action: { viewModel.addReminder(for: deadline) }) {
                    Label("Remind", systemImage: "bell")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button(action: { viewModel.dismissDeadline(deadline.id) }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: deadline.status.color.opacity(0.3), radius: 4, x: 0, y: 2)
    }
}
```

**5.2: Create DeadlineListView** (40 min)
```swift
struct DeadlineListView: View {
    @StateObject var viewModel: DeadlineViewModel
    @State private var selectedFilter: DeadlineFilter = .upcoming
    
    enum DeadlineFilter {
        case upcoming, today, overdue, completed
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filter tabs
                Picker("Filter", selection: $selectedFilter) {
                    Text("Upcoming").tag(DeadlineFilter.upcoming)
                    Text("Today").tag(DeadlineFilter.today)
                    Text("Overdue").tag(DeadlineFilter.overdue)
                    Text("Completed").tag(DeadlineFilter.completed)
                }
                .pickerStyle(.segmented)
                .padding()
                
                // Deadline list
                if viewModel.isLoading {
                    ProgressView()
                        .padding()
                } else if filteredDeadlines.isEmpty {
                    emptyStateView
                } else {
                    List {
                        ForEach(filteredDeadlines) { deadline in
                            DeadlineRowView(deadline: deadline)
                                .onTapGesture {
                                    // Navigate to conversation
                                    viewModel.navigateToConversation(deadline.conversationId)
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button("Complete", systemImage: "checkmark") {
                                        viewModel.markComplete(deadline.id)
                                    }
                                    .tint(.green)
                                }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Deadlines")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Mark All Complete") {
                            viewModel.markAllComplete()
                        }
                        Button("Clear Completed") {
                            viewModel.clearCompleted()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
    }
    
    private var filteredDeadlines: [Deadline] {
        switch selectedFilter {
        case .upcoming: return viewModel.upcomingDeadlines
        case .today: return viewModel.todayDeadlines
        case .overdue: return viewModel.overdueDeadlines
        case .completed: return viewModel.completedDeadlines
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 60))
                .foregroundColor(.green)
            Text("No \(selectedFilter.rawValue) deadlines")
                .font(.headline)
            Text("You're all caught up!")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}
```

**5.3: Create DeadlineRowView** (20 min)
```swift
struct DeadlineRowView: View {
    let deadline: Deadline
    
    var body: some View {
        HStack(spacing: 12) {
            // Status indicator
            Circle()
                .fill(deadline.status.color)
                .frame(width: 8, height: 8)
            
            // Deadline info
            VStack(alignment: .leading, spacing: 4) {
                Text(deadline.title)
                    .font(.headline)
                
                HStack {
                    Text(deadline.formattedDueDate)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let description = deadline.description {
                        Text("•")
                            .foregroundColor(.secondary)
                        Text(description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            
            Spacer()
            
            // Countdown
            VStack(alignment: .trailing, spacing: 2) {
                Text(deadline.countdownText)
                    .font(.caption)
                    .foregroundColor(deadline.urgencyLevel.color)
                
                Image(systemName: deadline.priority.icon)
                    .font(.caption2)
                    .foregroundColor(deadline.priority.color)
            }
        }
        .padding(.vertical, 8)
    }
}
```

---

#### Phase 6: Integration (30-45 minutes)

**6.1: Update ChatView** (20 min)
```swift
// Add deadline card display
if !viewModel.extractedDeadlines.isEmpty {
    ForEach(viewModel.extractedDeadlines) { deadline in
        DeadlineCardView(deadline: deadline, viewModel: viewModel)
            .padding(.horizontal)
            .padding(.vertical, 4)
    }
}
```

**6.2: Update ChatListView** (15 min)
```swift
// Add deadline tab to TabView
TabView(selection: $selectedTab) {
    // Existing tabs...
    
    DeadlineListView(viewModel: deadlineViewModel)
        .tabItem {
            Label("Deadlines", systemImage: "calendar.badge.clock")
        }
        .badge(deadlineViewModel.upcomingDeadlines.count + deadlineViewModel.todayDeadlines.count)
        .tag(Tab.deadlines)
}
```

**6.3: Automatic detection on message received** (10 min)
```swift
// In ChatViewModel, when new message arrives:
.onReceive(chatService.messagesPublisher) { messages in
    // ... existing code ...
    
    // Auto-detect deadlines on new messages
    if let lastMessage = messages.last, lastMessage.senderId != currentUserId {
        detectMessageDeadline(for: lastMessage)
    }
}
```

---

## Testing Strategy

### Test Categories

#### 1. Unit Tests (Cloud Function)
```javascript
describe('deadlineExtraction', () => {
  test('extracts explicit deadline', async () => {
    const result = await extractDeadline('Permission slip due Wednesday by 3pm');
    expect(result.hasDeadline).toBe(true);
    expect(result.title).toContain('Permission slip');
    expect(result.dueDate).toBeDefined();
  });
  
  test('filters non-deadline messages', async () => {
    const result = await extractDeadline('Hey, how are you?');
    expect(result.hasDeadline).toBe(false);
  });
  
  test('handles relative dates', async () => {
    const result = await extractDeadline('RSVP by next Friday');
    expect(result.dueDate).toBeInstanceOf(Date);
    expect(result.daysRemaining).toBe(7);
  });
});
```

#### 2. Integration Tests (End-to-End)
- Send message with deadline → Verify Cloud Function called
- Extract deadline → Verify saved to Firestore
- Display deadline card → Verify appears in chat
- Update deadline status → Verify reflected in global tab
- Mark complete → Verify removed from active list

#### 3. Edge Case Tests
- Ambiguous dates ("next Friday" when it's Friday)
- Multiple deadlines in one message
- Past deadlines ("was due yesterday")
- Time zones (relative to user's location)
- All-day vs time-specific
- Very short messages with deadline
- Very long messages (500+ chars)

#### 4. Performance Tests
- Keyword filter: <100ms (95th percentile)
- GPT-4 extraction: <3s (95th percentile)
- Firestore write: <500ms
- UI update: <100ms after detection
- Load global tab: <1s for 100+ deadlines

---

## Success Criteria

### Feature is complete when:

1. **Cloud Function Working** ✅
   - [ ] Keyword filter correctly identifies 80%+ of deadline messages
   - [ ] GPT-4 extraction accuracy >85% for explicit deadlines
   - [ ] Returns structured JSON with all required fields
   - [ ] Handles edge cases gracefully (past dates, ambiguous, etc.)
   - [ ] Performance <3s for GPT-4 extraction

2. **iOS Models & Service** ✅
   - [ ] Deadline model with all computed properties
   - [ ] DeadlineStatus enum with colors and icons
   - [ ] DeadlineService CRUD operations working
   - [ ] Real-time Firestore listener updates

3. **Automatic Detection** ✅
   - [ ] Detects deadlines on incoming messages automatically
   - [ ] Keyword pre-filter screens non-deadline messages
   - [ ] No user action required (fully automatic)
   - [ ] Works in both 1-on-1 and group chats

4. **In-Chat Display** ✅
   - [ ] Deadline card appears below relevant message
   - [ ] Countdown updates in real-time
   - [ ] Status color coding works (upcoming/today/overdue)
   - [ ] Action buttons functional (complete, remind, dismiss)

5. **Global Deadline Tab** ✅
   - [ ] All deadlines from all conversations visible
   - [ ] Filter tabs work (Upcoming/Today/Overdue/Completed)
   - [ ] Sorted chronologically by due date
   - [ ] Tap to navigate to source conversation
   - [ ] Badge shows count of active deadlines

6. **Status Management** ✅
   - [ ] Status auto-updates (upcoming → today → overdue)
   - [ ] Mark complete removes from active lists
   - [ ] Completed deadlines stored for history
   - [ ] Can undo completion

7. **Performance** ✅
   - [ ] Keyword filter <100ms
   - [ ] GPT-4 extraction <3s (cold), <1s (warm)
   - [ ] No UI lag when processing deadlines
   - [ ] Firestore queries optimized with indexes

8. **User Experience** ✅
   - [ ] Visual hierarchy clear (overdue red, today orange, upcoming blue)
   - [ ] Countdown text readable ("3 days remaining")
   - [ ] Empty states friendly and helpful
   - [ ] Dark mode support

9. **Cost Control** ✅
   - [ ] Keyword pre-filter reduces GPT-4 calls by 70-80%
   - [ ] Rate limiting from PR#14 enforced
   - [ ] Average cost <$0.005/deadline detected
   - [ ] No runaway API costs

10. **Testing** ✅
    - [ ] All test scenarios passing
    - [ ] Tested with 10+ different deadline formats
    - [ ] Works on physical device
    - [ ] No crashes or errors in production

---

## Risk Assessment

### Risk 1: Low Extraction Accuracy
**Likelihood**: MEDIUM  
**Impact**: HIGH (users miss deadlines)  
**Mitigation**:
- Keyword pre-filter ensures we only process likely candidates
- GPT-4 confidence scoring (only show if >0.7 confidence)
- User can manually add/edit deadlines
- Learn from false negatives (log and improve prompts)

**Status**: 🟡 MEDIUM - Needs careful prompt engineering

---

### Risk 2: High API Costs
**Likelihood**: MEDIUM  
**Impact**: MEDIUM (budget concerns)  
**Mitigation**:
- Hybrid approach (70-80% filtered by keywords for free)
- Rate limiting from PR#14 (100 req/hour/user)
- Caching to prevent duplicate extractions
- Monitor costs in Firebase console

**Status**: 🟢 LOW - Well mitigated with hybrid approach

---

### Risk 3: Timezone Confusion
**Likelihood**: LOW  
**Impact**: MEDIUM (wrong deadline time)  
**Mitigation**:
- Use device's local timezone for interpretation
- GPT-4 returns ISO 8601 with timezone
- Display timezone in UI for clarity
- Test with various timezone scenarios

**Status**: 🟢 LOW - Standard date handling patterns

---

### Risk 4: Notification Spam
**Likelihood**: MEDIUM  
**Impact**: LOW (user annoyance)  
**Mitigation**:
- Don't implement notifications in this PR (defer to PR#22)
- Deadline badge on tab (non-intrusive)
- User controls notification preferences
- Smart notification timing (24h before, 1h before)

**Status**: 🟢 LOW - Deferred to PR#22

---

## Open Questions

### Question 1: Should we support recurring deadlines?
**Options**:
- A: Yes - "Every Monday" deadlines
- B: No - Single deadlines only (MVP)

**Recommendation**: **B (No recurring)** - Keep MVP simple, add in future PR if needed

---

### Question 2: Should we allow manual deadline creation?
**Options**:
- A: Yes - Users can add deadlines manually
- B: No - AI extraction only

**Recommendation**: **A (Yes, manual)** - Important for edge cases where AI misses

**Implementation**: Add "+" button in DeadlineListView → manual entry sheet

---

### Question 3: Should we integrate with iOS Reminders app?
**Options**:
- A: Yes - Export to Reminders
- B: No - Keep in-app only

**Recommendation**: **B (No Reminders integration)** for MVP - Focus on in-app experience first. Can add export feature in future PR if users request it.

---

## Timeline

**Total Estimate**: 3-4 hours

| Phase | Task | Time | Priority |
|-------|------|------|----------|
| 1 | Cloud Function | 60-90 min | CRITICAL |
| 2 | iOS Models | 45-60 min | CRITICAL |
| 3 | Deadline Service | 30-45 min | CRITICAL |
| 4 | ViewModels | 45-60 min | CRITICAL |
| 5 | SwiftUI Views | 60-90 min | CRITICAL |
| 6 | Integration | 30-45 min | CRITICAL |
| **TOTAL** | | **3-4 hours** | |

**Buffer**: +1 hour for debugging and edge cases

---

## Dependencies

**Hard Dependencies** (MUST be complete):
- [x] PR#14: Cloud Functions Setup - ✅ COMPLETE (AI infrastructure deployed)
- [x] PR#15: Calendar Extraction - ✅ COMPLETE (GPT-4 date parsing patterns established)

**Soft Dependencies** (Nice to have):
- [ ] PR#22: Push Notifications - For deadline reminders (optional)

**Blocks**:
- PR#20: Multi-Step Event Planning Agent (will use deadline data)

---

## References

### Similar Implementations
- PR#15: Calendar Extraction (date/time parsing with GPT-4)
- PR#18: RSVP Tracking (hybrid keyword + GPT-4 detection)

### Key Technologies
- GPT-4 function calling for structured extraction
- Firestore real-time listeners for deadline updates
- SwiftUI List with filtering and sorting
- iOS Calendar API for date calculations

### Design Inspiration
- Notion: Deadline database with status tracking
- Todoist: Countdown display and priority levels
- Google Keep: In-context deadline cards + global list

---

## Next Steps

**After PR#19 Complete**:
1. PR#20: Multi-Step Event Planning Agent (uses deadline + RSVP data)
2. PR#22: Push Notifications (deadline reminders)
3. PR#23: Image Sharing (can share deadline screenshots)

---

**Value Proposition**: "Never miss a deadline buried in group chat. See all upcoming deadlines at a glance."

**Success Metric**: 95% of deadlines in messages automatically detected and tracked, saving parents 10-15 minutes/day.

