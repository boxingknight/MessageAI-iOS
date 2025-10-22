# PR#14: Cloud Functions Setup & AI Service Base

**Estimated Time:** 2-3 hours  
**Complexity:** MEDIUM-HIGH  
**Dependencies:** PR #1-13 (Core messaging complete)  
**Priority:** 🔴 CRITICAL - Foundation for all AI features

---

## Overview

### What We're Building

The **AI infrastructure foundation** that enables all five required AI features for busy parents. This PR sets up:
- **Firebase Cloud Functions** - Serverless backend for AI processing
- **OpenAI Integration** - GPT-4 API connection with secure key management
- **Base AI Service** - Routing architecture for all AI features
- **iOS AIService** - Type-safe Swift wrapper for Cloud Function calls
- **Rate Limiting** - Protect against excessive API usage (100 req/hour/user)
- **Security Layer** - Authentication, authorization, validation
- **AI Metadata Models** - Data structures for storing AI results

**This is the foundation**. Everything else (calendar extraction, decision summarization, RSVP tracking, etc.) builds on this infrastructure.

### Why It Matters

**User Impact**: None visible yet - this is pure infrastructure  
**Developer Impact**: MASSIVE - enables entire AI feature set  
**Technical Debt**: Zero - done right from the start  
**Risk**: HIGH - must secure API keys, implement rate limiting, handle errors properly

### Success in One Sentence

"This PR is successful when we can securely call OpenAI from iOS through Cloud Functions with authentication, rate limiting, and proper error handling—ready to implement any AI feature."

---

## Technical Design

### Architecture Decisions

#### Decision 1: Cloud Functions vs Client-Side AI

**Options Considered:**
1. **Option A: Cloud Functions** (Serverless backend)
   - **Pros**: API keys secured server-side, rate limiting possible, scalable, no iOS app size increase
   - **Cons**: Network latency, cold start delays, Firebase costs

2. **Option B: Client-Side** (Call OpenAI directly from iOS)
   - **Pros**: Lower latency, no Firebase costs, offline capable
   - **Cons**: **SECURITY RISK** - API keys exposed in app binary, no rate limiting, large app size

**Chosen:** Option A - Cloud Functions

**Rationale:**
- **Security**: API keys NEVER in client code (easily extracted from app binary)
- **Control**: Server-side rate limiting prevents abuse
- **Flexibility**: Easy to switch AI providers or models without app update
- **Cost Control**: Server can implement caching, batching, optimization
- **Compliance**: Sensitive data processing on server (GDPR-friendly)

**Trade-offs:**
- Gain: Security, control, flexibility, cost management
- Lose: ~500ms network latency per AI call (acceptable for non-realtime features)

---

#### Decision 2: OpenAI vs Other AI Providers

**Options Considered:**
1. **Option A: OpenAI GPT-4**
   - **Pros**: Best quality, function calling, reliable, well-documented
   - **Cons**: Most expensive ($0.03/1K tokens)

2. **Option B: Anthropic Claude**
   - **Pros**: Long context, good quality, cheaper
   - **Cons**: No function calling (critical for structured output)

3. **Option C: Open-source (Llama, Mistral)**
   - **Pros**: Free, privacy-focused
   - **Cons**: Need hosting, lower quality, no function calling

**Chosen:** Option A - OpenAI GPT-4

**Rationale:**
- **Function Calling**: Critical for structured JSON output (dates, RSVPs, etc.)
- **Quality**: Best-in-class for entity extraction and classification
- **Reliability**: 99.9% uptime, proven at scale
- **Development Speed**: Excellent documentation, many examples
- **Budget**: ~$5-10/month for MVP testing (100 requests/day * 1000 tokens * $0.03/1K)

**Trade-offs:**
- Gain: Best quality, function calling, reliability
- Lose: Higher cost (mitigated by rate limiting and caching)

---

#### Decision 3: TypeScript vs JavaScript for Cloud Functions

**Options Considered:**
1. **Option A: TypeScript**
   - **Pros**: Type safety, better IDE support, catches errors at compile time
   - **Cons**: Build step required, slightly slower development

