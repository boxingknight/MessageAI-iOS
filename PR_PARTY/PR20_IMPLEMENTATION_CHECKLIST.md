# PR #20: Multi-Step Event Planning Agent - Implementation Checklist

**Use this as your daily todo list.** Check off items as you complete them.

**Estimated Total Time**: 5-6 hours  
**Complexity**: 🔴 HIGH (Most complex AI feature)  
**Status**: 📋 READY TO IMPLEMENT

---

## Pre-Implementation Setup (15 minutes)

### Prerequisites Verification

- [ ] Read main planning document (`PR20_EVENT_PLANNING_AGENT.md`) - **45 min**
- [ ] Verify PR#14 100% complete (Cloud Functions infrastructure)
- [ ] Verify PR#15 complete (Calendar Extraction - provides CalendarEvent model)
- [ ] Verify PR#18 complete (RSVP Tracking - provides RSVP infrastructure)
- [ ] OpenAI API key configured in Cloud Functions environment
- [ ] Firebase billing enabled (Blaze plan for Cloud Functions)

### Install Dependencies

```bash
# Navigate to functions directory
cd functions

# Install AI SDK by Vercel (recommended in project spec)
npm install ai

# Install additional dependencies if needed
npm install zod  # For schema validation
npm install date-fns  # For date parsing

# Return to project root
cd ..
```

### Create Git Branch

```bash
git checkout -b feature/pr20-event-planning-agent
```

---

## Phase 1: Cloud Function Infrastructure (2 hours)

### Step 1.1: Create Agent Directory Structure (10 min)

- [ ] Create directory structure:

```bash
cd functions/src/ai

mkdir -p eventPlanningAgent/{steps,tools,state,utils}
```

- [ ] Create placeholder files:

```bash
cd eventPlanningAgent

# Main files
touch index.ts agent.ts

# Step handlers
touch steps/greeting.ts
touch steps/eventType.ts
touch steps/dateTime.ts
touch steps/participants.ts
touch steps/location.ts
touch steps/details.ts
touch steps/confirmation.ts
touch steps/execution.ts

# Tools
touch tools/createEvent.ts
touch tools/sendInvites.ts
touch tools/trackRSVPs.ts

# State management
touch state/sessionManager.ts
touch state/contextRetriever.ts

# Utils
touch utils/dateParser.ts
touch utils/participantResolver.ts
touch utils/validator.ts
```

**Checkpoint**: Directory structure created, all placeholder files exist

**Commit**: `feat(pr20): Create agent directory structure`

---

### Step 1.2: Implement SessionManager (45 min)

- [ ] Create `state/sessionManager.ts`:

```typescript
// functions/src/ai/eventPlanningAgent/state/sessionManager.ts

import { Firestore, Timestamp } from 'firebase-admin/firestore';

export interface AgentSession {
  sessionId: string;
  userId: string;
  conversationId: string;
  createdAt: Timestamp;
  updatedAt: Timestamp;
  conversationHistory: Message[];
  currentStep: PlanningStep;
  gatheredInfo: EventInfo;
  pendingActions: Action[];
  completedActions: Action[];
  status: SessionStatus;
  errorMessage?: string;
  totalTurns: number;
  tokensUsed: number;
  cost: number;
}

export type PlanningStep =
  | 'greeting'
  | 'event_type'
  | 'date_time'
  | 'participants'
  | 'location'
  | 'additional_details'
  | 'confirmation'
  | 'creating'
  | 'completed';

export interface EventInfo {
  eventType?: string;
  title?: string;
  date?: string;          // ISO 8601
  startTime?: string;     // ISO 8601
  endTime?: string;       // ISO 8601
  participants?: string[];
  location?: string;
  notes?: string;
  confidence: number;
}

export interface Action {
  actionId: string;
  type: 'create_event' | 'send_invites' | 'track_rsvps';
  params: any;
  status: 'pending' | 'confirmed' | 'executing' | 'completed' | 'failed';
  result?: any;
  error?: string;
}

export type SessionStatus = 'active' | 'completed' | 'cancelled' | 'errored';

export interface Message {
  role: 'user' | 'assistant' | 'system';
  content: string;
  timestamp: Timestamp;
  metadata?: {
    step?: PlanningStep;
    extractedInfo?: Partial<EventInfo>;
    suggestedActions?: Action[];
  };
}

export class SessionManager {
  private collection;
  
  constructor(private db: Firestore) {
    this.collection = db.collection('agentSessions');
  }
  
  async createSession(data: {
    userId: string;
    conversationId: string;
    currentStep: PlanningStep;
  }): Promise<AgentSession> {
    const sessionId = this.db.collection('agentSessions').doc().id;
    
    const session: AgentSession = {
      sessionId,
      userId: data.userId,
      conversationId: data.conversationId,
      createdAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
      conversationHistory: [],
      currentStep: data.currentStep,
      gatheredInfo: { confidence: 0 },
      pendingActions: [],
      completedActions: [],
      status: 'active',
      totalTurns: 0,
      tokensUsed: 0,
      cost: 0
    };
    
    await this.collection.doc(sessionId).set(session);
    console.log(`[SessionManager] Created session: ${sessionId}`);
    
    return session;
  }
  
  async getSession(sessionId: string): Promise<AgentSession | null> {
    const doc = await this.collection.doc(sessionId).get();
    
    if (!doc.exists) {
      console.log(`[SessionManager] Session not found: ${sessionId}`);
      return null;
    }
    
    return doc.data() as AgentSession;
  }
  
  async updateSession(session: AgentSession): Promise<void> {
    session.updatedAt = Timestamp.now();
    
    await this.collection.doc(session.sessionId).set(session, { merge: true });
    console.log(`[SessionManager] Updated session: ${session.sessionId}`);
  }
  
  async deleteSession(sessionId: string): Promise<void> {
    await this.collection.doc(sessionId).delete();
    console.log(`[SessionManager] Deleted session: ${sessionId}`);
  }
}
```

