# PR#19: Deadline Extraction - Implementation Checklist

**Use this as your daily todo list.** Check off items as you complete them.

**Estimated Total Time**: 3-4 hours  
**Complexity**: MEDIUM-HIGH

---

## Pre-Implementation Setup (10 minutes)

- [ ] **Read planning documents** (~45 min)
  - [ ] Main spec: `PR19_DEADLINE_EXTRACTION.md`
  - [ ] Quick start: `PR19_README.md`
  - [ ] Testing guide: `PR19_TESTING_GUIDE.md`

- [ ] **Verify dependencies** (5 min)
  - [ ] PR#14 (Cloud Functions) 100% complete ✅
  - [ ] PR#15 (Calendar Extraction) 100% complete ✅
  - [ ] OpenAI API key configured in Cloud Functions
  - [ ] Firebase billing enabled (Blaze plan)

- [ ] **Create feature branch** (2 min)
  ```bash
  cd /Users/ijaramil/Documents/GauntletAI/Week2/messAI
  git checkout main
  git pull origin main
  git checkout -b feature/pr19-deadline-extraction
  ```

- [ ] **Open relevant files in editor** (3 min)
  - `functions/src/ai/` folder
  - `messAI/Models/` folder
  - `messAI/ViewModels/` folder
  - `messAI/Views/` folder

---

## Phase 1: Cloud Function - Deadline Detection (60-90 minutes)

### 1.1: Create deadlineExtraction.ts (45 min)

- [ ] **Create new file**: `functions/src/ai/deadlineExtraction.ts`

- [ ] **Add imports**
  ```typescript
  import { openai } from '../config/openai';
  import { CallableContext } from 'firebase-functions/v2/https';
  import * as admin from 'firebase-admin';
  ```

- [ ] **Define keyword patterns** (10 min)
  ```typescript
  const DEADLINE_KEYWORDS = [
    'due', 'deadline', 'by', 'before', 'closes', 'ends',
    'submit', 'turn in', 'expires', 'last day', 'final day',
    'no later than', 'cut-off', 'must', 'need to', 'has to'
  ];
  
  const DATE_PATTERNS = [
    /\b(monday|tuesday|wednesday|thursday|friday|saturday|sunday)\b/i,
    /\b(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\s+\d{1,2}/i,
    /\b\d{1,2}\/\d{1,2}\b/,
    /\b(today|tomorrow|tonight|this week|next week)\b/i
  ];
  ```

- [ ] **Implement keyword pre-filter** (10 min)
  ```typescript
  function containsDeadlineKeywords(text: string): boolean {
    const lowerText = text.toLowerCase();
    const hasKeyword = DEADLINE_KEYWORDS.some(kw => lowerText.includes(kw));
    const hasDate = DATE_PATTERNS.some(pattern => pattern.test(text));
    return hasKeyword && hasDate;
  }
  ```

- [ ] **Define GPT-4 extraction function** (25 min)
  ```typescript
  export async function extractDeadline(
    messageText: string,
    conversationId: string,
    context: CallableContext
  ) {
    // 1. Keyword pre-filter
    if (!containsDeadlineKeywords(messageText)) {
      return {
        success: false,
        reason: 'no_deadline_keywords',
        method: 'keyword_filter'
      };
    }
  
    // 2. GPT-4 extraction
    const completion = await openai.chat.completions.create({
      model: "gpt-4",
      messages: [
        {
          role: "system",
          content: "You are a deadline extraction assistant. Extract deadline information from messages. Be specific about dates and times. Return confidence score 0.0-1.0. If no clear deadline exists, set hasDeadline to false."
        },
        {
          role: "user",
          content: `Extract deadline from this message: "${messageText}"\n\nCurrent date: ${new Date().toISOString()}`
        }
      ],
      functions: [{
        name: "extract_deadline",
        description: "Extract deadline information from a message",
        parameters: {
          type: "object",
          properties: {
            hasDeadline: {
              type: "boolean",
              description: "Whether a deadline exists in the message"
            },
            title: {
              type: "string",
              description: "Short title for the deadline (e.g., 'Permission slip', 'RSVP')"
            },
            dueDate: {
              type: "string",
              format: "date-time",
              description: "ISO 8601 deadline date/time"
            },
            isAllDay: {
              type: "boolean",
              description: "Whether the deadline is for a specific time or all-day"
            },
            priority: {
              type: "string",
              enum: ["high", "medium", "low"],
              description: "Priority level based on deadline urgency and context"
            },
            confidence: {
              type: "number",
              minimum: 0,
              maximum: 1,
              description: "Confidence score (0.0-1.0) in the extraction accuracy"
            },
            description: {
              type: "string",
              description: "Optional additional details about the deadline"
            }
          },
          required: ["hasDeadline"]
        }
      }],
      function_call: { name: "extract_deadline" }
    });
  
    // 3. Parse response
    const functionCall = completion.choices[0].message.function_call;
    if (!functionCall || !functionCall.arguments) {
      return { success: false, reason: 'no_function_call' };
    }
  
    const result = JSON.parse(functionCall.arguments);
  
    if (!result.hasDeadline) {
      return { success: false, reason: 'no_deadline_detected' };
    }
  
    // 4. Calculate status
    const dueDate = new Date(result.dueDate);
    const now = new Date();
    const hoursUntil = (dueDate.getTime() - now.getTime()) / (1000 * 60 * 60);
  
    let status: string;
    if (hoursUntil < 0) {
      status = 'overdue';
    } else if (hoursUntil < 24) {
      status = 'today';
    } else {
      status = 'upcoming';
    }
  
    // 5. Return structured deadline
    return {
      success: true,
      deadline: {
        title: result.title,
        dueDate: result.dueDate,
        isAllDay: result.isAllDay || false,
        priority: result.priority || 'medium',
        confidence: result.confidence,
        description: result.description || null,
        status: status,
        method: 'gpt4'
      }
    };
  }
  ```

