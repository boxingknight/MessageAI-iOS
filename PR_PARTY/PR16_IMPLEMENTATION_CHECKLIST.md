# PR#16: Decision Summarization - Implementation Checklist

**Use this as your daily todo list.** Check off items as you complete them.

**Estimated Total Time:** 3-4 hours  
**Current Status:** ⏳ Ready to implement  
**Prerequisites:** PR#14 (Cloud Functions) MUST be 100% complete

---

## Pre-Implementation Verification (15 minutes)

### ✅ Prerequisites Check

- [ ] Read main specification (`PR16_DECISION_SUMMARIZATION.md`) - 45 minutes
- [ ] PR#14 (Cloud Functions) verified as COMPLETE
  - [ ] `processAI` function deployed to Firebase
  - [ ] OpenAI API key configured
  - [ ] Rate limiting working
  - [ ] Authentication middleware working
- [ ] Firebase CLI installed and logged in
  ```bash
  firebase --version  # Should show 12.0.0+
  firebase projects:list  # Should show messageai project
  ```
- [ ] OpenAI API account active with credits
  - Login to platform.openai.com
  - Check API key valid
  - Check usage limits ($5+ recommended)
- [ ] Xcode project opens without errors
- [ ] Current branch: `main` (or feature/pr15-calendar-extraction if sequential)

### 📦 Create Feature Branch

```bash
cd /Users/ijaramil/Documents/GauntletAI/Week2/messAI
git checkout main
git pull origin main
git checkout -b feature/pr16-decision-summarization
```

---

## Phase 1: Cloud Function Implementation (60 minutes)

### 1.1: Create decisionSummary.ts File (20 minutes)

#### Create File Structure
- [ ] Create `functions/src/ai/decisionSummary.ts`

#### Add Imports
- [ ] Add imports at top of file:
```typescript
import * as admin from 'firebase-admin';
import OpenAI from 'openai';

interface SummaryResult {
  summary: string;
  decisions: string[];
  actionItems: Array<{
    text: string;
    assignedTo?: string;
    dueDate?: string;
    priority: 'high' | 'medium' | 'low';
  }>;
  keyPoints: string[];
}
```

#### Implement Main Function
- [ ] Create `summarizeConversation()` function (~150 lines):
```typescript
export async function summarizeConversation(
  conversationId: string,
  userId: string,
  openai: OpenAI
): Promise<{
  summary: string;
  decisions: string[];
  actionItems: any[];
  keyPoints: string[];
  messageCount: number;
}> {
  // 1. Verify user is participant
  const conversationDoc = await admin.firestore()
    .collection('conversations')
    .doc(conversationId)
    .get();

  if (!conversationDoc.exists) {
    throw new Error('Conversation not found');
  }

  const conversation = conversationDoc.data();
  if (!conversation?.participants.includes(userId)) {
    throw new Error('User not authorized to summarize this conversation');
  }

  // 2. Fetch last 50 messages
  const messagesSnapshot = await admin.firestore()
    .collection('conversations')
    .doc(conversationId)
    .collection('messages')
    .orderBy('sentAt', 'desc')
    .limit(50)
    .get();

  if (messagesSnapshot.empty) {
    return {
      summary: 'No messages to summarize.',
      decisions: [],
      actionItems: [],
      keyPoints: [],
      messageCount: 0
    };
  }

  // 3. Build conversation context (reverse to chronological order)
  const messages = messagesSnapshot.docs.reverse();
  const conversationText = messages
    .map(doc => {
      const msg = doc.data();
      return `${msg.senderName || 'Unknown'}: ${msg.text}`;
    })
    .join('\n');

  // 4. Call OpenAI GPT-4
  const prompt = buildSummarizationPrompt(conversationText, messages.length);
  
  const completion = await openai.chat.completions.create({
    model: 'gpt-4',
    messages: [
      {
        role: 'system',
        content: 'You are an AI assistant helping busy parents summarize group chat conversations. Be concise, specific, and focus on actionable information.'
      },
      {
        role: 'user',
        content: prompt
      }
    ],
    max_tokens: 500,
    temperature: 0.3, // Lower temperature for more consistent output
    response_format: { type: 'json_object' } // Structured JSON response
  });

  // 5. Parse response
  const responseText = completion.choices[0].message.content || '{}';
  const result: SummaryResult = JSON.parse(responseText);

  // 6. Return structured summary
  return {
    summary: result.summary || 'No summary available.',
    decisions: result.decisions || [],
    actionItems: result.actionItems || [],
    keyPoints: result.keyPoints || [],
    messageCount: messages.length
  };
}

function buildSummarizationPrompt(conversationText: string, messageCount: number): string {
  return `You are analyzing a group chat conversation to help busy parents stay informed.