2. **Option B: JavaScript**
   - **Pros**: No build step, faster iteration
   - **Cons**: Runtime errors, harder to refactor

**Chosen:** Option A - TypeScript

**Rationale:**
- **Type Safety**: Prevents runtime errors (especially with OpenAI API types)
- **Refactoring**: Safe to change code as features evolve
- **Teamwork**: Self-documenting code with interfaces
- **Industry Standard**: 80%+ of Cloud Functions projects use TypeScript

---

#### Decision 4: Single vs Multiple Cloud Functions

**Options Considered:**
1. **Option A: Single Function with Router**
   - **Pros**: Shared code, single deployment, consistent auth/rate-limit
   - **Cons**: Larger cold start, harder to optimize per-feature

2. **Option B: Separate Function per Feature**
   - **Pros**: Isolated, optimized per feature, independent deploys
   - **Cons**: Code duplication, harder to maintain consistency

**Chosen:** Option A - Single Function with Router

**Rationale:**
- **DRY**: Authentication, rate limiting, error handling shared
- **Consistency**: All features use same patterns
- **Deployment**: Single deploy for all AI features
- **Cost**: Fewer function instances = lower costs
- **Maintainability**: Changes to common logic applied to all features

---

### Data Model

**New AI Metadata Structure:**
```swift
// Models/AIMetadata.swift
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
}

enum UrgencyLevel: String, Codable {
    case low      // "FYI", "when you can"
    case normal   // Regular messages
    case high     // "important", "need by tomorrow"
    case urgent   // "ASAP", "NOW", "TODAY"
}

struct ExtractedDate: Codable, Equatable, Identifiable {
    let id: String
    let date: Date
    let time: Date?
    let eventDescription: String
    let confidence: Double  // 0.0-1.0
}

struct Decision: Codable, Equatable {
    let summary: String
    let participants: [String]
    let timestamp: Date
}

struct RSVPResponse: Codable, Equatable {
    let eventId: String
    let response: RSVPStatus
    let respondedAt: Date
}

enum RSVPStatus: String, Codable {
    case yes, no, maybe, pending
}

struct Deadline: Codable, Equatable, Identifiable {
    let id: String
    let description: String
    let dueDate: Date
    let priority: UrgencyLevel
}

// Update Message model
extension Message {
    // Add AI metadata field
    var aiMetadata: AIMetadata?
}
```

**Firestore Schema Update:**
```
/conversations/{conversationId}/messages/{messageId}
  - senderId: String
  - text: String
  - sentAt: Timestamp
  - status: String
  - aiMetadata: Map<String, Any> (NEW!)
    {
      "extractedDates": [
        {
          "id": "uuid",
          "date": "2025-10-25T00:00:00Z",
          "time": "2025-10-25T16:00:00Z",
          "eventDescription": "Soccer practice",
          "confidence": 0.95
        }
      ],
      "isUrgent": true,
      "urgencyLevel": "high",
      "processedAt": Timestamp,
      "processingTimeMs": 450,
      "modelUsed": "gpt-4"
    }
```

---

### Cloud Functions Design

**File Structure:**
```
functions/
├── src/
│   ├── index.ts                    # Main export file
│   ├── ai/
│   │   ├── processAI.ts            # Main AI router function
│   │   ├── calendarExtraction.ts   # PR #15 (placeholder)
│   │   ├── decisionSummary.ts      # PR #16 (placeholder)
│   │   ├── priorityDetection.ts    # PR #17 (placeholder)
│   │   ├── rsvpTracking.ts         # PR #18 (placeholder)
│   │   ├── deadlineExtraction.ts   # PR #19 (placeholder)
│   │   └── eventPlanningAgent.ts   # PR #20 (placeholder)
│   ├── middleware/
│   │   ├── auth.ts                 # Authentication middleware
│   │   ├── rateLimit.ts            # Rate limiting middleware
│   │   └── validation.ts           # Input validation
│   └── utils/
│       ├── openai.ts               # OpenAI client wrapper
│       ├── firestore.ts            # Firestore helpers
│       └── logger.ts               # Logging utilities
├── package.json
├── tsconfig.json
├── .env                            # Local development (NOT in git)
└── .env.example                    # Template for .env

```