**Checkpoint 1.1**: Function extracts deadlines from test messages  
**Test**: `"Permission slip due Wednesday by 3pm"` → Returns structured deadline

**Commit**: `feat(pr19): implement GPT-4 deadline extraction function`

---

### 1.2: Add route to processAI.ts (15 min)

- [ ] **Open**: `functions/src/ai/processAI.ts`

- [ ] **Import deadline extraction**
  ```typescript
  import { extractDeadline } from './deadlineExtraction';
  ```

- [ ] **Add route case** (in switch statement)
  ```typescript
  case 'deadline_extraction':
    const messageText = data.messageText;
    const conversationId = data.conversationId;
    
    if (!messageText || typeof messageText !== 'string') {
      throw new HttpsError('invalid-argument', 'messageText is required');
    }
    
    result = await extractDeadline(messageText, conversationId, context);
    break;
  ```

**Checkpoint 1.2**: Route added and ready to deploy  
**Test**: Compile check with `npm run build`

**Commit**: `feat(pr19): add deadline_extraction route to AI router`

---

### 1.3: Deploy Cloud Function (30 min)

- [ ] **Build functions**
  ```bash
  cd functions
  npm run build
  ```

- [ ] **Deploy to Firebase**
  ```bash
  firebase deploy --only functions
  ```

- [ ] **Verify deployment**
  ```bash
  firebase functions:list
  # Look for processAI in list
  ```

- [ ] **Test with curl** (15 min)
  ```bash
  # Get auth token from Firebase Console or using firebase CLI
  
  curl -X POST \
    https://us-central1-messageai-95c8f.cloudfunctions.net/processAI \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer YOUR_ID_TOKEN" \
    -d '{
      "feature": "deadline_extraction",
      "messageText": "Permission slip due Wednesday by 3pm",
      "conversationId": "test_conv_123"
    }'
  ```

- [ ] **Expected response**:
  ```json
  {
    "success": true,
    "deadline": {
      "title": "Permission slip",
      "dueDate": "2025-03-15T15:00:00Z",
      "isAllDay": false,
      "priority": "high",
      "confidence": 0.92,
      "status": "upcoming",
      "method": "gpt4"
    }
  }
  ```

**Checkpoint 1.3**: Cloud Function deployed and tested  
**Phase 1 Complete**: ✅ Deadline extraction working on backend

**Commit**: `feat(pr19): deploy deadline extraction Cloud Function`

---

## Phase 2: iOS Models (45-60 minutes)

### 2.1: Create Deadline.swift (35 min)

- [ ] **Create new file**: `messAI/Models/Deadline.swift`

- [ ] **Add imports**
  ```swift
  import Foundation
  import FirebaseFirestore
  import SwiftUI
  ```

- [ ] **Define Deadline struct** (25 min)
  ```swift
  struct Deadline: Codable, Identifiable, Equatable {
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
          let components = Calendar.current.dateComponents([.day], from: Date(), to: dueDate)
          return components.day ?? 0
      }
      
      var hoursRemaining: Int {
          let components = Calendar.current.dateComponents([.hour], from: Date(), to: dueDate)
          return components.hour ?? 0
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
              if hoursRemaining > 0 {
                  return "\(hoursRemaining) hours remaining"
              } else {
                  return "Due today"
              }
          } else {
              let days = daysRemaining
              if days == 1 {
                  return "Tomorrow"
              } else {
                  return "\(days) days remaining"
              }
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
      
      var urgencyLevel: UrgencyLevel {
          if isOverdue {
              return .critical
          } else if isToday {
              return .urgent
          } else if daysRemaining <= 2 {
              return .high
          } else if daysRemaining <= 7 {
              return .medium
          } else {
              return .low
          }
      }
  }
  
  enum UrgencyLevel {
      case critical, urgent, high, medium, low
      
      var color: Color {
          switch self {
          case .critical: return .red
          case .urgent: return .orange
          case .high: return .yellow
          case .medium: return .blue
          case .low: return .gray
          }
      }
  }
  ```

