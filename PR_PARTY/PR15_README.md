# PR#15: Calendar Extraction - Quick Start Guide

**Branch:** `feature/pr15-calendar-extraction`  
**Time:** 3-4 hours  
**Complexity:** MEDIUM  
**Status:** 📋 READY TO BUILD

---

## TL;DR (30 seconds)

**What:** AI-powered calendar event extraction from messages using GPT-4. Messages like "Soccer practice Thursday at 4pm" automatically become calendar cards with one-tap confirmation to add to iOS Calendar.

**Why:** First AI feature users see. Saves busy parents 5-10 minutes/day of manually tracking dates/times buried in group chats.

**Time:** 3-4 hours (Cloud Function + iOS models + UI + integration)

**Complexity:** MEDIUM (GPT-4 integration, EventKit calendar access, SwiftUI calendar cards)

**Dependencies:** 🔴 **PR#14 MUST BE COMPLETE** (Cloud Functions base infrastructure)

---

## Decision Framework (2 minutes)

### Should You Build This Now?

**✅ Build it if:**
- PR#14 (Cloud Functions Setup) is 100% complete and deployed
- You have 3-4 uninterrupted hours available
- OpenAI API key is ready (get from platform.openai.com)
- You want to see the first visible AI feature working
- You're excited to integrate GPT-4 with iOS Calendar

