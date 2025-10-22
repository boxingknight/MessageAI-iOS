# PR#14: Cloud Functions Setup & AI Service Base - Quick Start

---

## TL;DR (30 seconds)

**What:** Set up Firebase Cloud Functions backend with OpenAI GPT-4 integration to enable all 5 AI features for busy parents.

**Why:** Secure API key management (server-side only), rate limiting (prevent abuse), flexible architecture (easy to add features). This is the foundation—nothing else works without it.

**Time:** 2-3 hours estimated

**Complexity:** MEDIUM-HIGH (Cloud Functions setup, TypeScript, environment config, iOS integration)

**Status:** 📋 PLANNED (documentation complete, ready to implement!)

---

## Decision Framework (2 minutes)

### Should You Build This?

**Green Lights (Build it!):**
- ✅ You have 2-3 hours available this session
- ✅ OpenAI API account (or can create one in 5 min)
- ✅ Firebase billing enabled (Blaze plan)
- ✅ Core messaging complete (PRs 1-13)
- ✅ Want to build AI features (PRs 15-20)

**Red Lights (Skip/defer it!):**
- ❌ Time-constrained (<2 hours available)
- ❌ Can't get OpenAI API key
- ❌ Firebase billing disabled (free tier)
- ❌ Core messaging incomplete
- ❌ Not interested in AI features

**Decision Aid:** This is CRITICAL infrastructure. If you're building AI features (calendar extraction, RSVP tracking, etc.), you MUST do this first. Without PR #14, PRs #15-20 cannot be built.

**Can't be skipped if:** You want any AI functionality

---

## Prerequisites (5 minutes)

### Required
- [x] **Core Messaging Complete** - PRs 1-13 done ✅
- [ ] **Firebase Project Active** - messageai-95c8f ✅
- [ ] **Firebase Billing Enabled** - Blaze plan (pay-as-you-go)
  ```bash
  # Check at: https://console.firebase.google.com/project/messageai-95c8f/usage
  ```
- [ ] **OpenAI API Account** - Get key from https://platform.openai.com
  - [ ] Sign up (free, takes 2 minutes)
  - [ ] Add payment method ($5 minimum)
  - [ ] Create API key
  - [ ] Copy key (starts with `sk-proj-...`)
- [ ] **Firebase CLI Installed**
  ```bash
  npm install -g firebase-tools
  firebase --version  # Should show v12.0.0 or higher
  firebase login      # Log in to your account
  ```

### Setup Commands
```bash
# 1. Navigate to project
cd /Users/ijaramil/Documents/GauntletAI/Week2/messAI

# 2. Create branch
git checkout -b feature/pr14-cloud-functions

# 3. Initialize Cloud Functions (will do this in implementation)
# firebase init functions
```

---

## Getting Started (First Hour)

### Step 1: Read Documentation (45 minutes)
- [ ] Read this quick start (10 min)
- [ ] Read main specification: `PR14_CLOUD_FUNCTIONS_SETUP.md` (35 min)
  - Architecture decisions
  - Data model design
  - Implementation details
- [ ] Note any questions

### Step 2: Get OpenAI API Key (5 minutes)
- [ ] Go to https://platform.openai.com
- [ ] Sign up or log in
- [ ] Navigate to API Keys
- [ ] Create new key
- [ ] **Copy key immediately** (only shown once!)
- [ ] Store safely (will add to .env file)

### Step 3: Enable Firebase Billing (5 minutes)
- [ ] Open https://console.firebase.google.com/project/messageai-95c8f/overview
- [ ] Go to Usage & Billing
- [ ] Upgrade to Blaze plan
- [ ] Set budget alert ($50/month recommended)
- [ ] Verify billing enabled

### Step 4: Start Implementation (5 minutes)
- [ ] Open implementation checklist: `PR14_IMPLEMENTATION_CHECKLIST.md`
- [ ] Begin Phase 1: Cloud Functions Initialization
- [ ] Run `firebase init functions`

---

## Implementation Overview

### Phase 1: Cloud Functions Setup (30 min)
**Goal:** Get Cloud Functions project initialized with TypeScript

**Tasks:**
- Initialize Firebase Cloud Functions
- Install OpenAI SDK and dependencies
- Configure environment variables (.env file)
- Set Firebase config for production

**Checkpoint:** `npm run build` succeeds

---

### Phase 2: Middleware (45 min)
**Goal:** Implement authentication, rate limiting, validation

**Tasks:**
- Create auth middleware (require login)
- Create rate limit middleware (100 req/hour/user)
- Create validation middleware (check required fields)

**Checkpoint:** All middleware compiles without errors

---

### Phase 3: AI Router (60 min)
**Goal:** Create main AI function with feature routing