- [ ] **Add Firestore conversion** (10 min)
  ```swift
  extension Deadline {
      init?(from dict: [String: Any]) {
          guard
              let id = dict["id"] as? String,
              let conversationId = dict["conversationId"] as? String,
              let messageId = dict["messageId"] as? String,
              let extractedFrom = dict["extractedFrom"] as? String,
              let title = dict["title"] as? String,
              let dueDate = (dict["dueDate"] as? Timestamp)?.dateValue(),
              let isAllDay = dict["isAllDay"] as? Bool,
              let priorityString = dict["priority"] as? String,
              let priority = PriorityLevel(rawValue: priorityString),
              let statusString = dict["status"] as? String,
              let status = DeadlineStatus(rawValue: statusString),
              let confidence = dict["confidence"] as? Double,
              let method = dict["method"] as? String,
              let extractedBy = dict["extractedBy"] as? String,
              let extractedAt = (dict["extractedAt"] as? Timestamp)?.dateValue()
          else {
              return nil
          }
          
          self.id = id
          self.conversationId = conversationId
          self.messageId = messageId
          self.extractedFrom = extractedFrom
          self.title = title
          self.description = dict["description"] as? String
          self.dueDate = dueDate
          self.isAllDay = isAllDay
          self.priority = priority
          self.status = status
          self.confidence = confidence
          self.method = method
          self.extractedBy = extractedBy
          self.extractedAt = extractedAt
          self.reminderSent = dict["reminderSent"] as? Bool ?? false
      }
      
      func toFirestore() -> [String: Any] {
          var dict: [String: Any] = [
              "id": id,
              "conversationId": conversationId,
              "messageId": messageId,
              "extractedFrom": extractedFrom,
              "title": title,
              "dueDate": Timestamp(date: dueDate),
              "isAllDay": isAllDay,
              "priority": priority.rawValue,
              "status": status.rawValue,
              "confidence": confidence,
              "method": method,
              "extractedBy": extractedBy,
              "extractedAt": Timestamp(date: extractedAt),
              "reminderSent": reminderSent
          ]
          
          if let description = description {
              dict["description"] = description
          }
          
          return dict
      }
  }
  ```

**Checkpoint 2.1**: Deadline model compiles and converts to/from Firestore  
**Test**: Build project (`Cmd+B`)

**Commit**: `feat(pr19): add Deadline model with computed properties`

---

### 2.2: Create DeadlineStatus.swift (10 min)

- [ ] **Create new file**: `messAI/Models/DeadlineStatus.swift`

- [ ] **Define enums**
  ```swift
  import SwiftUI
  
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
          case .overdue: return "exclamationmark.triangle.fill"
          case .completed: return "checkmark.circle.fill"
          }
      }
      
      var displayName: String {
          switch self {
          case .upcoming: return "Upcoming"
          case .today: return "Today"
          case .overdue: return "Overdue"
          case .completed: return "Completed"
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
      
      var icon: String {
          switch self {
          case .high: return "exclamationmark.3"
          case .medium: return "exclamationmark.2"
          case .low: return "exclamationmark"
          }
      }
  }
  ```

**Checkpoint 2.2**: Enums compile and provide display properties  
**Phase 2 Complete**: ✅ iOS models ready

**Commit**: `feat(pr19): add DeadlineStatus and PriorityLevel enums`

---

## Phase 3: Deadline Service (30-45 minutes)

### 3.1: Create DeadlineService.swift (45 min)

- [ ] **Create new file**: `messAI/Services/DeadlineService.swift`

- [ ] **Add imports**
  ```swift
  import Foundation
  import FirebaseFirestore
  import Combine
  ```

- [ ] **Implement service class** (40 min)
  ```swift
  class DeadlineService {
      private let db = Firestore.firestore()
      
      // MARK: - Create
      func createDeadline(_ deadline: Deadline) async throws {
          try db.collection("deadlines")
              .document(deadline.id)
              .setData(deadline.toFirestore())
      }
      
      // MARK: - Read (Real-time stream)
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
                          Deadline(from: doc.data())
                      }
                      
                      continuation.yield(deadlines)
                  }
              
              continuation.onTermination = { _ in
                  listener.remove()
              }
          }
      }
      
      // MARK: - Fetch deadlines for conversation
      func fetchDeadlines(for conversationId: String) async throws -> [Deadline] {
          let snapshot = try await db.collection("deadlines")
              .whereField("conversationId", isEqualTo: conversationId)
              .whereField("status", in: ["upcoming", "today", "overdue"])
              .order(by: "dueDate")
              .getDocuments()
          
          return snapshot.documents.compactMap { doc in
              Deadline(from: doc.data())
          }
      }
      
      // MARK: - Update
      func markComplete(_ deadlineId: String) async throws {
          try await db.collection("deadlines")
              .document(deadlineId)
              .updateData([
                  "status": "completed",
                  "completedAt": Timestamp(date: Date())
              ])
      }
      
      func updateStatus(_ deadlineId: String, status: DeadlineStatus) async throws {
          try await db.collection("deadlines")
              .document(deadlineId)
              .updateData(["status": status.rawValue])
      }
      
      // MARK: - Delete
      func deleteDeadline(_ deadlineId: String) async throws {
          try await db.collection("deadlines")
              .document(deadlineId)
              .delete()
      }
      
      // MARK: - Batch operations
      func markAllComplete(for userId: String) async throws {
          let snapshot = try await db.collection("deadlines")
              .whereField("extractedBy", isEqualTo: userId)
              .whereField("status", in: ["upcoming", "today", "overdue"])
              .getDocuments()
          
          let batch = db.batch()
          snapshot.documents.forEach { doc in
              batch.updateData(["status": "completed"], forDocument: doc.reference)
          }
          
          try await batch.commit()
      }
      
      func clearCompleted(for userId: String) async throws {
          let snapshot = try await db.collection("deadlines")
              .whereField("extractedBy", isEqualTo: userId)
              .whereField("status", isEqualTo: "completed")
              .getDocuments()
          
          let batch = db.batch()
          snapshot.documents.forEach { doc in
              batch.deleteDocument(doc.reference)
          }
          
          try await batch.commit()
      }
  }
  ```