**❌ Skip it if:**
- PR#14 is not complete (HARD BLOCKER)
- Time-constrained (<3 hours available)
- OpenAI API costs are a concern (~ $0.02 per extraction)
- Want to build other AI features first (PR#16-19 don't depend on this)

**🟡 Defer it if:**
- Working on MVP core features (this is post-MVP)
- Need to prioritize other AI features first
- Testing infrastructure not ready

### Decision Aid

**This is the FIRST AI feature users will see.** It sets expectations for AI quality and usefulness. If you build it well, users will trust subsequent AI features. If rushed or buggy, it damages AI credibility.

**Recommendation:** Build it if PR#14 is solid and you have time to do it right. Otherwise, defer and build other features first.

---

## Prerequisites (5 minutes)

### Required (Hard Dependencies)

- [x] **PR#14 Complete** - Cloud Functions infrastructure deployed
  - Verify: `functions/src/index.ts` exports `processAI`
  - Verify: `functions/src/middleware/auth.ts` exists
  - Verify: `Services/AIService.swift` exists with base methods
  - Verify: OpenAI API key configured: `firebase functions:config:get openai.key`
  - Verify: Functions deployed: Check Firebase Console > Functions

- [x] **OpenAI API Account**
  - Create account: https://platform.openai.com
  - Get API key: https://platform.openai.com/api-keys
  - Add payment method (required for GPT-4 access)
  - Budget: ~$5-10 for development testing
  - Production: ~$3-6/month/user at 10 extractions/day

- [x] **Firebase Blaze Plan**
  - Functions require pay-as-you-go
  - Free tier: 2M invocations/month (generous)
  - Cost: $0.40 per million after free tier
  - OpenAI calls: $0.02 per extraction (GPT-4)

- [x] **iOS Development Environment**
  - Xcode 15+ installed
  - iOS 16+ simulator or physical device
  - messAI project opens without errors
  - All previous PRs (1-14) merged and building

### Recommended

- [ ] Apple Developer Account (for TestFlight eventually)
- [ ] Physical iPhone (for calendar permission testing)
- [ ] Firebase project with active users (for real message testing)
- [ ] 3+ hours uninterrupted time

### Knowledge Prerequisites

- **Swift/SwiftUI:** Comfortable with models, async/await, @Published
- **Cloud Functions:** Basic TypeScript/Node.js understanding
- **EventKit:** Nice to have but not required (code provided)
- **OpenAI API:** No prior experience needed (we provide prompts)

---

## Setup Commands (5 minutes)

```bash
# 1. Navigate to project
cd /Users/ijaramil/Documents/GauntletAI/Week2/messAI

# 2. Ensure main is up to date
git checkout main
git pull origin main

# 3. Create feature branch
git checkout -b feature/pr15-calendar-extraction

# 4. Verify PR#14 is complete
# Check that these files exist:
ls functions/src/ai/processAI.ts
ls functions/src/middleware/auth.ts
ls messAI/Services/AIService.swift
ls messAI/Models/AIMetadata.swift

# 5. Verify OpenAI API key is configured
cd functions
firebase functions:config:get openai.key
# Should output: "sk-..." (your key)

# 6. Install any missing dependencies
npm install

# 7. Build functions to verify setup
npm run build
# Should compile without errors

# 8. Return to project root
cd ..

# 9. Open Xcode project
open messAI.xcodeproj

# Ready to build! ✅
```

---

## Getting Started (First Hour)

### Step 1: Read Documentation (45 minutes)

**Primary Reading:**
1. **This quick start** (10 minutes) - Overview and context
2. **`PR15_CALENDAR_EXTRACTION.md`** (30 minutes) - Full technical specification
   - Architecture diagrams
   - Data models
   - Design decisions
   - Risk assessment
3. **`PR15_IMPLEMENTATION_CHECKLIST.md`** (5 minutes) - Skim phases

**Key Sections to Focus On:**
- "Architecture Overview" - Understand the data flow
- "Key Design Decisions" - Why we made specific choices
- "Data Models" - CalendarEvent structure
- "Implementation Plan" - What files you'll create/modify

### Step 2: Verify Prerequisites (10 minutes)

Run this verification script:
```bash
# Check PR#14 completeness
echo "Checking PR#14 files..."
[ -f "functions/src/ai/processAI.ts" ] && echo "✅ processAI.ts exists" || echo "❌ processAI.ts missing"
[ -f "functions/src/middleware/auth.ts" ] && echo "✅ auth.ts exists" || echo "❌ auth.ts missing"
[ -f "messAI/Services/AIService.swift" ] && echo "✅ AIService.swift exists" || echo "❌ AIService.swift missing"

# Check OpenAI API key
echo "Checking OpenAI API key..."
cd functions
firebase functions:config:get openai.key > /dev/null 2>&1 && echo "✅ API key configured" || echo "❌ API key missing"
cd ..

# Check functions are deployed
echo "Checking deployed functions..."
echo "Visit: https://console.firebase.google.com/project/YOUR_PROJECT_ID/functions"
echo "You should see: processAI (us-central1)"

# All checks passed? Ready to start!
```

### Step 3: Start Phase 1 (5 minutes)

Open the implementation checklist:
```bash
# In your editor/IDE
open PR_PARTY/PR15_IMPLEMENTATION_CHECKLIST.md
```

Jump to **Phase 1: Cloud Function - Calendar Extraction Logic**

Begin with Step 1.1: Create Calendar Extraction Function

---

## Implementation Phases Overview

### Phase 1: Cloud Function (1 hour)
**What:** Create `calendarExtraction.ts` with GPT-4 integration  
**Output:** Cloud Function that extracts structured calendar data from message text  
**Test:** Deploy and test via curl  
**Checkpoint:** Function returns array of CalendarEvent objects

### Phase 2: iOS Models (30 minutes)
**What:** Create `CalendarEvent.swift` model + update `AIMetadata`  
**Output:** Swift models for calendar data  
**Test:** Build project, verify no errors  
**Checkpoint:** CalendarEvent can convert to EKEvent for iOS Calendar

### Phase 3: iOS AIService (30 minutes)
**What:** Add `extractCalendarEvents()` method to AIService  
**Output:** iOS can call Cloud Function and get structured calendar data  
**Test:** Call from ChatViewModel (Phase 5)  
**Checkpoint:** Method returns [CalendarEvent] from API

### Phase 4: Calendar Card UI (45 minutes)
**What:** Create `CalendarCardView.swift` - SwiftUI card with confirmation  
**Output:** Beautiful calendar event card with "Add to Calendar" button  
**Test:** SwiftUI preview in Xcode canvas  
**Checkpoint:** Card displays event details and handles confirmation

### Phase 5: ChatViewModel Integration (30 minutes)
**What:** Add extraction methods to ChatViewModel  
**Output:** Chat can process messages and show calendar cards  
**Test:** Long-press message → extract → card appears  
**Checkpoint:** Full extraction flow works

### Phase 6: ChatView UI Integration (30 minutes)
**What:** Display calendar cards below messages  
**Output:** Calendar cards appear in chat after extraction  
**Test:** End-to-end flow in simulator  
**Checkpoint:** Messages show calendar cards, tap "Add" → iOS Calendar

### Phase 7: Testing (45 minutes)
**What:** Comprehensive testing of all scenarios  
**Output:** Verified feature works in all cases  
**Test:** 6 integration tests + edge cases  
**Checkpoint:** All tests pass, ready for production

### Phase 8: Documentation (15 minutes)
**What:** Update memory bank, PR_PARTY README  
**Output:** Documentation reflects completion  
**Commit:** Final commit and push  
**Checkpoint:** PR#15 complete! 🎉

---

## Daily Progress Template

### Day 1: Implementation (3-4 hours)

**Morning Goals (1.5-2h)**
- [ ] Phase 1: Cloud Function complete (1h)
- [ ] Phase 2: iOS Models complete (30min)
- [ ] Phase 3: iOS AIService complete (30min)

**Checkpoint:** Can call Cloud Function from iOS and get CalendarEvent data ✓

**Afternoon Goals (1.5-2h)**
- [ ] Phase 4: Calendar Card UI complete (45min)
- [ ] Phase 5: ChatViewModel integration (30min)
- [ ] Phase 6: ChatView UI integration (30min)

**Checkpoint:** Full extraction flow works end-to-end ✓

**Testing & Wrap-up (45min-1h)**
- [ ] Phase 7: Testing complete (45min)
- [ ] Phase 8: Documentation updated (15min)

**End of Day:** PR#15 complete, merged to main! 🎉

---

## Common Issues & Solutions

### Issue 1: "PR#14 not complete" Error

**Symptoms:**
- Files missing: `processAI.ts`, `auth.ts`, `AIService.swift`
- Build errors in functions or iOS
- Cannot call AI endpoints

**Cause:** PR#14 (Cloud Functions Setup) not finished

**Solution:**
1. **STOP** - Do not proceed with PR#15
2. Complete PR#14 first (2-3 hours)
3. Verify all PR#14 files exist and functions are deployed
4. Return to PR#15 only after PR#14 is 100% complete

### Issue 2: OpenAI API Key Not Configured

**Symptoms:**
```
Error: OpenAI API key not found
Failed to call OpenAI API
```

**Cause:** API key not set in Firebase Functions config

**Solution:**
```bash
cd functions
firebase functions:config:set openai.key="sk-YOUR-API-KEY-HERE"
firebase deploy --only functions
```

### Issue 3: Calendar Permission Denied

**Symptoms:**
- "Add to Calendar" button → error
- Alert: "Calendar access denied"

**Cause:** Missing NSCalendarsUsageDescription in Info.plist

**Solution:**
1. Open `messAI/Info.plist`
2. Add key: `Privacy - Calendars Usage Description`
3. Value: `MessageAI needs calendar access to add detected events from your conversations.`
4. Rebuild app

### Issue 4: Calendar Card Not Appearing

**Symptoms:**
- Extract events works (logs show events)
- But no calendar card displays in chat

**Cause:** Message aiMetadata not updated or ChatView not rendering cards

**Solution:**
1. Check `ChatViewModel.extractCalendarEvents()` - verify it updates `messages[index].aiMetadata`
2. Check `ChatView` - verify it checks for `message.aiMetadata?.calendarEvents`
3. Add debug print:
```swift
if let events = message.aiMetadata?.calendarEvents {
    print("Showing \(events.count) calendar cards")
}
```

### Issue 5: Low Extraction Accuracy

**Symptoms:**
- Wrong dates extracted
- Events not detected
- Confidence scores consistently low

**Cause:** GPT-4 prompt needs tuning or context missing

**Solution:**
1. Check `calendarExtraction.ts` system prompt
2. Ensure `includeContext: true` for ambiguous messages
3. Test with more explicit messages first:
   - ✅ "Soccer practice Thursday at 4pm"
   - ✅ "Meeting tomorrow 2pm"
   - ❌ "Let's meet sometime" (too vague)
4. Tune confidence thresholds in prompt

### Issue 6: High API Costs

**Symptoms:**
- OpenAI bill unexpectedly high
- $10+ charges in first week

**Cause:** Over-extraction (processing every message automatically)

**Solution:**
1. **MVP approach:** Manual extraction only (user long-presses message)
2. Implement rate limiting (already in PR#14)
3. Add caching (don't re-process same message)
4. Monitor usage: https://platform.openai.com/usage
5. Consider GPT-3.5-turbo for cost reduction (~10x cheaper)

---

## Quick Reference

### Key Files Created

```
functions/src/ai/calendarExtraction.ts (~250 lines)
messAI/Models/CalendarEvent.swift (~120 lines)
messAI/Views/Chat/CalendarCardView.swift (~200 lines)
```

### Key Files Modified

```
functions/src/ai/processAI.ts (+20 lines) - Add calendar route
messAI/Models/AIMetadata.swift (+2 lines) - Add calendarEvents field
messAI/Services/AIService.swift (+80 lines) - Add extractCalendarEvents()
messAI/ViewModels/ChatViewModel.swift (+60 lines) - Add extraction methods
messAI/Views/Chat/ChatView.swift (+40 lines) - Display calendar cards
messAI/Info.plist (+2 lines) - Calendar permission
```

### Key Functions

**Cloud Function:**
```typescript
extractCalendarEvents(messageId, userId, includeContext): Promise<CalendarEvent[]>
```

**iOS Service:**
```swift
aiService.extractCalendarEvents(messageId: String, includeContext: Bool): async throws -> [CalendarEvent]
```

**iOS ViewModel:**
```swift
chatViewModel.extractCalendarEvents(for messageId: String): async
chatViewModel.confirmCalendarEvent(messageId: String, eventId: String): async
```

### Key Models

**CalendarEvent:**
```swift
struct CalendarEvent: Codable, Identifiable {
    let id: String
    let title: String
    let date: String  // "2025-10-24"
    let time: String?  // "16:00" or nil
    let isAllDay: Bool
    let location: String?
    let notes: String?
    let confidence: Double  // 0.0-1.0
    let extractedAt: Date
    
    func toEKEvent(eventStore: EKEventStore) -> EKEvent
}
```

### Useful Commands

```bash
# Build Cloud Functions
cd functions
npm run build

# Deploy Cloud Functions
firebase deploy --only functions

# Build iOS app
# In Xcode: Cmd+B

# Run iOS app
# In Xcode: Cmd+R

# View Firebase logs
firebase functions:log

# Check OpenAI usage
open https://platform.openai.com/usage
```

---

## Success Metrics

**You'll know it's working when:**
- [ ] User long-presses message with date/time
- [ ] "Extract Calendar Events" appears in context menu
- [ ] Tap → AI processes message (2-3 seconds)
- [ ] Calendar card appears below message with correct data
- [ ] Tap "Add to Calendar" → event added to iOS Calendar app
- [ ] Open iOS Calendar → event is there with correct date/time/title

**Performance Targets:**
- Extraction time: <2 seconds (warm), <5 seconds (cold start)
- Accuracy: >90% for explicit dates ("Thursday 4pm")
- Accuracy: >70% for relative dates ("tomorrow", "next week")
- Cost: ~$0.02 per extraction
- User satisfaction: "Wow, that actually worked!"

**Quality Targets:**
- Zero critical bugs in calendar extraction or iOS Calendar integration
- Calendar permission handling graceful (clear error if denied)
- Past events shown but not addable (visual indication)
- Low confidence events flagged (warning icon, <0.8 threshold)

---

## Testing Checklist (Quick)

### Before Claiming Complete

- [ ] **Test 1:** Message with explicit date/time → extracts correctly
- [ ] **Test 2:** Message with relative date ("tomorrow") → calculates correct date
- [ ] **Test 3:** All-day event ("School half day Friday") → isAllDay = true
- [ ] **Test 4:** Event with location → location field populated
- [ ] **Test 5:** Add to iOS Calendar → event appears in Calendar app
- [ ] **Test 6:** Past event → shows warning, no "Add" button
- [ ] **Test 7:** Low confidence event → warning icon visible
- [ ] **Test 8:** Non-event message → no cards appear (empty array)

### If All 8 Tests Pass → PR#15 Complete! 🎉

---

## Motivation & Context

### Why This Feature Matters

**User Pain Point:**
Sarah receives "Soccer practice Thursday at 4pm!" buried in a group chat with 50 other messages. She has to:
1. Read through all messages to find this
2. Remember the date/time
3. Open Calendar app
4. Manually create event
5. Hope she remembered correctly

**Total time:** 2-3 minutes per event × 5-10 events/day = **10-30 minutes/day**

**With Calendar Extraction:**
1. Message appears with calendar card below it
2. Sarah taps "Add to Calendar"
3. Done.

**Total time:** 5 seconds per event × 5-10 events/day = **~1 minute/day**

**Time saved:** 9-29 minutes/day = **3-10.5 hours/month!**

### What Makes This Special

- **First AI feature users see** - Sets expectations for AI quality
- **Immediate value** - Saves time on first use
- **Visual impact** - Calendar cards are beautiful and obvious
- **Foundation for future** - PR#18 (RSVP Tracking) builds on this

### Technical Achievement

- **GPT-4 integration** - Natural language understanding at scale
- **Structured outputs** - AI returns parseable JSON data
- **EventKit integration** - Native iOS Calendar access
- **Confidence scoring** - AI self-awareness of accuracy
- **Context-aware** - Uses conversation history for better extraction

This is a genuine AI-powered feature that solves a real problem. Build it well and users will love it! 💪📅

---

## Next Steps After Completion

### Immediate Next PRs

**PR#16: Decision Summarization** (3-4h)
- Summarize group decisions and action items
- "Group decided: Potluck on Saturday, bring appetizers"

**PR#17: Priority Highlighting** (2-3h)
- Detect urgent/important messages
- "Noah needs pickup at 2pm TODAY" → highlighted in red

**PR#18: RSVP Tracking** (3-4h)
- Track yes/no/maybe responses to events
- "5 of 12 parents confirmed for field trip"
- **Builds on PR#15** calendar extraction

**PR#19: Deadline Extraction** (3-4h)
- Extract and track deadlines
- "Permission slip due Wednesday"

**PR#20: Multi-Step Event Planning Agent** (5-6h) **+10 bonus!**
- Advanced conversational agent
- Multi-turn coordination for family events

### Related Features (Future)

- **Calendar View** (PR#21) - Dedicated view showing all extracted events
- **Recurring Events** (PR#22) - Detect "every Tuesday" patterns
- **Event Reminders** (PR#23) - Smart notifications before events
- **Smart Scheduling** (PR#24) - Suggest optimal times based on availability

---

## Resources

### Documentation
- Main Spec: `PR15_CALENDAR_EXTRACTION.md`
- Implementation Checklist: `PR15_IMPLEMENTATION_CHECKLIST.md`
- Testing Guide: `PR15_TESTING_GUIDE.md`
- Planning Summary: `PR15_PLANNING_SUMMARY.md`

### External Resources
- OpenAI Structured Outputs: https://platform.openai.com/docs/guides/structured-outputs
- EventKit Documentation: https://developer.apple.com/documentation/eventkit
- Firebase Cloud Functions: https://firebase.google.com/docs/functions
- SwiftUI Calendar Integration: https://developer.apple.com/documentation/swiftui

### Support
- Stuck? Check "Common Issues & Solutions" section above
- Still stuck? Review PR#14 documentation for Cloud Functions troubleshooting
- Need help? Search messAI repository issues or PR_PARTY docs

---

## Final Checklist Before Starting

- [ ] Read this entire quick start guide (15 minutes)
- [ ] PR#14 is 100% complete and deployed
- [ ] OpenAI API key is configured and working
- [ ] Firebase Blaze plan is active (for Cloud Functions)
- [ ] Have 3-4 uninterrupted hours available
- [ ] Xcode project opens and builds without errors
- [ ] Ready to see the first AI feature come to life! 🚀

---

**Ready? Let's build something amazing!** 💪📅✨

Open `PR15_IMPLEMENTATION_CHECKLIST.md` and start with Phase 1!