Analyze the following conversation and extract:
1. KEY DECISIONS: Any decisions that were made or agreed upon by the group
2. ACTION ITEMS: Things people need to do (include who and when if mentioned)
3. KEY POINTS: Other important information (schedule changes, important announcements, questions)

Focus on:
- Concrete decisions ("We decided X", "Let's do Y")
- Clear action items ("Sarah will bring snacks", "Everyone needs to RSVP by Friday")
- Important dates, times, locations
- Questions that need answers
- Schedule changes or updates

CONVERSATION (${messageCount} messages):
${conversationText}

Respond with JSON in this exact format:
{
  "summary": "2-3 sentence overview of the conversation",
  "decisions": ["decision 1", "decision 2"],
  "actionItems": [
    {
      "text": "description of what needs to be done",
      "assignedTo": "person's name or null if unassigned",
      "dueDate": "YYYY-MM-DD or null if not specified",
      "priority": "high|medium|low"
    }
  ],
  "keyPoints": ["important point 1", "important point 2"]
}

If no decisions/action items/key points exist, use empty arrays.`;
}
```

**Checkpoint:** Function compiles without errors ✓

**Commit:**
```bash
git add functions/src/ai/decisionSummary.ts
git commit -m "feat(ai): implement decision summary Cloud Function

- Extract decisions, action items, key points from conversations
- GPT-4 integration with structured JSON output
- Security: verify user is participant
- Handle empty conversations gracefully"
```

---

### 1.2: Update processAI Router (15 minutes)

#### Modify processAI.ts
- [ ] Open `functions/src/ai/processAI.ts`
- [ ] Add import:
```typescript
import { summarizeConversation } from './decisionSummary';
```

- [ ] Add route in switch statement:
```typescript
case 'decision_summary':
  const { conversationId } = data;
  
  if (!conversationId || typeof conversationId !== 'string') {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'conversationId is required'
    );
  }
  
  const summary = await summarizeConversation(
    conversationId,
    userId,
    openai
  );
  
  return {
    feature: 'decision_summary',
    result: summary,
    timestamp: Date.now()
  };
```

**Checkpoint:** TypeScript compiles without errors ✓

**Commit:**
```bash
git add functions/src/ai/processAI.ts
git commit -m "feat(ai): add decision_summary route to processAI

- Route decision_summary requests to summarizeConversation()
- Validate conversationId parameter
- Return structured summary result"
```

---

### 1.3: Deploy Cloud Functions (10 minutes)

#### Deploy to Firebase
- [ ] Build TypeScript:
```bash
cd functions
npm run build
```

- [ ] Deploy to Firebase:
```bash
firebase deploy --only functions:processAI
```

- [ ] Wait for deployment (1-2 minutes)
- [ ] Verify deployment successful:
```bash
firebase functions:list
# Should show: processAI(us-central1)
```

**Checkpoint:** Cloud Function deployed successfully ✓

**Commit:**
```bash
git add functions/lib/  # Compiled JS
git commit -m "deploy(functions): deploy decision summary to Firebase

- processAI updated with decision_summary route
- Deployed to us-central1
- Ready for iOS integration"
```

---

### 1.4: Test Cloud Function (15 minutes)

#### Manual Test via Test Button
- [ ] Open iOS app in Xcode
- [ ] Run on simulator
- [ ] Login to app
- [ ] Navigate to ChatListView
- [ ] Tap purple CPU test button
- [ ] Select "Test Decision Summary"
- [ ] Observe alert with results
- [ ] Verify response contains:
  - summary (string)
  - decisions (array)
  - actionItems (array)
  - keyPoints (array)
  - messageCount (number)

**Expected Response:**
```json
{
  "feature": "decision_summary",
  "result": {
    "summary": "This is a placeholder summary...",
    "decisions": [],
    "actionItems": [],
    "keyPoints": [],
    "messageCount": 0
  }
}
```

