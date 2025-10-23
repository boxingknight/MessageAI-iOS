# PR #20: Multi-Step Event Planning Agent - Technical Specification

**Status**: 📋 PLANNED (Ready to implement!)  
**Estimated Time**: 5-6 hours  
**Complexity**: 🔴 HIGH (Most complex AI feature - multi-turn conversation with state management)  
**Priority**: 🎯 ADVANCED FEATURE (+10 bonus points!)  
**Depends on**: PR#14 (Cloud Functions) ✅, PR#15 (Calendar Extraction) ✅, PR#18 (RSVP Tracking) ✅

---

## Overview

### What We're Building

An intelligent conversational AI agent that helps busy parents plan family events through natural multi-turn dialogue. Instead of Sarah manually coordinating "When should we do Emma's birthday party?", the agent conducts a structured conversation:

**Agent**: "I'll help you plan Emma's birthday party! What date were you thinking?"  
**Sarah**: "Maybe next Saturday?"  
**Agent**: "Next Saturday, October 28th. What time works best?"  
**Sarah**: "2pm to 5pm"  
**Agent**: "Great! Should I send invites to Emma's class group?"  
**Sarah**: "Yes"  
**Agent**: "Perfect! I've created the event 'Emma's Birthday Party' on Oct 28, 2-5pm and sent invites to 12 participants. I'll track RSVPs for you."

This is the **crown jewel** of MessageAI's AI features—a true conversational agent that demonstrates advanced AI capabilities beyond simple extraction.

### Why This Matters

**For Users**:
- Saves 20-30 minutes per event (vs manual coordination)
- Reduces cognitive load (agent asks questions, user just answers)
- Professional experience (feels like having a personal assistant)
- Viral moment ("An AI planned my kid's party!")

**For Project**:
- **+10 bonus points** (advanced agent capability)
- Demonstrates true AI agent architecture (not just extraction)
- Showcases multi-turn conversation handling
- Proves context management and state persistence
- Differentiator (no other messaging app has this)

**For Gauntlet Submission**:
- This is what separates good from great submissions
- Shows mastery of agent frameworks (AI SDK, OpenAI Swarm, or LangChain)
- Demonstrates RAG pipeline in action
- Proves production-ready AI architecture

### Success in One Sentence

"Sarah can plan a complete event by having a 2-minute natural conversation with an AI agent in her messaging app, without leaving the chat."

---

## Technical Design

### Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                         iOS App (SwiftUI)                        │
│                                                                  │
│  ┌──────────────────┐         ┌──────────────────────────────┐ │
│  │   ChatView       │────────▶│   ChatViewModel              │ │
│  │   - Agent UI     │         │   - Agent state management   │ │
│  │   - Message cards│         │   - Conversation tracking    │ │
│  └──────────────────┘         └──────────────────────────────┘ │
│                                            │                     │
│                                            ▼                     │
│                                 ┌──────────────────────────┐    │
│                                 │   AIService              │    │
│                                 │   - Agent communication  │    │
│                                 └──────────────────────────┘    │
└─────────────────────────────────────────────────────────────────┘
                                            │
                                            ▼
┌─────────────────────────────────────────────────────────────────┐
│                   Cloud Functions (Node.js + TypeScript)         │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────────┐
│  │ Event Planning Agent (eventPlanningAgent.ts)                 │
│  ├──────────────────────────────────────────────────────────────┤
│  │ • Multi-turn conversation orchestration                      │
│  │ • State management (Firestore-backed)                        │
│  │ • Context retrieval (RAG pipeline)                           │
│  │ • Tool calling (create event, send invites, track RSVPs)     │
│  │ • Error recovery (retry failed steps, clarify ambiguity)     │
│  └──────────────────────────────────────────────────────────────┘
│                                            │                     │
│                                            ▼                     │
│  ┌──────────────────────────────────────────────────────────────┐
│  │ Agent State Store (/agentSessions/{sessionId})               │
│  ├──────────────────────────────────────────────────────────────┤
│  │ • conversationHistory: Message[]                             │
│  │ • currentStep: PlanningStep                                  │
│  │ • gatheredInfo: EventInfo                                    │
│  │ • pendingActions: Action[]                                   │
│  │ • status: active | completed | cancelled                     │
│  └──────────────────────────────────────────────────────────────┘
└─────────────────────────────────────────────────────────────────┘
                                            │
                                            ▼