**Tasks:**
- Create 6 placeholder functions (one per AI feature)
- Implement main `processAI` function
- Add comprehensive error handling
- Add logging for debugging

**Checkpoint:** Can deploy to Firebase successfully

---

### Phase 4: iOS AIService (45 min)
**Goal:** Create Swift wrapper for Cloud Function calls

**Tasks:**
- Create AIMetadata model
- Update Message model with aiMetadata
- Implement AIService class with caching
- Add error mapping

**Checkpoint:** iOS app compiles without errors

---

### Phase 5: Deploy & Test (30 min)
**Goal:** Deploy and verify end-to-end

**Tasks:**
- Deploy Cloud Functions to Firebase
- Test from iOS app
- Verify authentication enforcement
- Verify rate limiting
- Check error handling

**Checkpoint:** Can successfully call AI from iOS app

---

## Daily Progress Template

### Day 1 Goals (2-3 hours)
- [ ] **Phase 1:** Cloud Functions initialized (30 min)
- [ ] **Phase 2:** Middleware implemented (45 min)
- [ ] **Phase 3:** AI router created (60 min)
- [ ] **Phase 4:** iOS AIService built (45 min)
- [ ] **Phase 5:** Deployed and tested (30 min)

**End of Day Checkpoint:** Can call Cloud Function from iOS app successfully

---

## Common Issues & Solutions

### Issue 1: "Firebase billing not enabled"
**Symptoms:** Deployment fails with billing error  
**Cause:** Still on Spark (free) plan  
**Solution:**
```bash
# 1. Go to Firebase Console
# 2. Navigate to Usage & Billing
# 3. Upgrade to Blaze plan
# 4. Set budget alert
# 5. Try deployment again
```

---

### Issue 2: "OpenAI API key not found"
**Symptoms:** Cloud Function fails with "API key missing"  
**Cause:** Environment variable not set correctly  
**Solution:**
```bash
# Verify .env file exists
cat functions/.env

# Should contain:
# OPENAI_API_KEY=sk-proj-your-key-here

# Set Firebase config
firebase functions:config:set openai.key="sk-proj-your-key-here"

# Verify
firebase functions:config:get

# Redeploy
firebase deploy --only functions
```

---

### Issue 3: "Rate limit exceeded" immediately
**Symptoms:** First AI call returns rate limit error  
**Cause:** Firestore counters not clearing properly  
**Solution:**
```bash
# Check Firestore console
# Delete documents in rateLimits collection
# Or wait 1 hour for counter to reset

# Alternatively, increase limit temporarily in code:
# functions/src/middleware/rateLimit.ts
# Change RATE_LIMIT_PER_HOUR to 1000 for testing
```

---

### Issue 4: "Function timed out"
**Symptoms:** iOS app waits 30 seconds then fails  
**Cause:** Cold start taking too long  
**Solution:**
```bash
# Check Firebase logs for actual error
firebase functions:log

# If OpenAI call is slow:
# - Check OpenAI API status
# - Try with shorter message
# - Increase timeout in processAI.ts:
#   timeoutSeconds: 60  # instead of 30
```

---

### Issue 5: "Unauthenticated" error from iOS
**Symptoms:** Cloud Function rejects iOS request  
**Cause:** User not logged in or auth token expired  
**Solution:**
```swift
// Verify user is logged in
if Auth.auth().currentUser == nil {
    print("❌ User not logged in")
    // Show login screen
}

// Get fresh token
let token = try await Auth.auth().currentUser?.getIDToken()
print("✅ Auth token:", token)
```

---

### Issue 6: TypeScript compilation errors
**Symptoms:** `npm run build` fails  
**Cause:** Missing type definitions or syntax errors  
**Solution:**
```bash
cd functions

# Install type definitions
npm install @types/node --save-dev

# Check for specific errors
npm run build

# Fix TypeScript errors shown in output
```

---

## Quick Reference

### Key Files Created
- `functions/src/ai/processAI.ts` - Main AI router
- `functions/src/middleware/auth.ts` - Authentication
- `functions/src/middleware/rateLimit.ts` - Rate limiting
- `functions/src/middleware/validation.ts` - Input validation
- `Services/AIService.swift` - iOS wrapper
- `Models/AIMetadata.swift` - AI result models

### Key Functions
- `processAI()` - Main Cloud Function (routes AI requests)
- `requireAuth()` - Middleware: check authentication
- `checkRateLimit()` - Middleware: enforce 100 req/hour
- `validateRequest()` - Middleware: check required fields
- `AIService.processMessage()` - iOS: call Cloud Function

### Key Concepts
- **Cloud Functions**: Serverless backend (runs on Firebase)
- **Rate Limiting**: Prevent abuse (100 requests/hour/user)
- **Middleware**: Reusable logic (auth, rate limit, validation)
- **Feature Router**: Route to appropriate AI function
- **Placeholder Functions**: Return dummy data until PRs #15-20