**Test**:
- [ ] SessionManager can create session
- [ ] SessionManager can retrieve session
- [ ] SessionManager can update session
- [ ] Returns null for non-existent session

**Checkpoint**: SessionManager working with Firestore

**Commit**: `feat(pr20): Implement SessionManager for agent state persistence`

---

### Step 1.3: Implement Context Retriever (RAG Pipeline) (30 min)

- [ ] Create `state/contextRetriever.ts`:

```typescript
// functions/src/ai/eventPlanningAgent/state/contextRetriever.ts

import { Firestore } from 'firebase-admin/firestore';

export class ContextRetriever {
  constructor(private db: Firestore) {}
  
  /**
   * Retrieve recent conversation context for RAG pipeline
   * @param conversationId Firestore conversation ID
   * @param limit Number of recent messages (default: 20)
   * @returns Formatted conversation context for GPT-4 prompt
   */
  async getContext(
    conversationId: string,
    limit: number = 20
  ): Promise<string> {
    console.log(`[ContextRetriever] Fetching context for conversation: ${conversationId}`);
    
    try {
      // Fetch last N messages from conversation
      const messagesSnapshot = await this.db
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .orderBy('sentAt', 'desc')
        .limit(limit)
        .get();
      
      if (messagesSnapshot.empty) {
        console.log('[ContextRetriever] No messages found');
        return 'No previous conversation history.';
      }
      
      // Reverse to chronological order (oldest first)
      const messages = messagesSnapshot.docs.reverse();
      
      // Format messages for GPT-4 context
      const formattedMessages = messages.map(doc => {
        const data = doc.data();
        const senderName = data.senderName || 'User';
        const text = data.text || '';
        const timestamp = data.sentAt?.toDate().toISOString() || '';
        
        return `[${timestamp}] ${senderName}: ${text}`;
      });
      
      const context = formattedMessages.join('\n');
      
      console.log(`[ContextRetriever] Retrieved ${messages.length} messages`);
      return context;
      
    } catch (error) {
      console.error('[ContextRetriever] Error fetching context:', error);
      return 'Error retrieving conversation history.';
    }
  }
  
  /**
   * Get participant names for the conversation
   */
  async getParticipantNames(conversationId: string): Promise<string[]> {
    try {
      const conversationDoc = await this.db
        .collection('conversations')
        .doc(conversationId)
        .get();
      
      if (!conversationDoc.exists) {
        return [];
      }
      
      const data = conversationDoc.data();
      const participants = data?.participants || [];
      
      // Fetch user names
      const names: string[] = [];
      for (const userId of participants) {
        const userDoc = await this.db.collection('users').doc(userId).get();
        if (userDoc.exists) {
          names.push(userDoc.data()?.displayName || 'Unknown');
        }
      }
      
      return names;
      
    } catch (error) {
      console.error('[ContextRetriever] Error fetching participants:', error);
      return [];
    }
  }
}
```