**Main AI Function (`functions/src/ai/processAI.ts`):**
```typescript
import * as functions from 'firebase-functions';
import OpenAI from 'openai';
import { requireAuth } from '../middleware/auth';
import { checkRateLimit } from '../middleware/rateLimit';
import { validateRequest } from '../middleware/validation';

// Initialize OpenAI
const openai = new OpenAI({
  apiKey: functions.config().openai.key || process.env.OPENAI_API_KEY
});

export const processAI = functions
  .runWith({
    memory: '512MB',
    timeoutSeconds: 30,
    maxInstances: 10
  })
  .https.onCall(async (data, context) => {
    const startTime = Date.now();
    
    try {
      // 1. Authentication required
      requireAuth(context);
      const userId = context.auth!.uid;
      
      // 2. Rate limiting (100 requests/hour/user)
      await checkRateLimit(userId);
      
      // 3. Validate request
      validateRequest(data, ['feature']);
      
      // 4. Route to appropriate AI feature
      const result = await routeAIFeature(data);
      
      // 5. Log metrics
      const processingTime = Date.now() - startTime;
      functions.logger.info('AI processing complete', {
        userId,
        feature: data.feature,
        processingTimeMs: processingTime
      });
      
      return {
        ...result,
        processingTimeMs: processingTime,
        modelUsed: 'gpt-4'
      };
      
    } catch (error) {
      functions.logger.error('AI processing failed', { error, data });
      
      // Map errors to user-friendly messages
      if (error.code === 'rate_limit_exceeded') {
        throw new functions.https.HttpsError(
          'resource-exhausted',
          'Too many AI requests. Please try again in an hour.'
        );
      }
      
      throw new functions.https.HttpsError(
        'internal',
        'AI processing failed. Please try again.'
      );
    }
  });

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
      throw new functions.https.HttpsError(
        'invalid-argument',
        `Unknown AI feature: ${data.feature}`
      );
  }
}

// Placeholder implementations (full implementations in feature PRs)
async function extractCalendarDates(data: any) {
  // TODO: Implement in PR #15
  return { events: [] };
}

async function summarizeDecisions(data: any) {
  // TODO: Implement in PR #16
  return { hasDecision: false };
}

async function detectUrgency(data: any) {
  // TODO: Implement in PR #17
  return { urgencyLevel: 'normal', isUrgent: false };
}

async function extractRSVP(data: any) {
  // TODO: Implement in PR #18
  return { response: 'pending' };
}

async function extractDeadlines(data: any) {
  // TODO: Implement in PR #19
  return { deadlines: [] };
}

async function eventPlanningAgent(data: any) {
  // TODO: Implement in PR #20
  return { message: 'Agent not yet implemented' };
}
```

---

### iOS AIService Design

**File:** `Services/AIService.swift`

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
        
        // Call Cloud Function
        let callable = functions.httpsCallable("processAI")
        
        do {
            let result = try await callable.call(data)
            
            guard let resultData = result.data as? [String: Any] else {
                throw AIError.invalidResponse
            }
            
            // Cache result
            cache[cacheKey] = (resultData, Date())
            
            return resultData
            
        } catch let error as NSError {
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
        default:
            return .serverError(error.localizedDescription)
        }
    }
    
    /// Clear cache (useful for testing)
    func clearCache() {
        cache.removeAll()
    }
}
```

---

## Implementation Details

### Phase 1: Cloud Functions Setup (45 min)

**Step 1: Initialize Firebase Cloud Functions**
```bash
# From project root
firebase init functions

# Select options:
# - Use an existing project: messageai-95c8f
# - TypeScript: YES
# - ESLint: YES
# - Install dependencies: YES
```

**Step 2: Install Dependencies**
```bash
cd functions
npm install openai@^4.0.0
npm install @types/node --save-dev
```

**Step 3: Create Environment File**
```bash
# Create .env file (NOT committed to git)
echo "OPENAI_API_KEY=sk-proj-your-key-here" > .env
echo "OPENAI_MODEL=gpt-4" >> .env

