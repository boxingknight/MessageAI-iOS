# PR #18: RSVP Tracking - Quick Start Guide

**Status**: 📋 PLANNED (Documentation Complete)  
**Ready to Build**: YES  
**Dependencies Met**: PR#14 ✅, PR#15 ✅

---

## TL;DR (30 seconds)

**What**: AI-powered RSVP tracking that automatically detects yes/no/maybe responses in group chats and shows "5 of 12 confirmed" summaries

**Why**: Busy parents waste 10+ minutes manually tracking who's coming to events via spreadsheets. This automates it.

**Time**: 3-4 hours estimated

**Complexity**: HIGH (Cloud Function + GPT-4 + iOS UI)

**Value**: HIGH (directly saves time, reduces stress, differentiator)

---

## Decision Framework (2 minutes)

### Should You Build This?

**🟢 Build it if:**
- ✅ You have PR#14 (Cloud Functions) and PR#15 (Calendar Extraction) complete
- ✅ You want to maximize project value (this is 4th of 5 required AI features)
- ✅ You have 3-4 hours available for focused work
- ✅ You're comfortable with TypeScript (Cloud Functions) and SwiftUI
- ✅ You want a high-impact feature (saves 10+ min/event)

**🔴 Skip it if:**
- ❌ PR#14 or PR#15 not complete (HARD DEPENDENCY)
- ❌ Time-constrained (<3 hours available)
- ❌ Need to finish PR#17 (Priority Highlighting) first
- ❌ Want simpler features first (PR#17 is easier)

**🟡 Defer it if:**
- You're building PRs in sequence (this is #18, consider doing #17 first)
- You want to batch-test AI features (implement #17, #18, #19 together)
- You're debugging PR#15 or PR#16 issues

### Decision Aid

**High ROI**: This feature delivers immediate, visible value. Users will love the "5 of 12 confirmed" summary. Great for demos.

**Medium Difficulty**: Requires Cloud Functions (TypeScript), iOS models (Swift), and UI (SwiftUI). Manageable if you've completed PR#15.

**Recommendation**: Build after completing PR#15 (Calendar Extraction). These features work great together—events get RSVPs automatically tracked.

---

## Prerequisites (5 minutes)

### HARD Requirements

- [x] **PR #14 COMPLETE**: Cloud Functions deployed and working
  - Test: Can call `processAI` function from iOS
  - Location: `functions/src/ai/processAI.ts` exists
  - Verify: Run test button in ChatListView

- [x] **PR #15 COMPLETE**: Calendar Extraction working
  - Test: Can extract "Pizza party Friday 6pm" from message
  - Location: `Models/CalendarEvent.swift` exists
  - Verify: Calendar cards display in chat

- [ ] **OpenAI API Key**: Configured in Cloud Functions
  ```bash
  firebase functions:config:get
  # Should show: openai.key="sk-xxxxx"
  ```

- [ ] **Firebase Billing**: Blaze plan enabled (Cloud Functions)
  - Check: Firebase Console → Settings → Usage and Billing
  - Note: Free tier sufficient for testing (2M calls/month)

- [ ] **Firestore Composite Index**: Will auto-create on first query
  - Note: May take 5-10 minutes to build
  - Check: Firebase Console → Firestore → Indexes

### Soft Requirements

- [ ] **Group Chat**: At least 3 test users for realistic testing
- [ ] **Physical Device**: Recommended for testing (simulators work fine)
- [ ] **4+ Hours Available**: Allows for comfortable implementation + testing

### Knowledge Prerequisites

- **TypeScript**: Moderate (Cloud Functions, ~300 lines)
- **Swift**: Moderate (Models + ViewModels, ~400 lines)
- **SwiftUI**: Moderate (4 new views, ~600 lines)
- **Firestore**: Basic (subcollections, queries)
- **GPT-4**: Basic (function calling, prompts)

---

## Getting Started (First Hour)

### Step 1: Read Documentation (45 minutes)

- [ ] Read this Quick Start (10 min)
- [ ] Read `PR18_RSVP_TRACKING.md` (30 min) - Main specification
- [ ] Skim `PR18_IMPLEMENTATION_CHECKLIST.md` (5 min) - Task breakdown

**Goal**: Understand architecture, data flow, and key decisions.

**Key Sections to Focus On**:
- Technical Design → Decisions 1-4 (why hybrid approach, why subcollections)
- Data Model → RSVPResponse, RSVPSummary structures
- API Design → Cloud Function flow (keyword filter → GPT-4)
- Implementation Phases → 6 phases, 3-4 hours

### Step 2: Verify Prerequisites (10 minutes)

- [ ] Check Cloud Functions working
  ```bash
  firebase functions:list
  # Should see: processAI
  ```

- [ ] Check Calendar Extraction working
  - Open iOS app
  - Send "Pizza party Friday 6pm"
  - Verify calendar card appears

- [ ] Check OpenAI API key
  ```bash
  firebase functions:config:get
  ```

- [ ] Check Firebase billing
  - Firebase Console → Settings
  - Verify Blaze plan active

### Step 3: Create Branch (5 minutes)

```bash
cd /path/to/messAI
git checkout main
git pull origin main
git checkout -b feature/pr18-rsvp-tracking
```

**Verify**: `git status` shows clean working directory on new branch

### Step 4: Start Phase 1 (Remaining time)

- [ ] Open `PR18_IMPLEMENTATION_CHECKLIST.md`
- [ ] Start "Phase 1: Cloud Function" (1 hour)
- [ ] Create `functions/src/ai/rsvpTracking.ts`
- [ ] Follow checklist step-by-step

---

## Daily Progress Template

### Day 1 Goals (3-4 hours)

**Morning Session (1.5 hours)**:
- [ ] Phase 1: Cloud Function (1 hour)
  - Create rsvpTracking.ts
  - Implement keyword filter
  - Add GPT-4 integration
  - Test with sample messages
- [ ] Phase 2: iOS Models (45 min)
  - Create RSVPResponse.swift
  - Define RSVPStatus enum
  - Add Firestore conversion

**Checkpoint**: Cloud Function detects RSVPs, iOS models ready ✓

**Afternoon Session (1.5-2 hours)**:
- [ ] Phase 3: AIService Integration (45 min)
  - Add detectRSVP() method
  - Add fetchRSVPSummary() method
  - Test from iOS
- [ ] Phase 4: ChatViewModel Logic (30 min)
  - Add RSVP state management
  - Implement auto-detection
  - Add summary loading
- [ ] Phase 5: UI Components (1 hour)
  - Create RSVPSectionView
  - Create RSVPHeaderView
  - Integrate into CalendarCardView

**Checkpoint**: Full feature working end-to-end ✓

**Evening Session (30 min - Optional)**:
- [ ] Phase 6: Testing & Polish
  - Test with group chat
  - Test all RSVP statuses
  - Performance testing
  - Deploy to production

**End of Day**: RSVP tracking complete, deployed, tested! 🎉

---

## Common Issues & Solutions

### Issue 1: Cloud Function Returns 403 Forbidden

**Symptoms**: iOS gets permission denied error when calling detectRSVP

**Cause**: Cloud Function requires authentication, but user not logged in

**Solution**:
```swift
// In AIService.swift, ensure auth token is included
private func callFunction(data: [String: Any]) async throws -> [String: Any] {
    guard let user = Auth.auth().currentUser else {
        throw AIError.notAuthenticated
    }
    
    // Get ID token
    let idToken = try await user.getIDToken()
    
    // Include in request...
}
```

**Prevention**: Always check `Auth.auth().currentUser != nil` before AI calls

---

### Issue 2: "Detected false, confidence 0.0" for Every Message

**Symptoms**: No RSVPs detected, even for obvious "Yes!" messages

**Cause**: Keyword filter too strict, or OpenAI API key not configured

**Solution**:
```bash
# Check API key
firebase functions:config:get
# If missing, set it:
firebase functions:config:set openai.key="sk-xxxxx"
firebase deploy --only functions
```

**Test**: Send "Yes!" in group chat → Should detect with confidence >0.9

---

### Issue 3: RSVP Links to Wrong Event

**Symptoms**: RSVP appears under incorrect calendar event

**Cause**: Multiple events in conversation, AI chose wrong one

**Solution**: Improve context by passing more event details
```typescript
// In rsvpTracking.ts
const eventsContext = recentEvents.map(e => 
  `${e.id}: ${e.title} on ${e.date}`
).join(', ');
```

**Prevention**: Limit to 3 most recent events, use recency heuristic

---

### Issue 4: Firestore Index Missing Error

**Symptoms**: Console error: "The query requires an index"

**Cause**: First query to `/conversations/{id}/messages` with `aiMetadata.calendarEvents` filter

**Solution**: 
1. Check console logs for index creation link
2. Click link to auto-create index
3. Wait 5-10 minutes for index to build
4. Re-run query

**Prevention**: Create index proactively in `firebase/firestore.indexes.json`

---

### Issue 5: RSVPSectionView Not Appearing

**Symptoms**: Calendar card shows, but no RSVP section below

**Cause**: `viewModel.rsvpSummaries[eventId]` is nil

**Solution**:
```swift
// In ChatViewModel, after detecting RSVP
if result.detected, let eventId = result.eventId {
    Task {
        await loadRSVPSummary(eventId: eventId)
    }
}
```

**Test**: Check Firestore Console → `/events/{eventId}/rsvps` has documents

---

### Issue 6: "User name" Shows Instead of Real Name

**Symptoms**: RSVP list shows "User" for all participants

**Cause**: ChatViewModel passes placeholder "User" instead of actual display name

**Solution**:
```swift
// In detectRSVPIfNeeded()
let senderName = messages.first(where: { $0.senderId == message.senderId })?.senderName ?? "User"
```

**Better**: Fetch User document from Firestore for display name

---

## Quick Reference

### Key Files to Know

**Cloud Functions**:
- `functions/src/ai/rsvpTracking.ts` - RSVP detection logic (~300 lines)
- `functions/src/ai/processAI.ts` - Main router (add rsvp_detection case)

**iOS Models**:
- `Models/RSVPResponse.swift` - RSVPStatus enum, RSVPResponse, RSVPSummary structs (~180 lines)
- `Models/AIMetadata.swift` - Add rsvpResponse field (+30 lines)

**iOS Services**:
- `Services/AIService.swift` - detectRSVP(), fetchRSVPSummary() methods (+120 lines)

**iOS ViewModels**:
- `ViewModels/ChatViewModel.swift` - RSVP state, auto-detection logic (+90 lines)

**iOS Views**:
- `Views/Chat/RSVPSectionView.swift` - Main RSVP container (~220 lines)
- `Views/Chat/RSVPHeaderView.swift` - Summary header (~120 lines)
- `Views/Chat/RSVPDetailView.swift` - Participant list (~180 lines)
- `Views/Chat/RSVPListItemView.swift` - Individual row (~90 lines)
- `Views/Chat/CalendarCardView.swift` - Integration (+50 lines)

### Key Functions

**Cloud Function**:
```typescript
export async function detectRSVP(
  data: DetectRSVPRequest,
  context: CallableContext
): Promise<DetectRSVPResponse>
```

**iOS AIService**:
```swift
func detectRSVP(
  conversationId: String,
  messageId: String,
  messageText: String,
  senderId: String,
  senderName: String,
  recentEventIds: [String]
) async throws -> RSVPDetectionResult

func fetchRSVPSummary(eventId: String) async throws -> RSVPSummary
```

**iOS ChatViewModel**:
```swift
func detectRSVPIfNeeded(for message: Message)
func loadRSVPSummary(eventId: String) async
func refreshAllRSVPSummaries() async
```

### Key Concepts

**Hybrid Detection**: Keyword filter (fast, free) → GPT-4 (accurate, paid)
- 80% of messages filtered out by keywords (skip GPT-4)
- 20% go to GPT-4 for context analysis
- Result: 90% accuracy at <$0.003/detection

**Event Linking**: AI links RSVP to most recent event
- Fetches last 5 messages with calendar events
- Passes event IDs to GPT-4 as context
- GPT-4 chooses best match (90%+ accuracy)

**Firestore Structure**: Subcollections for scalability
```
/events/{eventId}/rsvps/{userId}
  - status: "yes"|"no"|"maybe"
  - confidence: 0.0-1.0
  - detectedAt: Timestamp
```

**UI Pattern**: Collapsible section below calendar card
- Collapsed: Shows "5 of 12 confirmed" summary
- Expanded: Shows full participant list grouped by status
- Smooth spring animation (0.3s duration)

### Useful Commands

**Deploy Cloud Functions**:
```bash
cd functions
npm run build
firebase deploy --only functions
```

**Check Function Logs**:
```bash
firebase functions:log --only processAI
```

**Test RSVP Detection**:
```bash
# From iOS console (Debug View)
let result = try await aiService.detectRSVP(
  conversationId: "test",
  messageId: "msg123",
  messageText: "Yes!",
  senderId: "user1",
  senderName: "Alice",
  recentEventIds: ["event1"]
)
print("Detected: \(result.detected), Status: \(result.status?.rawValue ?? "nil")")
```

---

## Success Metrics

### You'll Know It's Working When:

**Phase 1 Complete**:
- [ ] Cloud Function responds with `{ detected: true, status: "yes", confidence: 0.95 }` for "Yes!"
- [ ] Firestore `/events/{eventId}/rsvps/{userId}` document created

**Phase 2 Complete**:
- [ ] RSVPResponse.swift compiles with zero errors
- [ ] Firestore round-trip preserves all fields

**Phase 3 Complete**:
- [ ] iOS can call `detectRSVP()` and get valid result
- [ ] Second identical call uses cache (faster)

**Phase 4 Complete**:
- [ ] New group message triggers RSVP detection
- [ ] RSVP summary loads and displays

**Phase 5 Complete**:
- [ ] RSVP section appears below calendar card
- [ ] Expand/collapse works smoothly
- [ ] Participant list grouped by status

**Phase 6 Complete**:
- [ ] All test scenarios pass (yes/no/maybe detection)
- [ ] Detection <2s warm, <5s cold
- [ ] No crashes or errors
- [ ] Deployed to production

### Performance Targets

- **Detection latency**: <2s (warm), <5s (cold start)
- **RSVP summary load**: <1s for 50 participants
- **Keyword filter**: >80% messages skip GPT-4
- **UI responsiveness**: 60fps animations

### Quality Gates

- **Accuracy**: >85% on test set (20 real messages)
- **False positive**: <5% (don't detect RSVP in non-RSVP)
- **Event linking**: >90% correct event
- **Zero critical bugs**: No crashes, no data loss

---

## Testing Checklist

### Basic Functionality

- [ ] Send "Yes!" → Detects as yes (confidence >0.9)
- [ ] Send "Can't make it" → Detects as no (confidence >0.9)
- [ ] Send "Maybe" → Detects as maybe (confidence >0.8)
- [ ] Send "What time?" → Not detected (confidence 0.0)
- [ ] RSVP section shows "1 of 3 confirmed"
- [ ] Expand section → See participant name
- [ ] Second RSVP → Updates to "2 of 3 confirmed"

### Edge Cases

- [ ] Ambiguous "I'll try" → Maybe or not detected
- [ ] Multiple events → Links to correct event
- [ ] No events → Handles gracefully (no crash)
- [ ] Emoji "👍" → Not detected for MVP (text only)

### Performance

- [ ] Detection <2s (warm) - Check console logs
- [ ] Detection <5s (cold start) - First call after deploy
- [ ] RSVP load <1s (50 participants) - Check with timer
- [ ] UI smooth 60fps - Watch animations

### Production Ready

- [ ] Works on physical device
- [ ] Works with real user accounts
- [ ] Firestore security rules enforced
- [ ] No console errors or warnings
- [ ] Cost monitoring (check OpenAI usage)

---

## Troubleshooting Decision Tree

```
RSVP not detected?
├─ Check keyword filter
│  └─ Message contains "yes", "no", "maybe"?
│     ├─ No → Expected (filtered out)
│     └─ Yes → Check GPT-4 call
│        └─ OpenAI API key configured?
│           ├─ No → Configure and redeploy
│           └─ Yes → Check logs for errors
│
RSVP links to wrong event?
├─ Check recent events list
│  └─ Multiple events in last 10 messages?
│     ├─ No → Should link correctly
│     └─ Yes → AI choosing best match (90% accurate)
│
RSVP section not showing?
├─ Check viewModel.rsvpSummaries
│  └─ Is summary loaded for event ID?
│     ├─ No → Call loadRSVPSummary()
│     └─ Yes → Check CalendarCardView integration
│
Performance slow (>5s)?
├─ Check network connection
│  └─ WiFi or 4G?
│     ├─ 3G/Edge → Expected (slow network)
│     └─ WiFi → Check Cloud Function logs
│        └─ Cold start? (first call after deploy)
│           ├─ Yes → Expected (<5s acceptable)
│           └─ No → Investigate Firestore query
```

---

## Motivation & Rewards

### Why This Feature Matters

**User Value**:
- Saves 10+ minutes per event organized
- Reduces stress ("Did everyone respond?")
- Prevents miscommunication ("I thought you said yes")
- Professional appearance (organized parent = impressed other parents)

**Business Value**:
- **Differentiation**: Feature not in WhatsApp/iMessage
- **Viral potential**: Users will share screenshots
- **Engagement**: Users check app to see RSVP status
- **Foundation**: Enables PR#20 (Event Planning Agent)

### What You'll Learn

- **GPT-4 Function Calling**: Structured output, reliable extraction
- **Hybrid Optimization**: Keyword filter + AI for cost/accuracy balance
- **Firestore Subcollections**: Scalable data modeling
- **SwiftUI Animations**: Spring animations, smooth expand/collapse
- **End-to-End AI**: Cloud → Mobile → UI complete integration

### You've Got This! 💪

**If you built PR#15 (Calendar Extraction)**, you already know:
- Cloud Functions with GPT-4 ✓
- Swift data models with Firestore ✓
- SwiftUI card components ✓
- AI integration patterns ✓

**PR#18 is similar**:
- Same Cloud Function structure (keyword filter → GPT-4)
- Similar data models (RSVPResponse vs CalendarEvent)
- Similar UI pattern (collapsible card)
- Same AIService integration

**The difference**: PR#18 adds subcollections (scalability) and list UI (participant display). You've got the foundation!

---

## Next Steps

### When Ready to Start

1. **☕ Get coffee** (this will take 3-4 hours)
2. **📖 Read main spec** `PR18_RSVP_TRACKING.md` (30 min)
3. **✅ Check prerequisites** (PR#14, PR#15 complete)
4. **🌿 Create branch** `feature/pr18-rsvp-tracking`
5. **📋 Open checklist** `PR18_IMPLEMENTATION_CHECKLIST.md`
6. **🚀 Start Phase 1** (Cloud Function)

### After Completion

1. **🎉 Celebrate!** (4th of 5 AI features done!)
2. **📝 Write complete summary** `PR18_COMPLETE_SUMMARY.md`
3. **🔄 Update PR_Party README** (mark PR#18 complete)
4. **💾 Commit & push** `feat(pr18): RSVP tracking complete`
5. **🎯 Choose next**: PR#17 (Priority) or PR#19 (Deadlines)

---

## Quick Decision: Build This Now?

**✅ YES, if:**
- PR#14 + PR#15 complete
- 3-4 hours available
- Want high-impact feature
- Comfortable with TypeScript + SwiftUI

**❌ NO, if:**
- Missing prerequisites
- Time-constrained (<3h)
- Prefer easier PR#17 first
- Need to debug previous PRs

**🤔 MAYBE, if:**
- Want to batch AI features (do #17, #18, #19 together)
- Want to see calendar + RSVP working together
- Excited about "5 of 12 confirmed" feature

---

**Status**: 📋 READY TO BUILD  
**Recommendation**: BUILD IT! (High value, manageable complexity, great demo feature)  
**Mood**: 🚀 Let's track some RSVPs!

---

*Last Updated: October 22, 2025*  
*Next Step: Read main spec, then start Phase 1!*