**Test**:
- [ ] getContext() retrieves messages from Firestore
- [ ] Messages formatted correctly for GPT-4
- [ ] Handles empty conversations gracefully
- [ ] getParticipantNames() returns participant display names

**Checkpoint**: RAG pipeline fetching conversation context

**Commit**: `feat(pr20): Implement ContextRetriever for RAG pipeline`

---

### Step 1.4: Implement Main Agent Class (45 min)

- [ ] Create `agent.ts`:

```typescript
// functions/src/ai/eventPlanningAgent/agent.ts

import { Firestore, Timestamp } from 'firebase-admin/firestore';
import OpenAI from 'openai';
import { SessionManager, AgentSession, PlanningStep } from './state/sessionManager';
import { ContextRetriever } from './state/contextRetriever';
import * as steps from './steps';

export class EventPlanningAgent {
  private openai: OpenAI;
  private sessionManager: SessionManager;
  private contextRetriever: ContextRetriever;
  private session: AgentSession | null = null;
  
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
    console.log('[Agent] Starting new session...');
    
    // Create new session
    this.session = await this.sessionManager.createSession({
      userId: this.userId,
      conversationId: this.conversationId,
      currentStep: 'greeting'
    });
    
    // Generate greeting message
    const conversationContext = await this.contextRetriever.getContext(
      this.conversationId,
      10
    );
    
    const greeting = await steps.greeting.generateGreeting(
      this.openai,
      this.session,
      conversationContext
    );
    
    // Add greeting to conversation history
    this.session.conversationHistory.push({
      role: 'assistant',
      content: greeting,
      timestamp: Timestamp.now()
    });
    
    await this.sessionManager.updateSession(this.session);
    
    console.log('[Agent] Session started:', this.session.sessionId);
    return this.session;
  }
  
  async loadSession(sessionId: string): Promise<AgentSession> {
    console.log('[Agent] Loading session:', sessionId);
    
    this.session = await this.sessionManager.getSession(sessionId);
    
    if (!this.session) {
      throw new Error(`Session not found: ${sessionId}`);
    }
    
    if (this.session.userId !== this.userId) {
      throw new Error('Unauthorized: Session belongs to different user');
    }
    
    return this.session;
  }
  
  async processMessage(message: string): Promise<AgentSession> {
    if (!this.session) {
      throw new Error('No active session. Call startSession() or loadSession() first.');
    }
    
    console.log(`[Agent] Processing message in step: ${this.session.currentStep}`);
    
    // Add user message to history
    this.session.conversationHistory.push({
      role: 'user',
      content: message,
      timestamp: Timestamp.now()
    });
    
    this.session.totalTurns++;
    
    // Retrieve conversation context (RAG)
    const conversationContext = await this.contextRetriever.getContext(
      this.conversationId,
      20
    );
    
    // Route to appropriate step handler
    const stepHandler = this.getStepHandler(this.session.currentStep);
    const result = await stepHandler.process(
      this.openai,
      this.session,
      message,
      conversationContext
    );
    
    // Update session with results
    this.session.conversationHistory.push({
      role: 'assistant',
      content: result.response,
      timestamp: Timestamp.now(),
      metadata: {
        step: this.session.currentStep,
        extractedInfo: result.extractedInfo,
        suggestedActions: result.suggestedActions
      }
    });
    
    // Merge extracted info
    this.session.gatheredInfo = {
      ...this.session.gatheredInfo,
      ...result.extractedInfo
    };
    
    // Move to next step
    this.session.currentStep = result.nextStep;
    
    // Add pending actions
    if (result.pendingActions) {
      this.session.pendingActions.push(...result.pendingActions);
    }
    
    // Update token usage and cost
    this.session.tokensUsed += result.tokensUsed || 0;
    this.session.cost += result.cost || 0;
    
    await this.sessionManager.updateSession(this.session);
    
    console.log('[Agent] Processed message, next step:', this.session.currentStep);
    return this.session;
  }
  
  async cancelSession(sessionId: string): Promise<AgentSession> {
    console.log('[Agent] Cancelling session:', sessionId);
    
    await this.loadSession(sessionId);
    
    if (this.session) {
      this.session.status = 'cancelled';
      await this.sessionManager.updateSession(this.session);
    }
    
    return this.session!;
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
      case 'completed': return steps.execution;
      default:
        throw new Error(`Unknown step: ${step}`);
    }
  }
}

// Export step handler interface
export interface StepHandler {
  process(
    openai: OpenAI,
    session: AgentSession,
    userMessage: string,
    conversationContext: string
  ): Promise<StepResult>;
}

export interface StepResult {
  response: string;
  nextStep: PlanningStep;
  extractedInfo?: Partial<EventInfo>;
  suggestedActions?: Action[];
  pendingActions?: Action[];
  tokensUsed?: number;
  cost?: number;
}
```