┌─────────────────────────────────────────────────────────────────┐
│                          OpenAI API (GPT-4)                      │
│  • Function calling for structured extraction                   │
│  • Context-aware conversation generation                        │
│  • Multi-turn dialogue management                               │
│  • Tool use orchestration                                       │
└─────────────────────────────────────────────────────────────────┘
```

### Key Design Decisions

#### Decision 1: Agent Framework Choice

**Options Considered:**
1. **OpenAI Swarm** (lightweight multi-agent orchestration)
   - ✅ Simple, minimal dependencies
   - ✅ GPT-4 native integration
   - ✅ Good for single-agent workflows
   - ❌ Limited tool calling support
   - ❌ No built-in state management

2. **AI SDK by Vercel** (recommended in spec)
   - ✅ Streamlined agent development
   - ✅ Excellent tool calling support
   - ✅ TypeScript-native with strong types
   - ✅ Built-in streaming support
   - ❌ Newer, less battle-tested

3. **LangChain** (comprehensive agent framework)
   - ✅ Extensive tool library
   - ✅ Production-proven
   - ✅ Advanced memory management
   - ❌ Heavy dependencies
   - ❌ Steeper learning curve
   - ❌ Overkill for single-agent use case

4. **Custom Implementation** (built from scratch)
   - ✅ Full control
   - ✅ Minimal dependencies
   - ✅ Tailored to our exact needs
   - ❌ More time (6+ hours vs 4-5 hours)
   - ❌ Reinventing the wheel

**Chosen**: **AI SDK by Vercel** (recommended in project spec)

**Rationale:**
- Project spec explicitly recommends AI SDK by Vercel
- Perfect balance: powerful but not overwhelming
- TypeScript-native (matches our Cloud Functions)
- Excellent tool calling (critical for agent actions)
- Active development and documentation
- 4-5 hour implementation timeline (vs 6+ for custom)

**Trade-offs:**
- Gain: Fast development, modern API, strong typing
- Lose: Some flexibility vs custom implementation

#### Decision 2: State Management Strategy

**Options Considered:**
1. **In-memory state** (store in Cloud Function memory)
   - ✅ Fast, no database reads
   - ❌ Lost on function restart
   - ❌ No multi-device support
   - ❌ Session doesn't survive crashes

2. **Client-side state** (store in iOS app)
   - ✅ No server storage needed
   - ❌ Lost on app restart
   - ❌ Can't resume from different device
   - ❌ Security risk (state manipulation)

3. **Firestore-backed state** (persist to database)
   - ✅ Survives function restarts
   - ✅ Multi-device support
   - ✅ Can resume conversations
   - ✅ Audit trail for debugging
   - ❌ Slightly slower (1-2 DB reads per message)

**Chosen**: **Firestore-backed state**

**Rationale:**
- Critical for production quality (agent sessions must survive restarts)
- Enables "resume later" UX (Sarah can pause planning, come back)
- Multi-device support (start on iPhone, finish on iPad)
- Debugging visibility (can inspect agent state in console)
- Cost is negligible (~$0.0001 per state save)
- Performance impact minimal (<100ms overhead)

**Trade-offs:**
- Gain: Reliability, resumability, multi-device support, debuggability
- Lose: Slight performance overhead (<100ms per turn)

#### Decision 3: Conversation Flow Design

**Options Considered:**
1. **Strict linear flow** (always ask in same order)
   - ✅ Simple to implement
   - ✅ Predictable
   - ❌ Feels robotic
   - ❌ Can't handle natural conversation

2. **Fully flexible flow** (user can provide info in any order)
   - ✅ Natural conversation
   - ✅ Handles free-form input
   - ❌ Complex state management
   - ❌ 6+ hours to implement well

3. **Guided flexible flow** (agent asks questions but accepts answers out of order)
   - ✅ Natural but structured
   - ✅ Agent guides when needed
   - ✅ Handles most natural variations
   - ✅ Manageable complexity (5-6 hours)

**Chosen**: **Guided flexible flow**

**Rationale:**
- Best UX: feels natural but doesn't get lost
- Agent guides conversation with questions
- But accepts answers out of order ("I want to plan a birthday party next Saturday at 2pm")
- Reasonable complexity for 5-6 hour timeline
- GPT-4 excellent at flexible extraction

**Trade-offs:**
- Gain: Natural conversation, good UX, handles variations
- Lose: Some complexity vs strict linear (but manageable)

#### Decision 4: Tool/Action Design

**Options Considered:**
1. **Execute immediately** (agent creates event as soon as it has info)
   - ✅ Fast
   - ❌ No user confirmation
   - ❌ Can't undo mistakes

2. **Confirm before executing** (agent asks "Should I create this event?")
   - ✅ User control
   - ✅ Prevents AI errors
   - ✅ Builds trust
   - ❌ Extra step (but worth it)

3. **Batch execution at end** (agent waits until conversation complete)
   - ✅ Single confirmation
   - ❌ Feels disconnected
   - ❌ Harder to fix individual steps

**Chosen**: **Confirm before executing**

**Rationale:**
- Safety first: AI can make mistakes
- User should see plan before it executes
- Builds trust ("I control what happens")
- Only adds 1 extra turn ("Should I proceed?")
- Industry standard (ChatGPT, Claude do this)

**Trade-offs:**
- Gain: Safety, trust, user control
- Lose: One extra conversational turn (acceptable)

---

## Data Models

### Agent Session State (Firestore: `/agentSessions/{sessionId}`)

```typescript
interface AgentSession {
  // Identity
  sessionId: string;              // Unique session ID
  userId: string;                 // User running the session
  conversationId: string;         // Firestore conversation ID
  createdAt: Timestamp;          // When session started
  updatedAt: Timestamp;          // Last activity
  
  // Conversation state
  conversationHistory: Message[]; // Full dialogue history
  currentStep: PlanningStep;     // Where we are in planning
  gatheredInfo: EventInfo;        // Information collected so far
  
  // Actions
  pendingActions: Action[];       // Actions awaiting confirmation
  completedActions: Action[];     // Actions executed
  
  // Status
  status: SessionStatus;          // active | completed | cancelled | errored
  errorMessage?: string;          // If errored, why
  
  // Metadata
  totalTurns: number;            // Conversation turn count
  tokensUsed: number;            // OpenAI tokens consumed
  cost: number;                  // Estimated API cost ($)
}

type PlanningStep =
  | 'greeting'              // Initial greeting, understand intent
  | 'event_type'            // What kind of event?
  | 'date_time'             // When should it happen?
  | 'participants'          // Who should be invited?
  | 'location'              // Where will it be?
  | 'additional_details'    // Any other info?
  | 'confirmation'          // Ready to create?
  | 'creating'              // Executing actions
  | 'completed';            // All done!

interface EventInfo {
  eventType?: string;       // "birthday party", "playdate", "school event"
  title?: string;           // "Emma's Birthday Party"
  date?: string;            // ISO 8601: "2025-10-28"
  startTime?: string;       // ISO 8601: "2025-10-28T14:00:00"
  endTime?: string;         // ISO 8601: "2025-10-28T17:00:00"
  participants?: string[];  // User IDs to invite
  location?: string;        // "Our house", "Park", etc.
  notes?: string;           // Additional details
  confidence: number;       // How confident agent is (0.0-1.0)
}

interface Action {
  actionId: string;
  type: 'create_event' | 'send_invites' | 'track_rsvps';
  params: any;
  status: 'pending' | 'confirmed' | 'executing' | 'completed' | 'failed';
  result?: any;
  error?: string;
}

type SessionStatus = 'active' | 'completed' | 'cancelled' | 'errored';

interface Message {
  role: 'user' | 'assistant' | 'system';
  content: string;
  timestamp: Timestamp;
  metadata?: {
    step: PlanningStep;
    extractedInfo?: Partial<EventInfo>;
    suggestedActions?: Action[];
  };
}
```

### iOS Models

```swift
// Models/AgentSession.swift (~180 lines)
struct AgentSession: Codable, Identifiable {
    let id: String              // sessionId
    let userId: String
    let conversationId: String
    let createdAt: Date
    var updatedAt: Date
    
    var conversationHistory: [AgentMessage]
    var currentStep: PlanningStep
    var gatheredInfo: EventInfo
    
    var pendingActions: [AgentAction]
    var completedActions: [AgentAction]
    
    var status: SessionStatus
    var errorMessage: String?
    
    var totalTurns: Int
    var tokensUsed: Int
    var cost: Double
    
    // Computed properties
    var isActive: Bool {
        status == .active
    }
    
    var canResume: Bool {
        status == .active || status == .errored
    }
    
    var progressPercentage: Double {
        // Calculate based on currentStep
        let stepOrder: [PlanningStep] = [
            .greeting, .eventType, .dateTime, .participants, 
            .location, .additionalDetails, .confirmation, 
            .creating, .completed
        ]
        guard let index = stepOrder.firstIndex(of: currentStep) else { return 0 }
        return Double(index + 1) / Double(stepOrder.count)
    }
    
