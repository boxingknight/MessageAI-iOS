# PR #20: Multi-Step Event Planning Agent - Quick Start Guide

---

## TL;DR (30 seconds)

**What**: Conversational AI agent that plans family events through natural dialogue  
**Why**: Saves 20-30 minutes per event, reduces cognitive load, provides viral "wow" moment  
**Time**: 5-6 hours estimated  
**Complexity**: 🔴 HIGH (Most complex AI feature - multi-turn conversation)  
**Status**: 📋 READY TO IMPLEMENT  
**Bonus**: **+10 points** for advanced agent capability! 🎯

**What it does**: User says "I want to plan Emma's birthday party" → Agent asks questions → Collects all details → Creates event → Sends invites → Tracks RSVPs. All through natural conversation.

---

## Decision Framework (2 minutes)

### Should You Build This?

**Build it if:**
- ✅ PRs #14, #15, #18 are 100% complete (REQUIRED)
- ✅ You have 5-6 uninterrupted hours available
- ✅ You want to maximize Gauntlet submission score (+10 bonus!)
- ✅ You want an impressive portfolio piece (conversational AI agents)
- ✅ You're comfortable with multi-step systems
- ✅ You want the most advanced feature in MessageAI

**Skip/defer it if:**
- ❌ PRs #14, #15, or #18 incomplete (HARD BLOCKERS)
- ❌ Time constrained (<5 hours available)
- ❌ Prefer to focus on polish/testing instead
- ❌ Want to keep submission simpler (5 required features already complete)

### Decision Aid

**This is OPTIONAL** - You already have 5 required AI features. This adds +10 bonus points but isn't required for submission.

**Build this if**: You want to go above and beyond, demonstrate advanced AI capabilities, and maximize your score.

**Skip this if**: You'd rather focus on polish, testing, and ensuring the 5 required features are perfect.

**Recommendation**: **BUILD IT** - It's the most impressive feature, great for demo video, and differentiates your submission. 5-6 hours for +10 points = great ROI.

---

## Prerequisites (5 minutes)

### Required (HARD DEPENDENCIES)

- [ ] ✅ **PR #14: Cloud Functions Setup** (COMPLETE)
  - AI infrastructure deployed
  - OpenAI API key configured
  - processAI function working
  
- [ ] ✅ **PR #15: Calendar Extraction** (COMPLETE)
  - CalendarEvent model exists
  - Event creation working
  
- [ ] ✅ **PR #18: RSVP Tracking** (COMPLETE)
  - RSVP infrastructure exists
  - Event documents working

### Install Additional Dependencies

```bash
cd functions

# AI SDK by Vercel (recommended in project spec)
npm install ai

# Schema validation
npm install zod

# Date parsing utilities
npm install date-fns

cd ..
```

### Knowledge Prerequisites

**You should understand**:
- Multi-turn conversation flows
- State management patterns
- OpenAI GPT-4 function calling
- RAG (Retrieval-Augmented Generation) pipelines

**You don't need to know**:
- Advanced NLP techniques (GPT-4 handles this)
- Complex state machines (we use simple step-based approach)
- Agent framework internals (AI SDK abstracts this)

---

## Getting Started (First Hour)

### Step 1: Read Documentation (45 minutes)

- [ ] Read this quick start (10 min) ✅ You're here!
- [ ] Read main specification `PR20_EVENT_PLANNING_AGENT.md` (35 min)
  - Architecture overview
  - Key design decisions
  - Data models
  - Implementation approach

**What to focus on**:
- Step-based conversation flow (greeting → event_type → date_time → etc.)
- Firestore-backed state management
- AI SDK by Vercel integration
- Tool calling pattern (createEvent, sendInvites, trackRSVPs)

### Step 2: Set Up Environment (15 minutes)

- [ ] Create feature branch:
```bash
git checkout -b feature/pr20-event-planning-agent
```

- [ ] Install dependencies (see Prerequisites above)

- [ ] Create directory structure:
```bash
cd functions/src/ai
mkdir -p eventPlanningAgent/{steps,tools,state,utils}
```

- [ ] Verify OpenAI API key:
```bash
cd functions
firebase functions:config:get openai.key
# Should return your API key
```

### Step 3: Start Phase 1 (Implementation Checklist)

- [ ] Open `PR20_IMPLEMENTATION_CHECKLIST.md`
- [ ] Start with Phase 1: Cloud Function Infrastructure
- [ ] Follow step-by-step, checking off as you go