**Test**:
- [ ] Agent can start new session
- [ ] Agent can load existing session
- [ ] Agent can process user messages
- [ ] Agent routes to correct step handlers
- [ ] Agent updates session state correctly

**Checkpoint**: Agent core orchestration working

**Commit**: `feat(pr20): Implement Agent core orchestration class`

---

### Step 1.5: Create Main Cloud Function Entry Point (15 min)

- [ ] Create `index.ts`:

```typescript
// functions/src/ai/eventPlanningAgent/index.ts

import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { getFirestore } from 'firebase-admin/firestore';
import { EventPlanningAgent } from './agent';

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
  cost: number;
  tokensUsed: number;
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
    
    console.log(`[eventPlanningAgent] Action: ${action}, SessionID: ${sessionId || 'new'}`);
    
    // 2. Validate input
    if (!conversationId) {
      throw new HttpsError('invalid-argument', 'conversationId is required');
    }
    
    // 3. Initialize agent
    const agent = new EventPlanningAgent(db, userId, conversationId);
    let session;
    
    try {
      switch (action) {
        case 'start':
          // Create new session
          session = await agent.startSession();
          break;
          
        case 'continue':
          // Load existing session and process message
          if (!sessionId) {
            throw new HttpsError('invalid-argument', 'sessionId required for continue');
          }
          
          session = await agent.loadSession(sessionId);
          
          if (message) {
            session = await agent.processMessage(message);
          }
          break;
          
        case 'cancel':
          // Cancel session
          if (!sessionId) {
            throw new HttpsError('invalid-argument', 'sessionId required for cancel');
          }
          
          session = await agent.cancelSession(sessionId);
          break;
          
        default:
          throw new HttpsError('invalid-argument', `Invalid action: ${action}`);
      }
      
      // 4. Calculate progress percentage
      const stepOrder = [
        'greeting', 'event_type', 'date_time', 'participants',
        'location', 'additional_details', 'confirmation',
        'creating', 'completed'
      ];
      const stepIndex = stepOrder.indexOf(session.currentStep);
      const progressPercentage = (stepIndex + 1) / stepOrder.length;
      
      // 5. Get last assistant message
      const lastAssistantMessage = session.conversationHistory
        .filter(m => m.role === 'assistant')
        .pop();
      
      // 6. Return response
      return {
        sessionId: session.sessionId,
        message: lastAssistantMessage?.content || '',
        currentStep: session.currentStep,
        gatheredInfo: session.gatheredInfo,
        pendingActions: session.pendingActions,
        status: session.status,
        progressPercentage,
        cost: session.cost,
        tokensUsed: session.tokensUsed
      };
      
    } catch (error: any) {
      console.error('[eventPlanningAgent] Error:', error);
      throw new HttpsError('internal', `Agent error: ${error.message}`);
    }
  }
);
```

- [ ] Export from main index:

```typescript
// functions/src/index.ts

// Add to existing exports
export { eventPlanningAgent } from './ai/eventPlanningAgent/index';
```

**Test**:
- [ ] Function callable from iOS app
- [ ] Authentication required
- [ ] Returns valid AgentResponse
- [ ] Error handling works

**Checkpoint**: Cloud Function endpoint ready

**Commit**: `feat(pr20): Create eventPlanningAgent Cloud Function endpoint`

---

## Phase 2: Step Handlers (1.5 hours)

### Step 2.1: Greeting Step (15 min)

- [ ] Implement `steps/greeting.ts`:

```typescript
// functions/src/ai/eventPlanningAgent/steps/greeting.ts

import OpenAI from 'openai';
import { AgentSession } from '../state/sessionManager';
import { StepHandler, StepResult } from '../agent';

export const greeting: StepHandler = {
  async process(
    openai: OpenAI,
    session: AgentSession,
    userMessage: string,
    conversationContext: string
  ): Promise<StepResult> {
    // This is called on user's first message after greeting
    // Extract event intent and move to event_type step
    
    const prompt = `You are an event planning assistant for busy parents.