    // Firestore conversion
    init(from dict: [String: Any]) throws {
        // Parse Firestore document
    }
    
    func toDictionary() -> [String: Any] {
        // Convert to Firestore format
    }
}

enum PlanningStep: String, Codable {
    case greeting
    case eventType = "event_type"
    case dateTime = "date_time"
    case participants
    case location
    case additionalDetails = "additional_details"
    case confirmation
    case creating
    case completed
    
    var displayName: String {
        switch self {
        case .greeting: return "Getting Started"
        case .eventType: return "Event Type"
        case .dateTime: return "Date & Time"
        case .participants: return "Invitations"
        case .location: return "Location"
        case .additionalDetails: return "Details"
        case .confirmation: return "Confirmation"
        case .creating: return "Creating Event"
        case .completed: return "Completed"
        }
    }
    
    var emoji: String {
        switch self {
        case .greeting: return "👋"
        case .eventType: return "🎉"
        case .dateTime: return "📅"
        case .participants: return "👥"
        case .location: return "📍"
        case .additionalDetails: return "📝"
        case .confirmation: return "✅"
        case .creating: return "⚙️"
        case .completed: return "🎊"
        }
    }
}

struct EventInfo: Codable {
    var eventType: String?
    var title: String?
    var date: String?        // ISO 8601
    var startTime: String?   // ISO 8601
    var endTime: String?     // ISO 8601
    var participants: [String]?  // User IDs
    var location: String?
    var notes: String?
    var confidence: Double
    
    var isComplete: Bool {
        title != nil && date != nil && startTime != nil
    }
    
    var missingFields: [String] {
        var missing: [String] = []
        if title == nil { missing.append("title") }
        if date == nil { missing.append("date") }
        if startTime == nil { missing.append("time") }
        return missing
    }
}

struct AgentAction: Codable, Identifiable {
    let id: String              // actionId
    let type: ActionType
    let params: [String: Any]   // Action-specific parameters
    var status: ActionStatus
    var result: [String: Any]?
    var error: String?
    
    enum ActionType: String, Codable {
        case createEvent = "create_event"
        case sendInvites = "send_invites"
        case trackRSVPs = "track_rsvps"
    }
    
    enum ActionStatus: String, Codable {
        case pending
        case confirmed
        case executing
        case completed
        case failed
    }
}

enum SessionStatus: String, Codable {
    case active
    case completed
    case cancelled
    case errored
}

struct AgentMessage: Codable {
    let role: MessageRole
    let content: String
    let timestamp: Date
    let metadata: MessageMetadata?
    
    enum MessageRole: String, Codable {
        case user
        case assistant
        case system
    }
    
    struct MessageMetadata: Codable {
        let step: PlanningStep?
        let extractedInfo: EventInfo?
        let suggestedActions: [AgentAction]?
    }
}
```

---

## Implementation Details

### Cloud Function Architecture

#### File Structure
```
functions/src/ai/eventPlanningAgent/
├── index.ts                    // Main agent entry point (~150 lines)
├── agent.ts                    // Agent orchestration logic (~300 lines)
├── steps/
│   ├── greeting.ts            // Initial conversation (~80 lines)
│   ├── eventType.ts           // Determine event type (~80 lines)
│   ├── dateTime.ts            // Extract date/time (~100 lines)
│   ├── participants.ts        // Select participants (~100 lines)
│   ├── location.ts            // Determine location (~80 lines)
│   ├── details.ts             // Additional info (~80 lines)
│   ├── confirmation.ts        // Confirm before execution (~100 lines)
│   └── execution.ts           // Execute actions (~150 lines)
├── tools/
│   ├── createEvent.ts         // Create calendar event (~100 lines)
│   ├── sendInvites.ts         // Send invitations (~80 lines)
│   └── trackRSVPs.ts          // Set up RSVP tracking (~80 lines)
├── state/
│   ├── sessionManager.ts      // State persistence (~150 lines)
│   └── contextRetriever.ts    // RAG pipeline (~100 lines)
└── utils/
    ├── dateParser.ts          // Natural date parsing (~80 lines)
    ├── participantResolver.ts // Map names to user IDs (~80 lines)
    └── validator.ts           // Input validation (~60 lines)

Total: ~1,810 lines (estimated)
```

#### Main Agent Function

```typescript
// functions/src/ai/eventPlanningAgent/index.ts
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { EventPlanningAgent } from './agent';

initializeApp();
const db = getFirestore();

interface AgentRequest {
  action: 'start' | 'continue' | 'cancel';
  sessionId?: string;
  message?: string;
  conversationId: string;
}

interface AgentResponse {
  sessionId: string;
  message: string;
  currentStep: string;
  gatheredInfo: any;
  pendingActions: any[];
  status: string;
  progressPercentage: number;
}

export const eventPlanningAgent = onCall<AgentRequest, AgentResponse>(
  { 
    timeoutSeconds: 60,
    memory: '512MiB',
    region: 'us-central1'
  },
  async (request) => {
    // 1. Authenticate user
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'User must be authenticated');
    }
    
    const userId = request.auth.uid;
    const { action, sessionId, message, conversationId } = request.data;
    
    // 2. Initialize or load agent session
    const agent = new EventPlanningAgent(db, userId, conversationId);
    let session;
    
    try {
      switch (action) {
        case 'start':
          // Create new session
          session = await agent.startSession();
          console.log(`[Agent] Started new session: ${session.sessionId}`);
          break;
          
        case 'continue':
          // Load existing session
          if (!sessionId) {
            throw new HttpsError('invalid-argument', 'Session ID required');
          }
          session = await agent.loadSession(sessionId);
          
          // Process user message
          if (message) {
            session = await agent.processMessage(message);
          }
          console.log(`[Agent] Processed turn in session: ${sessionId}`);
          break;
          
        case 'cancel':
          // Cancel session
          if (!sessionId) {
            throw new HttpsError('invalid-argument', 'Session ID required');
          }
          session = await agent.cancelSession(sessionId);
          console.log(`[Agent] Cancelled session: ${sessionId}`);
          break;
          
        default:
          throw new HttpsError('invalid-argument', `Invalid action: ${action}`);
      }
      
      // 3. Return agent response
      return {
        sessionId: session.sessionId,
        message: session.lastAssistantMessage,
        currentStep: session.currentStep,
        gatheredInfo: session.gatheredInfo,
        pendingActions: session.pendingActions,
        status: session.status,
        progressPercentage: session.progressPercentage
      };
      
    } catch (error) {
      console.error('[Agent] Error:', error);
      throw new HttpsError('internal', `Agent error: ${error.message}`);
    }
  }
);
```

#### Agent Core Logic

```typescript
// functions/src/ai/eventPlanningAgent/agent.ts
import { Firestore } from 'firebase-admin/firestore';
import { OpenAI } from 'openai';
import { SessionManager } from './state/sessionManager';
import { ContextRetriever } from './state/contextRetriever';
import * as steps from './steps';