**Checkpoint:** Cloud Function responds successfully ✓

---

## Phase 2: iOS Models (45 minutes)

### 2.1: Create ConversationSummary Model (25 minutes)

#### Create File
- [ ] Create `messAI/Models/ConversationSummary.swift`

#### Implement Model
- [ ] Add imports:
```swift
import Foundation
import FirebaseFirestore
```

- [ ] Implement ConversationSummary struct (~150 lines):
```swift
struct ConversationSummary: Codable, Identifiable, Equatable {
    let id: String // conversationId
    let summary: String
    let decisions: [String]
    let actionItems: [ActionItem]
    let keyPoints: [String]
    let messageCount: Int
    let createdAt: Date
    let createdBy: String
    
    // Computed properties
    var hasDecisions: Bool { !decisions.isEmpty }
    var hasActionItems: Bool { !actionItems.isEmpty }
    var hasKeyPoints: Bool { !keyPoints.isEmpty }
    var isEmpty: Bool { !hasDecisions && !hasActionItems && !hasKeyPoints }
    
    var formattedCreatedAt: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }
    
    // Firestore conversion
    func toFirestore() -> [String: Any] {
        return [
            "id": id,
            "summary": summary,
            "decisions": decisions,
            "actionItems": actionItems.map { $0.toFirestore() },
            "keyPoints": keyPoints,
            "messageCount": messageCount,
            "createdAt": Timestamp(date: createdAt),
            "createdBy": createdBy
        ]
    }
    
    static func fromFirestore(_ data: [String: Any], id: String) -> ConversationSummary? {
        guard
            let summary = data["summary"] as? String,
            let decisions = data["decisions"] as? [String],
            let actionItemsData = data["actionItems"] as? [[String: Any]],
            let keyPoints = data["keyPoints"] as? [String],
            let messageCount = data["messageCount"] as? Int,
            let timestamp = data["createdAt"] as? Timestamp,
            let createdBy = data["createdBy"] as? String
        else { return nil }
        
        let actionItems = actionItemsData.compactMap { ActionItem.fromFirestore($0) }
        
        return ConversationSummary(
            id: id,
            summary: summary,
            decisions: decisions,
            actionItems: actionItems,
            keyPoints: keyPoints,
            messageCount: messageCount,
            createdAt: timestamp.dateValue(),
            createdBy: createdBy
        )
    }
}
```

**Checkpoint:** File compiles without errors ✓

**Commit:**
```bash
git add messAI/Models/ConversationSummary.swift
git commit -m "feat(models): add ConversationSummary model

- Codable for API responses
- Firestore conversion helpers
- Computed properties for display
- isEmpty, hasDecisions, etc."
```

---

### 2.2: Create ActionItem Model (20 minutes)

#### Create File
- [ ] Create `messAI/Models/ActionItem.swift`

#### Implement Model
- [ ] Add imports and struct (~100 lines):
```swift
import Foundation
import SwiftUI
import FirebaseFirestore

struct ActionItem: Codable, Identifiable, Equatable, Hashable {
    let id: String
    let text: String
    let assignedTo: String?
    let dueDate: Date?
    let priority: Priority
    
    enum Priority: String, Codable, CaseIterable {
        case high, medium, low
        
        var emoji: String {
            switch self {
            case .high: return "🔴"
            case .medium: return "🟡"
            case .low: return "⚪"
            }
        }
        
        var color: Color {
            switch self {
            case .high: return .red
            case .medium: return .orange
            case .low: return .gray
            }
        }
    }
    
    var isOverdue: Bool {
        guard let dueDate = dueDate else { return false }
        return dueDate < Date()
    }
    
    var formattedDueDate: String? {
        guard let dueDate = dueDate else { return nil }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: dueDate)
    }
    
    // Firestore conversion
    func toFirestore() -> [String: Any] {
        var data: [String: Any] = [
            "id": id,
            "text": text,
            "priority": priority.rawValue
        ]
        
        if let assignedTo = assignedTo {
            data["assignedTo"] = assignedTo
        }
        
        if let dueDate = dueDate {
            data["dueDate"] = Timestamp(date: dueDate)
        }
        
        return data
    }
    
    static func fromFirestore(_ data: [String: Any]) -> ActionItem? {
        guard
            let id = data["id"] as? String,
            let text = data["text"] as? String,
            let priorityRaw = data["priority"] as? String,
            let priority = Priority(rawValue: priorityRaw)
        else { return nil }
        
        let assignedTo = data["assignedTo"] as? String
        let dueDate = (data["dueDate"] as? Timestamp)?.dateValue()
        
        return ActionItem(
            id: id,
            text: text,
            assignedTo: assignedTo,
            dueDate: dueDate,
            priority: priority
        )
    }
}
```

