# PR#14: Implementation Checklist

**Use this as your daily todo list.** Check off items as you complete them.

---

## Pre-Implementation Setup (15 minutes)

- [ ] Read main planning document `PR14_CLOUD_FUNCTIONS_SETUP.md` (~45 min)
- [ ] Verify prerequisites
  - [ ] Core messaging complete (PRs 1-13) ✅
  - [ ] Firebase project active ✅
  - [ ] Firebase billing enabled
  - [ ] OpenAI API account created
  - [ ] OpenAI API key obtained
- [ ] Git branch created
  ```bash
  git checkout -b feature/pr14-cloud-functions
  ```
- [ ] Firebase CLI installed
  ```bash
  npm install -g firebase-tools
  firebase login
  ```

---

## Phase 1: Cloud Functions Initialization (30 minutes)

### 1.1: Initialize Firebase Cloud Functions (10 min)

- [ ] Navigate to project root
  ```bash
  cd /Users/ijaramil/Documents/GauntletAI/Week2/messAI
  ```

- [ ] Run Firebase init
  ```bash
  firebase init functions
  ```
  
- [ ] Select options:
  - [ ] Use existing project: `messageai-95c8f`
  - [ ] Language: **TypeScript**
  - [ ] ESLint: **Yes**
  - [ ] Install dependencies: **Yes**

- [ ] Verify structure created
  ```bash
  ls -la functions/
  # Should see: src/, package.json, tsconfig.json
  ```

**Checkpoint:** ✅ `functions/` directory exists with TypeScript setup

**Commit:** `feat(pr14): initialize Cloud Functions with TypeScript`

---

### 1.2: Install Dependencies (5 min)

- [ ] Navigate to functions directory
  ```bash
  cd functions
  ```

- [ ] Install OpenAI SDK
  ```bash
  npm install openai@^4.0.0
  ```

- [ ] Install type definitions
  ```bash
  npm install @types/node --save-dev
  ```

- [ ] Verify package.json
  ```bash
  cat package.json | grep openai
  # Should show: "openai": "^4.0.0"
  ```

**Checkpoint:** ✅ Dependencies installed successfully

**Commit:** `feat(pr14): install OpenAI and dependencies`

---

### 1.3: Configure Environment Variables (15 min)

- [ ] Create `.env` file in `functions/` directory
  ```bash
  cd functions
  touch .env
  ```

- [ ] Add environment variables to `.env`
  ```env
  OPENAI_API_KEY=sk-proj-your-actual-key-here
  OPENAI_MODEL=gpt-4
  RATE_LIMIT_PER_HOUR=100
  ```

- [ ] Create `.env.example` template
  ```bash
  cat > .env.example << 'EOF'
  OPENAI_API_KEY=sk-proj-your-key-here
  OPENAI_MODEL=gpt-4
  RATE_LIMIT_PER_HOUR=100
  EOF
  ```

- [ ] Add `.env` to `.gitignore`
  ```bash
  echo ".env" >> .gitignore
  echo "*.env" >> ../.gitignore
  ```

- [ ] Verify `.env` is ignored
  ```bash
  git status | grep ".env"
  # Should NOT show .env file
  ```

- [ ] Set Firebase config (production)
  ```bash
  firebase functions:config:set openai.key="sk-proj-your-actual-key-here"
  firebase functions:config:set openai.model="gpt-4"
  ```

- [ ] Verify Firebase config
  ```bash
  firebase functions:config:get
  ```

**Checkpoint:** ✅ API keys configured and secured

**Commit:** `feat(pr14): configure environment variables and API keys`

---

## Phase 2: Middleware Implementation (45 minutes)

### 2.1: Create Authentication Middleware (10 min)

- [ ] Create middleware directory
  ```bash
  mkdir -p functions/src/middleware
  ```

- [ ] Create `functions/src/middleware/auth.ts`
  ```typescript
  import * as functions from 'firebase-functions';
  
  /**
   * Require authentication for AI requests
   * @throws HttpsError if not authenticated
   */
  export function requireAuth(context: functions.https.CallableContext): void {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'You must be logged in to use AI features.'
      );
    }
  }
  
  /**
   * Get authenticated user ID
   * @throws HttpsError if not authenticated
   */
  export function getUserId(context: functions.https.CallableContext): string {
    requireAuth(context);
    return context.auth!.uid;
  }
  ```