export class EventPlanningAgent {
  private openai: OpenAI;
  private sessionManager: SessionManager;
  private contextRetriever: ContextRetriever;
  
  constructor(
    private db: Firestore,
    private userId: string,
    private conversationId: string
  ) {
    this.openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });
    this.sessionManager = new SessionManager(db);
    this.contextRetriever = new ContextRetriever(db);
  }
  
  async startSession(): Promise<AgentSession> {
    // Create new session
    const session = await this.sessionManager.createSession({
      userId: this.userId,
      conversationId: this.conversationId,
      currentStep: 'greeting'
    });
    
    // Generate greeting message
    const greeting = await steps.greeting.generateGreeting(
      this.openai,
      this.userId,
      this.conversationId
    );
    
    session.conversationHistory.push({
      role: 'assistant',
      content: greeting,
      timestamp: Timestamp.now()
    });
    
    await this.sessionManager.updateSession(session);
    
    return session;
  }
  
  async loadSession(sessionId: string): Promise<AgentSession> {
    const session = await this.sessionManager.getSession(sessionId);
    
    if (!session) {
      throw new Error(`Session not found: ${sessionId}`);
    }
    
    if (session.userId !== this.userId) {
      throw new Error('Unauthorized: Session belongs to different user');
    }
    
    return session;
  }
  
  async processMessage(message: string): Promise<AgentSession> {
    const session = await this.loadSession(this.sessionId);
    
    // Add user message to history
    session.conversationHistory.push({
      role: 'user',
      content: message,
      timestamp: Timestamp.now()
    });
    
    session.totalTurns++;
    
    // Retrieve conversation context (RAG)
    const conversationContext = await this.contextRetriever.getContext(
      this.conversationId,
      limit: 20  // Last 20 messages for context
    );
    
    // Route to appropriate step handler
    const stepHandler = this.getStepHandler(session.currentStep);
    const result = await stepHandler.process(
      this.openai,
      session,
      message,
      conversationContext
    );
    
    // Update session with results
    session.conversationHistory.push({
      role: 'assistant',
      content: result.response,
      timestamp: Timestamp.now(),
      metadata: {
        step: session.currentStep,
        extractedInfo: result.extractedInfo,
        suggestedActions: result.suggestedActions
      }
    });
    
    session.gatheredInfo = { ...session.gatheredInfo, ...result.extractedInfo };
    session.currentStep = result.nextStep;
    session.tokensUsed += result.tokensUsed;
    session.cost += result.cost;
    
    if (result.pendingActions) {
      session.pendingActions.push(...result.pendingActions);
    }
    
    await this.sessionManager.updateSession(session);
    
    return session;
  }
  
  async cancelSession(sessionId: string): Promise<AgentSession> {
    const session = await this.loadSession(sessionId);
    session.status = 'cancelled';
    await this.sessionManager.updateSession(session);
    return session;
  }
  
  private getStepHandler(step: PlanningStep): StepHandler {
    switch (step) {
      case 'greeting': return steps.greeting;
      case 'event_type': return steps.eventType;
      case 'date_time': return steps.dateTime;
      case 'participants': return steps.participants;
      case 'location': return steps.location;
      case 'additional_details': return steps.details;
      case 'confirmation': return steps.confirmation;
      case 'creating': return steps.execution;
      default: throw new Error(`Unknown step: ${step}`);
    }
  }
  
  get lastAssistantMessage(): string {
    const lastMessage = this.session.conversationHistory
      .filter(m => m.role === 'assistant')
      .pop();
    return lastMessage?.content || '';
  }
  
  get progressPercentage(): number {
    const stepOrder: PlanningStep[] = [
      'greeting', 'event_type', 'date_time', 'participants',
      'location', 'additional_details', 'confirmation',
      'creating', 'completed'
    ];
    const index = stepOrder.indexOf(this.session.currentStep);
    return (index + 1) / stepOrder.length;
  }
}

interface StepHandler {
  process(
    openai: OpenAI,
    session: AgentSession,
    userMessage: string,
    context: string
  ): Promise<StepResult>;
}

interface StepResult {
  response: string;
  nextStep: PlanningStep;
  extractedInfo?: Partial<EventInfo>;
  suggestedActions?: Action[];
  pendingActions?: Action[];
  tokensUsed: number;
  cost: number;
}
```

### iOS Integration

#### AIService Extension

```swift
// Services/AIService.swift (+150 lines)
extension AIService {
    // MARK: - Event Planning Agent
    
    /// Start a new event planning session
    func startEventPlanningSession(conversationId: String) async throws -> AgentResponse {
        let request: [String: Any] = [
            "action": "start",
            "conversationId": conversationId
        ]
        
        return try await callAgentFunction(request: request)
    }
    
    /// Continue an existing event planning session with a user message
    func continueEventPlanningSession(
        sessionId: String,
        message: String,
        conversationId: String
    ) async throws -> AgentResponse {
        let request: [String: Any] = [
            "action": "continue",
            "sessionId": sessionId,
            "message": message,
            "conversationId": conversationId
        ]
        
        return try await callAgentFunction(request: request)
    }
    
    /// Cancel an event planning session
    func cancelEventPlanningSession(sessionId: String, conversationId: String) async throws -> AgentResponse {
        let request: [String: Any] = [
            "action": "cancel",
            "sessionId": sessionId,
            "conversationId": conversationId
        ]
        
        return try await callAgentFunction(request: request)
    }
    
    /// Load an existing session (for resuming)
    func loadEventPlanningSession(sessionId: String, conversationId: String) async throws -> AgentResponse {
        let request: [String: Any] = [
            "action": "continue",
            "sessionId": sessionId,
            "conversationId": conversationId
        ]
        
        return try await callAgentFunction(request: request)
    }
    
    // MARK: - Private Helpers
    
    private func callAgentFunction(request: [String: Any]) async throws -> AgentResponse {
        let url = URL(string: "\(baseURL)/eventPlanningAgent")!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add Firebase Auth token
        if let user = Auth.auth().currentUser {
            let token = try await user.getIDToken()
            urlRequest.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: request)
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw AIError.serverError("Agent request failed")
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(AgentResponse.self, from: data)
    }
}