# Add to .gitignore
echo ".env" >> .gitignore
```

**Step 4: Set Firebase Config**
```bash
# Set OpenAI key in Firebase environment
firebase functions:config:set openai.key="sk-proj-your-key-here"

# Verify
firebase functions:config:get
```

---

### Phase 2: Implement AI Router (60 min)

**Create Base Structure:**
```typescript
// functions/src/middleware/auth.ts
import * as functions from 'firebase-functions';

export function requireAuth(context: functions.https.CallableContext) {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'Authentication required'
    );
  }
}

// functions/src/middleware/rateLimit.ts
import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

const RATE_LIMIT_PER_HOUR = 100;

export async function checkRateLimit(userId: string): Promise<void> {
  const hourKey = Math.floor(Date.now() / 3600000); // Hour bucket
  const rateLimitRef = admin.firestore()
    .collection('rateLimits')
    .doc(`${userId}_${hourKey}`);
  
  const doc = await rateLimitRef.get();
  const count = doc.exists ? (doc.data()?.count || 0) : 0;
  
  if (count >= RATE_LIMIT_PER_HOUR) {
    throw new functions.https.HttpsError(
      'resource-exhausted',
      'Rate limit exceeded. Try again in an hour.'
    );
  }
  
  // Increment counter
  await rateLimitRef.set({
    count: count + 1,
    updatedAt: admin.firestore.FieldValue.serverTimestamp()
  }, { merge: true });
}

// functions/src/middleware/validation.ts
import * as functions from 'firebase-functions';