**Checkpoint 3.1**: Service compiles and provides CRUD operations  
**Phase 3 Complete**: ✅ Deadline service ready

**Commit**: `feat(pr19): implement DeadlineService with Firestore CRUD`

---

## Phase 4: ViewModels (45-60 minutes)

### 4.1: Create DeadlineViewModel (30 min)

- [ ] **Create new file**: `messAI/ViewModels/DeadlineViewModel.swift`

- [ ] **Implement ViewModel**
  ```swift
  import SwiftUI
  import Combine
  
  @MainActor
  class DeadlineViewModel: ObservableObject {
      @Published var deadlines: [Deadline] = []
      @Published var isLoading = false
      @Published var errorMessage: String?
      
      private let deadlineService: DeadlineService
      private let authService: AuthService
      private var cancellables = Set<AnyCancellable>()
      
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
      
      // MARK: - Filtered lists
      var upcomingDeadlines: [Deadline] {
          deadlines
              .filter { $0.status == .upcoming && !$0.isToday }
              .sorted { $0.dueDate < $1.dueDate }
      }
      
      var todayDeadlines: [Deadline] {
          deadlines
              .filter { $0.isToday && $0.status != .completed }
              .sorted { $0.dueDate < $1.dueDate }
      }
      
      var overdueDeadlines: [Deadline] {
          deadlines
              .filter { $0.isOverdue && $0.status != .completed }
              .sorted { $0.dueDate < $1.dueDate }
      }
      
      var completedDeadlines: [Deadline] {
          deadlines
              .filter { $0.status == .completed }
              .sorted { $0.dueDate > $1.dueDate }
      }
      
      // MARK: - Actions
      func markComplete(_ deadlineId: String) {
          Task {
              do {
                  try await deadlineService.markComplete(deadlineId)
              } catch {
                  errorMessage = error.localizedDescription
              }
          }
      }
      
      func markAllComplete() {
          guard let userId = authService.currentUser?.id else { return }
          
          Task {
              do {
                  try await deadlineService.markAllComplete(for: userId)
              } catch {
                  errorMessage = error.localizedDescription
              }
          }
      }
      
      func clearCompleted() {
          guard let userId = authService.currentUser?.id else { return }
          
          Task {
              do {
                  try await deadlineService.clearCompleted(for: userId)
              } catch {
                  errorMessage = error.localizedDescription
              }
          }
      }
      
      func deleteDeadline(_ deadlineId: String) {
          Task {
              do {
                  try await deadlineService.deleteDeadline(deadlineId)
              } catch {
                  errorMessage = error.localizedDescription
              }
          }
      }
  }
  ```

**Checkpoint 4.1**: ViewModel compiles and manages deadline state

**Commit**: `feat(pr19): add DeadlineViewModel for global deadline management`

---

### 4.2: Update ChatViewModel (30 min)

- [ ] **Open**: `messAI/ViewModels/ChatViewModel.swift`

- [ ] **Add deadline properties**
  ```swift
  @Published var extractedDeadlines: [Deadline] = []
  @Published var isExtractingDeadline = false
  ```

- [ ] **Add DeadlineService dependency**
  ```swift
  private let deadlineService: DeadlineService
  
  init(..., deadlineService: DeadlineService) {
      // ... existing init code ...
      self.deadlineService = deadlineService
      
      // ... existing setup ...
  }
  ```

