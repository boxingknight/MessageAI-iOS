# PR #18: RSVP Tracking - Implementation Checklist

**Use this as your daily todo list.** Check off items as you complete them.

**Estimated Time**: 3-4 hours  
**Complexity**: HIGH  
**Dependencies**: PR#14 ✅, PR#15 ✅

---

## Pre-Implementation Setup (15 minutes)

- [ ] Read main planning document `PR18_RSVP_TRACKING.md` (~45 min)
- [ ] Verify prerequisites complete
  - [ ] PR#14 deployed (Cloud Functions working)
  - [ ] PR#15 complete (CalendarEvent model exists)
  - [ ] OpenAI API key configured
  - [ ] Firebase billing enabled (Blaze plan)
- [ ] Create git branch
  ```bash
  git checkout -b feature/pr18-rsvp-tracking
  ```
- [ ] Open Xcode project
- [ ] Pull latest from main (ensure clean working directory)

**Checkpoint**: Ready to start Phase 1 ✓

---

## Phase 1: Cloud Function - RSVP Detection (1 hour)

### 1.1: Create Base File (10 min)

- [ ] Create `functions/src/ai/rsvpTracking.ts`
- [ ] Add imports
  ```typescript
  import { CallableContext } from 'firebase-functions/v1/https';
  import { OpenAI } from 'openai';
  import * as admin from 'firebase-admin';
  ```
- [ ] Define interfaces
  ```typescript
  interface DetectRSVPRequest {
    conversationId: string;
    messageId: string;
    messageText: string;
    senderId: string;
    senderName: string;
    recentEventIds?: string[];
  }
  
  interface DetectRSVPResponse {
    detected: boolean;
    status?: 'yes' | 'no' | 'maybe';
    eventId?: string;
    confidence: number;
    reasoning?: string;
  }
  ```

### 1.2: Implement Keyword Filter (15 min)

- [ ] Add keyword list for optimization
  ```typescript
  const rsvpKeywords = [
    'yes', 'no', 'maybe', 'count me in', 'i\'ll be there', 
    'can\'t make it', 'probably', 'not sure', 'definitely', 
    'absolutely', 'unfortunately', 'attending', 'coming', 
    'going', 'skip', 'pass', 'tentative'
  ];
  ```
- [ ] Implement quick filter check
  ```typescript
  const hasKeyword = rsvpKeywords.some(keyword => 
    messageText.toLowerCase().includes(keyword)
  );
  
  if (!hasKeyword) {
    return { detected: false, confidence: 0.0 };
  }
  ```
- [ ] Test keyword filter
  - [ ] "Yes!" → passes filter
  - [ ] "What time?" → skips filter (no GPT-4 call)

### 1.3: Fetch Recent Events (10 min)

- [ ] Add event fetching logic
  ```typescript
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
  ```
- [ ] Test event fetching
  - [ ] Fetches events from recent messages
  - [ ] Returns empty array if no events

### 1.4: GPT-4 Integration (20 min)

- [ ] Build system prompt
  ```typescript
  const eventsContext = eventIds.length > 0 
    ? `Recent events: ${eventIds.slice(0, 3).join(', ')}`
    : 'No recent events';

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
  ```
- [ ] Parse GPT-4 response
  ```typescript
  const functionCall = completion.choices[0]?.message?.function_call;
  if (!functionCall || !functionCall.arguments) {
    return { detected: false, confidence: 0.0 };
  }

  const result = JSON.parse(functionCall.arguments);
  ```

### 1.5: Save to Firestore (10 min)

- [ ] Implement RSVP saving
  ```typescript
  if (result.detected && result.confidence > 0.7 && result.status) {
    const eventId = result.eventId || eventIds[0];
    
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
  ```
- [ ] Test Firestore write
  - [ ] RSVP document created in `/events/{eventId}/rsvps/{userId}`
  - [ ] All fields populated correctly

### 1.6: Update Router (5 min)

- [ ] Add to `functions/src/ai/processAI.ts`
  ```typescript
  import { detectRSVP } from './rsvpTracking';
  
  // In router switch statement
  case 'rsvp_detection':
    result = await detectRSVP(featureData, context);
    break;
  ```
- [ ] Export function from index.ts (if not using router)

