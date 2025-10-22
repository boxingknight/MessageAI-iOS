# PR#16: Decision Summarization - Quick Start Guide

---

## TL;DR (30 seconds)

**What:** AI-powered conversation summaries that extract decisions, action items, and key points from group chats using GPT-4

**Why:** Busy parents receive 50-100+ messages/day in group chats. Reading all messages takes 30-45 minutes. AI can summarize 50 messages in 2 seconds.

**Time:** 3-4 hours estimated

**Complexity:** MEDIUM (Cloud Functions, GPT-4, iOS UI, caching)

**Status:** 📋 PLANNED (ready to implement!)

**Value:** Saves users 10-15 minutes/day of reading group chat backlogs

---

## Decision Framework (2 minutes)

### Should You Build This?

**Green Lights (Build it!):**
- ✅ PR#14 (Cloud Functions) is 100% complete and deployed
- ✅ OpenAI API account active with $5+ credits
- ✅ You have 3-4 hours available for focused work
- ✅ You're excited about AI-powered summarization
- ✅ You want to see GPT-4 extract decisions from conversations

**Red Lights (Skip/defer it!):**
- ❌ PR#14 not complete (HARD DEPENDENCY)
- ❌ No OpenAI API account or credits
- ❌ Less than 3 hours available (can't finish in one session)
- ❌ Not interested in AI features right now
- ❌ Concerned about API costs (~$0.06/summary)

**Decision Aid:**
- If GREEN LIGHTS > RED LIGHTS → **Build it!** This is a high-value, user-facing AI feature.
- If uncertain about PR#14 status → Check Firebase Console (Functions tab) for `processAI`
- If uncertain about costs → Start with manual trigger (user controls frequency)
- If tight on time → PR#15 (Calendar Extraction) is simpler, start there

---

## Prerequisites (5 minutes)

### Required
- [ ] **PR#14 COMPLETE** (Cloud Functions deployed, OpenAI configured)
  - Verify: `firebase functions:list` shows `processAI`
  - Verify: OpenAI API key set in Firebase config
  - Verify: Test button in ChatListView works
- [ ] **Firebase Blaze Plan** (pay-as-you-go for Cloud Functions)
  - Required for Cloud Functions (free tier: 2M invocations/month)
- [ ] **OpenAI API Account** with credits ($5+ recommended)
  - Sign up: https://platform.openai.com/signup
  - Get API key: https://platform.openai.com/api-keys
  - Check usage: https://platform.openai.com/usage
- [ ] **iOS Project** builds successfully (0 errors)
- [ ] **Git Branch** ready: `main` or `feature/pr15-calendar-extraction`

### Setup Commands
```bash
# 1. Verify Firebase CLI
firebase --version  # Should show 12.0.0+

# 2. Verify Firebase project
firebase projects:list  # Should show messageai-xxxxx

# 3. Verify Cloud Functions deployed
firebase functions:list  # Should show processAI(us-central1)

# 4. Verify OpenAI API key configured
firebase functions:config:get  # Should show openai.key

# 5. Create feature branch
git checkout main
git pull origin main
git checkout -b feature/pr16-decision-summarization
```

---

## Getting Started (First Hour)

### Step 1: Read Documentation (45 minutes)
- [ ] Read this quick start (10 min) ✓
- [ ] Read main specification (`PR16_DECISION_SUMMARIZATION.md`) - 35 min
  - Sections to focus on:
    - Overview (what we're building)
    - Technical Design (architecture)
    - Data Models (ConversationSummary, ActionItem)
    - Implementation Plan (6 phases)

### Step 2: Verify Prerequisites (15 minutes)
- [ ] Test Cloud Function:
  - Run iOS app
  - Tap purple CPU test button
  - Select "Test Decision Summary"
  - Verify response (should have placeholder data)
- [ ] Check OpenAI credits:
  - Visit platform.openai.com/usage
  - Verify $5+ available (10-15 summaries = ~$1)
- [ ] Confirm Firestore access:
  - Firebase Console → Firestore Database
  - Check /conversations collection has test data

### Step 3: Start Phase 1 (Cloud Function)
- [ ] Open `PR16_IMPLEMENTATION_CHECKLIST.md`
- [ ] Navigate to Phase 1: Cloud Function Implementation
- [ ] Follow step-by-step (1.1 → 1.2 → 1.3 → 1.4)
- [ ] Commit after each sub-phase

---

## Daily Progress Template

### Day 1 Goals (3-4 hours)
- [ ] **Phase 1:** Cloud Function implementation (60 min)
  - Create decisionSummary.ts (~150 lines)
  - Update processAI router (+20 lines)
  - Deploy to Firebase
  - Test with sample conversation
- [ ] **Phase 2:** iOS Models (45 min)
  - ConversationSummary struct
  - ActionItem struct with priority levels
  - Firestore conversion helpers
- [ ] **Phase 3:** AIService Extension (60 min)
  - summarizeConversation() method
  - 5-minute caching logic
  - Error handling and retries
  - Unit test with console logs

**Checkpoint:** Can generate summaries via AIService ✓

---

### Day 1 (continued) or Day 2
- [ ] **Phase 4:** ChatViewModel Integration (45 min)
  - Summary state management
  - requestSummary() method
  - Firestore persistence
  - Test state transitions
- [ ] **Phase 5:** UI Components (60 min)
  - DecisionSummaryCardView (~250 lines)
  - Collapsible sections with animations
  - Integrate into ChatView
  - Add "Summarize" toolbar button
- [ ] **Phase 6:** Integration Testing (30 min)
  - End-to-end test (tap → generate → display → dismiss)
  - Cache test (second request instant)
  - Empty conversation test
  - Firestore persistence verification

**Checkpoint:** Feature complete, all tests passing ✓

---

## Common Issues & Solutions

### Issue 1: "PR#14 not complete" Error
**Symptoms:** Cloud Function doesn't exist or returns 404  
**Cause:** PR#14 not fully deployed  
**Solution:**
```bash
cd functions
firebase deploy --only functions:processAI
firebase functions:list  # Verify deployment
```

---

### Issue 2: "OpenAI API Error: Invalid API Key"
**Symptoms:** Cloud Function returns 401 Unauthorized from OpenAI  
**Cause:** API key not configured or invalid  
**Solution:**
```bash
# Set OpenAI API key
firebase functions:config:set openai.key="sk-YOUR-API-KEY-HERE"

# Redeploy functions
firebase deploy --only functions:processAI
```

---

### Issue 3: "Request Timeout After 30 Seconds"
**Symptoms:** AIService throws timeout error  
**Cause:** GPT-4 slow response (cold start)  
**Solution:**
- This is expected on first request (cold start)
- Second request should be <1 second (cached)
- If persistent: Switch to gpt-3.5-turbo (faster, less accurate)
- Or increase timeout to 60 seconds in AIService

---

### Issue 4: "Summary is Empty or Low Quality"
**Symptoms:** Summary shows "No summary available" or generic text  
**Cause:** Conversation has no clear decisions/action items, or prompt needs tuning  
**Solution:**
- Test with conversations that have explicit decisions ("Let's do X")
- Add more context to GPT-4 prompt (examples of good summaries)
- Lower temperature (currently 0.3, try 0.1 for more consistent output)

---

### Issue 5: "Cache Not Working (Always Calls GPT-4)"
**Symptoms:** Every summary request takes 2-3 seconds  
**Cause:** Cache key mismatch or TTL expired  
**Solution:**
- Check console: Should see "✅ AIService: Using cached summary" on 2nd request
- Verify cache TTL: 300 seconds = 5 minutes
- If still broken: Clear summaryCache dictionary (app restart)

---

### Issue 6: "High OpenAI Costs"
**Symptoms:** OpenAI bill higher than expected  
**Cause:** Users requesting summaries too frequently  
**Solution:**
- Verify caching working (5-minute TTL)
- Check rate limiting (100 req/hour from PR#14)
- Add cost estimate in UI ("This will use 1 summary credit")
- Consider showing cached timestamp ("Summary from 3 minutes ago")

---

## Quick Reference

### Key Files

**Cloud Functions (Node.js):**
- `functions/src/ai/decisionSummary.ts` - GPT-4 summarization logic (~250 lines)
- `functions/src/ai/processAI.ts` - Router with decision_summary route (+20 lines)

**iOS Models (Swift):**
- `Models/ConversationSummary.swift` - Summary data structure (~150 lines)
- `Models/ActionItem.swift` - Action item with priority (~100 lines)

**iOS Services (Swift):**
- `Services/AIService.swift` - summarizeConversation() method (+120 lines)

**iOS ViewModels (Swift):**
- `ViewModels/ChatViewModel.swift` - Summary state management (+100 lines)

**iOS Views (SwiftUI):**
- `Views/Chat/DecisionSummaryCardView.swift` - Summary card UI (~250 lines)
- `Views/Chat/ChatView.swift` - Display summary card (+80 lines)

---

### Key Functions

**Cloud Function:**
```typescript
export async function summarizeConversation(
  conversationId: string,
  userId: string,
  openai: OpenAI
): Promise<SummaryResult>
```

**iOS AIService:**
```swift
func summarizeConversation(conversationId: String) async throws -> ConversationSummary
```

**iOS ChatViewModel:**
```swift
func requestSummary() async
func dismissSummary()
```

---

### Key Concepts

**Decision Summarization:**
- AI reads 50 messages in 2 seconds (GPT-4)
- Extracts 3 types of information:
  1. Decisions ("We decided to do X")
  2. Action Items ("Sarah will bring snacks by Friday")
  3. Key Points ("Important announcement", "Schedule change")
- User taps "Summarize" button (manual trigger)
- Summary displays as inline card at top of chat
- 5-minute cache (prevents duplicate API calls)

**GPT-4 Prompt Engineering:**
- System prompt: "You are helping busy parents..."
- User prompt: Conversation text + structured JSON format
- Temperature: 0.3 (consistent output)
- Max tokens: 500 (concise summaries)
- Response format: JSON object (decisions, actionItems, keyPoints)

**Caching Strategy:**
- Cache key: conversationId
- TTL: 5 minutes (300 seconds)
- Cache hit: Return cached ConversationSummary (instant)
- Cache miss: Call Cloud Function → OpenAI → cache result

---

### Useful Commands

**Firebase:**
```bash
# Deploy Cloud Functions
firebase deploy --only functions:processAI

# Check deployment
firebase functions:list

# View logs (live)
firebase functions:log --only processAI

# Check OpenAI API key
firebase functions:config:get openai.key
```

**Git:**
```bash
# Create branch
git checkout -b feature/pr16-decision-summarization

# Commit after each phase
git add .
git commit -m "feat(ai): Phase 1 - Cloud Function implementation"

# Push to GitHub
git push origin feature/pr16-decision-summarization
```

**Testing:**
```bash
# Run iOS app
open messAI.xcodeproj
# Cmd+R to run

# Watch console logs
# Look for: "📊 AIService: Requesting summary..."
```

---

## Success Metrics

### You'll Know It's Working When:

**Functional Success:**
- [ ] Tap "Summarize" button → Loading spinner appears
- [ ] 2-3 seconds later → Summary card appears at top
- [ ] Summary shows:
  - Main summary text (2-3 sentences)
  - Decisions section (if any)
  - Action Items section with priority emojis (🔴/🟡/⚪)
  - Key Points section (if any)
- [ ] Tap sections → Smooth collapse/expand animation
- [ ] Tap "x" → Card dismisses
- [ ] Tap "Summarize" again → Instant (cached)

**Performance Success:**
- [ ] First request: <5 seconds (cold start)
- [ ] Cached request: <1 second (instant)
- [ ] Console shows: "✅ AIService: Using cached summary"

**Cost Success:**
- [ ] Each summary costs ~$0.06 (50 messages)
- [ ] Caching reduces API calls by 60%+
- [ ] Rate limiting prevents abuse (100 req/hour)

---

## Help & Support

### Stuck on Prerequisites?
- **Problem:** Can't deploy Cloud Functions  
  **Solution:** Check Firebase Blaze plan enabled (billing required for Functions)

- **Problem:** OpenAI API key not working  
  **Solution:** Regenerate key at platform.openai.com/api-keys, set with `firebase functions:config:set`

### Stuck on Implementation?
1. Check main spec (`PR16_DECISION_SUMMARIZATION.md`) for detailed design
2. Follow checklist (`PR16_IMPLEMENTATION_CHECKLIST.md`) step-by-step
3. Review similar PR#15 (Calendar Extraction) for patterns
4. Check console logs for error messages
5. Test each phase before moving to next

### Want to Skip Some Features?
- **Can skip:** Firestore persistence (Phase 4.1) - Summary still works in-memory
- **Can skip:** Collapsible sections (Phase 5.1) - Just show all sections always
- **Cannot skip:** Cloud Function (Phase 1), Models (Phase 2), AIService (Phase 3), ChatViewModel (Phase 4), UI (Phase 5)

### Running Out of Time?
**Priority order:**
1. Phase 1 (Cloud Function) - **CRITICAL**
2. Phase 2 (Models) - **CRITICAL**
3. Phase 3 (AIService) - **CRITICAL**
4. Phase 4 (ChatViewModel) - **CRITICAL**
5. Phase 5 (UI) - **HIGH** (but can use simplified version)
6. Phase 6 (Testing) - **MEDIUM** (but strongly recommended)

**Minimum Viable:** Phases 1-4 = Basic functionality (no UI yet)

---

## Motivation

### You've Got This! 💪

**What You've Already Built:**
- ✅ PR#14: Complete AI infrastructure (Cloud Functions + OpenAI)
- ✅ 13 PRs completed (core messaging working perfectly)
- ✅ 31+ hours of focused development time

**What This Feature Adds:**
- 🎯 **First high-value AI feature** (directly saves user time)
- 🎯 **Viral potential** ("This app read 50 messages in 2 seconds!")
- 🎯 **Differentiator** (WhatsApp/iMessage don't have this)
- 🎯 **Foundation for PR#20** (Multi-Step Event Planning Agent)

**Why This Matters:**
- Busy parents will LOVE this feature (saves 10-15 min/day)
- Shows off GPT-4 capabilities in practical way
- Sets up for advanced agent features (PR#20)
- Demonstrates you can build production AI features

---

## Next Steps

**When Ready:**
1. Run prerequisites checklist (5 min)
2. Read main spec (`PR16_DECISION_SUMMARIZATION.md`) - 35 min
3. Open implementation checklist (`PR16_IMPLEMENTATION_CHECKLIST.md`)
4. Start Phase 1: Cloud Function implementation
5. Commit early and often (after each sub-phase)
6. Test after each phase (catch bugs early)
7. Celebrate when complete! 🎉

**Status:** 📋 Ready to build! 🚀

**Estimated Time:** 3-4 hours (based on PR#15 experience)

**Expected Result:** AI-powered decision summaries working end-to-end!

---

*"The best time to build AI features was yesterday. The second best time is now."*

**Let's build this! 🔥**