- [ ] **Implement deadline detection** (20 min)
  ```swift
  // MARK: - Deadline Detection
  func detectMessageDeadline(for message: Message) {
      // Keyword pre-filter (client-side)
      guard containsDeadlineKeywords(message.text) else {
          print("❌ No deadline keywords in message")
          return
      }
      
      print("✅ Deadline keywords detected, calling Cloud Function...")
      
      isExtractingDeadline = true
      
      Task {
          do {
              let result = try await aiService.extractDeadline(
                  messageId: message.id,
                  conversationId: conversationId,
                  messageText: message.text
              )
              
              if let deadlineData = result["deadline"] as? [String: Any] {
                  // Create Deadline object
                  guard let title = deadlineData["title"] as? String,
                        let dueDateString = deadlineData["dueDate"] as? String,
                        let dueDate = ISO8601DateFormatter().date(from: dueDateString),
                        let confidence = deadlineData["confidence"] as? Double,
                        let userId = authService.currentUser?.id else {
                      print("❌ Invalid deadline data format")
                      return
                  }
                  
                  let deadline = Deadline(
                      id: UUID().uuidString,
                      conversationId: conversationId,
                      messageId: message.id,
                      extractedFrom: String(message.text.prefix(100)),
                      title: title,
                      description: deadlineData["description"] as? String,
                      dueDate: dueDate,
                      isAllDay: deadlineData["isAllDay"] as? Bool ?? false,
                      priority: PriorityLevel(rawValue: deadlineData["priority"] as? String ?? "medium") ?? .medium,
                      status: DeadlineStatus(rawValue: deadlineData["status"] as? String ?? "upcoming") ?? .upcoming,
                      confidence: confidence,
                      method: deadlineData["method"] as? String ?? "gpt4",
                      extractedBy: userId,
                      extractedAt: Date(),
                      reminderSent: false
                  )
                  
                  // Save to Firestore
                  try await deadlineService.createDeadline(deadline)
                  
                  // Update local state
                  await MainActor.run {
                      extractedDeadlines.append(deadline)
                      isExtractingDeadline = false
                  }
                  
                  print("✅ Deadline extracted and saved: \(title)")
              } else {
                  print("ℹ️ No deadline detected by AI")
                  await MainActor.run {
                      isExtractingDeadline = false
                  }
              }
          } catch {
              print("❌ Deadline extraction error: \(error)")
              await MainActor.run {
                  errorMessage = "Failed to extract deadline: \(error.localizedDescription)"
                  isExtractingDeadline = false
              }
          }
      }
  }
  
  private func containsDeadlineKeywords(_ text: String) -> Bool {
      let keywords = [
          "due", "deadline", "by", "before", "closes", "ends",
          "submit", "turn in", "expires", "last day"
      ]
      let lowerText = text.lowercased()
      return keywords.contains { lowerText.contains($0) }
  }
  
  // Load deadlines for current conversation
  func loadConversationDeadlines() {
      Task {
          do {
              let deadlines = try await deadlineService.fetchDeadlines(for: conversationId)
              await MainActor.run {
                  self.extractedDeadlines = deadlines
              }
          } catch {
              print("❌ Failed to load deadlines: \(error)")
          }
      }
  }
  ```

- [ ] **Trigger detection on new messages** (10 min)
  ```swift
  // In existing message listener or onReceive:
  .onReceive(messagesPublisher) { messages in
      // ... existing code ...
      
      // Auto-detect deadlines on new messages
      if let lastMessage = messages.last,
         lastMessage.senderId != currentUserId {
          detectMessageDeadline(for: lastMessage)
      }
  }
  ```

**Checkpoint 4.2**: ChatViewModel can detect and save deadlines  
**Phase 4 Complete**: ✅ ViewModels ready

**Commit**: `feat(pr19): add automatic deadline detection to ChatViewModel`

---

## Phase 5: SwiftUI Views (60-90 minutes)

### 5.1: Create DeadlineCardView (30 min)

- [ ] **Create new file**: `messAI/Views/Deadline/DeadlineCardView.swift`

- [ ] **Implement card view**
  ```swift
  import SwiftUI
  
  struct DeadlineCardView: View {
      let deadline: Deadline
      @ObservedObject var viewModel: ChatViewModel
      
      var body: some View {
          VStack(alignment: .leading, spacing: 12) {
              // Header with icon and title
              HStack {
                  Image(systemName: deadline.status.icon)
                      .foregroundColor(deadline.status.color)
                      .font(.title2)
                  
                  VStack(alignment: .leading, spacing: 2) {
                      Text(deadline.title)
                          .font(.headline)
                      
                      Text("Deadline")
                          .font(.caption)
                          .foregroundColor(.secondary)
                  }
                  
                  Spacer()
                  
                  Image(systemName: deadline.priority.icon)
                      .font(.caption)
                      .foregroundColor(deadline.priority.color)
              }
              
              Divider()
              
              // Due date and countdown
              HStack {
                  VStack(alignment: .leading, spacing: 4) {
                      Text(deadline.formattedDueDate)
                          .font(.subheadline)
                      
                      Text(deadline.countdownText)
                          .font(.caption)
                          .foregroundColor(deadline.urgencyLevel.color)
                  }
                  
                  Spacer()
                  
                  // Urgency indicator
                  Text(deadline.countdownText)
                      .font(.caption.bold())
                      .foregroundColor(.white)
                      .padding(.horizontal, 10)
                      .padding(.vertical, 6)
                      .background(deadline.urgencyLevel.color)
                      .cornerRadius(8)
              }
              
              // Description (if present)
              if let description = deadline.description {
                  Text(description)
                      .font(.caption)
                      .foregroundColor(.secondary)
                      .lineLimit(2)
                      .padding(.top, 4)
              }
              
              Divider()
              
              // Actions
              HStack(spacing: 12) {
                  Button(action: { markComplete() }) {
                      Label("Complete", systemImage: "checkmark.circle")
                          .font(.caption)
                  }
                  .buttonStyle(.bordered)
                  .tint(.green)
                  
                  Button(action: { addReminder() }) {
                      Label("Remind", systemImage: "bell")
                          .font(.caption)
                  }
                  .buttonStyle(.bordered)
                  
                  Spacer()
                  
                  Button(action: { dismiss() }) {
                      Image(systemName: "xmark.circle.fill")
                          .foregroundColor(.secondary)
                  }
              }
          }
          .padding()
          .background(Color(.systemBackground))
          .cornerRadius(12)
          .shadow(color: deadline.urgencyLevel.color.opacity(0.3), radius: 4, x: 0, y: 2)
          .overlay(
              RoundedRectangle(cornerRadius: 12)
                  .stroke(deadline.urgencyLevel.color.opacity(0.5), lineWidth: 2)
          )
      }
      
      private func markComplete() {
          Task {
              do {
                  try await viewModel.markDeadlineComplete(deadline.id)
              } catch {
                  print("Error marking deadline complete: \(error)")
              }
          }
      }
      
      private func addReminder() {
          // TODO: Implement reminder (PR#22)
          print("Add reminder for deadline: \(deadline.title)")
      }
      
      private func dismiss() {
          Task {
              do {
                  try await viewModel.dismissDeadline(deadline.id)
              } catch {
                  print("Error dismissing deadline: \(error)")
              }
          }
      }
  }
  
  // MARK: - Preview
  struct DeadlineCardView_Previews: PreviewProvider {
      static var previews: some View {
          DeadlineCardView(
              deadline: Deadline(
                  id: "1",
                  conversationId: "conv1",
                  messageId: "msg1",
                  extractedFrom: "Permission slip due Wednesday",
                  title: "Permission Slip",
                  description: "Field trip permission form",
                  dueDate: Calendar.current.date(byAdding: .day, value: 2, to: Date())!,
                  isAllDay: false,
                  priority: .high,
                  status: .upcoming,
                  confidence: 0.92,
                  method: "gpt4",
                  extractedBy: "user1",
                  extractedAt: Date(),
                  reminderSent: false
              ),
              viewModel: ChatViewModel(/* mock dependencies */)
          )
          .padding()
          .previewLayout(.sizeThatFits)
      }
  }
  ```