**Checkpoint:** File compiles without errors ✓

**Commit:**
```bash
git add messAI/Models/ActionItem.swift
git commit -m "feat(models): add ActionItem model with priority levels

- High/medium/low priority with emoji and color
- Optional assignedTo and dueDate fields
- Firestore conversion helpers
- Computed properties (isOverdue, formattedDueDate)"
```

---

## Phase 3: AIService Extension (60 minutes)

### 3.1: Add summarizeConversation Method (40 minutes)

#### Modify AIService.swift
- [ ] Open `messAI/Services/AIService.swift`
- [ ] Add cache property at top of class:
```swift
// Summary caching (5-minute TTL)
private var summaryCache: [String: CachedSummary] = [:]

private struct CachedSummary {
    let summary: ConversationSummary
    let timestamp: Date
}
```

- [ ] Add method (~100 lines):
```swift
func summarizeConversation(conversationId: String) async throws -> ConversationSummary {
    print("📊 AIService: Requesting summary for conversation \(conversationId)")
    
    // Check cache first (5-minute TTL)
    if let cached = summaryCache[conversationId],
       Date().timeIntervalSince(cached.timestamp) < 300 {
        print("✅ AIService: Using cached summary")
        return cached.summary
    }
    
    // Get auth token
    guard let user = Auth.auth().currentUser else {
        throw AIError.notAuthenticated
    }
    
    let token = try await user.getIDToken()
    
    // Build request
    let url = URL(string: "\(functionsURL)/processAI")!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.timeoutInterval = 30 // GPT-4 can be slow
    
    let requestBody: [String: Any] = [
        "feature": "decision_summary",
        "conversationId": conversationId
    ]
    
    request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
    
    // Make request
    let startTime = Date()
    let (data, response) = try await URLSession.shared.data(for: request)
    let duration = Date().timeIntervalSince(startTime)
    
    print("⏱️ AIService: Summary request took \(String(format: "%.2f", duration))s")
    
    // Check response
    guard let httpResponse = response as? HTTPURLResponse else {
        throw AIError.invalidResponse
    }
    
    guard (200...299).contains(httpResponse.statusCode) else {
        let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
        throw AIError.serverError(errorMessage)
    }
    
    // Parse response
    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
    guard let resultData = json?["result"] as? [String: Any] else {
        throw AIError.invalidResponse
    }
    
    // Extract summary data
    guard let summary = resultData["summary"] as? String,
          let decisions = resultData["decisions"] as? [String],
          let actionItemsData = resultData["actionItems"] as? [[String: Any]],
          let keyPoints = resultData["keyPoints"] as? [String],
          let messageCount = resultData["messageCount"] as? Int else {
        throw AIError.invalidResponse
    }
    
    // Parse action items
    let actionItems = actionItemsData.compactMap { itemData -> ActionItem? in
        guard let text = itemData["text"] as? String,
              let priorityStr = itemData["priority"] as? String,
              let priority = ActionItem.Priority(rawValue: priorityStr) else {
            return nil
        }
        
        let assignedTo = itemData["assignedTo"] as? String
        let dueDate: Date? = {
            if let dateStr = itemData["dueDate"] as? String,
               let date = ISO8601DateFormatter().date(from: dateStr) {
                return date
            }
            return nil
        }()
        
        return ActionItem(
            id: UUID().uuidString,
            text: text,
            assignedTo: assignedTo,
            dueDate: dueDate,
            priority: priority
        )
    }
    
    // Create ConversationSummary
    let conversationSummary = ConversationSummary(
        id: conversationId,
        summary: summary,
        decisions: decisions,
        actionItems: actionItems,
        keyPoints: keyPoints,
        messageCount: messageCount,
        createdAt: Date(),
        createdBy: user.uid
    )
    
    // Cache result
    summaryCache[conversationId] = CachedSummary(
        summary: conversationSummary,
        timestamp: Date()
    )
    
    print("✅ AIService: Summary generated successfully (\(messageCount) messages)")
    
    return conversationSummary
}
```