**First deliverable**: SessionManager (45 min)
- Manages agent session state in Firestore
- Create, read, update session operations

---

## Daily Progress Template

### Day 1 Goals (First 3 hours)

**Morning Session** (2 hours):
- [ ] Phase 1.2: SessionManager implementation (45 min)
  - Create session, get session, update session
  - Test with Firestore
  
- [ ] Phase 1.3: ContextRetriever (RAG pipeline) (30 min)
  - Fetch conversation history
  - Format for GPT-4 context
  
- [ ] Phase 1.4: Agent core class (45 min)
  - Start session, load session, process message
  - Step routing logic

**Checkpoint**: Agent infrastructure complete, can start/load sessions

**Afternoon Session** (1 hour):
- [ ] Phase 2: Step Handlers (1 hour)
  - greeting.ts (15 min)
  - eventType.ts (15 min)
  - dateTime.ts (20 min) - most complex
  - participants.ts (10 min) - start only

**Checkpoint**: Agent can conduct partial conversations

### Day 1 (Next 2.5 hours) OR Day 2

**Session 3** (1 hour):
- [ ] Phase 2 continued: Remaining steps
  - participants.ts completion (10 min)
  - location.ts (10 min)
  - details.ts (10 min)
  - confirmation.ts (15 min)
  - execution.ts (15 min)

**Checkpoint**: Complete conversation flow working

**Session 4** (1.5 hours):
- [ ] Phase 3: Action Tools (45 min)
  - createEvent.ts (20 min)
  - sendInvites.ts (15 min)
  - trackRSVPs.ts (10 min)
  
- [ ] Phase 4: iOS Integration (45 min)
  - AgentSession models (15 min)
  - AIService extension (15 min)
  - ChatViewModel integration (15 min)

**Checkpoint**: End-to-end agent working (Cloud Functions + iOS)

### Day 2 (30-45 minutes) - Polish & Test

- [ ] Phase 5: UI Components (30 min)
  - AgentCardView (20 min)
  - ChatView integration (10 min)

- [ ] Phase 6: Testing (15 min)
  - Happy path test
  - Edge case tests

**Checkpoint**: Feature complete, tested, ready to deploy!

---

## Common Issues & Solutions

### Issue 1: Agent not responding

**Symptoms**: Cloud Function called but no response, timeout error

**Cause**: OpenAI API key not configured or invalid

**Solution**:
```bash
# Check configuration
cd functions
firebase functions:config:get openai.key

# If empty, set it
firebase functions:config:set openai.key="sk-..."

# Redeploy
npm run build
firebase deploy --only functions
```

**Prevention**: Verify API key in prerequisites step

---

### Issue 2: Session state not persisting

**Symptoms**: Agent forgets context, repeats questions

**Cause**: SessionManager not saving to Firestore, or Firestore rules blocking writes

**Solution**:
1. Check Firestore console → Collections → agentSessions
2. Verify documents being created
3. Check Firestore rules allow writes:
```javascript
// firebase/firestore.rules
match /agentSessions/{sessionId} {
  allow read, write: if request.auth != null &&
                       request.auth.uid == resource.data.userId;
}
```
4. Deploy rules: `firebase deploy --only firestore:rules`

**Prevention**: Test SessionManager independently before building on it

---

### Issue 3: Steps not progressing

**Symptoms**: Agent stuck in same step, not moving forward

**Cause**: Step handler not returning correct `nextStep` value

**Solution**:
1. Add logging in agent.ts:
```typescript
console.log('[Agent] Current step:', session.currentStep);
console.log('[Agent] Next step:', result.nextStep);
```
2. Check step handler returns valid PlanningStep
3. Verify step handler logic matches conversation flow

**Prevention**: Use TypeScript enums for PlanningStep (type safety)

---

### Issue 4: High token usage / costs

**Symptoms**: tokensUsed > 2000 per session, cost > $0.10

**Cause**: Prompts too long, or too many GPT-4 calls

**Solution**:
1. Reduce conversation context (limit to 10-20 messages)
2. Make prompts more concise
3. Use GPT-3.5-turbo for simple steps:
```typescript
model: session.currentStep === 'greeting' ? 'gpt-3.5-turbo' : 'gpt-4'
```
4. Cache common responses