**Checkpoint 5.1**: Deadline card displays correctly in preview

**Commit**: `feat(pr19): create DeadlineCardView for in-chat display`

---

### 5.2: Create DeadlineListView (40 min)

- [ ] **Create new file**: `messAI/Views/Deadline/DeadlineListView.swift`

- [ ] **Implement list view**
  ```swift
  import SwiftUI
  
  struct DeadlineListView: View {
      @StateObject var viewModel: DeadlineViewModel
      @State private var selectedFilter: DeadlineFilter = .upcoming
      
      enum DeadlineFilter: String, CaseIterable {
          case upcoming = "Upcoming"
          case today = "Today"
          case overdue = "Overdue"
          case completed = "Completed"
      }
      
      var body: some View {
          NavigationStack {
              VStack(spacing: 0) {
                  // Filter tabs
                  Picker("Filter", selection: $selectedFilter) {
                      ForEach(DeadlineFilter.allCases, id: \.self) { filter in
                          Text(filter.rawValue).tag(filter)
                      }
                  }
                  .pickerStyle(.segmented)
                  .padding()
                  
                  // Content
                  if viewModel.isLoading {
                      ProgressView("Loading deadlines...")
                          .padding()
                  } else if filteredDeadlines.isEmpty {
                      emptyStateView
                  } else {
                      deadlinesList
                  }
              }
              .navigationTitle("Deadlines")
              .toolbar {
                  toolbarMenu
              }
              .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                  Button("OK") {
                      viewModel.errorMessage = nil
                  }
              } message: {
                  Text(viewModel.errorMessage ?? "")
              }
          }
      }
      
      private var deadlinesList: some View {
          List {
              ForEach(filteredDeadlines) { deadline in
                  DeadlineRowView(deadline: deadline)
                      .onTapGesture {
                          // TODO: Navigate to conversation
                          print("Navigate to: \(deadline.conversationId)")
                      }
                      .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                          Button("Complete", systemImage: "checkmark") {
                              viewModel.markComplete(deadline.id)
                          }
                          .tint(.green)
                          
                          Button("Delete", systemImage: "trash", role: .destructive) {
                              viewModel.deleteDeadline(deadline.id)
                          }
                      }
              }
          }
          .listStyle(.plain)
      }
      
      private var emptyStateView: some View {
          VStack(spacing: 16) {
              Image(systemName: emptyStateIcon)
                  .font(.system(size: 60))
                  .foregroundColor(emptyStateColor)
              
              Text(emptyStateTitle)
                  .font(.headline)
              
              Text(emptyStateSubtitle)
                  .font(.subheadline)
                  .foregroundColor(.secondary)
                  .multilineTextAlignment(.center)
          }
          .padding()
      }
      
      @ToolbarContentBuilder
      private var toolbarMenu: some ToolbarContent {
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
      
      // MARK: - Computed properties
      private var filteredDeadlines: [Deadline] {
          switch selectedFilter {
          case .upcoming: return viewModel.upcomingDeadlines
          case .today: return viewModel.todayDeadlines
          case .overdue: return viewModel.overdueDeadlines
          case .completed: return viewModel.completedDeadlines
          }
      }
      
      private var emptyStateIcon: String {
          switch selectedFilter {
          case .upcoming: return "calendar"
          case .today: return "clock"
          case .overdue: return "exclamationmark.triangle"
          case .completed: return "checkmark.circle"
          }
      }
      
      private var emptyStateColor: Color {
          switch selectedFilter {
          case .upcoming: return .blue
          case .today: return .orange
          case .overdue: return .red
          case .completed: return .green
          }
      }
      
      private var emptyStateTitle: String {
          "No \(selectedFilter.rawValue) Deadlines"
      }
      
      private var emptyStateSubtitle: String {
          switch selectedFilter {
          case .upcoming: return "New deadlines will appear here"
          case .today: return "No deadlines due today"
          case .overdue: return "You're all caught up!"
          case .completed: return "Completed deadlines will appear here"
          }
      }
  }
  ```

