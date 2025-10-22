# PR#17: Priority Highlighting - Implementation Checklist

**Use this as your daily todo list.** Check off items as you complete them.

**Estimated Time:** 2-3 hours  
**Status:** ⏳ NOT STARTED

---

## Pre-Implementation Setup (10 minutes)

- [ ] Read main planning document `PR17_PRIORITY_HIGHLIGHTING.md` (~45 min)
- [ ] Review PR#14 (Cloud Functions) to understand AI infrastructure
- [ ] Review PR#16 (Decision Summarization) for similar AI pattern
- [ ] Verify prerequisites:
  - [ ] PR#14 complete (Cloud Functions deployed)
  - [ ] OpenAI API key configured in Firebase Functions
  - [ ] Firebase CLI installed (`firebase --version`)
  - [ ] Xcode project builds successfully
- [ ] Create git branch:
  ```bash
  git checkout -b feature/pr17-priority-highlighting
  ```
- [ ] Commit initial state:
  ```bash
  git add .
  git commit -m "[PR#17] Start priority highlighting feature"
  ```

---

## Phase 1: Cloud Function - Priority Detection (45 minutes)

### 1.1: Create Priority Detection Function (30 min)

#### Create File
- [ ] Create `functions/src/ai/priorityDetection.ts`

#### Add Imports
- [ ] Add imports:
  ```typescript
  import * as functions from 'firebase-functions';
  import * as admin from 'firebase-admin';
  ```

#### Define Urgency Keywords
- [ ] Add critical keywords array:
  ```typescript
  const CRITICAL_KEYWORDS = [
    'emergency', 'urgent', 'asap', 'immediately', 'right now',
    'critical', 'serious', 'help', '911', 'sos'
  ];
  ```
- [ ] Add high priority keywords array:
  ```typescript
  const HIGH_KEYWORDS = [
    'important', 'soon', 'today', 'tonight', 'this morning',
    'this afternoon', 'this evening', 'deadline', 'due',
    'reminder', 'don\\'t forget', 'please', 'needs', 'required'
  ];
  ```
- [ ] Add time-sensitive patterns:
  ```typescript
  const TIME_SENSITIVE_PATTERNS = [
    /\b(pickup|pick up|pick-up)\s+(at|by|changed|moved)\s+\d{1,2}(:\d{2})?\s*(am|pm|today)/i,
    /\b(meeting|appointment)\s+(at|by)\s+\d{1,2}(:\d{2})?\s*(am|pm)/i,
    /\b(due|deadline|submit)\s+(by|before|today|tonight)/i,
    /\b(canceled|cancelled|postponed|rescheduled)/i,
    /\b(last chance|final notice)/i
  ];
  ```

#### Implement Main Detection Function
- [ ] Create `detectPriority()` function:
  ```typescript
  export async function detectPriority(
    messageText: string,
    recentMessages: any[],
    conversationId: string
  ): Promise<PriorityDetectionResponse> {
    // Step 1: Quick keyword filter
    const keywordResult = await keywordBasedDetection(messageText);
    
    // If clearly normal, skip GPT-4
    if (keywordResult.level === 'normal' && keywordResult.confidence > 0.8) {
      return keywordResult;
    }
    
    // Step 2: GPT-4 context analysis
    const gpt4Result = await gpt4BasedDetection(
      messageText,
      recentMessages,
      keywordResult.keywords
    );
    
    // Combine results
    if (gpt4Result.confidence > 0.7) {
      return gpt4Result;
    }
    
    return keywordResult;
  }
  ```