- [ ] Test compilation
  ```bash
  npm run build
  ```

**Checkpoint:** ✅ Auth middleware compiles without errors

**Commit:** `feat(pr14): add authentication middleware`

---

### 2.2: Create Rate Limiting Middleware (20 min)

- [ ] Create `functions/src/middleware/rateLimit.ts`
  ```typescript
  import * as functions from 'firebase-functions';
  import * as admin from 'firebase-admin';
  
  const RATE_LIMIT_PER_HOUR = 100;
  
  /**
   * Check and enforce rate limiting for AI requests
   * Limits: 100 requests per hour per user
   * @param userId - User ID to check rate limit for
   * @throws HttpsError if rate limit exceeded
   */
  export async function checkRateLimit(userId: string): Promise<void> {
    // Create hour bucket key
    const hourKey = Math.floor(Date.now() / 3600000);
    const rateLimitRef = admin.firestore()
      .collection('rateLimits')
      .doc(`${userId}_${hourKey}`);
    
    try {
      // Get current count
      const doc = await rateLimitRef.get();
      const count = doc.exists ? (doc.data()?.count || 0) : 0;
      
      // Check if limit exceeded
      if (count >= RATE_LIMIT_PER_HOUR) {
        functions.logger.warn('Rate limit exceeded', { userId, count });
        throw new functions.https.HttpsError(
          'resource-exhausted',
          `Too many AI requests. You've used ${count}/${RATE_LIMIT_PER_HOUR} requests this hour. Please try again later.`
        );
      }
      
      // Increment counter
      await rateLimitRef.set({
        count: count + 1,
        lastRequest: admin.firestore.FieldValue.serverTimestamp(),
        userId: userId
      }, { merge: true });
      
      functions.logger.info('Rate limit check passed', { 
        userId, 
        count: count + 1,
        limit: RATE_LIMIT_PER_HOUR 
      });
      
    } catch (error: any) {
      if (error.code === 'resource-exhausted') {
        throw error; // Re-throw rate limit errors
      }
      functions.logger.error('Rate limit check failed', { error, userId });
      // Continue on error (fail open) - don't block users due to Firestore issues
    }
  }
  
  /**
   * Get current rate limit status for a user
   */
  export async function getRateLimitStatus(userId: string): Promise<{
    used: number;
    limit: number;
    remaining: number;
  }> {
    const hourKey = Math.floor(Date.now() / 3600000);
    const rateLimitRef = admin.firestore()
      .collection('rateLimits')
      .doc(`${userId}_${hourKey}`);
    
    const doc = await rateLimitRef.get();
    const used = doc.exists ? (doc.data()?.count || 0) : 0;
    
    return {
      used,
      limit: RATE_LIMIT_PER_HOUR,
      remaining: Math.max(0, RATE_LIMIT_PER_HOUR - used)
    };
  }
  ```

- [ ] Test compilation
  ```bash
  npm run build
  ```

**Checkpoint:** ✅ Rate limiting middleware compiles without errors

**Commit:** `feat(pr14): add rate limiting middleware`

---

### 2.3: Create Validation Middleware (15 min)

- [ ] Create `functions/src/middleware/validation.ts`
  ```typescript
  import * as functions from 'firebase-functions';
  
  /**
   * Validate request has required fields
   * @param data - Request data to validate
   * @param requiredFields - Array of required field names
   * @throws HttpsError if validation fails
   */
  export function validateRequest(data: any, requiredFields: string[]): void {
    // Check if data exists
    if (!data) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Request data is required.'
      );
    }
    
    // Check each required field
    const missingFields: string[] = [];
    for (const field of requiredFields) {
      if (data[field] === undefined || data[field] === null) {
        missingFields.push(field);
      }
    }
    
    if (missingFields.length > 0) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        `Missing required fields: ${missingFields.join(', ')}`
      );
    }
  }
  
  /**
   * Validate AI feature type
   * @param feature - Feature name to validate
   * @throws HttpsError if invalid feature
   */
  export function validateFeature(feature: string): void {
    const validFeatures = [
      'calendar',
      'decision',
      'urgency',
      'rsvp',
      'deadline',
      'agent'
    ];
    
    if (!validFeatures.includes(feature)) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        `Invalid AI feature: ${feature}. Valid features: ${validFeatures.join(', ')}`
      );
    }
  }
  
  /**
   * Validate message text
   * @param message - Message text to validate
   * @throws HttpsError if invalid
   */
  export function validateMessage(message: string): void {
    if (!message || typeof message !== 'string') {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Message must be a non-empty string.'
      );
    }
    
    if (message.length > 5000) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Message too long. Maximum 5000 characters.'
      );
    }
  }
  ```

- [ ] Test compilation
  ```bash
  npm run build
  ```

**Checkpoint:** ✅ Validation middleware compiles without errors

**Commit:** `feat(pr14): add validation middleware`

---

## Phase 3: AI Router Implementation (60 minutes)

### 3.1: Create AI Directory Structure (5 min)

- [ ] Create AI directory
  ```bash
  mkdir -p functions/src/ai
  ```

- [ ] Create placeholder files
  ```bash
  touch functions/src/ai/calendarExtraction.ts
  touch functions/src/ai/decisionSummary.ts
  touch functions/src/ai/priorityDetection.ts
  touch functions/src/ai/rsvpTracking.ts
  touch functions/src/ai/deadlineExtraction.ts
  touch functions/src/ai/eventPlanningAgent.ts
  ```

**Checkpoint:** ✅ AI directory structure created

---

### 3.2: Implement Placeholder Functions (20 min)

- [ ] Create `functions/src/ai/calendarExtraction.ts`
  ```typescript
  /**
   * Extract calendar dates from messages (PR #15)
   * @param data - Request data with message
   * @returns Placeholder response
   */
  export async function extractCalendarDates(data: any): Promise<any> {
    // TODO: Implement in PR #15
    return {
      events: [],
      message: 'Calendar extraction not yet implemented (PR #15)'
    };
  }
  ```

- [ ] Create `functions/src/ai/decisionSummary.ts`
  ```typescript
  /**
   * Summarize group decisions (PR #16)
   * @param data - Request data with messages
   * @returns Placeholder response
   */
  export async function summarizeDecisions(data: any): Promise<any> {
    // TODO: Implement in PR #16
    return {
      hasDecision: false,
      message: 'Decision summarization not yet implemented (PR #16)'
    };
  }
  ```

- [ ] Create `functions/src/ai/priorityDetection.ts`
  ```typescript
  /**
   * Detect message urgency/priority (PR #17)
   * @param data - Request data with message
   * @returns Placeholder response
   */
  export async function detectUrgency(data: any): Promise<any> {
    // TODO: Implement in PR #17
    return {
      urgencyLevel: 'normal',
      isUrgent: false,
      message: 'Priority detection not yet implemented (PR #17)'
    };
  }
  ```

- [ ] Create `functions/src/ai/rsvpTracking.ts`
  ```typescript
  /**
   * Extract RSVP responses (PR #18)
   * @param data - Request data with message
   * @returns Placeholder response
   */
  export async function extractRSVP(data: any): Promise<any> {
    // TODO: Implement in PR #18
    return {
      response: 'pending',
      message: 'RSVP tracking not yet implemented (PR #18)'
    };
  }
  ```

- [ ] Create `functions/src/ai/deadlineExtraction.ts`
  ```typescript
  /**
   * Extract deadlines from messages (PR #19)
   * @param data - Request data with message
   * @returns Placeholder response
   */
  export async function extractDeadlines(data: any): Promise<any> {
    // TODO: Implement in PR #19
    return {
      deadlines: [],
      message: 'Deadline extraction not yet implemented (PR #19)'
    };
  }
  ```

- [ ] Create `functions/src/ai/eventPlanningAgent.ts`
  ```typescript
  /**
   * Multi-step event planning agent (PR #20)
   * @param data - Request data with context
   * @returns Placeholder response
   */
  export async function eventPlanningAgent(data: any): Promise<any> {
    // TODO: Implement in PR #20
    return {
      message: 'Event planning agent not yet implemented (PR #20)',
      nextStep: null
    };
  }
  ```

- [ ] Test compilation
  ```bash
  npm run build
  ```

**Checkpoint:** ✅ All placeholder functions compile

**Commit:** `feat(pr14): add placeholder AI feature functions`

---

### 3.3: Implement Main AI Router (35 min)

- [ ] Create `functions/src/ai/processAI.ts`
  ```typescript
  import * as functions from 'firebase-functions';
  import { requireAuth, getUserId } from '../middleware/auth';
  import { checkRateLimit } from '../middleware/rateLimit';
  import { validateRequest, validateFeature, validateMessage } from '../middleware/validation';
  import { extractCalendarDates } from './calendarExtraction';
  import { summarizeDecisions } from './decisionSummary';
  import { detectUrgency } from './priorityDetection';
  import { extractRSVP } from './rsvpTracking';
  import { extractDeadlines } from './deadlineExtraction';
  import { eventPlanningAgent } from './eventPlanningAgent';
  
  /**
   * Main AI processing function
   * Routes requests to appropriate AI features
   */
  export const processAI = functions
    .runWith({
      memory: '512MB',
      timeoutSeconds: 30,
      maxInstances: 10
    })
    .https.onCall(async (data, context) => {
      const startTime = Date.now();
      
      try {
        // 1. Require authentication
        requireAuth(context);
        const userId = getUserId(context);
        
        functions.logger.info('AI request received', {
          userId,
          feature: data.feature,
          hasMessage: !!data.message,
          hasContext: !!data.context
        });
        
        // 2. Validate request
        validateRequest(data, ['feature']);
        validateFeature(data.feature);
        
        if (data.message) {
          validateMessage(data.message);
        }
        
        // 3. Check rate limiting (100 req/hour/user)
        await checkRateLimit(userId);
        
        // 4. Route to appropriate AI feature
        const result = await routeAIFeature(data);
        
        // 5. Add metadata
        const processingTime = Date.now() - startTime;
        const response = {
          ...result,
          processingTimeMs: processingTime,
          modelUsed: 'gpt-4',
          processedAt: new Date().toISOString()
        };
        
        functions.logger.info('AI request completed', {
          userId,
          feature: data.feature,
          processingTimeMs: processingTime
        });
        
        return response;
        
      } catch (error: any) {
        const processingTime = Date.now() - startTime;
        
        functions.logger.error('AI request failed', {
          error: error.message,
          code: error.code,
          userId: context.auth?.uid,
          feature: data?.feature,
          processingTimeMs: processingTime
        });
        
        // Map known errors to user-friendly messages
        if (error.code === 'unauthenticated') {
          throw error; // Already formatted
        }
        
        if (error.code === 'resource-exhausted') {
          throw error; // Already formatted
        }
        
        if (error.code === 'invalid-argument') {
          throw error; // Already formatted
        }
        
        // Unknown error
        throw new functions.https.HttpsError(
          'internal',
          'AI processing failed. Please try again later.'
        );
      }
    });
  
  /**
   * Route request to appropriate AI feature
   */
  async function routeAIFeature(data: any): Promise<any> {
    switch (data.feature) {
      case 'calendar':
        return await extractCalendarDates(data);
      
      case 'decision':
        return await summarizeDecisions(data);
      
      case 'urgency':
        return await detectUrgency(data);
      
      case 'rsvp':
        return await extractRSVP(data);
      
      case 'deadline':
        return await extractDeadlines(data);
      
      case 'agent':
        return await eventPlanningAgent(data);
      
      default:
        // This should never happen due to validation
        throw new functions.https.HttpsError(
          'invalid-argument',
          `Unknown AI feature: ${data.feature}`
        );
    }
  }
  ```

- [ ] Update `functions/src/index.ts` to export function
  ```typescript
  import * as admin from 'firebase-admin';
  admin.initializeApp();
  
  export { processAI } from './ai/processAI';
  ```

- [ ] Test compilation
  ```bash
  npm run build
  ```

**Checkpoint:** ✅ Main AI router compiles without errors

**Commit:** `feat(pr14): implement main AI router with feature routing`

---

## Phase 4: iOS AIService Implementation (45 minutes)

### 4.1: Create AIMetadata Model (15 min)

- [ ] Create `messAI/Models/AIMetadata.swift`
  ```swift
  import Foundation
  
  /// Urgency level for messages
  enum UrgencyLevel: String, Codable {
      case low      // "FYI", "when you can"
      case normal   // Regular messages
      case high     // "important", "need by tomorrow"
      case urgent   // "ASAP", "NOW", "TODAY"
  }
  
  /// Extracted date/time from message
  struct ExtractedDate: Codable, Equatable, Identifiable {
      let id: String
      let date: Date
      let time: Date?
      let eventDescription: String
      let confidence: Double  // 0.0-1.0
  }
  
  /// Group decision summary
  struct Decision: Codable, Equatable {
      let summary: String
      let participants: [String]
      let timestamp: Date
  }
  
  /// RSVP response status
  enum RSVPStatus: String, Codable {
      case yes, no, maybe, pending
  }
  
  /// RSVP response info
  struct RSVPResponse: Codable, Equatable {
      let eventId: String
      let response: RSVPStatus
      let respondedAt: Date
  }
  
  /// Deadline extracted from message
  struct Deadline: Codable, Equatable, Identifiable {
      let id: String
      let description: String
      let dueDate: Date
      let priority: UrgencyLevel
  }
  
  /// AI metadata attached to messages
  struct AIMetadata: Codable, Equatable {
      // Calendar Extraction (PR #15)
      var extractedDates: [ExtractedDate]?
      
      // Decision Summarization (PR #16)
      var isDecision: Bool?
      var decision: Decision?
      
      // Priority Highlighting (PR #17)
      var isUrgent: Bool?
      var urgencyLevel: UrgencyLevel?
      
      // RSVP Tracking (PR #18)
      var rsvpInfo: RSVPResponse?
      
      // Deadline Extraction (PR #19)
      var deadlines: [Deadline]?
      
      // Common metadata
      var processedAt: Date
      var processingTimeMs: Int?
      var modelUsed: String?
      
      init(processedAt: Date = Date()) {
          self.processedAt = processedAt
      }
  }
  ```

- [ ] Build project to verify compilation
  ```bash
  # Open Xcode and build (⌘B)
  ```

**Checkpoint:** ✅ AIMetadata model compiles without errors

**Commit:** `feat(pr14): add AIMetadata model for AI results`

---

### 4.2: Update Message Model (10 min)

- [ ] Open `messAI/Models/Message.swift`

- [ ] Add aiMetadata property
  ```swift
  struct Message: Identifiable, Codable, Equatable {
      // ... existing properties ...
      
      // AI metadata (PR #14+)
      var aiMetadata: AIMetadata?
      
      // ... existing methods ...
  }
  ```

- [ ] Update Firestore conversion to include aiMetadata
  ```swift
  // In toDictionary() method
  var dict: [String: Any] = [
      // ... existing fields ...
  ]
  
  // Add AI metadata if present
  if let aiMetadata = aiMetadata {
      if let data = try? JSONEncoder().encode(aiMetadata),
         let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
          dict["aiMetadata"] = json
      }
  }
  
  return dict
  
  // In init(dictionary:) initializer
  if let aiMetadataDict = dictionary["aiMetadata"] as? [String: Any],
     let jsonData = try? JSONSerialization.data(withJSONObject: aiMetadataDict),
     let metadata = try? JSONDecoder().decode(AIMetadata.self, from: jsonData) {
      self.aiMetadata = metadata
  }
  ```

- [ ] Build project
  ```bash
  # Build in Xcode (⌘B)
  ```

**Checkpoint:** ✅ Message model updated with AI metadata

**Commit:** `feat(pr14): add aiMetadata field to Message model`

---

### 4.3: Create AIService (20 min)

- [ ] Create `messAI/Services/AIService.swift`
  ```swift
  import Foundation
  import FirebaseFunctions
  
  /// AI features available through Cloud Functions
  enum AIFeature: String, Codable {
      case calendar
      case decision
      case urgency
      case rsvp
      case deadline
      case agent
  }
  
  /// Errors that can occur during AI processing
  enum AIError: LocalizedError {
      case unauthenticated
      case rateLimitExceeded
      case invalidResponse
      case networkError
      case serverError(String)
      case unknownFeature
      
      var errorDescription: String? {
          switch self {
          case .unauthenticated:
              return "You must be logged in to use AI features."
          case .rateLimitExceeded:
              return "Too many AI requests. Please try again in an hour."
          case .invalidResponse:
              return "Received invalid response from AI service."
          case .networkError:
              return "Network error. Please check your connection."
          case .serverError(let message):
              return "Server error: \(message)"
          case .unknownFeature:
              return "Unknown AI feature requested."
          }
      }
  }
  
  /// Service for calling AI Cloud Functions
  @MainActor
  class AIService {
      static let shared = AIService()
      private let functions = Functions.functions()
      
      // Cache for AI results (5 minutes)
      private var cache: [String: (result: Any, timestamp: Date)] = [:]
      private let cacheExpiration: TimeInterval = 300 // 5 minutes
      
      private init() {}
      
      /// Process a message with specified AI feature
      func processMessage(
          _ message: String,
          feature: AIFeature,
          context: [Message]? = nil,
          conversationId: String? = nil
      ) async throws -> [String: Any] {
          
          // Check cache
          let cacheKey = "\(feature.rawValue):\(message.prefix(100))"
          if let cached = cache[cacheKey],
             Date().timeIntervalSince(cached.timestamp) < cacheExpiration {
              print("✅ AIService: Cache hit for \(feature.rawValue)")
              return cached.result as! [String: Any]
          }
          
          // Prepare request data
          var data: [String: Any] = [
              "feature": feature.rawValue,
              "message": message
          ]
          
          if let context = context {
              data["context"] = context.map { [
                  "text": $0.text,
                  "senderId": $0.senderId,
                  "sentAt": $0.sentAt.timeIntervalSince1970
              ]}
          }
          
          if let conversationId = conversationId {
              data["conversationId"] = conversationId
          }
          
          print("📤 AIService: Calling Cloud Function for \(feature.rawValue)")
          
          // Call Cloud Function
          let callable = functions.httpsCallable("processAI")
          
          do {
              let result = try await callable.call(data)
              
              guard let resultData = result.data as? [String: Any] else {
                  throw AIError.invalidResponse
              }
              
              print("✅ AIService: Received response from \(feature.rawValue)")
              
              // Cache result
              cache[cacheKey] = (resultData, Date())
              
              return resultData
              
          } catch let error as NSError {
              print("❌ AIService: Error calling Cloud Function: \(error)")
              throw mapFirebaseError(error)
          }
      }
      
      /// Map Firebase errors to AIError
      private func mapFirebaseError(_ error: NSError) -> AIError {
          switch error.code {
          case FunctionsErrorCode.unauthenticated.rawValue:
              return .unauthenticated
          case FunctionsErrorCode.resourceExhausted.rawValue:
              return .rateLimitExceeded
          case FunctionsErrorCode.unavailable.rawValue:
              return .networkError
          case FunctionsErrorCode.invalidArgument.rawValue:
              return .serverError(error.localizedDescription)
          default:
              return .serverError(error.localizedDescription)
          }
      }
      
      /// Clear cache (useful for testing)
      func clearCache() {
          cache.removeAll()
          print("🗑️ AIService: Cache cleared")
      }
  }
  ```

- [ ] Add to Xcode project
  - [ ] Open Xcode
  - [ ] Right-click `Services` folder
  - [ ] Add Files to "messAI"
  - [ ] Select `AIService.swift`
  - [ ] Ensure target is checked

- [ ] Build project
  ```bash
  # Build in Xcode (⌘B)
  ```

**Checkpoint:** ✅ AIService compiles without errors

**Commit:** `feat(pr14): implement iOS AIService for Cloud Function calls`

---

## Phase 5: Deployment & Testing (30 minutes)

### 5.1: Deploy Cloud Functions (10 min)

- [ ] Build TypeScript
  ```bash
  cd functions
  npm run build
  ```

- [ ] Verify build output
  ```bash
  ls -la lib/
  # Should see compiled .js files
  ```

- [ ] Deploy to Firebase
  ```bash
  firebase deploy --only functions
  ```

- [ ] Wait for deployment to complete
  - [ ] Watch console output
  - [ ] Note the function URL
  - [ ] Verify "Deploy complete" message

- [ ] Verify in Firebase Console
  - [ ] Open https://console.firebase.google.com
  - [ ] Navigate to Functions
  - [ ] Confirm `processAI` function is listed
  - [ ] Check function logs

**Checkpoint:** ✅ Cloud Function deployed successfully

**Commit:** `feat(pr14): deploy AI Cloud Functions to Firebase`

---

### 5.2: Test from iOS App (15 min)

- [ ] Create test view or add to existing view
  ```swift
  // Add a test button somewhere (e.g., in ChatListView)
  Button("Test AI") {
      Task {
          await testAIInfrastructure()
      }
  }
  
  func testAIInfrastructure() async {
      print("🧪 Testing AI infrastructure...")
      
      do {
          // Test calendar feature (placeholder)
          let result = try await AIService.shared.processMessage(
              "Soccer practice Thursday at 4pm",
              feature: .calendar
          )
          print("✅ AI Test Success:", result)
          print("📊 Processing time:", result["processingTimeMs"] ?? "N/A")
          print("🤖 Model:", result["modelUsed"] ?? "N/A")
          
      } catch {
          print("❌ AI Test Failed:", error.localizedDescription)
      }
  }
  ```

- [ ] Run app on simulator
  ```bash
  # Open Xcode and run (⌘R)
  ```

- [ ] Tap "Test AI" button

- [ ] Verify in console:
  - [ ] "Calling Cloud Function" message appears
  - [ ] Response received from Cloud Function
  - [ ] No errors in console

- [ ] Verify in Firebase Console:
  - [ ] Open Functions logs
  - [ ] See "AI request received" log entry
  - [ ] See "AI request completed" log entry
  - [ ] No error logs

**Checkpoint:** ✅ Can successfully call Cloud Function from iOS

**Commit:** `feat(pr14): verify AI infrastructure end-to-end`

---

### 5.3: Test Error Scenarios (5 min)

- [ ] Test unauthenticated request
  - [ ] Log out user
  - [ ] Try to call AI
  - [ ] Verify "must be logged in" error

- [ ] Test invalid feature
  - [ ] Call with feature: "invalid"
  - [ ] Verify "Unknown feature" error

- [ ] Test rate limiting (optional - takes time)
  - [ ] Make 100+ rapid requests
  - [ ] Verify rate limit error on 101st

**Checkpoint:** ✅ Error handling works correctly

---

## Completion Checklist

### Code Quality
- [ ] All TypeScript compiles without errors
- [ ] All Swift compiles without errors
- [ ] No ESLint warnings in Cloud Functions
- [ ] No Xcode warnings

### Functionality
- [ ] Cloud Function deployed to Firebase
- [ ] Can call function from iOS app
- [ ] Authentication is required and enforced
- [ ] Rate limiting works (100 req/hour/user)
- [ ] All 6 AI features route correctly
- [ ] Placeholder functions return expected format
- [ ] Error handling works for all error types

### Security
- [ ] API keys never in iOS app code
- [ ] .env file in .gitignore
- [ ] Firebase config uses environment variables
- [ ] Authentication enforced on Cloud Function
- [ ] Rate limiting prevents abuse

### Documentation
- [ ] Code comments added to complex functions
- [ ] Function parameters documented
- [ ] Error types documented

### Git
- [ ] All changes committed
- [ ] Commit messages follow convention
- [ ] Branch ready to merge

---

## Final Verification

- [ ] Run full build in Xcode
  ```bash
  # Clean build folder: ⌘⇧K
  # Build: ⌘B
  # Result: Build Succeeded ✅
  ```

- [ ] Test on simulator
  ```bash
  # Run app: ⌘R
  # Log in
  # Call AI test function
  # Result: Success ✅
  ```

- [ ] Check Firebase Console
  - [ ] Functions deployed ✅
  - [ ] Logs show requests ✅
  - [ ] No errors ✅

- [ ] Check git status
  ```bash
  git status
  # Verify all files committed
  ```

---

## Success! 🎉

**Infrastructure Ready For:**
- ✅ PR #15: Calendar Extraction
- ✅ PR #16: Decision Summarization
- ✅ PR #17: Priority Highlighting
- ✅ PR #18: RSVP Tracking
- ✅ PR #19: Deadline Extraction
- ✅ PR #20: Multi-Step Event Planning Agent

**Total Time:** ~2-3 hours  
**Files Created:** 12 files  
**Lines of Code:** ~800 lines  

**Next Step:** Merge to main and start PR #15!