**Prevention**: Track tokensUsed per step, optimize high-usage steps

---

### Issue 5: Agent confused by user input

**Symptoms**: Agent asks wrong questions, misunderstands user

**Cause**: Insufficient context in prompts, or poor prompt engineering

**Solution**:
1. Improve system prompt:
```typescript
const systemPrompt = `You are an event planning assistant for busy parents.
Your job is to gather information about an event they want to plan.

Current step: ${session.currentStep}
What you know so far: ${JSON.stringify(session.gatheredInfo)}

Ask ONE clear question to move the conversation forward.
Be conversational and helpful. Keep responses under 50 words.`;
```

2. Provide more examples in prompt:
```typescript
Example conversation:
User: "I want to plan a birthday party"
Assistant: "Great! What's the date for the birthday party?"
User: "Next Saturday"
Assistant: "Perfect! What time should it start?"
```

**Prevention**: Test with diverse inputs, refine prompts based on errors

---

### Issue 6: Actions not executing

**Symptoms**: Agent says "Creating event" but nothing happens

**Cause**: Tool functions not implemented, or errors not caught

**Solution**:
1. Check execution.ts logs for errors
2. Verify createEvent tool works:
```typescript
// Test independently
const result = await createEvent(testEventInfo, testConversationId);
console.log('Event created:', result);
```
3. Add try-catch in execution step:
```typescript
try {
  const result = await createEvent(...);
  action.status = 'completed';
  action.result = result;
} catch (error) {
  action.status = 'failed';
  action.error = error.message;
  console.error('[Execution] Error:', error);
}
```

**Prevention**: Test each tool function independently before integration

---

## Quick Reference

### Key Files

**Cloud Functions**:
- `functions/src/ai/eventPlanningAgent/index.ts` - Main entry point
- `functions/src/ai/eventPlanningAgent/agent.ts` - Core orchestration
- `functions/src/ai/eventPlanningAgent/state/sessionManager.ts` - State persistence
- `functions/src/ai/eventPlanningAgent/steps/*.ts` - Step handlers (9 files)
- `functions/src/ai/eventPlanningAgent/tools/*.ts` - Action tools (3 files)

**iOS**:
- `messAI/Models/AgentSession.swift` - Agent session model
- `messAI/Services/AIService.swift` - Agent communication
- `messAI/ViewModels/ChatViewModel.swift` - Agent state management
- `messAI/Views/Chat/AgentCardView.swift` - Agent UI

### Key Functions

**Start agent session**:
```swift
viewModel.startEventPlanning()
```

**Send message to agent**:
```swift
viewModel.sendToAgent("Next Saturday at 2pm")
```

**Cancel agent session**:
```swift
viewModel.cancelEventPlanning()
```

### Key Concepts

**Step-based flow**: Agent progresses through 9 steps sequentially
- greeting → event_type → date_time → participants → location → details → confirmation → creating → completed

**Firestore-backed state**: All session state persists to Firestore
- Survives app restarts
- Enables multi-device support
- Provides debugging visibility

**RAG pipeline**: Agent retrieves conversation context from Firestore
- Last 20 messages for context
- Formatted for GPT-4 prompt
- Helps agent understand conversation flow