**Checkpoint:** File compiles without errors ✓

**Commit:**
```bash
git add messAI/Services/AIService.swift
git commit -m "feat(ai): add summarizeConversation method to AIService

- Calls decision_summary Cloud Function
- 5-minute caching (prevents duplicate calls)
- 30-second timeout for slow GPT-4 responses
- Parses action items with priority/dueDate
- Returns structured ConversationSummary"
```

---

### 3.2: Test AIService Method (20 minutes)

#### Unit Test
- [ ] Add test call in ChatViewModel (temporary):
```swift
func testSummaryGeneration() async {
    print("🧪 Testing summary generation...")
    
    do {
        let summary = try await AIService.shared.summarizeConversation(
            conversationId: conversationId
        )
        
        print("✅ Summary generated:")
        print("  - Summary: \(summary.summary)")
        print("  - Decisions: \(summary.decisions.count)")
        print("  - Action Items: \(summary.actionItems.count)")
        print("  - Key Points: \(summary.keyPoints.count)")
        print("  - Message Count: \(summary.messageCount)")
    } catch {
        print("❌ Summary generation failed: \(error)")
    }
}
```

- [ ] Run app in simulator
- [ ] Call testSummaryGeneration() from ChatView
- [ ] Verify output in console
- [ ] Check that second call uses cache (instant)

**Checkpoint:** AIService method works end-to-end ✓

---

## Phase 4: ChatViewModel Integration (45 minutes)

### 4.1: Add Summary State Management (30 minutes)

#### Modify ChatViewModel.swift
- [ ] Open `messAI/ViewModels/ChatViewModel.swift`
- [ ] Add import:
```swift
import FirebaseFirestore
```

- [ ] Add state properties:
```swift
// Summary state
enum SummaryState {
    case idle
    case loading
    case success(ConversationSummary)
    case error(String)
}

@Published var summaryState: SummaryState = .idle
@Published var showSummary: Bool = false
```

- [ ] Add requestSummary method (~50 lines):
```swift
@MainActor
func requestSummary() async {
    print("📊 ChatViewModel: Requesting conversation summary...")
    
    // Set loading state
    summaryState = .loading
    showSummary = true
    
    do {
        // Call AIService
        let summary = try await AIService.shared.summarizeConversation(
            conversationId: conversationId
        )
        
        // Update state
        summaryState = .success(summary)
        
        // Save to Firestore (background)
        Task {
            await saveSummaryToFirestore(summary)
        }
        
        print("✅ ChatViewModel: Summary loaded successfully")
        
    } catch {
        print("❌ ChatViewModel: Summary failed - \(error.localizedDescription)")
        
        // Update state with error
        let errorMessage: String
        if let aiError = error as? AIError {
            errorMessage = aiError.localizedDescription
        } else {
            errorMessage = "Failed to generate summary. Please try again."
        }
        
        summaryState = .error(errorMessage)
    }
}

private func saveSummaryToFirestore(_ summary: ConversationSummary) async {
    do {
        try await Firestore.firestore()
            .collection("summaries")
            .document(conversationId)
            .setData(summary.toFirestore())
        
        print("✅ ChatViewModel: Summary saved to Firestore")
    } catch {
        print("❌ ChatViewModel: Failed to save summary: \(error)")
        // Non-fatal - summary still works in-memory
    }
}

func dismissSummary() {
    showSummary = false
}
```

**Checkpoint:** File compiles without errors ✓

**Commit:**
```bash
git add messAI/ViewModels/ChatViewModel.swift
git commit -m "feat(chat): add summary state management to ChatViewModel

- SummaryState enum (idle/loading/success/error)
- requestSummary() method with AIService integration
- saveSummaryToFirestore() for persistence
- dismissSummary() to hide card"
```

---

### 4.2: Test ChatViewModel Integration (15 minutes)