#### Implement Keyword Detection
- [ ] Create `keywordBasedDetection()` function:
  ```typescript
  async function keywordBasedDetection(text: string): Promise<PriorityDetectionResponse> {
    const lowerText = text.toLowerCase();
    const detectedKeywords: string[] = [];
    
    // Check critical keywords
    for (const keyword of CRITICAL_KEYWORDS) {
      if (lowerText.includes(keyword)) {
        detectedKeywords.push(keyword);
      }
    }
    
    // Check time-sensitive patterns
    for (const pattern of TIME_SENSITIVE_PATTERNS) {
      if (pattern.test(text)) {
        detectedKeywords.push('time-sensitive-pattern');
      }
    }
    
    if (detectedKeywords.length > 0) {
      return {
        priorityLevel: 'critical',
        confidence: Math.min(0.6 + (detectedKeywords.length * 0.1), 0.9),
        reason: `Contains urgent keywords: ${detectedKeywords.join(', ')}`,
        keywords: detectedKeywords,
        timeContext: {
          isToday: /\b(today|tonight|this morning|this afternoon)\b/i.test(text),
          isImmediate: /\b(now|right now|asap|immediately)\b/i.test(text)
        }
      };
    }
    
    // Check high priority keywords
    for (const keyword of HIGH_KEYWORDS) {
      if (lowerText.includes(keyword)) {
        detectedKeywords.push(keyword);
      }
    }
    
    if (detectedKeywords.length > 0) {
      return {
        priorityLevel: 'high',
        confidence: Math.min(0.5 + (detectedKeywords.length * 0.1), 0.8),
        reason: `Contains important keywords: ${detectedKeywords.join(', ')}`,
        keywords: detectedKeywords
      };
    }
    
    return {
      priorityLevel: 'normal',
      confidence: 0.85,
      reason: 'No urgency indicators detected',
      keywords: []
    };
  }
  ```

#### Implement GPT-4 Detection
- [ ] Create `gpt4BasedDetection()` function:
  ```typescript
  async function gpt4BasedDetection(
    messageText: string,
    recentMessages: any[],
    detectedKeywords: string[]
  ): Promise<PriorityDetectionResponse> {
    
    const openai = getOpenAIClient();
    
    // Build context
    const contextMessages = recentMessages
      .slice(-10)
      .map(msg => `${msg.senderName}: ${msg.text}`)
      .join('\n');
    
    const prompt = `You are an AI assistant helping busy parents identify urgent messages in group chats.

**Recent conversation context:**
${contextMessages}

**New message to analyze:**
"${messageText}"

**Detected keywords:** ${detectedKeywords.join(', ') || 'None'}

**Task:** Classify urgency level (critical/high/normal) based on:
1. **Critical** = Immediate action required + time-sensitive + consequences
2. **High** = Important but not emergency + needs attention soon
3. **Normal** = Everything else

Return ONLY a JSON object:
{
  "priorityLevel": "critical" | "high" | "normal",
  "confidence": <0.0-1.0>,
  "reason": "<brief explanation>",
  "keywords": [<detected urgency indicators>],
  "timeContext": {
    "isToday": <boolean>,
    "isImmediate": <boolean>,
    "deadline": "<time if applicable>"
  }
}`;

    const completion = await openai.chat.completions.create({
      model: 'gpt-4',
      messages: [
        { role: 'system', content: 'You are a helpful assistant that classifies message urgency.' },
        { role: 'user', content: prompt }
      ],
      temperature: 0.3,
      max_tokens: 200
    });
    
    const responseText = completion.choices[0].message.content || '{}';
    const result = JSON.parse(responseText);
    
    return {
      priorityLevel: result.priorityLevel || 'normal',
      confidence: result.confidence || 0.5,
      reason: result.reason || 'GPT-4 classification',
      keywords: result.keywords || detectedKeywords,
      timeContext: result.timeContext
    };
  }
  ```

#### Add OpenAI Client
- [ ] Create `getOpenAIClient()` helper:
  ```typescript
  let openaiClient: any = null;
  function getOpenAIClient() {
    if (!openaiClient) {
      const { OpenAI } = require('openai');
      openaiClient = new OpenAI({
        apiKey: functions.config().openai.key
      });
    }
    return openaiClient;
  }
  ```

#### Add TypeScript Interface
- [ ] Define response type:
  ```typescript
  interface PriorityDetectionResponse {
    priorityLevel: 'critical' | 'high' | 'normal';
    confidence: number;
    reason: string;
    keywords: string[];
    timeContext?: {
      isToday: boolean;
      isImmediate: boolean;
      deadline?: string;
    };
  }
  ```

**Checkpoint:** Priority detection function complete ✓

**Test:**
- [ ] Function compiles without errors
- [ ] Keyword detection works (test with "urgent", "today", "asap")
- [ ] Time patterns work (test with "pickup at 2pm today")
- [ ] Normal messages return "normal" level

---