**Checkpoint 5.2**: Deadline list displays and filters correctly

**Commit**: `feat(pr19): create DeadlineListView with filtering`

---

### 5.3: Create DeadlineRowView (20 min)

- [ ] **Create new file**: `messAI/Views/Deadline/DeadlineRowView.swift`

- [ ] **Implement row view**
  ```swift
  import SwiftUI
  
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
                  
                  HStack(spacing: 4) {
                      Text(deadline.formattedDueDate)
                          .font(.caption)
                          .foregroundColor(.secondary)
                      
                      if let description = deadline.description {
                          Text("•")
                              .foregroundColor(.secondary)
                              .font(.caption)
                          
                          Text(description)
                              .font(.caption)
                              .foregroundColor(.secondary)
                              .lineLimit(1)
                      }
                  }
              }
              
              Spacer()
              
              // Countdown and priority
              VStack(alignment: .trailing, spacing: 4) {
                  Text(deadline.countdownText)
                      .font(.caption.bold())
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

**Checkpoint 5.3**: Deadline rows display in list  
**Phase 5 Complete**: ✅ All views implemented

**Commit**: `feat(pr19): create DeadlineRowView for list display`

---

## Phase 6: Integration & AIService (30-45 minutes)

### 6.1: Update AIService (20 min)

- [ ] **Open**: `messAI/Services/AIService.swift`

- [ ] **Add extractDeadline method**
  ```swift
  // MARK: - Deadline Extraction (PR#19)
  func extractDeadline(
      messageId: String,
      conversationId: String,
      messageText: String
  ) async throws -> [String: Any] {
      let requestData: [String: Any] = [
          "feature": "deadline_extraction",
          "messageId": messageId,
          "conversationId": conversationId,
          "messageText": messageText
      ]
      
      let (data, response) = try await URLSession.shared.data(for: createRequest(with: requestData))
      
      guard let httpResponse = response as? HTTPURLResponse else {
          throw AIError.networkError("Invalid response")
      }
      
      guard httpResponse.statusCode == 200 else {
          throw AIError.serverError("HTTP \(httpResponse.statusCode)")
      }
      
      guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
          throw AIError.invalidResponse
      }
      
      return json
  }
  ```

**Checkpoint 6.1**: AIService can call deadline extraction endpoint

**Commit**: `feat(pr19): add extractDeadline method to AIService`

---

### 6.2: Update ChatView (15 min)

- [ ] **Open**: `messAI/Views/Chat/ChatView.swift`

- [ ] **Display deadline cards** (add in message list)
  ```swift
  ScrollView {
      LazyVStack(spacing: 8) {
          // Existing messages...
          
          ForEach(viewModel.messages) { message in
              MessageBubbleView(...)
              
              // Show deadline card if extracted
              if let deadline = viewModel.extractedDeadlines.first(where: { $0.messageId == message.id }) {
                  DeadlineCardView(deadline: deadline, viewModel: viewModel)
                      .padding(.horizontal)
                      .padding(.top, 4)
              }
          }
      }
  }
  ```

**Checkpoint 6.2**: Deadline cards appear in chat

**Commit**: `feat(pr19): display deadline cards in ChatView`

---

### 6.3: Update ChatListView (10 min)

- [ ] **Open**: `messAI/Views/Chat/ChatListView.swift`

- [ ] **Add deadline tab**
  ```swift
  TabView(selection: $selectedTab) {
      // Existing chats tab...
      
      DeadlineListView(
          viewModel: DeadlineViewModel(
              deadlineService: DeadlineService(),
              authService: authViewModel.authService
          )
      )
      .tabItem {
          Label("Deadlines", systemImage: "calendar.badge.clock")
      }
      .badge(deadlineViewModel.upcomingCount + deadlineViewModel.todayCount)
      .tag(Tab.deadlines)
  }
  ```

**Checkpoint 6.3**: Deadline tab accessible from main navigation  
**Phase 6 Complete**: ✅ Integration complete

**Commit**: `feat(pr19): add Deadlines tab to ChatListView`

---

## Phase 7: Testing & Refinement (30 minutes)

### 7.1: Test Deadline Detection (15 min)

- [ ] **Test message 1**: "Permission slip due Wednesday by 3pm"
  - [ ] Cloud Function called
  - [ ] Deadline extracted correctly
  - [ ] Saved to Firestore
  - [ ] Card appears in chat

- [ ] **Test message 2**: "RSVP by next Friday"
  - [ ] Relative date calculated correctly
  - [ ] Priority assigned appropriately

- [ ] **Test message 3**: "Registration closes March 15th"
  - [ ] Explicit date parsed correctly
  - [ ] All-day deadline created

- [ ] **Test non-deadline**: "Hey, how are you?"
  - [ ] Keyword filter skips message
  - [ ] No Cloud Function call
  - [ ] No deadline created

**Checkpoint 7.1**: Detection working for various deadline formats

---

### 7.2: Test Global Deadline View (10 min)

- [ ] **Navigate to Deadlines tab**
  - [ ] All deadlines load correctly
  - [ ] Filter tabs work (Upcoming/Today/Overdue)
  - [ ] Tap deadline → navigates to conversation
  - [ ] Badge shows correct count

- [ ] **Test actions**
  - [ ] Mark complete → removed from active list
  - [ ] Swipe to complete → works
  - [ ] Clear completed → removes from list

**Checkpoint 7.2**: Global deadline view fully functional

---

### 7.3: Test Edge Cases (5 min)

- [ ] **Past deadline**: "Was due yesterday" → Status: overdue
- [ ] **Multiple deadlines**: Two in one message → Both extracted
- [ ] **Ambiguous date**: "Next Friday" on Friday → Correct interpretation
- [ ] **No date**: "Due soon" → No deadline created (expected)

**Checkpoint 7.3**: Edge cases handled correctly  
**Phase 7 Complete**: ✅ Testing complete

**Commit**: `test(pr19): verify deadline detection and display`

---

## Phase 8: Final Polish & Deployment (15 minutes)

### 8.1: Add Firestore indexes (5 min)

- [ ] **Open Firebase Console** → Firestore → Indexes

- [ ] **Create composite index** (if needed):
  - Collection: `deadlines`
  - Fields: `extractedBy` (Ascending), `status` (Ascending), `dueDate` (Ascending)

- [ ] **Or run this query in app to auto-generate**:
  ```swift
  // This query will trigger index creation prompt
  db.collection("deadlines")
      .whereField("extractedBy", isEqualTo: userId)
      .whereField("status", in: ["upcoming", "today"])
      .order(by: "dueDate")
  ```

**Checkpoint 8.1**: Firestore indexes created

---

### 8.2: Clean up console logs (5 min)

- [ ] Remove or comment out debug print statements
- [ ] Ensure no sensitive data logged
- [ ] Keep error logging for debugging

**Checkpoint 8.2**: Logging cleaned up

---

### 8.3: Final build & deploy (5 min)

- [ ] **Build iOS app**
  ```bash
  # In Xcode: Product → Build (Cmd+B)
  # Verify 0 errors, 0 warnings
  ```

- [ ] **Verify Cloud Function deployed**
  ```bash
  firebase functions:list
  # Confirm processAI is deployed with deadline_extraction route
  ```

- [ ] **Test end-to-end one more time**
  - Send message with deadline
  - Verify extraction
  - Check Firestore
  - View in app

**Checkpoint 8.4**: Everything working end-to-end  
**Phase 8 Complete**: ✅ PR#19 READY TO MERGE!

**Commit**: `feat(pr19): deadline extraction feature complete`

---

## Final Checklist

### Code Complete
- [ ] All 7 new files created
- [ ] All 6 modified files updated
- [ ] Project builds successfully (0 errors, 0 warnings)
- [ ] No console errors during testing

### Functionality Complete
- [ ] Cloud Function extracts deadlines correctly
- [ ] Deadline cards display in chat
- [ ] Global deadline tab works
- [ ] Filtering and sorting work
- [ ] Actions work (mark complete, delete)
- [ ] Automatic detection on new messages
- [ ] Real-time updates working

### Performance
- [ ] Keyword filter <100ms
- [ ] GPT-4 extraction <3s
- [ ] No UI lag
- [ ] Firestore queries optimized

### Testing
- [ ] 10+ deadline formats tested
- [ ] Edge cases verified
- [ ] Cross-device sync tested
- [ ] No data loss

### Documentation
- [ ] Code comments added
- [ ] Debug logs removed
- [ ] README updated (if needed)

---

## Success! 🎉

**Total Time Spent**: ______ hours  
**Estimated Time**: 3-4 hours  
**On Time?**: Yes / No

**What Worked Well**:
- 

**Challenges Faced**:
- 

**Next Steps**:
- Test with real users
- Gather feedback
- Move to PR#20 (Event Planning Agent)

---

## Commit History

```bash
git log --oneline feature/pr19-deadline-extraction
```

Expected commits:
1. feat(pr19): implement GPT-4 deadline extraction function
2. feat(pr19): add deadline_extraction route to AI router
3. feat(pr19): deploy deadline extraction Cloud Function
4. feat(pr19): add Deadline model with computed properties
5. feat(pr19): add DeadlineStatus and PriorityLevel enums
6. feat(pr19): implement DeadlineService with Firestore CRUD
7. feat(pr19): add DeadlineViewModel for global deadline management
8. feat(pr19): add automatic deadline detection to ChatViewModel
9. feat(pr19): create DeadlineCardView for in-chat display
10. feat(pr19): create DeadlineListView with filtering
11. feat(pr19): create DeadlineRowView for list display
12. feat(pr19): add extractDeadline method to AIService
13. feat(pr19): display deadline cards in ChatView
14. feat(pr19): add Deadlines tab to ChatListView
15. test(pr19): verify deadline detection and display
16. feat(pr19): deadline extraction feature complete

---

**Ready to merge to main!** 🚀