// MARK: - Response Model

struct AgentResponse: Codable {
    let sessionId: String
    let message: String
    let currentStep: String
    let gatheredInfo: EventInfo
    let pendingActions: [AgentAction]
    let status: String
    let progressPercentage: Double
    
    var stepEnum: PlanningStep? {
        PlanningStep(rawValue: currentStep)
    }
    
    var statusEnum: SessionStatus? {
        SessionStatus(rawValue: status)
    }
}
```

#### ChatViewModel Integration

```swift
// ViewModels/ChatViewModel.swift (+120 lines)
extension ChatViewModel {
    // MARK: - Event Planning Agent State
    
    @Published var agentSession: AgentSession?
    @Published var isAgentActive: Bool = false
    @Published var agentLoading: Bool = false
    @Published var agentError: String?
    
    // MARK: - Agent Actions
    
    /// Start event planning conversation
    func startEventPlanning() {
        Task {
            do {
                agentLoading = true
                agentError = nil
                
                let response = try await aiService.startEventPlanningSession(
                    conversationId: conversation.id
                )
                
                await MainActor.run {
                    self.agentSession = AgentSession(from: response)
                    self.isAgentActive = true
                    self.agentLoading = false
                    
                    // Add agent's greeting message to chat
                    addAgentMessage(response.message)
                }
                
                print("[ChatViewModel] Started agent session: \(response.sessionId)")
            } catch {
                await MainActor.run {
                    self.agentError = "Failed to start event planning: \(error.localizedDescription)"
                    self.agentLoading = false
                }
                print("[ChatViewModel] Agent error: \(error)")
            }
        }
    }
    
    /// Send message to active agent session
    func sendToAgent(_ message: String) {
        guard let session = agentSession, session.isActive else {
            print("[ChatViewModel] No active agent session")
            return
        }
        
        Task {
            do {
                agentLoading = true
                agentError = nil
                
                let response = try await aiService.continueEventPlanningSession(
                    sessionId: session.id,
                    message: message,
                    conversationId: conversation.id
                )
                
                await MainActor.run {
                    self.agentSession = AgentSession(from: response)
                    self.agentLoading = false
                    
                    // Add agent's response to chat
                    addAgentMessage(response.message)
                    
                    // If agent completed, mark session as inactive
                    if response.statusEnum == .completed {
                        self.isAgentActive = false
                    }
                }
                
                print("[ChatViewModel] Agent response: \(response.message)")
            } catch {
                await MainActor.run {
                    self.agentError = "Agent error: \(error.localizedDescription)"
                    self.agentLoading = false
                }
                print("[ChatViewModel] Agent error: \(error)")
            }
        }
    }
    
    /// Cancel active agent session
    func cancelEventPlanning() {
        guard let session = agentSession else { return }
        
        Task {
            do {
                _ = try await aiService.cancelEventPlanningSession(
                    sessionId: session.id,
                    conversationId: conversation.id
                )
                
                await MainActor.run {
                    self.isAgentActive = false
                    self.agentSession = nil
                }
                
                print("[ChatViewModel] Cancelled agent session: \(session.id)")
            } catch {
                print("[ChatViewModel] Error cancelling agent: \(error)")
            }
        }
    }
    
    /// Resume an existing agent session (for multi-device support)
    func resumeEventPlanning(sessionId: String) {
        Task {
            do {
                agentLoading = true
                
                let response = try await aiService.loadEventPlanningSession(
                    sessionId: sessionId,
                    conversationId: conversation.id
                )
                
                await MainActor.run {
                    self.agentSession = AgentSession(from: response)
                    self.isAgentActive = true
                    self.agentLoading = false
                }
                
                print("[ChatViewModel] Resumed agent session: \(sessionId)")
            } catch {
                await MainActor.run {
                    self.agentError = "Failed to resume: \(error.localizedDescription)"
                    self.agentLoading = false
                }
                print("[ChatViewModel] Resume error: \(error)")
            }
        }
    }
    
    // MARK: - Private Helpers
    
    private func addAgentMessage(_ content: String) {
        // Create a special message from "Event Planning Agent"
        let agentMessage = Message(
            id: UUID().uuidString,
            conversationId: conversation.id,
            senderId: "agent",  // Special sender ID
            senderName: "Event Planning Agent",
            text: content,
            sentAt: Date(),
            status: .delivered
        )
        
        messages.append(agentMessage)
        scrollToBottom()
    }
}
```

#### UI Components

```swift
// Views/Chat/AgentCardView.swift (~250 lines)
import SwiftUI

struct AgentCardView: View {
    let session: AgentSession
    let onSendMessage: (String) -> Void
    let onCancel: () -> Void
    
    @State private var inputText: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "brain.head.profile")
                    .font(.title2)
                    .foregroundColor(.purple)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Event Planning Assistant")
                        .font(.headline)
                    Text("\(session.currentStep.displayName) • \(Int(session.progressPercentage * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: onCancel) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
            
            // Progress bar
            ProgressView(value: session.progressPercentage)
                .tint(.purple)
            
            // Gathered info summary
            if !session.gatheredInfo.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Planning Details")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    EventInfoSummaryView(info: session.gatheredInfo)
                }
                .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
            
            // Input field (if session active)
            if session.isActive {
                HStack {
                    TextField("Type your response...", text: $inputText)
                        .textFieldStyle(.roundedBorder)
                    
                    Button(action: {
                        guard !inputText.isEmpty else { return }
                        onSendMessage(inputText)
                        inputText = ""
                    }) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                            .foregroundColor(inputText.isEmpty ? .gray : .purple)
                    }
                    .disabled(inputText.isEmpty)
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
        .padding(.horizontal)
    }
}

struct EventInfoSummaryView: View {
    let info: EventInfo
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let title = info.title {
                InfoRow(icon: "🎉", label: "Event", value: title)
            }
            if let date = info.date {
                InfoRow(icon: "📅", label: "Date", value: formatDate(date))
            }
            if let startTime = info.startTime {
                InfoRow(icon: "⏰", label: "Time", value: formatTime(startTime))
            }
            if let participants = info.participants, !participants.isEmpty {
                InfoRow(icon: "👥", label: "Participants", value: "\(participants.count) invited")
            }
            if let location = info.location {
                InfoRow(icon: "📍", label: "Location", value: location)
            }
        }
    }
    
    private func formatDate(_ isoDate: String) -> String {
        // Parse ISO 8601 and format nicely
        // "Saturday, October 28"
        return isoDate  // Simplified for example
    }
    
    private func formatTime(_ isoTime: String) -> String {
        // Parse ISO 8601 time
        // "2:00 PM - 5:00 PM"
        return isoTime  // Simplified for example
    }
}