### 1.2: Add Route to processAI Router (15 min)

#### Update Router
- [ ] Open `functions/src/ai/processAI.ts`
- [ ] Add import:
  ```typescript
  import { detectPriority } from './priorityDetection';
  ```
- [ ] Add case to feature router:
  ```typescript
  case 'priority_detection': {
    const { messageText, messageId, recentMessages } = data.data;
    
    const result = await detectPriority(
      messageText,
      recentMessages || [],
      data.conversationId
    );
    
    return {
      result: {
        priorityLevel: result.priorityLevel,
        confidence: result.confidence,
        reason: result.reason,
        keywords: result.keywords,
        timeContext: result.timeContext
      },
      cached: false,
      timestamp: Date.now()
    };
  }
  ```

**Checkpoint:** Route added to processAI ✓

**Test:**
- [ ] Router compiles without errors
- [ ] New route accessible

**Commit:**
```bash
git add functions/src/ai/priorityDetection.ts functions/src/ai/processAI.ts
git commit -m "[PR#17] Add Cloud Function for priority detection (hybrid keyword + GPT-4)"
```

---

## Phase 2: iOS Models - Priority Data Structures (15 minutes)

### 2.1: Create PriorityLevel Enum (10 min)

#### Create File
- [ ] Create `Models/PriorityLevel.swift`

#### Implement Enum
- [ ] Add import: `import SwiftUI`
- [ ] Define enum:
  ```swift
  enum PriorityLevel: String, Codable {
      case critical   // 🔴 Immediate action required
      case high       // 🟡 Important but not emergency
      case normal     // No special urgency
      
      var color: Color {
          switch self {
          case .critical: return .red
          case .high: return .orange
          case .normal: return .clear
          }
      }
      
      var borderWidth: CGFloat {
          switch self {
          case .critical: return 3.0
          case .high: return 2.0
          case .normal: return 0.0
          }
      }
      
      var badgeIcon: String? {
          switch self {
          case .critical: return "exclamationmark.triangle.fill"
          case .high: return "exclamationmark.circle.fill"
          case .normal: return nil
          }
      }
      
      var badgeColor: Color {
          switch self {
          case .critical: return .white
          case .high: return .white
          case .normal: return .clear
          }
      }
      
      var displayName: String {
          switch self {
          case .critical: return "Critical"
          case .high: return "High Priority"
          case .normal: return "Normal"
          }
      }
      
      var description: String {
          switch self {
          case .critical: return "Immediate action required"
          case .high: return "Needs attention soon"
          case .normal: return "No special urgency"
          }
      }
  }
  ```

**Checkpoint:** PriorityLevel enum complete ✓

**Test:**
- [ ] File compiles without errors
- [ ] Can create instances: `let level = PriorityLevel.critical`
- [ ] Properties accessible: `level.color`, `level.badgeIcon`

---

### 2.2: Extend AIMetadata with Priority Fields (5 min)

#### Update AIMetadata
- [ ] Open `Models/AIMetadata.swift`
- [ ] Add priority fields:
  ```swift
  // Priority Detection (PR#17)
  var priorityLevel: PriorityLevel?
  var priorityConfidence: Double?        // 0.0-1.0
  var priorityReason: String?            // Why AI classified this way
  var priorityDetectedAt: Date?
  var priorityDismissed: Bool?           // User dismissed urgent indicator
  var priorityKeywords: [String]?        // Detected keywords
  ```

**Checkpoint:** AIMetadata updated with priority fields ✓

**Test:**
- [ ] File compiles without errors
- [ ] Can encode/decode with priority fields

**Commit:**
```bash
git add Models/PriorityLevel.swift Models/AIMetadata.swift
git commit -m "[PR#17] Add PriorityLevel enum and extend AIMetadata with priority fields"
```

---

## Phase 3: iOS AI Service - Priority Detection Method (20 minutes)

### 3.1: Add detectPriority() to AIService (20 min)

#### Open AIService
- [ ] Open `Services/AIService.swift`

#### Add Detection Result Struct
- [ ] Add at bottom of file:
  ```swift
  struct PriorityDetectionResult {
      let priorityLevel: PriorityLevel
      let confidence: Double
      let reason: String
      let keywords: [String]
      let detectedAt: Date
  }
  ```