#### Test in Simulator
- [ ] Run app
- [ ] Navigate to a conversation
- [ ] Call viewModel.requestSummary() (temporary button)
- [ ] Observe state transitions:
  - summaryState = .loading
  - 2-3 second delay
  - summaryState = .success(summary)
- [ ] Verify Firestore document created:
  - Open Firebase Console → Firestore
  - Check /summaries/{conversationId} document exists

**Checkpoint:** ChatViewModel integration works ✓

---

## Phase 5: UI Components (60 minutes)

### 5.1: Create DecisionSummaryCardView (40 minutes)

#### Create File
- [ ] Create `messAI/Views/Chat/DecisionSummaryCardView.swift`

#### Implement View (~250 lines)
- [ ] Add imports:
```swift
import SwiftUI
```

- [ ] Implement DecisionSummaryCardView:
```swift
struct DecisionSummaryCardView: View {
    let summary: ConversationSummary
    let onDismiss: () -> Void
    
    @State private var expandedSections: Set<SummarySection> = [.decisions, .actionItems, .keyPoints]
    
    enum SummarySection: String, CaseIterable, Hashable {
        case decisions = "Decisions Made"
        case actionItems = "Action Items"
        case keyPoints = "Key Points"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            headerView
            
            Divider()
            
            // Main summary text
            Text(summary.summary)
                .font(.body)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
            
            // Collapsible sections
            if summary.hasDecisions {
                decisionsSection
            }
            
            if summary.hasActionItems {
                actionItemsSection
            }
            
            if summary.hasKeyPoints {
                keyPointsSection
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 4)
        .padding(.horizontal)
        .padding(.top, 8)
    }
    
    private var headerView: some View {
        HStack {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.title2)
                .foregroundColor(.blue)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Summary")
                    .font(.headline)
                
                Text("Last \(summary.messageCount) messages • \(summary.formattedCreatedAt)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var decisionsSection: some View {
        CollapsibleSection(
            title: "Decisions Made",
            icon: "checkmark.circle.fill",
            iconColor: .green,
            isExpanded: expandedSections.contains(.decisions)
        ) {
            toggleSection(.decisions)
        } content: {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(summary.decisions, id: \.self) { decision in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                        
                        Text(decision)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                    }
                }
            }
        }
    }
    
    private var actionItemsSection: some View {
        CollapsibleSection(
            title: "Action Items",
            icon: "list.bullet.circle.fill",
            iconColor: .orange,
            isExpanded: expandedSections.contains(.actionItems)
        ) {
            toggleSection(.actionItems)
        } content: {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(summary.actionItems) { item in
                    ActionItemRow(item: item)
                }
            }
        }
    }
    
    private var keyPointsSection: some View {
        CollapsibleSection(
            title: "Key Points",
            icon: "info.circle.fill",
            iconColor: .blue,
            isExpanded: expandedSections.contains(.keyPoints)
        ) {
            toggleSection(.keyPoints)
        } content: {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(summary.keyPoints, id: \.self) { point in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.blue)
                            .font(.caption)
                        
                        Text(point)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                    }
                }
            }
        }
    }
    
    private func toggleSection(_ section: SummarySection) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            if expandedSections.contains(section) {
                expandedSections.remove(section)
            } else {
                expandedSections.insert(section)
            }
        }
    }
}

// Helper views
struct CollapsibleSection<Content: View>: View {
    let title: String
    let icon: String
    let iconColor: Color
    let isExpanded: Bool
    let onTap: () -> Void
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Section header (tappable)
            Button(action: onTap) {
                HStack {
                    Image(systemName: icon)
                        .foregroundColor(iconColor)
                    
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
            
            // Section content (collapsible)
            if isExpanded {
                content()
                    .padding(.leading, 24)
            }
        }
        .padding(.vertical, 4)
    }
}

struct ActionItemRow: View {
    let item: ActionItem
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(item.priority.emoji)
                .font(.caption)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.text)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                
                HStack(spacing: 12) {
                    if let assignedTo = item.assignedTo {
                        Label(assignedTo, systemImage: "person.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if let dueDate = item.formattedDueDate {
                        Label(dueDate, systemImage: "calendar")
                            .font(.caption)
                            .foregroundColor(item.isOverdue ? .red : .secondary)
                    }
                }
            }
        }
        .padding(8)
        .background(item.priority.color.opacity(0.1))
        .cornerRadius(8)
    }
}

// Preview
struct DecisionSummaryCardView_Previews: PreviewProvider {
    static var previews: some View {
        DecisionSummaryCardView(
            summary: ConversationSummary(
                id: "test",
                summary: "The group discussed the upcoming field trip and made several important decisions.",
                decisions: [
                    "Field trip will be on Friday, October 27th",
                    "Parents need to sign permission slips by Wednesday"
                ],
                actionItems: [
                    ActionItem(id: "1", text: "Sarah will bring snacks", assignedTo: "Sarah", dueDate: Date().addingTimeInterval(86400), priority: .high),
                    ActionItem(id: "2", text: "Everyone RSVP by Wednesday", assignedTo: nil, dueDate: Date().addingTimeInterval(172800), priority: .medium)
                ],
                keyPoints: [
                    "Bus departs at 8:30am sharp",
                    "Cost is $15 per student"
                ],
                messageCount: 47,
                createdAt: Date(),
                createdBy: "user123"
            ),
            onDismiss: {}
        )
        .padding()
    }
}
```