export function validateRequest(data: any, requiredFields: string[]) {
  for (const field of requiredFields) {
    if (!data[field]) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        `Missing required field: ${field}`
      );
    }
  }
}
```

**Implement Main Router:**
(See Cloud Functions Design section above for full implementation)

---

### Phase 3: iOS AIService (45 min)

**Create AIService.swift:**
(See iOS AIService Design section above for full implementation)

**Create AIMetadata.swift:**
(See Data Model section above for full implementation)

---

### Phase 4: Testing & Deployment (30 min)

**Deploy Cloud Functions:**
```bash
cd functions
npm run build
firebase deploy --only functions
```

**Test from iOS:**
```swift
// In a test view or ViewModel
Task {
    do {
        let result = try await AIService.shared.processMessage(
            "Soccer practice Thursday at 4pm",
            feature: .calendar
        )
        print("AI Result:", result)
    } catch {
        print("AI Error:", error.localizedDescription)
    }
}
```

---

## Testing Strategy

### Unit Tests

**Cloud Functions Tests:**
- ✅ Authentication middleware rejects unauthenticated requests
- ✅ Rate limiting blocks after 100 requests per hour
- ✅ Validation catches missing required fields
- ✅ Router correctly routes each feature
- ✅ Error handling returns user-friendly messages
- ✅ Placeholder functions return expected structure

**iOS Tests:**
- ✅ AIService correctly calls Cloud Function
- ✅ AIService caches results for 5 minutes
- ✅ AIService maps Firebase errors to AIError
- ✅ AIMetadata encodes/decodes correctly to Firestore

---

### Integration Tests

**End-to-End Flow:**
1. User authenticated in iOS app
2. Call AIService.processMessage()
3. Request reaches Cloud Function with auth token
4. Rate limit check passes
5. Feature router executes
6. Response returns to iOS
7. Result cached for 5 minutes

**Rate Limit Test:**
1. Make 100 AI requests in quick succession
2. Verify all succeed
3. Make 101st request
4. Verify rate limit error returned

---

### Edge Cases

- ❌ **Unauthenticated Request**: Reject with clear error
- ❌ **Missing API Key**: Fail gracefully with log message
- ❌ **Invalid Feature**: Return "unknown feature" error
- ❌ **Network Timeout**: Return network error after 30 seconds
- ❌ **OpenAI API Down**: Return server error with retry suggestion
- ❌ **Malformed Response**: Return invalid response error

---

## Success Criteria

**This PR is complete when:**

### Functional Requirements
- [ ] Cloud Functions deployed and callable from iOS
- [ ] Authentication required and enforced
- [ ] Rate limiting works (100 req/hour/user)
- [ ] All 6 AI features route to placeholder functions
- [ ] Placeholder functions return expected structure
- [ ] iOS AIService successfully calls Cloud Function
- [ ] AI results cached for 5 minutes
- [ ] Error handling works for all error types

### Performance Targets
- [ ] Cold start: < 3 seconds
- [ ] Warm response: < 1 second
- [ ] Total request time (iOS → Cloud → iOS): < 2 seconds
- [ ] Rate limit check: < 50ms

### Quality Gates
- [ ] All TypeScript compiles without errors
- [ ] All Swift compiles without errors
- [ ] ESLint passes with no warnings
- [ ] Firebase console shows function deployed
- [ ] Can view logs in Firebase console
- [ ] API keys never exposed in client code
- [ ] .env file in .gitignore

---

## Risk Assessment

### Risk 1: API Key Exposure 🔴 CRITICAL
**Likelihood:** MEDIUM  
**Impact:** CRITICAL  
**Mitigation:** 
- Use Firebase Functions config (never commit keys)
- Add .env to .gitignore
- Regular audit of git history
- Use environment variables, never hardcode
**Status:** ✅ Mitigated

### Risk 2: Rate Limit Bypass 🟡 MEDIUM
**Likelihood:** LOW  
**Impact:** HIGH (cost explosion)  
**Mitigation:**
- Server-side rate limiting (can't be bypassed from client)
- Per-user tracking in Firestore
- Alert if any user exceeds 200 req/hour
- Firebase budget alerts set
**Status:** ✅ Mitigated

### Risk 3: Cold Start Latency 🟡 MEDIUM
**Likelihood:** HIGH  
**Impact:** MEDIUM (poor UX)  
**Mitigation:**
- Set min instances to 1 for production ($0.20/day)
- Show loading states in UI
- Cache results aggressively
- Consider warming function with scheduled job
**Status:** ⚠️ Accept for MVP (optimize later)

### Risk 4: OpenAI API Cost 🟢 LOW
**Likelihood:** MEDIUM  
**Impact:** LOW (budget-manageable)  
**Mitigation:**
- Rate limiting caps usage
- Caching reduces duplicate calls
- Budget alert at $50/month
- Monitor cost per user in Firebase
**Status:** ✅ Mitigated

---

## Timeline

**Total Estimate:** 2-3 hours

| Phase | Task | Time | Status |
|-------|------|------|--------|
| 1 | Initialize Cloud Functions | 30 min | ⏳ |
| 2 | Create AI router with middleware | 60 min | ⏳ |
| 3 | Implement iOS AIService | 45 min | ⏳ |
| 4 | Deploy and test | 30 min | ⏳ |

**Note:** This is infrastructure only. No user-visible features yet. That comes in PRs #15-20.

---

## Dependencies

**Requires:**
- [x] PR #1-13: Core messaging complete
- [x] Firebase project active
- [ ] OpenAI API account and key
- [ ] Firebase billing enabled (for Cloud Functions)

**Blocks:**
- PR #15: Calendar Extraction (needs AI infrastructure)
- PR #16: Decision Summarization (needs AI infrastructure)
- PR #17: Priority Highlighting (needs AI infrastructure)
- PR #18: RSVP Tracking (needs AI infrastructure)
- PR #19: Deadline Extraction (needs AI infrastructure)
- PR #20: Multi-Step Agent (needs AI infrastructure)

---

## References

- OpenAI API Documentation: https://platform.openai.com/docs
- Firebase Cloud Functions: https://firebase.google.com/docs/functions
- Firebase Functions TypeScript: https://firebase.google.com/docs/functions/typescript
- Rate Limiting Strategies: https://firebase.google.com/docs/firestore/solutions/counters
- Security Best Practices: https://firebase.google.com/docs/functions/security

---

*This PR is the foundation for all AI features. Get this right, and the rest will be easy.*