#### Implement Detection Method
- [ ] Add method to AIService extension:
  ```swift
  /// Detect priority/urgency level of a message
  func detectPriority(
      for message: Message,
      recentMessages: [Message]
  ) async throws -> PriorityDetectionResult {
      
      // Check cache first (5-minute TTL)
      let cacheKey = "priority_\(message.id)"
      if let cached = responseCache[cacheKey] as? PriorityDetectionResult,
         Date().timeIntervalSince(cached.detectedAt) < 300 {
          print("AIService: Using cached priority result")
          return cached
      }
      
      // Prepare request
      let requestData: [String: Any] = [
          "feature": "priority_detection",
          "conversationId": message.conversationId,
          "data": [
              "messageText": message.text,
              "messageId": message.id,
              "senderId": message.senderId,
              "sentAt": message.sentAt.timeIntervalSince1970,
              "recentMessages": recentMessages.suffix(10).map { [
                  "text": $0.text,
                  "senderName": $0.senderName ?? "Unknown",
                  "sentAt": $0.sentAt.timeIntervalSince1970
              ]}
          ]
      ]
      
      print("AIService: Detecting priority for message: \(message.id)")
      
      do {
          let result = try await functions.httpsCallable("processAI").call(requestData)
          
          guard let data = result.data as? [String: Any],
                let priorityData = data["result"] as? [String: Any] else {
              throw AIError.invalidResponse
          }
          
          // Parse response
          let priorityLevelStr = priorityData["priorityLevel"] as? String ?? "normal"
          let priorityLevel = PriorityLevel(rawValue: priorityLevelStr) ?? .normal
          let confidence = priorityData["confidence"] as? Double ?? 0.0
          let reason = priorityData["reason"] as? String ?? "AI classification"
          let keywords = priorityData["keywords"] as? [String] ?? []
          
          let detectionResult = PriorityDetectionResult(
              priorityLevel: priorityLevel,
              confidence: confidence,
              reason: reason,
              keywords: keywords,
              detectedAt: Date()
          )
          
          // Cache result
          responseCache[cacheKey] = detectionResult
          
          print("AIService: Priority detected: \(priorityLevel.rawValue) (confidence: \(confidence))")
          
          return detectionResult
          
      } catch let error as NSError {
          print("AIService: Priority detection failed: \(error.localizedDescription)")
          throw AIError.from(error)
      }
  }
  ```

**Checkpoint:** AIService.detectPriority() complete ✓

**Test:**
- [ ] File compiles without errors
- [ ] Method signature correct
- [ ] Can call from ChatViewModel

**Commit:**
```bash
git add Services/AIService.swift
git commit -m "[PR#17] Add detectPriority() method to AIService with caching"
```

---

## Phase 4: Enhanced Message Bubble UI (30 minutes)

### 4.1: Add Priority Border to MessageBubbleView (20 min)

#### Open MessageBubbleView
- [ ] Open `Views/Chat/MessageBubbleView.swift`

#### Add Priority Border Overlay
- [ ] Find the message bubble VStack
- [ ] Add `.overlay()` modifier after `.clipShape()`:
  ```swift
  .overlay(priorityBorder)
  ```

#### Implement Priority Border View
- [ ] Add computed property:
  ```swift
  private var priorityBorder: some View {
      Group {
          if let priority = message.aiMetadata?.priorityLevel,
             priority != .normal {
              RoundedRectangle(cornerRadius: 18)
                  .strokeBorder(priority.color, lineWidth: priority.borderWidth)
          }
      }
  }
  ```

**Checkpoint:** Priority border displays ✓

**Test:**
- [ ] Message with priority = critical shows red border (3pt)
- [ ] Message with priority = high shows orange border (2pt)
- [ ] Message with priority = normal shows no border
- [ ] Border doesn't interfere with message text readability

---

### 4.2: Add Priority Badge (10 min)

#### Add Badge Below Bubble
- [ ] After the bubble VStack, add:
  ```swift
  // Priority badge (if critical/high)
  if let priority = message.aiMetadata?.priorityLevel,
     priority != .normal {
      priorityBadge(for: priority)
  }
  ```