**Checkpoint:** File compiles without errors ✓

**Commit:**
```bash
git add messAI/Views/Chat/DecisionSummaryCardView.swift
git commit -m "feat(ui): add DecisionSummaryCardView component

- Frosted glass card with header and dismiss button
- Collapsible sections (decisions, action items, key points)
- ActionItemRow with priority emoji and due dates
- Smooth animations (spring animation)
- SwiftUI preview for testing"
```

---

### 5.2: Integrate Summary Card into ChatView (20 minutes)

#### Modify ChatView.swift
- [ ] Open `messAI/Views/Chat/ChatView.swift`
- [ ] Add "Summarize" button to toolbar:
```swift
.toolbar {
    // Existing toolbar items...
    
    ToolbarItem(placement: .navigationBarTrailing) {
        Button(action: {
            Task {
                await viewModel.requestSummary()
            }
        }) {
            Image(systemName: "doc.text.magnifyingglass")
        }
        .disabled(viewModel.summaryState == .loading)
    }
}
```

- [ ] Add summary card display at top of ScrollView:
```swift
ScrollView {
    // Summary card (if visible)
    if viewModel.showSummary {
        switch viewModel.summaryState {
        case .loading:
            ProgressView("Analyzing \(viewModel.messages.count) messages...")
                .frame(maxWidth: .infinity)
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(16)
                .padding(.horizontal)
                .padding(.top, 8)
            
        case .success(let summary):
            DecisionSummaryCardView(
                summary: summary,
                onDismiss: {
                    viewModel.dismissSummary()
                }
            )
            
        case .error(let message):
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.largeTitle)
                    .foregroundColor(.red)
                
                Text("Summary Failed")
                    .font(.headline)
                
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                Button("Dismiss") {
                    viewModel.dismissSummary()
                }
                .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(16)
            .padding(.horizontal)
            .padding(.top, 8)
            
        case .idle:
            EmptyView()
        }
    }
    
    // Existing messages LazyVStack...
}
```

**Checkpoint:** File compiles without errors ✓

**Commit:**
```bash
git add messAI/Views/Chat/ChatView.swift
git commit -m "feat(chat): integrate summary card into ChatView

- Add 'Summarize' button to toolbar (doc.text.magnifyingglass icon)
- Display summary card at top of ScrollView
- Show loading state (ProgressView) while generating
- Show error state with retry option
- Disable button while loading"
```

---

## Phase 6: Integration Testing (30 minutes)

### 6.1: End-to-End Test (20 minutes)

#### Test Scenario 1: First Summary Generation
- [ ] Run app on simulator
- [ ] Login to app
- [ ] Navigate to group chat with 50+ messages
- [ ] Tap "Summarize" button (doc.text.magnifyingglass icon)
- [ ] Observe loading state (ProgressView, "Analyzing X messages...")
- [ ] Wait 2-3 seconds
- [ ] Verify summary card appears:
  - Header shows message count and timestamp
  - Summary text (2-3 sentences)
  - Decisions section (if any)
  - Action Items section (if any)
  - Key Points section (if any)