The user just said: "${userMessage}"

Extract any information about the event they want to plan. Respond naturally and ask what kind of event they want to plan if unclear.

Recent conversation context (for reference):
${conversationContext}

Respond with:
1. A friendly acknowledgment of their request
2. Ask what kind of event they want to plan (birthday party, playdate, school event, etc.)

Keep your response conversational and helpful, under 50 words.`;

    const completion = await openai.chat.completions.create({
      model: 'gpt-4',
      messages: [
        { role: 'system', content: 'You are a helpful event planning assistant.' },
        { role: 'user', content: prompt }
      ],
      temperature: 0.7,
      max_tokens: 150
    });

    const response = completion.choices[0].message.content || 
      "I'd love to help you plan an event! What kind of event are you thinking about?";

    return {
      response,
      nextStep: 'event_type',
      tokensUsed: completion.usage?.total_tokens || 0,
      cost: calculateCost(completion.usage?.total_tokens || 0)
    };
  },
  
  async generateGreeting(
    openai: OpenAI,
    session: AgentSession,
    conversationContext: string
  ): Promise<string> {
    // Generate initial greeting when session starts
    
    const prompt = `Generate a friendly, concise greeting for an event planning assistant.
The user is a busy parent who might want to plan a family event.

Recent conversation context (for reference):
${conversationContext}

Greeting should:
- Be warm and helpful
- Introduce yourself as an event planning assistant
- Invite them to tell you what they want to plan
- Be under 30 words

Generate greeting:`;

    const completion = await openai.chat.completions.create({
      model: 'gpt-4',
      messages: [
        { role: 'system', content: 'You are a helpful event planning assistant.' },
        { role: 'user', content: prompt }
      ],
      temperature: 0.7,
      max_tokens: 100
    });

    return completion.choices[0].message.content || 
      "Hi! I'm your event planning assistant. Tell me what event you'd like to plan and I'll help coordinate everything! 🎉";
  }
};

function calculateCost(tokens: number): number {
  // GPT-4 pricing: ~$0.03 per 1K input tokens, ~$0.06 per 1K output tokens
  // Simplified: $0.05 per 1K tokens average
  return (tokens / 1000) * 0.05;
}
```

**Checkpoint**: Greeting step working

**Commit**: `feat(pr20): Implement greeting step handler`

---

### Step 2.2-2.7: Implement Remaining Steps (1 hour 15 min)

Due to length constraints, I'll provide the structure for each step. Implement similarly to greeting:

- [ ] **eventType.ts** (15 min): Extract event type, ask for date/time
- [ ] **dateTime.ts** (20 min): Parse dates (explicit & relative), ask for participants  
- [ ] **participants.ts** (20 min): Extract participant selection, ask for location
- [ ] **location.ts** (10 min): Extract location, ask for additional details
- [ ] **details.ts** (10 min): Gather any extra info, move to confirmation

Each step should:
1. Use GPT-4 to extract info from user message
2. Update session.gatheredInfo with extracted data
3. Generate natural response acknowledging info
4. Ask for next piece of information
5. Return next step

**Commit after each**: `feat(pr20): Implement [step_name] handler`

---

## Phase 3: Action Tools (45 min)

### Step 3.1: Implement confirmation.ts (15 min)

```typescript
// functions/src/ai/eventPlanningAgent/steps/confirmation.ts

export const confirmation: StepHandler = {
  async process(openai, session, userMessage, context) {
    // Check if user confirmed
    const userConfirmed = /yes|yeah|sure|correct|confirmed|go ahead|do it/i.test(userMessage);
    
    if (userConfirmed) {
      // Move to creating step
      return {
        response: "Perfect! Creating your event now... ⚙️",
        nextStep: 'creating',
        pendingActions: [
          { actionId: 'create1', type: 'create_event', params: session.gatheredInfo, status: 'pending' },
          { actionId: 'invite1', type: 'send_invites', params: session.gatheredInfo, status: 'pending' },
          { actionId: 'rsvp1', type: 'track_rsvps', params: session.gatheredInfo, status: 'pending' }
        ],
        tokensUsed: 0,
        cost: 0
      };
    } else {
      // User wants to modify
      return {
        response: "No problem! What would you like to change?",
        nextStep: 'event_type',  // Go back to collect changes
        tokensUsed: 0,
        cost: 0
      };
    }
  }
};
```