#### Implement Badge View
- [ ] Add method:
  ```swift
  @ViewBuilder
  private func priorityBadge(for level: PriorityLevel) -> some View {
      HStack(spacing: 4) {
          if let icon = level.badgeIcon {
              Image(systemName: icon)
                  .font(.caption2)
                  .foregroundColor(level.badgeColor)
          }
          
          Text(level.displayName)
              .font(.caption2)
              .fontWeight(.semibold)
          
          if let confidence = message.aiMetadata?.priorityConfidence {
              Text("(\(Int(confidence * 100))%)")
                  .font(.caption2)
                  .foregroundColor(.secondary)
          }
      }
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
      .background(level.color.opacity(0.15))
      .clipShape(Capsule())
  }
  ```

**Checkpoint:** Priority badge displays ✓

**Test:**
- [ ] Badge shows for critical messages (🚨 + "Critical" + confidence)
- [ ] Badge shows for high messages (⚠️ + "High Priority" + confidence)
- [ ] Badge doesn't show for normal messages
- [ ] Badge is readable and visually distinct

**Commit:**
```bash
git add Views/Chat/MessageBubbleView.swift
git commit -m "[PR#17] Add priority border and badge to MessageBubbleView"
```

---

## Phase 5: Priority Banner (In-Chat Urgent Section) (30 minutes)

### 5.1: Create PriorityBannerView (25 min)

#### Create File
- [ ] Create `Views/Chat/PriorityBannerView.swift`

#### Add Imports
- [ ] Add imports:
  ```swift
  import SwiftUI
  ```

#### Implement Main View
- [ ] Create struct:
  ```swift
  struct PriorityBannerView: View {
      let urgentMessages: [Message]
      @Binding var isExpanded: Bool
      let onMessageTap: (Message) -> Void
      let onDismiss: () -> Void
      
      var body: some View {
          VStack(spacing: 0) {
              // Header (always visible)
              Button(action: { withAnimation { isExpanded.toggle() } }) {
                  HStack {
                      Image(systemName: "exclamationmark.triangle.fill")
                          .foregroundColor(.red)
                      
                      VStack(alignment: .leading, spacing: 2) {
                          Text("\(urgentMessages.count) urgent message\(urgentMessages.count == 1 ? "" : "s")")
                              .font(.subheadline)
                              .fontWeight(.semibold)
                          
                          if !isExpanded {
                              Text("Tap to view")
                                  .font(.caption)
                                  .foregroundColor(.secondary)
                          }
                      }
                      
                      Spacer()
                      
                      Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                          .foregroundColor(.secondary)
                  }
                  .padding()
                  .background(Color.red.opacity(0.1))
              }
              .buttonStyle(.plain)
              
              // Expanded content
              if isExpanded {
                  Divider()
                  
                  ScrollView {
                      LazyVStack(spacing: 8) {
                          ForEach(urgentMessages) { message in
                              UrgentMessageRow(message: message, onTap: {
                                  onMessageTap(message)
                              })
                          }
                      }
                      .padding()
                  }
                  .frame(maxHeight: 300)
                  
                  Divider()
                  
                  Button(action: onDismiss) {
                      Text("Mark all as seen")
                          .font(.footnote)
                          .foregroundColor(.blue)
                          .frame(maxWidth: .infinity)
                          .padding(.vertical, 8)
                  }
              }
          }
          .background(Color(.systemBackground))
          .clipShape(RoundedRectangle(cornerRadius: 12))
          .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
          .padding(.horizontal)
          .padding(.top, 8)
      }
  }
  ```