**Phase 1 Complete!** ✅  
**Checkpoint**: Cloud Function detecting RSVPs and saving to Firestore

**Commit**: `feat(pr18): implement RSVP detection Cloud Function`

---

## Phase 2: iOS Models (45 minutes)

### 2.1: Create RSVPStatus Enum (15 min)

- [ ] Create `messAI/Models/RSVPResponse.swift`
- [ ] Define RSVPStatus enum
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
  ```
- [ ] Test enum
  - [ ] All cases have displayText
  - [ ] All cases have icon
  - [ ] All cases have color

### 2.2: Create RSVPResponse Struct (15 min)

- [ ] Define RSVPResponse struct
  ```swift
  struct RSVPResponse: Codable, Identifiable, Equatable {
      let id: String // userId
      let userId: String
      let userName: String
      let eventId: String
      let status: RSVPStatus
      let messageId: String
      let detectedAt: Date
      let confidence: Double
      let responseText: String?
      let notes: String?
      
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
- [ ] Test Firestore conversion
  - [ ] toDictionary() creates valid dictionary
  - [ ] fromDictionary() reconstructs object
  - [ ] Round-trip preserves all data

### 2.3: Create RSVPSummary Struct (15 min)

- [ ] Define RSVPSummary struct
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
      
      var yesList: [RSVPResponse] { responses.filter { $0.status == .yes } }
      var noList: [RSVPResponse] { responses.filter { $0.status == .no } }
      var maybeList: [RSVPResponse] { responses.filter { $0.status == .maybe } }
      var pendingList: [RSVPResponse] { responses.filter { $0.status == .pending } }
  }
  ```
- [ ] Test computed properties
  - [ ] confirmationRate calculates correctly
  - [ ] responseRate calculates correctly
  - [ ] statusText formats correctly
  - [ ] List filters work

**Phase 2 Complete!** ✅  
**Checkpoint**: RSVP data models ready with Firestore conversion

**Commit**: `feat(pr18): add RSVP data models`

---

## Phase 3: AIService Integration (45 minutes)

### 3.1: Add detectRSVP Method (25 min)

- [ ] Open `messAI/Services/AIService.swift`
- [ ] Add detectRSVP method
  ```swift
  extension AIService {
      func detectRSVP(
          conversationId: String,
          messageId: String,
          messageText: String,
          senderId: String,
          senderName: String,
          recentEventIds: [String] = []
      ) async throws -> RSVPDetectionResult {
          let cacheKey = "rsvp_\(messageId)"
          
          // Check cache (1-minute TTL)
          if let cached = cache[cacheKey],
             Date().timeIntervalSince(cached.timestamp) < 60 {
              if let result = cached.value as? RSVPDetectionResult {
                  print("✅ AIService: RSVP cache hit for \(messageId)")
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
  }
  ```
- [ ] Add RSVPDetectionResult struct
  ```swift
  struct RSVPDetectionResult: Codable {
      let detected: Bool
      let status: RSVPStatus?
      let eventId: String?
      let confidence: Double
      let reasoning: String?
  }
  ```
- [ ] Test detectRSVP
  - [ ] Returns valid result
  - [ ] Caching reduces duplicate calls
  - [ ] Errors handled gracefully

### 3.2: Add fetchRSVPSummary Method (20 min)

- [ ] Add fetchRSVPSummary method
  ```swift
  extension AIService {
      func fetchRSVPSummary(eventId: String) async throws -> RSVPSummary {
          let db = Firestore.firestore()
          
          // Fetch all RSVPs for event
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
          
          // Calculate counts
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
  ```
- [ ] Test fetchRSVPSummary
  - [ ] Returns correct counts
  - [ ] Handles empty RSVP list
  - [ ] Calculates pending correctly

**Phase 3 Complete!** ✅  
**Checkpoint**: iOS can detect RSVPs and fetch summaries

**Commit**: `feat(pr18): integrate RSVP detection in AIService`

---

## Phase 4: ChatViewModel Logic (30 minutes)

### 4.1: Add RSVP State (10 min)

- [ ] Open `messAI/ViewModels/ChatViewModel.swift`
- [ ] Add @Published properties
  ```swift
  @Published var rsvpSummaries: [String: RSVPSummary] = [:] // eventId → summary
  @Published var isDetectingRSVP: Bool = false
  @Published var rsvpError: String?
  ```
- [ ] Add private properties
  ```swift
  private var rsvpDetectionTask: Task<Void, Never>?
  ```

### 4.2: Implement Auto-Detection (15 min)

- [ ] Add detectRSVPIfNeeded method
  ```swift
  func detectRSVPIfNeeded(for message: Message) {
      // Cancel previous task
      rsvpDetectionTask?.cancel()
      
      // Only detect for messages in group chats
      guard let conversation = conversation, conversation.isGroup else { return }
      
      // Skip if already processed
      if message.aiMetadata?.rsvpResponse != nil { return }
      
      // Get recent calendar events
      let recentEvents = messages
          .suffix(10)
          .compactMap { $0.aiMetadata?.calendarEvents }
          .flatMap { $0 }
      let eventIds = recentEvents.map { $0.id }
      
      // Detect RSVP asynchronously
      rsvpDetectionTask = Task {
          do {
              isDetectingRSVP = true
              
              let result = try await aiService.detectRSVP(
                  conversationId: conversation.id,
                  messageId: message.id,
                  messageText: message.text,
                  senderId: message.senderId,
                  senderName: "User", // TODO: Get from User model
                  recentEventIds: eventIds
              )
              
              await MainActor.run {
                  isDetectingRSVP = false
                  
                  if result.detected, let eventId = result.eventId {
                      // Refresh RSVP summary for this event
                      Task {
                          await loadRSVPSummary(eventId: eventId)
                      }
                  }
              }
          } catch {
              await MainActor.run {
                  isDetectingRSVP = false
                  rsvpError = error.localizedDescription
              }
          }
      }
  }
  ```
- [ ] Call from message send
  ```swift
  // In sendMessage() after successful send
  detectRSVPIfNeeded(for: newMessage)
  ```

### 4.3: Implement Summary Loading (5 min)

- [ ] Add loadRSVPSummary method
  ```swift
  func loadRSVPSummary(eventId: String) async {
      do {
          let summary = try await aiService.fetchRSVPSummary(eventId: eventId)
          await MainActor.run {
              rsvpSummaries[eventId] = summary
          }
      } catch {
          print("❌ Failed to load RSVP summary: \(error)")
      }
  }
  ```
- [ ] Add refresh method
  ```swift
  func refreshAllRSVPSummaries() async {
      let eventIds = messages
          .compactMap { $0.aiMetadata?.calendarEvents }
          .flatMap { $0 }
          .map { $0.id }
          .unique()
      
      for eventId in eventIds {
          await loadRSVPSummary(eventId: eventId)
      }
  }
  ```

**Phase 4 Complete!** ✅  
**Checkpoint**: ChatViewModel detects RSVPs and loads summaries

**Commit**: `feat(pr18): add RSVP detection to ChatViewModel`

---

## Phase 5: UI Components (1.5 hours)

### 5.1: Create RSVPSectionView (30 min)

- [ ] Create `messAI/Views/Chat/RSVPSectionView.swift`
- [ ] Define struct
  ```swift
  import SwiftUI

  struct RSVPSectionView: View {
      let summary: RSVPSummary
      @State private var isExpanded: Bool = false
      
      var body: some View {
          VStack(alignment: .leading, spacing: 8) {
              // Header (always visible)
              RSVPHeaderView(
                  summary: summary,
                  isExpanded: $isExpanded
              )
              
              // Detail (collapsible)
              if isExpanded {
                  RSVPDetailView(summary: summary)
                      .transition(.opacity.combined(with: .scale))
              }
          }
          .padding(12)
          .background(Color(UIColor.systemGray6))
          .cornerRadius(12)
          .padding(.horizontal, 12)
          .padding(.vertical, 4)
      }
  }
  ```
- [ ] Add preview
  ```swift
  #Preview {
      RSVPSectionView(summary: RSVPSummary(
          eventId: "test",
          totalParticipants: 12,
          yesCount: 5,
          noCount: 2,
          maybeCount: 1,
          pendingCount: 4,
          responses: [],
          lastUpdated: Date()
      ))
  }
  ```
- [ ] Test rendering
  - [ ] Section displays correctly
  - [ ] Expand/collapse works
  - [ ] Animation smooth

### 5.2: Create RSVPHeaderView (20 min)

- [ ] Create `messAI/Views/Chat/RSVPHeaderView.swift`
- [ ] Define struct
  ```swift
  import SwiftUI

  struct RSVPHeaderView: View {
      let summary: RSVPSummary
      @Binding var isExpanded: Bool
      
      var body: some View {
          HStack(spacing: 12) {
              // Icon
              Image(systemName: "person.3.fill")
                  .foregroundColor(.blue)
                  .font(.system(size: 20))
              
              // Summary text
              VStack(alignment: .leading, spacing: 2) {
                  Text("RSVPs")
                      .font(.system(size: 14, weight: .semibold))
                      .foregroundColor(.primary)
                  
                  Text(summary.confirmationText)
                      .font(.system(size: 13))
                      .foregroundColor(.secondary)
              }
              
              Spacer()
              
              // Status badges (compact)
              HStack(spacing: 4) {
                  StatusBadge(count: summary.yesCount, color: .green, icon: "checkmark")
                  StatusBadge(count: summary.noCount, color: .red, icon: "xmark")
                  if summary.maybeCount > 0 {
                      StatusBadge(count: summary.maybeCount, color: .orange, icon: "questionmark")
                  }
              }
              
              // Expand/collapse chevron
              Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                  .foregroundColor(.gray)
                  .font(.system(size: 12, weight: .semibold))
          }
          .contentShape(Rectangle())
          .onTapGesture {
              withAnimation(.spring(response: 0.3)) {
                  isExpanded.toggle()
              }
          }
      }
  }

  struct StatusBadge: View {
      let count: Int
      let color: Color
      let icon: String
      
      var body: some View {
          HStack(spacing: 2) {
              Image(systemName: icon)
                  .font(.system(size: 10))
              Text("\(count)")
                  .font(.system(size: 11, weight: .medium))
          }
          .foregroundColor(.white)
          .padding(.horizontal, 6)
          .padding(.vertical, 3)
          .background(color)
          .cornerRadius(6)
      }
  }
  ```
- [ ] Test header
  - [ ] Summary text correct
  - [ ] Badges display counts
  - [ ] Chevron rotates on tap

### 5.3: Create RSVPDetailView (25 min)

- [ ] Create `messAI/Views/Chat/RSVPDetailView.swift`
- [ ] Define struct
  ```swift
  import SwiftUI

  struct RSVPDetailView: View {
      let summary: RSVPSummary
      
      var body: some View {
          VStack(alignment: .leading, spacing: 12) {
              // Yes section
              if !summary.yesList.isEmpty {
                  RSVPListSection(
                      title: "Yes",
                      color: .green,
                      icon: "checkmark.circle.fill",
                      responses: summary.yesList
                  )
              }
              
              // No section
              if !summary.noList.isEmpty {
                  RSVPListSection(
                      title: "No",
                      color: .red,
                      icon: "xmark.circle.fill",
                      responses: summary.noList
                  )
              }
              
              // Maybe section
              if !summary.maybeList.isEmpty {
                  RSVPListSection(
                      title: "Maybe",
                      color: .orange,
                      icon: "questionmark.circle.fill",
                      responses: summary.maybeList
                  )
              }
              
              // Pending (if any)
              if summary.pendingCount > 0 {
                  HStack {
                      Image(systemName: "clock.circle.fill")
                          .foregroundColor(.gray)
                      Text("\(summary.pendingCount) pending")
                          .font(.system(size: 13))
                          .foregroundColor(.secondary)
                  }
              }
              
              // Actions
              HStack(spacing: 12) {
                  Button {
                      copyRSVPList()
                  } label: {
                      Label("Copy List", systemImage: "doc.on.doc")
                          .font(.system(size: 13))
                  }
                  
                  Spacer()
                  
                  Text("Updated \(summary.lastUpdated.timeAgoText)")
                      .font(.system(size: 11))
                      .foregroundColor(.secondary)
              }
          }
          .padding(.top, 8)
      }
      
      func copyRSVPList() {
          let text = """
          Yes (\(summary.yesCount)):
          \(summary.yesList.map { "• \($0.userName)" }.joined(separator: "\n"))
          
          No (\(summary.noCount)):
          \(summary.noList.map { "• \($0.userName)" }.joined(separator: "\n"))
          
          Maybe (\(summary.maybeCount)):
          \(summary.maybeList.map { "• \($0.userName)" }.joined(separator: "\n"))
          """
          UIPasteboard.general.string = text
      }
  }

  struct RSVPListSection: View {
      let title: String
      let color: Color
      let icon: String
      let responses: [RSVPResponse]
      
      var body: some View {
          VStack(alignment: .leading, spacing: 6) {
              HStack {
                  Image(systemName: icon)
                      .foregroundColor(color)
                  Text("\(title) (\(responses.count))")
                      .font(.system(size: 14, weight: .semibold))
              }
              
              ForEach(responses) { response in
                  RSVPListItemView(response: response)
              }
          }
      }
  }
  ```
- [ ] Test detail view
  - [ ] All sections display
  - [ ] Grouped by status
  - [ ] Copy list works

### 5.4: Create RSVPListItemView (15 min)

- [ ] Create `messAI/Views/Chat/RSVPListItemView.swift`
- [ ] Define struct
  ```swift
  import SwiftUI

  struct RSVPListItemView: View {
      let response: RSVPResponse
      
      var body: some View {
          HStack(spacing: 8) {
              // Avatar placeholder
              Circle()
                  .fill(Color.blue.opacity(0.2))
                  .frame(width: 28, height: 28)
                  .overlay(
                      Text(response.userName.prefix(1).uppercased())
                          .font(.system(size: 12, weight: .semibold))
                          .foregroundColor(.blue)
                  )
              
              // Name
              Text(response.userName)
                  .font(.system(size: 13))
              
              Spacer()
              
              // Confidence indicator (if low)
              if response.confidence < 0.8 {
                  Image(systemName: "questionmark.circle")
                      .foregroundColor(.orange)
                      .font(.system(size: 12))
              }
          }
          .padding(.horizontal, 8)
          .padding(.vertical, 4)
      }
  }
  ```
- [ ] Test item view
  - [ ] Avatar displays
  - [ ] Name displays
  - [ ] Confidence indicator shows when <0.8

### 5.5: Integrate into CalendarCardView (10 min)

- [ ] Open `messAI/Views/Chat/CalendarCardView.swift`
- [ ] Add RSVP section below card
  ```swift
  struct CalendarCardView: View {
      let event: CalendarEvent
      let rsvpSummary: RSVPSummary?
      
      var body: some View {
          VStack(spacing: 0) {
              // Existing calendar card UI
              calendarCardContent
              
              // NEW: RSVP section
              if let summary = rsvpSummary {
                  RSVPSectionView(summary: summary)
              }
          }
      }
      
      // ... existing code
  }
  ```
- [ ] Update ChatView to pass RSVP summary
  ```swift
  // In ChatView message rendering
  if let events = message.aiMetadata?.calendarEvents {
      ForEach(events) { event in
          CalendarCardView(
              event: event,
              rsvpSummary: viewModel.rsvpSummaries[event.id]
          )
      }
  }
  ```

**Phase 5 Complete!** ✅  
**Checkpoint**: Beautiful RSVP UI integrated with calendar cards

**Commit**: `feat(pr18): add RSVP UI components`

---

## Phase 6: Testing & Polish (30 minutes)

### 6.1: Manual Testing (15 min)

- [ ] Test with simulator/device
  - [ ] Create test group chat (3+ users)
  - [ ] Send event message: "Pizza party Friday 6pm"
  - [ ] Calendar card appears
  - [ ] Reply "Yes!" → RSVP detected
  - [ ] RSVP section appears with "1 of 3 confirmed"
  - [ ] Expand RSVP section → See participant list
  - [ ] Second user replies "Can't make it"
  - [ ] RSVP updates: "1 of 3 confirmed, 1 declined"
  - [ ] Third user replies "Maybe"
  - [ ] RSVP updates: "1 of 3 confirmed, 1 declined, 1 maybe"

### 6.2: Edge Case Testing (10 min)

- [ ] Test ambiguous responses
  - [ ] "I'll try" → Maybe (confidence 0.6-0.8)
  - [ ] "Sounds good!" → Yes (confidence 0.6) or not detected
  - [ ] "What time?" → Not detected (no RSVP)
- [ ] Test multiple events
  - [ ] Two events in chat
  - [ ] RSVP links to correct event
- [ ] Test no events
  - [ ] RSVP in chat with no calendar events
  - [ ] Handles gracefully (no crash)

### 6.3: Performance Testing (5 min)

- [ ] Measure detection time
  - [ ] Warm: <2 seconds
  - [ ] Cold start: <5 seconds
- [ ] Measure RSVP summary load
  - [ ] <1 second for 10 participants
  - [ ] <1 second for 50 participants
- [ ] Check caching
  - [ ] Same message detected twice uses cache
  - [ ] No duplicate Firestore writes

**Phase 6 Complete!** ✅  
**Checkpoint**: All tests passing, production-ready

**Commit**: `test(pr18): comprehensive RSVP tracking tests`

---

## Deployment Checklist

### Deploy Cloud Function

- [ ] Build functions
  ```bash
  cd functions
  npm run build
  ```
- [ ] Deploy to Firebase
  ```bash
  firebase deploy --only functions
  ```
- [ ] Verify deployment
  ```bash
  firebase functions:list
  # Should see: processAI
  ```
- [ ] Test in production
  - [ ] Call from iOS app
  - [ ] Check Firebase console logs
  - [ ] Verify RSVP saved to Firestore

### Firestore Security Rules

- [ ] Add RSVP subcollection rules
  ```javascript
  match /events/{eventId}/rsvps/{userId} {
    allow read: if request.auth != null && 
      exists(/databases/$(database)/documents/events/$(eventId)) &&
      get(/databases/$(database)/documents/events/$(eventId)).data.participants.hasAny([request.auth.uid]);
    
    allow create, update: if request.auth != null && 
      request.auth.uid == userId &&
      request.resource.data.userId == userId;
    
    allow delete: if request.auth != null && request.auth.uid == userId;
  }
  ```
- [ ] Deploy rules
  ```bash
  firebase deploy --only firestore:rules
  ```

### iOS Build

- [ ] Clean build folder (Cmd+Shift+K)
- [ ] Build project (Cmd+B)
- [ ] Run on simulator
- [ ] Fix any errors
- [ ] Run on physical device
- [ ] Test end-to-end flow

**Deployment Complete!** ✅

**Commit**: `deploy(pr18): deploy RSVP tracking to production`

---

## Completion Checklist

### Code Complete

- [ ] All 6 phases implemented
- [ ] All files created/modified
- [ ] Zero compiler errors
- [ ] Zero warnings (or all acceptable)

### Testing Complete

- [ ] Unit tests pass (Cloud Function)
- [ ] Integration tests pass (end-to-end)
- [ ] Edge cases handled
- [ ] Performance targets met

### Documentation Complete

- [ ] Code comments added
- [ ] Function JSDoc/SwiftDoc
- [ ] README updated (if needed)
- [ ] PR18_COMPLETE_SUMMARY.md written

### Production Ready

- [ ] Cloud Function deployed
- [ ] Firestore rules deployed
- [ ] iOS app builds successfully
- [ ] Tested on physical device
- [ ] No critical bugs

---

## Summary

**Files Created (6 files, ~850 lines)**:
- `functions/src/ai/rsvpTracking.ts` (~300 lines)
- `messAI/Models/RSVPResponse.swift` (~180 lines)
- `messAI/Views/Chat/RSVPSectionView.swift` (~220 lines)
- `messAI/Views/Chat/RSVPHeaderView.swift` (~120 lines)
- `messAI/Views/Chat/RSVPDetailView.swift` (~180 lines)
- `messAI/Views/Chat/RSVPListItemView.swift` (~90 lines)

**Files Modified (+~320 lines)**:
- `functions/src/ai/processAI.ts` (+20 lines)
- `messAI/Models/AIMetadata.swift` (+30 lines)
- `messAI/Services/AIService.swift` (+120 lines)
- `messAI/ViewModels/ChatViewModel.swift` (+90 lines)
- `messAI/Views/Chat/CalendarCardView.swift` (+50 lines)
- `messAI/Views/Chat/ChatView.swift` (+30 lines)

**Total**: ~1,170 lines across 12 files

**Time Spent**: [Record actual time]

**Bugs Fixed**: [Record any bugs encountered]

**Next Steps**: Ready for PR#19 (Deadline Extraction) or PR#20 (Event Planning Agent)!

---

*Last Updated: October 22, 2025*  
*Status: Ready for Implementation*