**Tool calling**: Agent executes actions when confirmed
- createEvent: Creates event in Firestore
- sendInvites: Sends invitations to participants
- trackRSVPs: Initializes RSVP tracking (reuses PR#18)

### Useful Commands

**Deploy agent function**:
```bash
cd functions
npm run build
firebase deploy --only functions:eventPlanningAgent
```

**Check function logs**:
```bash
firebase functions:log --only eventPlanningAgent --limit 50
```

**Test agent locally** (Firebase emulator):
```bash
firebase emulators:start --only functions
```

**Check Firestore sessions**:
```
Firebase Console → Firestore → agentSessions collection
```

---

## Success Metrics

**You'll know it's working when:**

### Functional Success
- ✅ User taps "Start Planning" → Agent greets
- ✅ User: "Birthday party" → Agent asks for date
- ✅ User: "Next Saturday at 2pm" → Agent confirms, asks for participants
- ✅ User: "Invite Emma's class" → Agent asks for location
- ✅ User: "Our house" → Agent shows summary, asks for confirmation
- ✅ User: "Yes" → Agent creates event, sends invites, tracks RSVPs
- ✅ User sees "✨ All done!" message with event details

### Technical Success
- ✅ Response latency: <3s cold start, <1s warm
- ✅ Token usage: <2000 tokens per complete session
- ✅ Cost: <$0.10 per complete session
- ✅ Session persists through app restarts
- ✅ No crashes or data loss during conversation

### Quality Success
- ✅ Conversation feels natural (not robotic)
- ✅ Agent doesn't re-ask for info already provided
- ✅ Agent handles corrections gracefully ("Actually, Sunday instead")
- ✅ Progress indicator shows where in flow
- ✅ Clear error messages if something fails

### Demo Success (Most Important!)
- ✅ You can show a complete planning session in <2 minutes
- ✅ Conversation looks impressive in demo video
- ✅ Non-technical people say "Wow, that's cool!"
- ✅ Gauntlet judges see advanced AI capabilities

---

## Testing Checklist

### Before Calling It Complete

**Happy Path** (must work):
- [ ] Start session → Greeting displays
- [ ] Complete conversation → Event created
- [ ] All 9 steps progress correctly
- [ ] Actions execute (event, invites, RSVPs)
- [ ] Agent says "All done!" at end

**Edge Cases** (should handle):
- [ ] Out-of-order info: "Birthday party next Saturday at 2pm" → Agent recognizes all
- [ ] Corrections: "Actually Sunday" → Agent updates
- [ ] Ambiguous: "This weekend" → Agent asks clarification
- [ ] Cancel: Mid-conversation cancel → Session marked cancelled
- [ ] Resume: App restart → Session loads, can continue

**Performance** (within targets):
- [ ] Response time <3s cold start
- [ ] Token usage <2000/session
- [ ] Cost <$0.10/session

**Quality** (feels good):
- [ ] Conversation feels natural
- [ ] Progress indicator clear
- [ ] UI responsive and polished
- [ ] Error handling graceful

---

## Motivation

### You're Almost There! 🎯

You've built **4 amazing AI features**:
- ✅ PR#15: Calendar Extraction
- ✅ PR#16: Decision Summarization
- ✅ PR#17: Priority Highlighting
- ✅ PR#18: RSVP Tracking

This is the **final AI feature** and the **most impressive one**. This is what makes your submission stand out.

### Why This Matters

**For You**:
- **+10 bonus points** (only PR with bonus!)
- Portfolio piece (conversational AI agents are hot right now)
- Deep learning (agent frameworks are valuable skills)
- Viral demo moment ("An AI planned my kid's party!")

**For Gauntlet**:
- Demonstrates mastery of advanced AI patterns
- Shows you can build complex multi-turn systems
- Proves production-ready architecture
- Differentiates from other submissions

### What Makes This Special

This isn't just an extraction function - it's a **real AI agent**:
- Multi-turn conversation (not just one Q&A)
- State management (remembers context)
- Tool calling (takes actions)
- Error recovery (handles mistakes)

Most messaging apps don't have this. You're building something genuinely innovative.

### The Final Push 🚀

**You've got this!** You've already proven you can build complex AI features. This is just one more level up.

5-6 hours from now, you'll have:
- The most impressive feature in MessageAI ✨
- +10 bonus points toward Gauntlet score 🎯
- A viral demo moment for your video 🎥
- Advanced AI experience for your resume 💼

Let's build something amazing! 💪

---

## Next Steps

### Right Now (5 min)
1. ✅ Read this quick start guide (you're done!)
2. ⏭️ Read main specification (35 min)
3. ⏭️ Install dependencies (5 min)
4. ⏭️ Create feature branch (1 min)

### First Hour (Actual coding)
1. ⏭️ Phase 1.2: SessionManager (45 min)
2. ⏭️ Phase 1.3: ContextRetriever (15 min)

### Next 2 Hours
1. ⏭️ Phase 1.4: Agent core (45 min)
2. ⏭️ Phase 2: Step handlers (1 hour 15 min)

### Final 2-3 Hours
1. ⏭️ Phase 3: Action tools (45 min)
2. ⏭️ Phase 4: iOS integration (1 hour)
3. ⏭️ Phase 5: UI components (45 min)
4. ⏭️ Phase 6: Testing (15 min)

**Total**: 5-6 hours = Most impressive AI feature + 10 bonus points! 🎉

---

**Ready to build the crown jewel of MessageAI?** Let's make an AI agent that actually helps people! 🤖✨