#### Create UrgentMessageRow Component
- [ ] Add struct:
  ```swift
  struct UrgentMessageRow: View {
      let message: Message
      let onTap: () -> Void
      
      var body: some View {
          Button(action: onTap) {
              HStack(alignment: .top, spacing: 12) {
                  Circle()
                      .fill(message.aiMetadata?.priorityLevel?.color ?? .gray)
                      .frame(width: 8, height: 8)
                      .padding(.top, 6)
                  
                  VStack(alignment: .leading, spacing: 4) {
                      HStack {
                          Text(message.senderDisplayName)
                              .font(.caption)
                              .fontWeight(.semibold)
                          
                          Spacer()
                          
                          Text(message.sentAt.formatted(date: .omitted, time: .shortened))
                              .font(.caption2)
                              .foregroundColor(.secondary)
                      }
                      
                      Text(message.text)
                          .font(.subheadline)
                          .lineLimit(2)
                          .foregroundColor(.primary)
                      
                      if let reason = message.aiMetadata?.priorityReason {
                          Text(reason)
                              .font(.caption2)
                              .foregroundColor(.secondary)
                              .italic()
                      }
                  }
                  
                  Image(systemName: "chevron.right")
                      .font(.caption)
                      .foregroundColor(.secondary)
              }
              .padding()
              .background(Color(.secondarySystemBackground))
              .clipShape(RoundedRectangle(cornerRadius: 8))
          }
          .buttonStyle(.plain)
      }
  }
  ```

**Checkpoint:** PriorityBannerView complete ✓

**Test:**
- [ ] Banner displays with correct urgent message count
- [ ] Expand/collapse animation smooth
- [ ] Tap on message row works
- [ ] "Mark all as seen" button works
- [ ] Scrolling works with many urgent messages

---

### 5.2: Integrate Banner into ChatView (5 min)

#### Open ChatView
- [ ] Open `Views/Chat/ChatView.swift`

#### Add State Variable
- [ ] Add to ChatView:
  ```swift
  @State private var isPriorityBannerExpanded = false
  ```

#### Add Banner Above Messages
- [ ] In ScrollView, before ForEach(messages):
  ```swift
  // Priority banner (if urgent messages exist)
  if !viewModel.urgentMessages.isEmpty {
      PriorityBannerView(
          urgentMessages: viewModel.urgentMessages,
          isExpanded: $isPriorityBannerExpanded,
          onMessageTap: { message in
              // Scroll to message
              scrollTo(messageId: message.id)
              isPriorityBannerExpanded = false
          },
          onDismiss: {
              viewModel.markUrgentMessagesAsSeen()
              isPriorityBannerExpanded = false
          }
      )
  }
  ```

#### Add Helper Method
- [ ] Add to ChatView:
  ```swift
  private func scrollTo(messageId: String) {
      withAnimation {
          scrollProxy?.scrollTo(messageId, anchor: .center)
      }
  }
  ```

**Checkpoint:** Priority banner integrated into chat ✓

**Test:**
- [ ] Banner appears when urgent messages exist
- [ ] Tapping message scrolls to it in chat
- [ ] Dismiss marks messages as seen
- [ ] Banner disappears when no urgent messages

**Commit:**
```bash
git add Views/Chat/PriorityBannerView.swift Views/Chat/ChatView.swift
git commit -m "[PR#17] Add collapsible priority banner to chat view"
```

---

## Phase 6: ChatViewModel - Priority Detection Logic (30 minutes)

### 6.1: Add Priority Detection to ChatViewModel (30 min)

#### Open ChatViewModel
- [ ] Open `ViewModels/ChatViewModel.swift`

#### Add State Properties
- [ ] Add to class:
  ```swift
  @Published var urgentMessages: [Message] = []
  @Published var isPriorityDetectionEnabled = true
  ```

#### Implement Priority Detection Method
- [ ] Add method:
  ```swift
  /// Detect priority for new message
  func detectPriorityIfNeeded(for message: Message) {
      // Skip if disabled
      guard isPriorityDetectionEnabled else { return }
      
      // Skip if already has priority
      guard message.aiMetadata?.priorityLevel == nil else { return }
      
      // Skip if from current user
      guard message.senderId != AuthService.shared.currentUser?.id else { return }
      
      Task {
          do {
              let recentMessages = messages.suffix(10).map { $0 }
              let result = try await aiService.detectPriority(
                  for: message,
                  recentMessages: Array(recentMessages)
              )
              
              // Update message in Firestore
              try await updateMessagePriority(
                  messageId: message.id,
                  level: result.priorityLevel,
                  confidence: result.confidence,
                  reason: result.reason,
                  keywords: result.keywords
              )
              
          } catch {
              print("ChatViewModel: Priority detection failed: \(error)")
          }
      }
  }
  ```