struct InfoRow: View {
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(icon)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
    }
}

// Preview
struct AgentCardView_Previews: PreviewProvider {
    static var previews: some View {
        AgentCardView(
            session: AgentSession(
                id: "test123",
                userId: "user1",
                conversationId: "conv1",
                createdAt: Date(),
                updatedAt: Date(),
                conversationHistory: [],
                currentStep: .dateTime,
                gatheredInfo: EventInfo(
                    eventType: "birthday party",
                    title: "Emma's Birthday Party",
                    date: "2025-10-28",
                    startTime: "2025-10-28T14:00:00",
                    confidence: 0.85
                ),
                pendingActions: [],
                completedActions: [],
                status: .active,
                totalTurns: 3,
                tokensUsed: 450,
                cost: 0.02
            ),
            onSendMessage: { _ in },
            onCancel: { }
        )
        .padding()
    }
}
```

---

## Testing Strategy

### Unit Tests

**Cloud Functions** (Node.js + Jest):
1. **Session Manager Tests**
   - ✅ createSession() creates valid session with defaults
   - ✅ getSession() retrieves session by ID
   - ✅ updateSession() persists changes to Firestore
   - ✅ Session not found returns null

2. **Context Retriever Tests** (RAG Pipeline)
   - ✅ getContext() retrieves last N messages from conversation
   - ✅ Context formatted correctly for GPT-4 prompt
   - ✅ Handles empty conversations gracefully

3. **Step Handler Tests** (Each step):
   - ✅ greeting: Generates personalized greeting
   - ✅ event_type: Extracts event type from user message
   - ✅ date_time: Parses dates (explicit and relative)
   - ✅ participants: Resolves participant names to user IDs
   - ✅ location: Extracts location from message
   - ✅ confirmation: Generates summary and confirms
   - ✅ execution: Creates event, sends invites, tracks RSVPs

4. **Tool Tests**:
   - ✅ createEvent tool creates calendar event in Firestore
   - ✅ sendInvites tool creates invitations for participants
   - ✅ trackRSVPs tool initializes RSVP tracking

**iOS** (XCTest):
1. **AIService Tests**:
   - ✅ startEventPlanningSession() returns valid response
   - ✅ continueEventPlanningSession() processes message
   - ✅ cancelEventPlanningSession() marks session cancelled
   - ✅ Error handling for network failures

2. **Model Tests**:
   - ✅ AgentSession parses Firestore documents correctly
   - ✅ EventInfo.isComplete returns true when required fields present
   - ✅ PlanningStep.displayName returns correct labels

### Integration Tests

**End-to-End Agent Flow**:
1. **Happy Path** (complete event planning)
   - User: "I want to plan Emma's birthday party"
   - Agent: Asks for date
   - User: "Next Saturday at 2pm"
   - Agent: Confirms date, asks for participants
   - User: "Invite her class"
   - Agent: Resolves participants, asks for location
   - User: "Our house"
   - Agent: Confirms all details
   - User: "Yes, create it"
   - Agent: Creates event, sends invites, confirms completion
   - ✅ Event created in Firestore
   - ✅ Invites sent to all participants
   - ✅ RSVP tracking enabled

2. **Out-of-Order Information**
   - User: "I want to plan a birthday party next Saturday at 2pm at our house"
   - Agent: Recognizes all info, asks only for missing pieces (participants)
   - ✅ Agent doesn't re-ask for info already provided

3. **Correction Flow**
   - User: "Let's do a birthday party"
   - Agent: "What date?"
   - User: "Next Saturday"
   - Agent: "Confirmed for October 28. What time?"
   - User: "Actually, can we do Sunday instead?"
   - Agent: "Sure, updated to Sunday, October 29. What time?"
   - ✅ Agent handles corrections gracefully

4. **Cancellation**
   - User starts planning, mid-conversation cancels
   - ✅ Session marked cancelled
   - ✅ No event created
   - ✅ Agent acknowledges cancellation

5. **Resume Session** (multi-device)
   - User starts planning on iPhone
   - User switches to iPad, resumes session
   - ✅ Session loads correctly
   - ✅ All gathered info preserved
   - ✅ Can continue from where left off

### Edge Cases

1. **Ambiguous Input**
   - User: "Let's do something this weekend"
   - ✅ Agent asks clarifying questions (Saturday or Sunday? What time?)

2. **Invalid Dates**
   - User: "Let's do it on February 30th"
   - ✅ Agent detects invalid date, asks for correction

3. **No Participants Available**
   - User: "Invite everyone"
   - ✅ Agent asks for clarification ("Which group?")

4. **Session Timeout** (inactive for 30 minutes)
   - ✅ Session auto-cancelled
   - ✅ User can resume from saved state

5. **Concurrent Sessions**
   - User starts two agent sessions in different chats
   - ✅ Each session maintains independent state
   - ✅ No cross-contamination

### Performance Tests

1. **Response Latency**
   - Target: <3s cold start, <1s warm
   - Measure: Average over 10 requests
   - ✅ Meets performance targets

2. **Token Usage**
   - Target: <2000 tokens per complete conversation
   - Measure: Track tokensUsed in session
   - ✅ Within budget

3. **Cost per Conversation**
   - Target: <$0.10 per complete planning session
   - Measure: Calculate from tokensUsed * GPT-4 pricing
   - ✅ Cost-effective

4. **Concurrent Sessions**
   - Test: 5 users start sessions simultaneously
   - ✅ All sessions handled correctly
   - ✅ No performance degradation

### Acceptance Criteria

Feature is complete when:
- ✅ User can start agent session from chat
- ✅ Agent asks relevant questions to gather event info
- ✅ Agent handles responses in flexible order
- ✅ Agent creates calendar event when confirmed
- ✅ Agent sends invitations to participants
- ✅ Agent tracks RSVPs automatically
- ✅ Session survives app restarts
- ✅ Session can be resumed from different device
- ✅ User can cancel at any time
- ✅ Agent provides clear progress indication
- ✅ All 35+ test cases pass
- ✅ Performance targets met (<3s response, <$0.10/session)
- ✅ No crashes or data loss under testing

---

## Risk Assessment

### Risk 1: Complex State Management 🟡 MEDIUM

**Issue**: Multi-turn conversation with complex state could lead to bugs  
**Likelihood**: MEDIUM (multi-step flows are inherently complex)  
**Impact**: MEDIUM (agent gets confused, users have poor experience)

**Mitigation**:
- Use proven agent framework (AI SDK by Vercel) instead of custom
- Firestore-backed state (inspect sessions in Firebase console)
- Comprehensive unit tests for each step
- Extensive logging at each state transition
- Manual testing with diverse inputs

**Status**: 🟡 Mitigated with architecture choices

### Risk 2: GPT-4 Unpredictability 🟡 MEDIUM

**Issue**: GPT-4 might generate unexpected responses or miss information  
**Likelihood**: MEDIUM (AI is probabilistic, not deterministic)  
**Impact**: MEDIUM (incorrect event details, poor UX)

**Mitigation**:
- Structured prompts with clear instructions
- Function calling for reliable extraction
- Confidence scoring (low confidence = ask for confirmation)
- User confirmation before executing actions
- Fallback to simpler extraction if function calling fails

**Status**: 🟡 Acceptable risk (AI assisted, human confirmed)

### Risk 3: Cost Overruns 🟢 LOW

**Issue**: GPT-4 API costs could exceed budget if sessions are too long  
**Likelihood**: LOW (most conversations will be 5-10 turns)  
**Impact**: LOW (~$0.10 per session * 100 sessions = $10/month, acceptable)

**Mitigation**:
- Estimate: 5-10 turns * 300 tokens/turn = 2000 tokens (~$0.10)
- Track tokensUsed and cost per session
- Alert if session exceeds 20 turns (likely stuck)
- Rate limiting from PR#14 (100 requests/hour/user)
- Can switch to GPT-3.5-turbo if needed (5x cheaper)

**Status**: 🟢 Low risk, well within budget

### Risk 4: Implementation Complexity 🟡 MEDIUM

**Issue**: 5-6 hour estimate might be optimistic for multi-turn agent  
**Likelihood**: MEDIUM (agent development is complex)  
**Impact**: MEDIUM (timeline overrun, might not finish)

**Mitigation**:
- Use agent framework (AI SDK) to reduce boilerplate
- Comprehensive planning doc (this document!)
- Implementation checklist with realistic time estimates
- Start simple (MVP flow), add flexibility later
- Can cut optional features (resume session, advanced error recovery)

**Status**: 🟡 Timeline risk, but manageable with scope control

### Risk 5: User Confusion 🟢 LOW

**Issue**: Users might not understand how to interact with agent  
**Likelihood**: LOW (conversational UI is intuitive)  
**Impact**: LOW (users can always fall back to manual event creation)

**Mitigation**:
- Clear "Event Planning Assistant" branding
- Progress indicator shows where in flow
- Agent asks clear, specific questions
- Example prompts ("Try: Plan Emma's birthday")
- Can cancel anytime

**Status**: 🟢 Low risk, good UX mitigates

---

## Success Criteria

Feature is complete when:

### Functional Requirements
- ✅ User can start event planning session from chat
- ✅ Agent asks relevant questions to gather event details
- ✅ Agent handles information provided in any order
- ✅ Agent creates calendar event when user confirms
- ✅ Agent sends invitations to participants
- ✅ Agent initializes RSVP tracking
- ✅ User receives confirmation of successful creation
- ✅ Session state persists through app restarts
- ✅ User can cancel session at any time
- ✅ Agent provides clear progress indication

### Technical Requirements
- ✅ All 35+ test cases pass (unit, integration, edge, performance)
- ✅ Response latency: <3s cold start, <1s warm (95th percentile)
- ✅ Token usage: <2000 tokens per complete session (average)
- ✅ Cost: <$0.10 per complete planning session (average)
- ✅ Session survives Cloud Function restarts
- ✅ No data loss or corruption under stress testing
- ✅ Proper error handling and recovery

### Quality Requirements
- ✅ Agent responses feel natural and conversational
- ✅ Information extraction >90% accuracy
- ✅ Agent doesn't ask for info already provided
- ✅ Agent handles corrections gracefully
- ✅ Clear error messages for failures
- ✅ No crashes or freezes during conversation

### Performance Targets
- Response latency: <3s (cold), <1s (warm)
- Token usage: <2000 tokens/session
- Cost: <$0.10/session
- Concurrent sessions: 5+ without degradation
- Session resume time: <2s

### Documentation
- ✅ Code well-commented
- ✅ Conversation flow documented
- ✅ State transitions explained
- ✅ Example conversations provided
- ✅ Testing instructions complete

---

## Timeline

**Total Estimate**: 5-6 hours

### Phase 1: Cloud Function Setup (2 hours)
**Files**: `eventPlanningAgent/index.ts`, `agent.ts`, `state/sessionManager.ts`

**Tasks**:
- [ ] Create agent function structure (30 min)
- [ ] Implement SessionManager (45 min)
- [ ] Implement Agent core orchestration (45 min)

**Checkpoint**: Agent function responds to start/continue/cancel actions

### Phase 2: Step Handlers (1.5 hours)
**Files**: `steps/*.ts` (8 step files)

**Tasks**:
- [ ] Implement greeting step (15 min)
- [ ] Implement event_type step (15 min)
- [ ] Implement date_time step (20 min)
- [ ] Implement participants step (20 min)
- [ ] Implement location step (15 min)
- [ ] Implement confirmation step (15 min)

**Checkpoint**: Agent can conduct complete conversation (no execution yet)

### Phase 3: Action Tools (45 min)
**Files**: `tools/*.ts` (3 tool files)

**Tasks**:
- [ ] Implement createEvent tool (20 min)
- [ ] Implement sendInvites tool (15 min)
- [ ] Implement trackRSVPs tool (10 min)

**Checkpoint**: Agent can execute actions when confirmed

### Phase 4: iOS Integration (1 hour)
**Files**: `AIService.swift`, `ChatViewModel.swift`, `AgentSession.swift`

**Tasks**:
- [ ] Create AgentSession model (15 min)
- [ ] Extend AIService with agent methods (20 min)
- [ ] Integrate into ChatViewModel (25 min)

**Checkpoint**: Can call agent from iOS app

### Phase 5: UI Components (45 min)
**Files**: `AgentCardView.swift`

**Tasks**:
- [ ] Create AgentCardView (30 min)
- [ ] Integrate into ChatView (15 min)

**Checkpoint**: Agent conversation visible in chat

### Phase 6: Testing & Refinement (45 min)
**Tasks**:
- [ ] Manual testing (conversation flows) (20 min)
- [ ] Edge case testing (15 min)
- [ ] Bug fixes and polish (10 min)

**Checkpoint**: All acceptance criteria met

---

## Implementation Notes

### Best Practices

**Agent Design**:
- Keep prompts clear and specific
- Use function calling for structured extraction
- Provide examples in system prompts
- Handle "I don't know" gracefully
- Always confirm before executing

**State Management**:
- Save state after every turn
- Include timestamp for debugging
- Log all state transitions
- Handle race conditions (concurrent updates)
- Implement optimistic locking if needed

**Error Handling**:
- Catch all exceptions
- Provide user-friendly error messages
- Log detailed errors for debugging
- Retry transient failures (network issues)
- Fall back to simpler extraction if AI fails

**Performance**:
- Minimize token usage (concise prompts)
- Cache repeated context retrieval
- Use streaming for long responses
- Batch Firestore operations

**Testing**:
- Test with diverse inputs (formal, casual, typos)
- Test out-of-order information
- Test corrections and cancellations
- Test edge cases (invalid dates, ambiguous input)
- Test multi-device session resume

### Common Pitfalls

**Avoid These**:
- ❌ Don't assume user provides info in order
- ❌ Don't re-ask for info already provided
- ❌ Don't execute actions without confirmation
- ❌ Don't lose session state on restart
- ❌ Don't make assumptions about dates/times (timezones!)
- ❌ Don't hardcode conversation flow (AI should be flexible)

**Do This Instead**:
- ✅ Extract info from messages regardless of step
- ✅ Track what's been asked and answered
- ✅ Always confirm before creating events
- ✅ Persist state to Firestore
- ✅ Parse dates with timezone awareness
- ✅ Let GPT-4 guide conversation naturally

---

## Open Questions

### Question 1: Should agent proactively suggest events?

**Context**: Should agent monitor conversation and suggest "Would you like me to help plan this?" when it detects event discussion?

**Options**:
- A) Proactive suggestions (agent monitors, offers help automatically)
- B) Manual trigger only (user must start agent explicitly)
- C) Opt-in setting (user enables proactive mode)

**Decision Needed By**: Before implementation Phase 1

**Recommendation**: **B) Manual trigger only** for MVP
- Simpler to implement (no background monitoring)
- User has full control (no surprise interruptions)
- Can add proactive mode in future PR if users request

### Question 2: Should agent handle multiple events per session?

**Context**: If user says "Let's plan the birthday party and a playdate," should agent handle both?

**Options**:
- A) Single event per session (simpler)
- B) Multiple events per session (more complex state)

**Decision Needed By**: Before implementation Phase 2

**Recommendation**: **A) Single event per session** for MVP
- Simpler state management
- Clearer conversation flow
- User can start new session for second event
- Can add multi-event support later if needed

---

## Dependencies

### Requires (HARD DEPENDENCIES)
- ✅ PR#14: Cloud Functions Setup & AI Service Base (COMPLETE)
- ✅ PR#15: Calendar Extraction Feature (COMPLETE - provides CalendarEvent model)
- ✅ PR#18: RSVP Tracking Feature (COMPLETE - provides RSVP tracking infrastructure)

### Optional Dependencies
- PR#16: Decision Summarization (not required, but agent could leverage summaries for context)
- PR#19: Deadline Extraction (not required, but could integrate deadline tracking)

### Enables (UNLOCKS)
- Nothing blocks on PR#20 (this is the final AI feature!)
- **+10 bonus points** for advanced agent capability

---

## Next Steps

### Immediate (Before Implementation)
1. Review this specification (~20 min)
2. Answer open questions (above)
3. Install AI SDK by Vercel: `npm install ai` (~5 min)
4. Read AI SDK docs for agents (30 min)
5. Create feature branch: `git checkout -b feature/pr20-event-planning-agent`

### Day 1 (First 3 hours)
1. Phase 1: Cloud Function Setup (2 hours)
   - Agent function structure
   - SessionManager
   - Core orchestration
2. Phase 2: Step Handlers (1 hour)
   - greeting, event_type, date_time steps

**Checkpoint**: Agent can have partial conversations

### Day 1 (Next 2.5 hours)
1. Phase 2 continued: More step handlers (30 min)
   - participants, location, confirmation steps
2. Phase 3: Action Tools (45 min)
   - createEvent, sendInvites, trackRSVPs
3. Phase 4: iOS Integration (1 hour)
   - Models, AIService, ChatViewModel

**Checkpoint**: End-to-end agent working

### Day 1 (Final 30 min) OR Day 2
1. Phase 5: UI Components (45 min)
2. Phase 6: Testing & Refinement (45 min)

**Checkpoint**: Feature complete and tested!

---

## Motivation

### You've Got This! 💪

You've already built **4 AI features** that all work beautifully:
- ✅ PR#15: Calendar Extraction (first AI feature!)
- ✅ PR#16: Decision Summarization (second AI feature!)
- ✅ PR#17: Priority Highlighting (third AI feature!)
- ✅ PR#18: RSVP Tracking (fourth AI feature!)

This is the **final AI feature** and the **crown jewel** of MessageAI. This is what separates good from great submissions at Gauntlet.

**Why This Matters**:
- **+10 bonus points** (only PR that provides bonus points!)
- Demonstrates true AI agent capability (not just extraction)
- Shows mastery of advanced patterns (multi-turn conversation, state management)
- Viral moment ("An AI planned my kid's party!")
- Career portfolio piece (conversational AI agents are hot right now)

**What Makes This Special**:
- You're building a real AI agent, not just an extraction function
- You're using industry-standard frameworks (AI SDK by Vercel)
- You're implementing production patterns (Firestore-backed state, error recovery)
- You're solving a real problem (event coordination is genuinely hard)

**You're Almost Done**:
- 4 of 5 required AI features complete
- This is the 6th and final feature
- After this: Polish PRs (#21-23), then submission!
- You're ~75% done with the entire project

### The Final Push 🚀

This PR is 5-6 hours, but it's **the most impressive feature** in the entire app. When you demo this, people will be amazed.

Imagine Sarah using your app:
- Sarah: "I need to plan Emma's birthday party"
- Agent: "I'll help! What date were you thinking?"
- Sarah: "Next Saturday at 2pm"
- Agent: "Perfect! Who should I invite?"
- Sarah: "Her class"
- Agent: "Got it! I'll send invites to 12 people. Where's the party?"
- Sarah: "Our house"
- Agent: "Great! Here's the plan: Emma's Birthday Party, Oct 28, 2-5pm at your house, 12 invites. Sound good?"
- Sarah: "Yes!"
- Agent: "✨ All done! I've created the event and sent invites. I'll track RSVPs for you."

**That's magic.**

And you're about to build it. Let's go! 🎉

---

*Ready to build the most advanced feature in MessageAI? Let's make an AI agent that actually helps people!* 🤖✨