- [ ] Tap sections to collapse/expand (smooth animation)
- [ ] Verify action items show:
  - Priority emoji (🔴/🟡/⚪)
  - Assigned person (if specified)
  - Due date (if specified)
- [ ] Tap "x" to dismiss
- [ ] Verify card disappears

**Expected Result:** Summary generates successfully and displays ✓

---

#### Test Scenario 2: Cached Summary (Instant)
- [ ] Immediately tap "Summarize" button again
- [ ] Observe NO loading state (instant)
- [ ] Verify same summary appears
- [ ] Check console: "✅ AIService: Using cached summary"

**Expected Result:** Second request uses cache (instant) ✓

---

#### Test Scenario 3: Empty Conversation
- [ ] Navigate to conversation with 0 messages
- [ ] Tap "Summarize" button
- [ ] Verify error message: "No messages to summarize"

**Expected Result:** Handles empty conversations gracefully ✓

---

#### Test Scenario 4: Firestore Persistence
- [ ] Generate summary for a conversation
- [ ] Open Firebase Console → Firestore
- [ ] Navigate to /summaries collection
- [ ] Find document with conversationId
- [ ] Verify fields:
  - id (conversationId)
  - summary (string)
  - decisions (array)
  - actionItems (array with objects)
  - keyPoints (array)
  - messageCount (number)
  - createdAt (timestamp)
  - createdBy (userId)

**Expected Result:** Summary saved to Firestore ✓

---

### 6.2: Performance Testing (10 minutes)

#### Test Latency
- [ ] Measure summary generation time:
  - 10 messages: <2 seconds
  - 50 messages: <5 seconds (cold start), <1 second (cached)
- [ ] Check console logs for timing:
  ```
  ⏱️ AIService: Summary request took 2.43s
  ```

**Expected Result:** Meets performance targets ✓

---

#### Test Cost Estimation
- [ ] Generate 5 summaries
- [ ] Calculate approximate cost:
  - 50 messages ≈ 2,000 tokens input
  - 300 tokens output
  - GPT-4 pricing: $0.03/1K input, $0.06/1K output
  - Cost per summary: ~$0.06
- [ ] Verify rate limiting working (100 req/hour)

**Expected Result:** Cost within budget ✓

---

## Completion Checklist

### Code Complete
- [ ] All 6 phases implemented
- [ ] All files compile without errors
- [ ] All test scenarios pass
- [ ] Performance targets met (summary <5s cold, <1s cached)
- [ ] No console errors or warnings

### Documentation
- [ ] Code comments added to complex functions
- [ ] SwiftUI previews working
- [ ] Firestore schema documented

### Testing
- [ ] End-to-end flow tested (summarize → display → dismiss)
- [ ] Edge cases tested (empty conversation, errors)
- [ ] Caching tested (second request instant)
- [ ] Firestore persistence tested
- [ ] Performance tested (latency, cost)

### Final Commit & Merge
```bash
# Final commit
git add .
git commit -m "feat(ai): complete decision summarization feature (PR#16)

Features delivered:
- Cloud Function with GPT-4 integration
- ConversationSummary and ActionItem models
- AIService.summarizeConversation() with caching
- DecisionSummaryCardView UI component
- ChatViewModel integration
- Firestore persistence

Time: 3.5 hours actual
Status: All tests passing, ready for production

Closes #16"

# Push to GitHub
git push origin feature/pr16-decision-summarization

# Merge to main
git checkout main
git merge feature/pr16-decision-summarization
git push origin main
```

---

## Success Metrics

**Time Tracking:**
- Phase 1 (Cloud Function): _____ minutes (target: 60)
- Phase 2 (Models): _____ minutes (target: 45)
- Phase 3 (AIService): _____ minutes (target: 60)
- Phase 4 (ChatViewModel): _____ minutes (target: 45)
- Phase 5 (UI): _____ minutes (target: 60)
- Phase 6 (Testing): _____ minutes (target: 30)
- **Total**: _____ hours (target: 3-4 hours)

**Quality Metrics:**
- Bugs encountered: _____
- Build failures: _____
- Test scenarios passed: _____ / 4
- Performance met: ✅ / ❌
- Cost within budget: ✅ / ❌

---

**PR#16 Implementation Complete!** 🎉

Next: Write `PR16_COMPLETE_SUMMARY.md` with retrospective and lessons learned.