#### Implement Update Method
- [ ] Add method:
  ```swift
  /// Update message priority in Firestore
  private func updateMessagePriority(
      messageId: String,
      level: PriorityLevel,
      confidence: Double,
      reason: String,
      keywords: [String]
  ) async throws {
      let messageRef = firestore
          .collection("conversations")
          .document(conversationId)
          .collection("messages")
          .document(messageId)
      
      try await messageRef.updateData([
          "aiMetadata.priorityLevel": level.rawValue,
          "aiMetadata.priorityConfidence": confidence,
          "aiMetadata.priorityReason": reason,
          "aiMetadata.priorityKeywords": keywords,
          "aiMetadata.priorityDetectedAt": Date(),
          "aiMetadata.priorityDismissed": false
      ])
      
      print("ChatViewModel: Updated priority for message \(messageId): \(level.rawValue)")
  }
  ```

#### Add to Message Listener
- [ ] In existing message listener, after adding new message:
  ```swift
  // Trigger priority detection for new messages
  detectPriorityIfNeeded(for: message)
  ```

#### Add Urgent Messages Filter
- [ ] Add computed property:
  ```swift
  /// Filtered view of urgent messages (critical/high, not dismissed)
  private var computedUrgentMessages: [Message] {
      messages.filter { message in
          guard let priority = message.aiMetadata?.priorityLevel else { return false }
          guard priority != .normal else { return false }
          guard message.aiMetadata?.priorityDismissed != true else { return false }
          return true
      }
  }
  ```

#### Update urgentMessages on Change
- [ ] In message listener, after updating `messages`:
  ```swift
  self.urgentMessages = self.computedUrgentMessages
  ```

#### Implement Mark as Seen
- [ ] Add method:
  ```swift
  /// Mark all urgent messages as seen (dismissed)
  func markUrgentMessagesAsSeen() {
      Task {
          for message in urgentMessages {
              try? await firestore
                  .collection("conversations")
                  .document(conversationId)
                  .collection("messages")
                  .document(message.id)
                  .updateData([
                      "aiMetadata.priorityDismissed": true
                  ])
          }
          
          // Update local state
          urgentMessages = []
      }
  }
  ```

**Checkpoint:** ChatViewModel priority logic complete ✓

**Test:**
- [ ] New messages trigger priority detection
- [ ] Priority updates saved to Firestore
- [ ] urgentMessages array updates correctly
- [ ] Mark as seen works

**Commit:**
```bash
git add ViewModels/ChatViewModel.swift
git commit -m "[PR#17] Add priority detection logic to ChatViewModel with auto-trigger"
```

---

## Phase 7: Testing & Validation (30 minutes)

### 7.1: Cloud Function Tests (10 min)

#### Test Keyword Detection
- [ ] Test critical keywords:
  - Input: "urgent pickup change"
  - Expected: priorityLevel = "critical"
- [ ] Test high keywords:
  - Input: "important reminder for tomorrow"
  - Expected: priorityLevel = "high"
- [ ] Test normal message:
  - Input: "sounds good, thanks!"
  - Expected: priorityLevel = "normal"
- [ ] Test time patterns:
  - Input: "pickup at 2pm today"
  - Expected: priorityLevel = "critical", timeContext.isToday = true

#### Test GPT-4 Fallback
- [ ] Test ambiguous message:
  - Input: "Noah needs something by this afternoon"
  - Expected: GPT-4 analyzes context, returns high or critical

**Checkpoint:** Cloud Function tests pass ✓

---

### 7.2: iOS Integration Tests (10 min)

#### Test End-to-End Flow
- [ ] Send test message with "urgent" keyword
- [ ] Verify Cloud Function called
- [ ] Verify response received
- [ ] Verify Firestore updated with priority
- [ ] Verify UI updates (border + badge appear)

#### Test UI Components
- [ ] Critical message shows red border (3pt) + 🚨 badge
- [ ] High message shows orange border (2pt) + ⚠️ badge
- [ ] Normal message shows no indicators
- [ ] Priority banner appears when urgent messages exist
- [ ] Banner expand/collapse works smoothly
- [ ] Tap message in banner scrolls to message

**Checkpoint:** Integration tests pass ✓

---

### 7.3: Accuracy Testing (10 min)