### Step 3.2: Implement execution.ts (30 min)

```typescript
// functions/src/ai/eventPlanningAgent/steps/execution.ts

import { createEvent } from '../tools/createEvent';
import { sendInvites } from '../tools/sendInvites';
import { trackRSVPs } from '../tools/trackRSVPs';

export const execution: StepHandler = {
  async process(openai, session, userMessage, context) {
    // Execute pending actions
    const results = [];
    
    for (const action of session.pendingActions) {
      if (action.status === 'pending') {
        action.status = 'executing';
        
        try {
          let result;
          
          switch (action.type) {
            case 'create_event':
              result = await createEvent(session.gatheredInfo, session.conversationId);
              break;
            case 'send_invites':
              result = await sendInvites(session.gatheredInfo, session.conversationId);
              break;
            case 'track_rsvps':
              result = await trackRSVPs(result.eventId, session.conversationId);
              break;
          }
          
          action.status = 'completed';
          action.result = result;
          results.push(result);
          
        } catch (error) {
          action.status = 'failed';
          action.error = error.message;
        }
        
        session.completedActions.push(action);
      }
    }
    
    session.pendingActions = [];
    
    // Generate completion message
    const eventTitle = session.gatheredInfo.title || 'Event';
    const participantCount = session.gatheredInfo.participants?.length || 0;
    
    const response = `✨ All done! I've created "${eventTitle}" and sent invitations to ${participantCount} people. I'll track RSVPs for you automatically!`;
    
    return {
      response,
      nextStep: 'completed',
      tokensUsed: 0,
      cost: 0
    };
  }
};
```

**Checkpoint**: Action execution working

**Commit**: `feat(pr20): Implement confirmation and execution steps`

---

### Step 3.3: Implement Tool Functions (remaining time)

Create three tool files:

- [ ] `tools/createEvent.ts` - Creates event document in Firestore `/events/{eventId}`
- [ ] `tools/sendInvites.ts` - Sends messages to participants
- [ ] `tools/trackRSVPs.ts` - Initializes RSVP tracking (reuses PR#18 infrastructure)

**Commit**: `feat(pr20): Implement createEvent, sendInvites, and trackRSVPs tools`

---

## Phase 4: iOS Integration (1 hour)

### Step 4.1: Create iOS Models (15 min)

- [ ] Create `Models/AgentSession.swift`:

```swift
// Models/AgentSession.swift

import Foundation

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
        let stepOrder: [PlanningStep] = [
            .greeting, .eventType, .dateTime, .participants,
            .location, .additionalDetails, .confirmation,
            .creating, .completed
        ]
        guard let index = stepOrder.firstIndex(of: currentStep) else { return 0 }
        return Double(index + 1) / Double(stepOrder.count)
    }
    
    // Convenience initializer from AgentResponse
    init(from response: AgentResponse) {
        self.id = response.sessionId
        self.userId = ""  // Will be filled by client
        self.conversationId = ""  // Will be filled by client
        self.createdAt = Date()
        self.updatedAt = Date()
        self.conversationHistory = []
        self.currentStep = response.stepEnum ?? .greeting
        self.gatheredInfo = response.gatheredInfo
        self.pendingActions = response.pendingActions
        self.completedActions = []
        self.status = response.statusEnum ?? .active
        self.totalTurns = 0
        self.tokensUsed = response.tokensUsed
        self.cost = response.cost
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
    
    enum MessageRole: String, Codable {
        case user
        case assistant
        case system
    }
}

struct AgentAction: Codable, Identifiable {
    let id: String
    let type: ActionType
    var status: ActionStatus
    var result: String?
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
```

**Checkpoint**: iOS models compile successfully

**Commit**: `feat(pr20): Create iOS models for agent session`

---

### Step 4.2: Extend AIService (20 min)

- [ ] Add to `Services/AIService.swift`:

```swift
// Services/AIService.swift

extension AIService {
    // MARK: - Event Planning Agent
    
    func startEventPlanningSession(conversationId: String) async throws -> AgentResponse {
        let request: [String: Any] = [
            "action": "start",
            "conversationId": conversationId
        ]
        
        return try await callAgentFunction(request: request)
    }
    
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
    
    func cancelEventPlanningSession(
        sessionId: String,
        conversationId: String
    ) async throws -> AgentResponse {
        let request: [String: Any] = [
            "action": "cancel",
            "sessionId": sessionId,
            "conversationId": conversationId
        ]
        
        return try await callAgentFunction(request: request)
    }
    
    // MARK: - Private
    
    private func callAgentFunction(request: [String: Any]) async throws -> AgentResponse {
        let url = URL(string: "\(baseURL)/eventPlanningAgent")!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
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

struct AgentResponse: Codable {
    let sessionId: String
    let message: String
    let currentStep: String
    let gatheredInfo: EventInfo
    let pendingActions: [AgentAction]
    let status: String
    let progressPercentage: Double
    let cost: Double
    let tokensUsed: Int
    
    var stepEnum: PlanningStep? {
        PlanningStep(rawValue: currentStep)
    }
    
    var statusEnum: SessionStatus? {
        SessionStatus(rawValue: status)
    }
}
```

**Checkpoint**: AIService methods compile

**Commit**: `feat(pr20): Add agent methods to AIService`

---

### Step 4.3: Integrate into ChatViewModel (25 min)

- [ ] Add to `ViewModels/ChatViewModel.swift`:

```swift
// ViewModels/ChatViewModel.swift

extension ChatViewModel {
    // MARK: - Event Planning Agent State
    
    @Published var agentSession: AgentSession?
    @Published var isAgentActive: Bool = false
    @Published var agentLoading: Bool = false
    @Published var agentError: String?
    
    // MARK: - Agent Actions
    
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
                    
                    addAgentMessage(response.message)
                }
                
                print("[ChatViewModel] Started agent: \(response.sessionId)")
            } catch {
                await MainActor.run {
                    self.agentError = "Failed to start: \(error.localizedDescription)"
                    self.agentLoading = false
                }
            }
        }
    }
    
    func sendToAgent(_ message: String) {
        guard let session = agentSession, session.isActive else { return }
        
        Task {
            do {
                agentLoading = true
                
                let response = try await aiService.continueEventPlanningSession(
                    sessionId: session.id,
                    message: message,
                    conversationId: conversation.id
                )
                
                await MainActor.run {
                    self.agentSession = AgentSession(from: response)
                    self.agentLoading = false
                    
                    addAgentMessage(response.message)
                    
                    if response.statusEnum == .completed {
                        self.isAgentActive = false
                    }
                }
            } catch {
                await MainActor.run {
                    self.agentError = "Agent error: \(error.localizedDescription)"
                    self.agentLoading = false
                }
            }
        }
    }
    
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
            } catch {
                print("[ChatViewModel] Cancel error: \(error)")
            }
        }
    }
    
    // MARK: - Private
    
    private func addAgentMessage(_ content: String) {
        let agentMessage = Message(
            id: UUID().uuidString,
            conversationId: conversation.id,
            senderId: "agent",
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

**Checkpoint**: ChatViewModel compiles, agent state managed

**Commit**: `feat(pr20): Integrate agent into ChatViewModel`

---

## Phase 5: UI Components (45 min)

### Step 5.1: Create AgentCardView (30 min)

- [ ] Create `Views/Chat/AgentCardView.swift` (see main spec for full code)
- [ ] Card shows: progress bar, gathered info summary, input field
- [ ] Styling: Purple theme, SF Symbols, smooth animations

**Checkpoint**: AgentCardView renders correctly in preview

**Commit**: `feat(pr20): Create AgentCardView UI component`

---

### Step 5.2: Integrate into ChatView (15 min)

- [ ] Add "Start Planning" button to ChatView toolbar
- [ ] Display AgentCardView when agent active
- [ ] Route user messages to agent when active

```swift
// Views/Chat/ChatView.swift

.toolbar {
    ToolbarItem(placement: .navigationBarTrailing) {
        Button {
            viewModel.startEventPlanning()
        } label: {
            Image(systemName: "brain.head.profile")
                .foregroundColor(.purple)
        }
    }
}

// In ScrollView, before MessageBubbles:
if viewModel.isAgentActive, let session = viewModel.agentSession {
    AgentCardView(
        session: session,
        onSendMessage: { message in
            viewModel.sendToAgent(message)
        },
        onCancel: {
            viewModel.cancelEventPlanning()
        }
    )
}
```

**Checkpoint**: Can start agent from chat, send messages, see responses

**Commit**: `feat(pr20): Integrate AgentCardView into ChatView`

---

## Phase 6: Testing & Refinement (45 min)

### Manual Testing (20 min)

- [ ] **Happy Path Test**:
  - Start agent: "I want to plan Emma's birthday party"
  - Provide date: "Next Saturday at 2pm"
  - Select participants: "Invite her class"
  - Provide location: "Our house"
  - Confirm: "Yes, create it"
  - ✅ Event created, invites sent, RSVPs tracked

- [ ] **Out-of-Order Test**:
  - Start: "Let's do a birthday party next Saturday at 2pm at our house"
  - ✅ Agent recognizes all info, only asks for participants

- [ ] **Correction Test**:
  - Start: "Birthday party"
  - Agent asks date: "Next Saturday"
  - User: "Actually, Sunday instead"
  - ✅ Agent updates date to Sunday

- [ ] **Cancellation Test**:
  - Start planning, mid-conversation cancel
  - ✅ Session marked cancelled

### Edge Case Testing (15 min)

- [ ] Ambiguous input: "This weekend" → Agent asks clarification
- [ ] Invalid date: "February 30th" → Agent detects error
- [ ] Session resume: Start on iPhone, continue on iPad
- [ ] App restart: Session state persists

### Bug Fixes & Polish (10 min)

- [ ] Fix any issues found during testing
- [ ] Polish UI animations
- [ ] Improve error messages
- [ ] Add loading indicators

**Checkpoint**: All test scenarios pass

**Commit**: `test(pr20): Fix bugs found during testing, add polish`

---

## Final Steps

### Deploy to Firebase (5 min)

```bash
cd functions
npm run build
firebase deploy --only functions:eventPlanningAgent
```

- [ ] Deployment successful
- [ ] Function URL: `https://us-central1-messageai-95c8f.cloudfunctions.net/eventPlanningAgent`

### Test End-to-End (10 min)

- [ ] iOS app → Cloud Function → OpenAI → Response
- [ ] Complete planning session works
- [ ] Events created correctly
- [ ] RSVPs tracked automatically

### Update Documentation (5 min)

- [ ] Update PR_PARTY/README.md with PR#20 status
- [ ] Create PR20_COMPLETE_SUMMARY.md
- [ ] Update memory-bank/activeContext.md
- [ ] Update memory-bank/progress.md

### Final Commit

```bash
git add .
git commit -m "feat(pr20): Complete Multi-Step Event Planning Agent implementation

- Cloud Functions agent with AI SDK by Vercel
- 9 step handlers (greeting → completed)
- 3 action tools (createEvent, sendInvites, trackRSVPs)
- Firestore-backed state management
- RAG pipeline for conversation context
- iOS AgentSession models and UI
- ChatViewModel integration
- AgentCardView with progress indicator
- All test scenarios passing
- Deployed to production

BONUS: +10 points for advanced agent capability!

Time: 6 hours actual (5-6h estimated)
Lines: ~1,810 lines Cloud Functions, ~550 lines iOS
Status: ✅ COMPLETE, TESTED, DEPLOYED
"

git push origin feature/pr20-event-planning-agent
```

---

## Completion Checklist

Feature is complete when:

### Functional
- ✅ User can start agent session from chat
- ✅ Agent asks questions to gather event info
- ✅ Agent handles flexible conversation flow
- ✅ Agent creates calendar event
- ✅ Agent sends invitations
- ✅ Agent tracks RSVPs
- ✅ User can cancel anytime
- ✅ Session persists through restarts

### Technical
- ✅ All 35+ tests pass
- ✅ Response <3s cold, <1s warm
- ✅ Token usage <2000/session
- ✅ Cost <$0.10/session
- ✅ No crashes or data loss

### Quality
- ✅ Natural conversation flow
- ✅ >90% extraction accuracy
- ✅ Clear progress indication
- ✅ Good error handling
- ✅ Professional UI/UX

---

## If You Get Stuck

### Common Issues

**Issue**: Agent not responding
- Check OpenAI API key configured
- Check Cloud Function logs
- Verify authentication working

**Issue**: State not persisting
- Check Firestore rules allow writes
- Check SessionManager saving correctly
- Check Firestore console for documents

**Issue**: Steps not progressing
- Check step handler return values
- Verify nextStep correct
- Check agent.ts routing logic

---

**You've got this!** This is the final AI feature and the crown jewel of MessageAI. +10 bonus points await! 🚀✨

