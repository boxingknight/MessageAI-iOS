# PR#17: Priority Highlighting Feature - AI-Powered Urgent Message Detection

**Status:** 📋 PLANNED (Documentation complete, ready to implement!)  
**Branch:** `feature/pr17-priority-highlighting` (to be created)  
**Timeline:** 2-3 hours estimated  
**Priority:** 🟡 HIGH - Safety feature to prevent missing critical information  
**Depends on:** PR#14 (Cloud Functions Setup) COMPLETE ✅, PR#16 (Decision Summarization) RECOMMENDED  
**Created:** October 22, 2025

---

## Overview

### What We're Building

An AI-powered feature that **automatically detects and visually highlights urgent or important messages** using GPT-4 context analysis. When critical messages arrive (school pickup changes, emergency notices, time-sensitive requests), the app:

1. **Analyzes** message content and conversation context with GPT-4
2. **Classifies** urgency level (🔴 Critical, 🟡 High, 🟢 Normal)
3. **Highlights** message visually (red/yellow border, badge, emoji indicator)
4. **Surfaces** critical messages in a priority section at top of chat
5. **Notifies** users with enhanced alerts (future: vibration, sound)

**Target User:** Sarah, working mom, who needs to know immediately that "Pickup changed to 2pm TODAY" is critical, but "Anyone bringing cookies Friday?" can wait.

**Value Proposition:** "Never miss an urgent message buried in 100+ daily group chat messages. AI flags what needs attention NOW vs what can wait."

### Why It Matters

**The Problem:**
- 100+ messages/day across family, school, work groups
- Critical information buried in casual conversation
- **Parents miss urgent info**: Pickup changes, last-minute cancellations, emergency notices
- High anxiety from "What if I missed something important?"
- **Real consequences**: Late pickups, missed deadlines, unprepared kids

**The Solution:**
- AI reads every message and assesses urgency using context
- Critical messages visually stand out (red border, 🚨 badge)
- Priority section shows all urgent messages across all chats
- Reduces "scanning anxiety" - trust AI to flag what matters