### Useful Commands
```bash
# Build TypeScript
cd functions && npm run build

# Deploy to Firebase
firebase deploy --only functions

# View logs
firebase functions:log

# Get Firebase config
firebase functions:config:get

# Set Firebase config
firebase functions:config:set key="value"
```

---

## Success Metrics

**You'll know it's working when:**
- [ ] Cloud Function shows as deployed in Firebase Console
- [ ] Can call `AIService.processMessage()` from iOS
- [ ] Request requires authentication (fails when logged out)
- [ ] Rate limiting works (101st request fails)
- [ ] Placeholder responses return with expected structure
- [ ] Firebase logs show "AI request received" and "AI request completed"
- [ ] No API keys visible in iOS app code

**Performance Targets:**
- Cold start: < 3 seconds (first call)
- Warm response: < 1 second (subsequent calls)
- Total iOS → Cloud → iOS: < 2 seconds
- Rate limit check: < 50ms

---

## Testing Your Implementation

### Quick Test (2 minutes)
```swift
// Add to ChatListView or any view
Button("Test AI Infrastructure") {
    Task {
        await testAI()
    }
}

func testAI() async {
    do {
        let result = try await AIService.shared.processMessage(
            "Soccer practice Thursday at 4pm",
            feature: .calendar
        )
        print("✅ AI Test Success:", result)
    } catch {
        print("❌ AI Test Failed:", error)
    }
}
```

### Expected Output
```
📤 AIService: Calling Cloud Function for calendar
✅ AIService: Received response from calendar
✅ AI Test Success: [
    "events": [],
    "message": "Calendar extraction not yet implemented (PR #15)",
    "processingTimeMs": 450,
    "modelUsed": "gpt-4",
    "processedAt": "2025-10-22T..."
]
```

### If It Fails
1. Check user is logged in
2. Check Firebase Console for errors
3. Check Firebase logs: `firebase functions:log`
4. Verify API key is set
5. Verify billing is enabled

---

## What Gets Built

### Cloud Functions (TypeScript)
- **Lines:** ~500 lines
- **Files:** 11 files
- **Features:** Auth, rate limiting, validation, 6 AI feature routers

### iOS (Swift)
- **Lines:** ~300 lines
- **Files:** 3 files (AIService, AIMetadata, Message update)
- **Features:** Type-safe wrapper, caching, error handling

### Total Implementation
- **Time:** 2-3 hours
- **Lines of Code:** ~800 lines
- **User-Visible Features:** 0 (pure infrastructure)
- **AI Features Enabled:** 6 (via placeholders)

---

## What Comes After

**Next PRs (each builds on this infrastructure):**

1. **PR #15: Calendar Extraction** (3-4h) 
   - Implement `extractCalendarDates()`
   - Detect dates/times in messages
   - Display events in UI

2. **PR #16: Decision Summarization** (3-4h)
   - Implement `summarizeDecisions()`
   - Summarize group chat decisions
   - Show summaries in UI

3. **PR #17: Priority Highlighting** (2-3h)
   - Implement `detectUrgency()`
   - Highlight urgent messages
   - Color-code by priority

4. **PR #18: RSVP Tracking** (3-4h)
   - Implement `extractRSVP()`
   - Track event responses
   - Show attendance lists

5. **PR #19: Deadline Extraction** (3-4h)
   - Implement `extractDeadlines()`
   - Extract deadlines from messages
   - Show deadline reminders

6. **PR #20: Event Planning Agent** (5-6h) **+10 BONUS!**
   - Implement `eventPlanningAgent()`
   - Multi-step conversational AI
   - Coordinate family events

---

## Motivation

**Why This Matters:**

This PR enables ALL AI features for busy parents. Without it:
- ❌ Can't extract calendar dates from messages
- ❌ Can't summarize group decisions
- ❌ Can't highlight urgent messages
- ❌ Can't track RSVPs
- ❌ Can't extract deadlines
- ❌ Can't build event planning agent

With it:
- ✅ Secure API key management (server-side only)
- ✅ Cost control (rate limiting prevents abuse)
- ✅ Flexible architecture (easy to add features)
- ✅ Professional infrastructure (production-ready)
- ✅ All AI features enabled (PRs #15-20 can proceed)

**Think of it as:** Building the foundation before the house. Not exciting, but absolutely necessary.

---

## Status

**Ready to build!** 🚀

**Next Step:** Open `PR14_IMPLEMENTATION_CHECKLIST.md` and start Phase 1.

---

*"The best infrastructure is invisible until you need it."*

**You've got this!** 💪

---