#### Test Real-World Messages
- [ ] Test 10 critical messages (all should be flagged)
  - "Pickup changed to 2pm TODAY"
  - "Emergency - school closed"
  - "Payment due by 5pm today or late fee"
  - "URGENT: Noah needs medication at school"
  - [Add 6 more real examples]

- [ ] Test 10 normal messages (none should be flagged)
  - "Thanks everyone!"
  - "Sounds good"
  - "Anyone bringing cookies Friday?"
  - [Add 7 more real examples]

- [ ] Calculate metrics:
  - True positive rate: ___% (target: >80%)
  - False negative rate: ___% (target: <5%)
  - False positive rate: ___% (acceptable if <20%)

**Checkpoint:** Accuracy meets targets ✓

---

## Phase 8: Deploy & Document (10 minutes)

### 8.1: Deploy Cloud Functions (5 min)

- [ ] Deploy to Firebase:
  ```bash
  cd functions
  npm run build
  firebase deploy --only functions:processAI
  ```
- [ ] Verify deployment:
  ```bash
  firebase functions:list
  ```
- [ ] Test deployed function from iOS app

**Checkpoint:** Cloud Functions deployed ✓

---

### 8.2: Update Documentation (5 min)

- [ ] Update `PR_PARTY/README.md`:
  - Mark PR#17 as COMPLETE
  - Add time taken (actual vs estimated)
  - Add completion date

- [ ] Update `memory-bank/activeContext.md`:
  - Move PR#17 from "In Progress" to "Completed"
  - Add completion summary

- [ ] Update `memory-bank/progress.md`:
  - Mark PR#17 tasks as complete
  - Update completion percentage

**Checkpoint:** Documentation updated ✓

**Commit:**
```bash
git add PR_PARTY/README.md memory-bank/
git commit -m "[PR#17] Update documentation - PR#17 complete"
```

---

## Completion Checklist

**Feature is complete when:**

- [ ] ✅ Cloud Function deployed with priority detection
- [ ] ✅ iOS can call detectPriority() and receive PriorityLevel
- [ ] ✅ Message bubbles display priority border + badge correctly
- [ ] ✅ Priority banner appears in chat for urgent messages
- [ ] ✅ Banner expand/collapse works smoothly
- [ ] ✅ Tap message in banner scrolls to message in chat
- [ ] ✅ Mark as seen dismisses urgent indicators
- [ ] ✅ Classification accuracy >80% true positive, <5% false negative
- [ ] ✅ Performance: Keyword check <100ms, GPT-4 <3s
- [ ] ✅ Firestore schema updated (aiMetadata.priorityLevel)
- [ ] ✅ All builds successful (0 errors, 0 warnings)
- [ ] ✅ Documentation updated (README, memory bank)
- [ ] ✅ Commit messages clear and descriptive

**Performance Verified:**
- [ ] Keyword detection <100ms (tested with 10 messages)
- [ ] GPT-4 detection <3s (tested with 5 messages)
- [ ] Cache hit rate >60% (tested with repeated messages)
- [ ] Cost estimate: <$2/month/user at 100 messages/day

**Quality Verified:**
- [ ] UI works in light and dark mode
- [ ] Accessibility: Border + icon (colorblind friendly)
- [ ] No console errors or warnings
- [ ] Firestore security rules allow priority updates
- [ ] No memory leaks (Instruments verified)

---

## Final Commit & Merge

- [ ] Final commit:
  ```bash
  git add .
  git commit -m "[PR#17] Priority highlighting feature complete - AI-powered urgent message detection"
  ```

- [ ] Merge to main:
  ```bash
  git checkout main
  git merge feature/pr17-priority-highlighting
  git push
  ```

- [ ] Delete feature branch (optional):
  ```bash
  git branch -d feature/pr17-priority-highlighting
  ```

---

## 🎉 Celebration!

**PR#17 Complete!** You've built an AI-powered system that helps busy parents never miss urgent messages. This is a safety feature that prevents real-world problems (late pickups, missed deadlines).

**Key Achievement:** Hybrid keyword + GPT-4 approach provides 80% cost savings while maintaining high accuracy.

**Next Steps:** PR#18 (RSVP Tracking) or PR#19 (Deadline Extraction)

---

**Remember:** "False negatives are NOT OK (missing urgent messages), false positives are OK (extra red borders)." Tune for safety, not perfection.