**Business Impact:**
- 🎯 Safety feature (prevents real-world problems)
- 🎯 Anxiety reducer (users trust app to catch urgent info)
- 🎯 Differentiator (WhatsApp/iMessage treat all messages equally)
- 🎯 Viral potential ("This app saved me from late pickup!")
- 🎯 Foundation for smart notifications (PR#22)

### Success in One Sentence

"Sarah receives 'Noah needs pickup at 2pm TODAY' in a busy group chat, and the app immediately highlights it in red with a 🚨 badge so she sees it before it's too late."

---

## Technical Design

### Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                         iOS App (SwiftUI)                        │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ ChatView (Conversation Display)                           │  │
│  │  ├─ MessageBubbleView (with urgency indicators) ← ENHANCED│ │
│  │  │   ├─ 🔴 Red border for Critical                        │  │
│  │  │   ├─ 🟡 Yellow border for High                         │  │
│  │  │   └─ 🚨 Badge icon for Critical                        │  │
│  │  └─ PriorityBannerView (critical messages) ← NEW!        │  │
│  └──────────────────────────────────────────────────────────┘  │
│                           │                                      │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ ChatListView (Conversation List)                          │  │
│  │  ├─ ConversationRowView (with urgency badge) ← ENHANCED  │  │
│  │  │   └─ 🔴 Red badge if conversation has urgent message   │  │
│  │  └─ PriorityTabView (all urgent messages) ← NEW!         │  │
│  └──────────────────────────────────────────────────────────┘  │
│                           │                                      │
│                           ▼                                      │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ ChatViewModel                                             │  │
│  │  ├─ detectPriority(message) → triggers AI                │  │
│  │  ├─ priorityMessages: [Message] (filtered view)          │  │
│  │  └─ updateMessagePriority(id, level)                     │  │
│  └──────────────────────────────────────────────────────────┘  │
│                           │                                      │
│                           ▼                                      │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ AIService.detectPriority(message, context)                │  │
│  │  - Calls Cloud Functions with message + recent context    │  │
│  │  - Returns PriorityLevel + confidence + reason            │  │
│  │  - Caches for 5 minutes (same message, same result)      │  │
│  └──────────────────────────────────────────────────────────┘  │
│                           │                                      │
└───────────────────────────┼──────────────────────────────────────┘
                            │ HTTPS Request
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│              Firebase Cloud Functions (Node.js)                  │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ processAI (Router)                                        │  │
│  │  ├─ auth middleware (verify user)                         │  │
│  │  ├─ rate limit (100 req/hour)                             │  │
│  │  ├─ route to: priorityDetection()                        │  │
│  │  └─ return PriorityLevel + confidence + reason           │  │
│  └──────────────────────────────────────────────────────────┘  │
│                           │                                      │
│                           ▼                                      │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ priorityDetection.ts (AI Feature #3)                      │  │
│  │  ├─ Build context prompt (recent messages)               │  │
│  │  ├─ Analyze with GPT-4 (keywords + context + time)       │  │
│  │  ├─ Extract urgency indicators                            │  │
│  │  ├─ Classify: Critical/High/Normal                        │  │
│  │  └─ Return structured response                            │  │
│  └──────────────────────────────────────────────────────────┘  │
│                           │                                      │
│                           ▼                                      │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ OpenAI GPT-4 API                                          │  │
│  │  - Receives: message + context + urgency detection prompt│  │
│  │  - Returns: urgency level + confidence + reasoning       │  │
│  └──────────────────────────────────────────────────────────┘  │
│                           │                                      │
└───────────────────────────┼──────────────────────────────────────┘
                            │ Response
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│                      Firestore Database                          │
│                                                                  │
│  /messages/{messageId}                                          │
│    - aiMetadata: {                                              │
│        priorityLevel: "critical" | "high" | "normal"           │
│        priorityConfidence: 0.0-1.0                              │
│        priorityReason: "Pickup time change - same day"         │
│        priorityDetectedAt: Timestamp                            │
│      }                                                           │
│                                                                  │
│  /conversations/{conversationId}                                │
│    - hasUrgentMessages: boolean                                │
│    - urgentMessageCount: number                                │
│    - lastUrgentMessageAt: Timestamp                             │
└─────────────────────────────────────────────────────────────────┘
```

### Data Flow

**When a new message arrives:**

```
1. Message received via Firestore listener
   └─> ChatViewModel.onMessageReceived()

2. Check if message needs priority detection
   ├─> Skip if: sender is currentUser (don't analyze own messages)
   ├─> Skip if: message already has aiMetadata.priorityLevel
   └─> Proceed if: new message from others

3. Trigger AI priority detection
   └─> AIService.detectPriority(message, recentContext)
       ├─> Fetch last 10 messages for context
       ├─> Call Cloud Function: processAI(feature: "priority_detection")
       └─> Cloud Function calls GPT-4 with structured prompt

4. GPT-4 analyzes message
   ├─> Keywords: "urgent", "emergency", "ASAP", "today", "now", "important"
   ├─> Time sensitivity: "pickup at 2pm TODAY", "due by 3pm"
   ├─> Consequences: "or else", "last chance", "required"
   ├─> Context: Recent conversation topics, sender role
   └─> Returns: { level: "critical", confidence: 0.92, reason: "Same-day time change" }

5. Update message in Firestore
   └─> Update aiMetadata.priorityLevel, priorityConfidence, priorityReason

6. Update local UI immediately
   ├─> Message bubble gets red/yellow border + badge
   ├─> Message appears in Priority Banner if critical
   └─> Conversation row shows urgency indicator
```

---

## Key Design Decisions

### Decision 1: Processing Trigger - Automatic (Real-Time) vs Manual

**Options Considered:**

**Option A: Automatic (Real-Time)**
- ✅ **Pros:** Zero user friction, all messages analyzed, never miss urgent info
- ✅ **Pros:** Most valuable for safety (catches urgent before user reads)
- ❌ **Cons:** Higher API costs (~$0.01 per message analyzed)
- ❌ **Cons:** Rate limiting complexity (100 messages/hour in busy group)

**Option B: Manual (User-Triggered)**
- ✅ **Pros:** Lower API costs (user controls when to analyze)
- ✅ **Pros:** No rate limit issues
- ❌ **Cons:** User must remember to trigger (defeats purpose of "automatic")
- ❌ **Cons:** Might miss urgent message if user doesn't trigger in time

**Option C: Hybrid (Keywords → GPT-4)**
- ✅ **Pros:** Best of both worlds - cheap keyword filter, AI for complex cases
- ✅ **Pros:** Low cost for normal messages, GPT-4 only for potential urgency
- ✅ **Pros:** Fast response (<500ms for keyword check, <2s for GPT-4 if needed)
- ❌ **Cons:** Might miss urgently-phrased messages without keywords

**Chosen:** **Option C: Hybrid (Keywords → GPT-4)**

**Rationale:**
1. **Cost-effective:** Keyword filter catches 80% of messages as "normal" instantly (free)
2. **Accurate:** GPT-4 analyzes remaining 20% with full context ($0.002 per call)
3. **Fast:** Keyword check <100ms, GPT-4 only for potential urgent messages
4. **Scalable:** Handles 100+ messages/day per user at ~$1-2/month
5. **Safety:** Keyword filter tuned to over-capture (false positives OK, false negatives NOT OK)

**Trade-offs:**
- Gain: 80% cost reduction vs full GPT-4 on every message
- Lose: Might miss creatively-phrased urgent messages (mitigated by broad keyword list)

---

### Decision 2: Urgency Levels - 2-Level vs 3-Level vs 5-Level

**Options Considered:**

**Option A: 2-Level (Urgent/Normal)**
- ✅ **Pros:** Simple binary decision (is it urgent? yes/no)
- ✅ **Pros:** Easy to implement, easy to understand
- ❌ **Cons:** No nuance - treats "pickup changed" same as "anyone bringing snacks?"
- ❌ **Cons:** Too coarse for real-world scenarios

**Option B: 3-Level (Critical/High/Normal)**
- ✅ **Pros:** Nuanced enough for real use (critical = act now, high = soon, normal = later)
- ✅ **Pros:** Matches user mental model (red = danger, yellow = caution, green = OK)
- ✅ **Pros:** Visual hierarchy clear (red border stands out more than yellow)
- ❌ **Cons:** Slightly more complex to classify

**Option C: 5-Level (Critical/High/Medium/Low/Normal)**
- ✅ **Pros:** Maximum granularity
- ❌ **Cons:** Over-complicated (users can't distinguish 5 levels visually)
- ❌ **Cons:** Classification harder for AI (5-way vs 3-way)
- ❌ **Cons:** Cognitive overload (what's difference between Low and Normal?)

**Chosen:** **Option B: 3-Level (Critical/High/Normal)**

**Rationale:**
1. **User clarity:** Red = act now, Yellow = pay attention, No color = normal
2. **Visual hierarchy:** Users can scan chat and instantly see critical (red) vs normal
3. **AI accuracy:** 3-way classification more accurate than 5-way
4. **Matches real urgency:** Critical = time-sensitive + consequences, High = important but not emergency, Normal = everything else

**Trade-offs:**
- Gain: Clear visual distinction, easier AI classification, matches user mental model
- Lose: Less granularity than 5-level (but 5-level was overkill)

---

### Decision 3: UI Pattern - Badge vs Border vs Background vs Icon

**Options Considered:**

**Option A: Colored Background**
- ✅ **Pros:** Most visually prominent (entire bubble red/yellow)
- ❌ **Cons:** Too aggressive (every critical message is bright red - overwhelming)
- ❌ **Cons:** Reduces readability (text on colored background)

**Option B: Border Only**
- ✅ **Pros:** Subtle but clear (colored outline around bubble)
- ✅ **Pros:** Doesn't interfere with message readability
- ❌ **Cons:** Might be missed by users not looking closely

**Option C: Icon Badge**
- ✅ **Pros:** Clear indicator (🚨 emoji or SF Symbol)
- ❌ **Cons:** Small, might be overlooked
- ❌ **Cons:** Takes space in bubble

**Option D: Border + Badge (Hybrid)**
- ✅ **Pros:** Best of both - colored border catches eye, badge confirms urgency
- ✅ **Pros:** Clear hierarchy (critical = thick red border + 🚨, high = thin yellow border + ⚠️)
- ✅ **Pros:** Accessible (color + icon = works for colorblind users)
- ❌ **Cons:** More visual elements (but justified for critical messages)

**Chosen:** **Option D: Border + Badge (Hybrid)**

**Rationale:**
1. **Visibility:** Colored border catches eye when scanning chat
2. **Clarity:** Badge icon confirms urgency type (🚨 for critical, ⚠️ for high)
3. **Accessibility:** Works for colorblind users (icon + color)
4. **Hierarchy:** Visual weight matches urgency (thick red border = critical)
5. **Non-intrusive:** Doesn't block message text or reduce readability

**Trade-offs:**
- Gain: Maximum visibility + accessibility
- Lose: Slightly more visual clutter (but only for urgent messages, which is the point)

---

### Decision 4: Priority Section - Always Visible vs Collapsible vs Tab

**Options Considered:**

**Option A: Always Visible at Top**
- ✅ **Pros:** Impossible to miss (always in view)
- ❌ **Cons:** Takes screen space even when no urgent messages
- ❌ **Cons:** Annoying if user already addressed urgent items

**Option B: Collapsible Banner**
- ✅ **Pros:** Appears when needed, dismissible when done
- ✅ **Pros:** User control (can collapse to regain screen space)
- ✅ **Pros:** Counts down (shows "3 urgent messages")
- ❌ **Cons:** User must manually expand to see messages

**Option C: Separate Tab in Chat List**
- ✅ **Pros:** Dedicated space for all urgent messages across all chats
- ✅ **Pros:** One place to see everything that needs attention
- ❌ **Cons:** Requires navigation (user must tap tab)
- ❌ **Cons:** Out of context (message separated from conversation)

**Chosen:** **Option B: Collapsible Banner** (in-chat) + **Option C: Priority Tab** (in chat list)

**Rationale:**
1. **In-Chat Banner:** Shows urgent messages in context (within conversation)
2. **Chat List Tab:** Global view of all urgent messages across all chats
3. **Collapsible:** User control - expand when needed, collapse when done
4. **Non-intrusive:** Doesn't permanently take screen space
5. **Discoverable:** Banner auto-expands on new critical message

**Trade-offs:**
- Gain: Best of both worlds (in-context + global view)
- Lose: Two UI elements to maintain (but both serve different purposes)

---

## Implementation Details

### File Structure

**New Files (5 files, ~600 lines):**

```
messAI/
├── functions/src/ai/
│   └── priorityDetection.ts          (~250 lines) ← GPT-4 priority classifier
│
├── messAI/Models/
│   ├── PriorityLevel.swift           (~80 lines)  ← Urgency enum + colors
│   └── AIMetadata.swift              (✏️ +30 lines) ← Add priority fields
│
├── messAI/Views/Chat/
│   ├── PriorityBannerView.swift      (~150 lines) ← In-chat urgent section
│   └── MessageBubbleView.swift       (✏️ +60 lines) ← Add border + badge
│
└── messAI/Views/Priority/
    └── PriorityTabView.swift         (~120 lines) ← Global urgent messages
```

**Modified Files (+250 lines):**

```
messAI/
├── functions/src/ai/
│   └── processAI.ts                  (✏️ +20 lines) ← Add priority route
│
├── messAI/Services/
│   └── AIService.swift               (✏️ +100 lines) ← detectPriority() method
│
├── messAI/ViewModels/
│   └── ChatViewModel.swift           (✏️ +80 lines) ← Priority detection logic
│
└── messAI/Views/Chat/
    └── ChatView.swift                (✏️ +50 lines) ← Display priority banner
```

---

### Data Models

**1. PriorityLevel Enum**

```swift
// Models/PriorityLevel.swift

import Foundation
import SwiftUI

/// Urgency classification for messages
enum PriorityLevel: String, Codable {
    case critical   // 🔴 Immediate action required (time-sensitive + consequences)
    case high       // 🟡 Important but not emergency (needs attention soon)
    case normal     // No special urgency (can wait)
    
    /// Display properties
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
        case .critical: return "exclamationmark.triangle.fill" // 🚨
        case .high: return "exclamationmark.circle.fill" // ⚠️
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

**2. AIMetadata Extension (Add Priority Fields)**

```swift
// Models/AIMetadata.swift (existing file, add these fields)

struct AIMetadata: Codable {
    // ... existing calendar fields ...
    
    // Priority Detection (PR#17)
    var priorityLevel: PriorityLevel?
    var priorityConfidence: Double?        // 0.0-1.0 confidence score
    var priorityReason: String?            // Why AI classified this way
    var priorityDetectedAt: Date?
    var priorityDismissed: Bool?           // User dismissed urgent indicator
    
    // Priority keywords detected (for debugging/refinement)
    var priorityKeywords: [String]?
}
```

**3. Cloud Function Response Structure**

```typescript
// functions/src/ai/priorityDetection.ts

interface PriorityDetectionResponse {
  priorityLevel: 'critical' | 'high' | 'normal';
  confidence: number; // 0.0-1.0
  reason: string; // Human-readable explanation
  keywords: string[]; // Keywords that triggered detection
  timeContext?: {
    isToday: boolean;
    isImmediate: boolean; // Within next 2 hours
    deadline?: string; // If time-sensitive
  };
}
```

---

### Cloud Function Implementation

**File: `functions/src/ai/priorityDetection.ts`**

```typescript
import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

// Urgency keywords (tiered)
const CRITICAL_KEYWORDS = [
  'emergency', 'urgent', 'asap', 'immediately', 'right now',
  'critical', 'serious', 'help', '911', 'sos'
];

const HIGH_KEYWORDS = [
  'important', 'soon', 'today', 'tonight', 'this morning',
  'this afternoon', 'this evening', 'deadline', 'due',
  'reminder', 'don\\'t forget', 'please', 'needs', 'required'
];

const TIME_SENSITIVE_PATTERNS = [
  /\b(pickup|pick up|pick-up)\s+(at|by|changed|moved)\s+\d{1,2}(:\d{2})?\s*(am|pm|today)/i,
  /\b(meeting|appointment)\s+(at|by)\s+\d{1,2}(:\d{2})?\s*(am|pm)/i,
  /\b(due|deadline|submit)\s+(by|before|today|tonight)/i,
  /\b(canceled|cancelled|postponed|rescheduled)/i,
  /\b(last chance|final notice)/i
];

/**
 * Detect priority/urgency level of a message using hybrid approach:
 * 1. Keyword filter (fast, free)
 * 2. GPT-4 context analysis (slow, paid, only if keywords detected)
 */
export async function detectPriority(
  messageText: string,
  recentMessages: any[], // Last 10 messages for context
  conversationId: string
): Promise<PriorityDetectionResponse> {
  
  // Step 1: Quick keyword filter
  const keywordResult = await keywordBasedDetection(messageText);
  
  // If clearly normal (no keywords), skip GPT-4
  if (keywordResult.level === 'normal' && keywordResult.confidence > 0.8) {
    return keywordResult;
  }
  
  // Step 2: GPT-4 context analysis (for potential urgent messages)
  const gpt4Result = await gpt4BasedDetection(
    messageText,
    recentMessages,
    keywordResult.keywords
  );
  
  // Combine results (GPT-4 overrides if confident)
  if (gpt4Result.confidence > 0.7) {
    return gpt4Result;
  }
  
  // Fall back to keyword result if GPT-4 uncertain
  return keywordResult;
}

/**
 * Fast keyword-based detection (free, <100ms)
 */
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
  
  // No keywords detected
  return {
    priorityLevel: 'normal',
    confidence: 0.85,
    reason: 'No urgency indicators detected',
    keywords: []
  };
}

/**
 * GPT-4 context-aware detection (paid, ~2s)
 */
async function gpt4BasedDetection(
  messageText: string,
  recentMessages: any[],
  detectedKeywords: string[]
): Promise<PriorityDetectionResponse> {
  
  const openai = getOpenAIClient();
  
  // Build context from recent messages
  const contextMessages = recentMessages
    .slice(-10) // Last 10 messages
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
   - Examples: "Pickup changed to 2pm TODAY", "School closed - emergency", "Payment due by 5pm today"
2. **High** = Important but not emergency + needs attention soon
   - Examples: "Permission slip due Friday", "Don't forget snacks tomorrow", "Meeting at 3pm"
3. **Normal** = Everything else
   - Examples: "Anyone bringing cookies?", "Thanks everyone!", "Sounds good"

**Context matters:**
- Is there a time constraint? (today, now, by X time)
- Are there consequences for missing this? (late pickup, missed deadline)
- Does this require immediate action from recipient?

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
    temperature: 0.3, // Low temperature for consistent classification
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

// Initialize OpenAI client (lazy initialization)
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

---

### iOS Service Implementation

**File: `Services/AIService.swift` (add detectPriority method)**

```swift
// Services/AIService.swift

import Foundation
import FirebaseFunctions

extension AIService {
    
    /// Detect priority/urgency level of a message
    /// - Parameters:
    ///   - message: Message to analyze
    ///   - recentMessages: Last 10 messages for context
    /// - Returns: PriorityLevel + confidence + reason
    func detectPriority(
        for message: Message,
        recentMessages: [Message]
    ) async throws -> PriorityDetectionResult {
        
        // Check cache first (5-minute TTL)
        let cacheKey = "priority_\(message.id)"
        if let cached = responseCache[cacheKey] as? PriorityDetectionResult,
           Date().timeIntervalSince(cached.detectedAt) < 300 { // 5 minutes
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
}

/// Result of priority detection
struct PriorityDetectionResult {
    let priorityLevel: PriorityLevel
    let confidence: Double // 0.0-1.0
    let reason: String // Why AI classified this way
    let keywords: [String] // Detected urgency keywords
    let detectedAt: Date
}
```

---

### UI Implementation

**1. Enhanced MessageBubbleView (Add Border + Badge)**

```swift
// Views/Chat/MessageBubbleView.swift

import SwiftUI

struct MessageBubbleView: View {
    let message: Message
    let isFromCurrentUser: Bool
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if !isFromCurrentUser {
                // Profile picture (left side)
                AsyncImage(url: URL(string: message.senderPhotoURL ?? "")) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle().fill(Color.gray.opacity(0.3))
                }
                .frame(width: 32, height: 32)
                .clipShape(Circle())
            }
            
            VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                // Sender name (for group chats, non-current user)
                if !isFromCurrentUser && message.shouldShowSenderName {
                    Text(message.senderDisplayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Message bubble with priority border
                VStack(alignment: .leading, spacing: 4) {
                    Text(message.text)
                        .font(.body)
                        .foregroundColor(isFromCurrentUser ? .white : .primary)
                    
                    // Timestamp + status
                    HStack(spacing: 4) {
                        Text(message.sentAt.formatted(date: .omitted, time: .shortened))
                            .font(.caption2)
                            .foregroundColor(isFromCurrentUser ? .white.opacity(0.7) : .secondary)
                        
                        if isFromCurrentUser {
                            statusIcon
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(bubbleBackground)
                .overlay(priorityBorder) // ← NEW: Priority border
                .clipShape(RoundedRectangle(cornerRadius: 18))
                
                // Priority badge (if critical/high)
                if let priority = message.aiMetadata?.priorityLevel,
                   priority != .normal {
                    priorityBadge(for: priority)
                }
            }
            .frame(maxWidth: 280, alignment: isFromCurrentUser ? .trailing : .leading)
            
            if isFromCurrentUser {
                Spacer() // Push to right
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }
    
    // MARK: - Priority Border (NEW!)
    
    private var priorityBorder: some View {
        Group {
            if let priority = message.aiMetadata?.priorityLevel,
               priority != .normal {
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(priority.color, lineWidth: priority.borderWidth)
            }
        }
    }
    
    // MARK: - Priority Badge (NEW!)
    
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
    
    // ... existing statusIcon, bubbleBackground, etc.
}
```

**2. Priority Banner View (In-Chat Urgent Section)**

```swift
// Views/Chat/PriorityBannerView.swift

import SwiftUI

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
            
            // Expanded content (list of urgent messages)
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
            }
            
            // Dismiss button (if expanded)
            if isExpanded {
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

struct UrgentMessageRow: View {
    let message: Message
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {
                // Priority indicator
                Circle()
                    .fill(message.aiMetadata?.priorityLevel?.color ?? .gray)
                    .frame(width: 8, height: 8)
                    .padding(.top, 6)
                
                VStack(alignment: .leading, spacing: 4) {
                    // Sender + time
                    HStack {
                        Text(message.senderDisplayName)
                            .font(.caption)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        Text(message.sentAt.formatted(date: .omitted, time: .shortened))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    // Message preview
                    Text(message.text)
                        .font(.subheadline)
                        .lineLimit(2)
                        .foregroundColor(.primary)
                    
                    // AI reason (if available)
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

**3. Priority Tab View (Global Urgent Messages)**

```swift
// Views/Priority/PriorityTabView.swift

import SwiftUI

struct PriorityTabView: View {
    @StateObject private var viewModel = PriorityViewModel()
    
    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView("Loading urgent messages...")
                } else if viewModel.urgentMessages.isEmpty {
                    emptyState
                } else {
                    messagesList
                }
            }
            .navigationTitle("Urgent Messages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Mark all as seen") {
                            viewModel.markAllAsSeen()
                        }
                        
                        Button("Refresh") {
                            Task { await viewModel.refreshMessages() }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .task {
            await viewModel.loadUrgentMessages()
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 64))
                .foregroundColor(.green)
            
            Text("No urgent messages")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("You're all caught up! Urgent messages will appear here.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }
    
    private var messagesList: some View {
        List {
            ForEach(viewModel.urgentMessages) { message in
                NavigationLink(value: message.conversationId) {
                    UrgentMessageRow(message: message, onTap: {
                        // Navigation handled by NavigationLink
                    })
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }
        }
        .listStyle(.plain)
        .navigationDestination(for: String.self) { conversationId in
            // Navigate to ChatView with conversation
            if let conversation = viewModel.getConversation(conversationId) {
                ChatView(conversation: conversation)
            }
        }
    }
}

@MainActor
class PriorityViewModel: ObservableObject {
    @Published var urgentMessages: [Message] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let chatService = ChatService.shared
    private let firestore = Firestore.firestore()
    
    func loadUrgentMessages() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Query all messages with priority = critical or high
            let snapshot = try await firestore
                .collectionGroup("messages")
                .whereField("aiMetadata.priorityLevel", in: ["critical", "high"])
                .whereField("aiMetadata.priorityDismissed", isEqualTo: false)
                .order(by: "sentAt", descending: true)
                .limit(to: 50)
                .getDocuments()
            
            urgentMessages = snapshot.documents.compactMap { doc in
                try? doc.data(as: Message.self)
            }
            
            print("PriorityViewModel: Loaded \(urgentMessages.count) urgent messages")
            
        } catch {
            print("PriorityViewModel: Error loading urgent messages: \(error)")
            errorMessage = error.localizedDescription
        }
    }
    
    func refreshMessages() async {
        await loadUrgentMessages()
    }
    
    func markAllAsSeen() {
        Task {
            for message in urgentMessages {
                try? await firestore
                    .collection("conversations")
                    .document(message.conversationId)
                    .collection("messages")
                    .document(message.id)
                    .updateData([
                        "aiMetadata.priorityDismissed": true
                    ])
            }
            
            await loadUrgentMessages()
        }
    }
    
    func getConversation(_ id: String) -> Conversation? {
        // Load conversation from Firestore or local cache
        // Implementation depends on existing ChatService
        return nil // Placeholder
    }
}
```

---

## Testing Strategy

### Test Categories

**1. Unit Tests (Cloud Function)**
- ✅ Keyword detection (critical keywords trigger critical level)
- ✅ Time-sensitive patterns (today, tonight, by 3pm)
- ✅ Confidence scoring (multiple keywords = higher confidence)
- ✅ Edge cases (empty message, very long message)

**2. Integration Tests (iOS + Cloud Function)**
- ✅ End-to-end priority detection (iOS → Cloud Function → response)
- ✅ Message update in Firestore (aiMetadata.priorityLevel saved)
- ✅ Real-time UI update (message bubble gets border + badge)
- ✅ Cache behavior (repeated detection uses cache)

**3. Classification Accuracy Tests**
- ✅ True positives (urgent messages correctly flagged)
- ✅ True negatives (normal messages not flagged)
- ✅ False positives (normal message incorrectly flagged as urgent)
- ✅ False negatives (urgent message not flagged) ← MOST CRITICAL TO MINIMIZE

**4. UI/UX Tests**
- ✅ Priority border displays correctly (red for critical, yellow for high)
- ✅ Priority badge shows icon + level name
- ✅ Priority banner appears when critical message arrives
- ✅ Banner expands/collapses smoothly
- ✅ Tap on urgent message scrolls to message in chat
- ✅ Priority tab shows all urgent messages across chats
- ✅ Mark as seen dismisses urgent indicators

**5. Performance Tests**
- ✅ Keyword detection <100ms (fast path)
- ✅ GPT-4 detection <3s (slow path, only when keywords detected)
- ✅ Cache hit rate >60% (5-minute TTL)
- ✅ No UI lag when priority detected

---

## Success Criteria

**Feature is complete when:**

- ✅ Cloud Function deployed with priority detection
- ✅ iOS can call detectPriority() and receive PriorityLevel
- ✅ Message bubbles display priority border + badge
- ✅ Priority banner appears in chat for critical messages
- ✅ Priority tab shows all urgent messages globally
- ✅ Classification accuracy >80% (tested with 50+ real messages)
- ✅ False negative rate <5% (urgent messages not missed)
- ✅ Performance: Keyword check <100ms, GPT-4 <3s
- ✅ All UI components work (borders, badges, banner, tab)
- ✅ Firestore schema updated (aiMetadata.priorityLevel)
- ✅ Documentation complete

**Performance Targets:**
- Keyword detection: <100ms (95th percentile)
- GPT-4 detection: <3s (95th percentile)
- Cache hit rate: >60% (5-minute TTL)
- Classification accuracy: >80% true positive, <5% false negative
- Cost: <$2/month/user (100 messages/day)

**Quality Gates:**
- Zero critical bugs (priority not detected when should be)
- UI works in light and dark mode
- Accessibility: Border + icon (works for colorblind)
- No console errors or warnings
- Firestore security rules allow priority updates

---

## Risk Assessment

### Risk 1: False Negatives (Urgent Messages Not Flagged)
**Likelihood:** 🟡 MEDIUM  
**Impact:** 🔴 CRITICAL (defeats purpose of feature - parent misses pickup change)  
**Mitigation:**
- Broad keyword list (over-capture rather than under-capture)
- GPT-4 as fallback for context analysis
- Tune thresholds based on real-world testing
- User feedback mechanism ("Was this urgent? Yes/No")
**Status:** 🟡 Mitigated by hybrid approach (keywords + GPT-4)

### Risk 2: False Positives (Normal Messages Flagged as Urgent)
**Likelihood:** 🟡 MEDIUM  
**Impact:** 🟢 LOW (annoying but not dangerous - user sees extra red borders)  
**Mitigation:**
- GPT-4 context analysis reduces false positives
- User can dismiss false urgents (trains system over time)
- Low confidence urgents shown as "high" not "critical"
**Status:** 🟢 Acceptable (false positives OK, false negatives NOT OK)

### Risk 3: High API Costs (GPT-4 on Every Message)
**Likelihood:** 🟢 LOW (hybrid approach prevents this)  
**Impact:** 🟡 MEDIUM (could cost $10-20/month/user if not controlled)  
**Mitigation:**
- Keyword filter catches 80% of messages as normal (free)
- GPT-4 only for 20% with potential urgency
- Rate limiting (100 req/hour/user)
- 5-minute cache (repeated analysis avoided)
**Status:** 🟢 Mitigated by hybrid approach

### Risk 4: Slow Performance (Users Wait for Priority Detection)
**Likelihood:** 🟢 LOW  
**Impact:** 🟡 MEDIUM (users frustrated if messages delayed)  
**Mitigation:**
- Async detection (message appears immediately, priority updates 1-2s later)
- Keyword check first (<100ms) before GPT-4
- Cache results (same message, instant response)
**Status:** 🟢 Mitigated by async + caching

---

## Open Questions

1. **Should we allow users to manually override AI classification?**
   - Scenario: AI marks message as "normal" but user thinks it's urgent
   - Options: (A) Yes, let users change priority (B) No, AI is authoritative
   - Decision needed by: Implementation
   - **Recommendation:** Yes, add long-press menu option "Mark as urgent/normal"

2. **Should we learn from user feedback to improve classification?**
   - Scenario: User repeatedly dismisses certain types of urgent flags
   - Options: (A) Store feedback, retrain model (B) Static classification
   - Decision needed by: Future PR (ML model training)
   - **Recommendation:** Log feedback for future iteration, not in MVP

3. **Should priority detection run on all messages or only new ones?**
   - Scenario: User opens chat with 50 existing messages - analyze all?
   - Options: (A) Only new messages (B) Batch analyze backlog (C) User-triggered for old messages
   - Decision needed by: Implementation
   - **Recommendation:** Option A (only new messages), with Option C for backlog if user requests

---

## Timeline

**Total Estimate:** 2-3 hours

| Phase | Task | Time | Status |
|-------|------|------|--------|
| 1 | Cloud Function implementation (keyword + GPT-4) | 45 min | ⏳ |
| 2 | iOS models (PriorityLevel enum, AIMetadata extension) | 15 min | ⏳ |
| 3 | AIService.detectPriority() method | 20 min | ⏳ |
| 4 | Enhanced MessageBubbleView (border + badge) | 30 min | ⏳ |
| 5 | PriorityBannerView (in-chat urgent section) | 30 min | ⏳ |
| 6 | PriorityTabView (global urgent messages) | 30 min | ⏳ |
| 7 | Testing (accuracy, performance, UI) | 30 min | ⏳ |

---

## Dependencies

**Requires:**
- ✅ PR#14 complete (Cloud Functions + OpenAI setup)
- ⏳ PR#16 recommended (Decision Summarization - similar AI pattern)

**Blocks:**
- PR#22: Smart Notifications (needs priority levels to determine notification urgency)

---

## References

- Related PR: PR#14 (Cloud Functions Setup)
- Related PR: PR#16 (Decision Summarization - similar AI architecture)
- OpenAI API: https://platform.openai.com/docs/guides/chat
- Design inspiration: Slack's "Important" message feature
- Research: False negative rate <5% critical for safety features

---

*This specification provides the foundation for implementing AI-powered priority detection. When in doubt, prioritize catching urgent messages (false positives OK) over missing them (false negatives NOT OK).*

