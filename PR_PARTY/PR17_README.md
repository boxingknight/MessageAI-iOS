# PR#17: Priority Highlighting Feature - Quick Start Guide

**Status:** 📋 PLANNED (Ready to implement!)  
**Time:** 2-3 hours estimated  
**Complexity:** MEDIUM (Cloud Function + GPT-4 + UI enhancements)

---

## TL;DR (30 seconds)

**What:** AI automatically detects and visually highlights urgent messages (red borders, badges) so busy parents never miss critical information ("Pickup changed to 2pm TODAY").

**Why:** Parents receive 100+ messages/day and miss urgent info buried in casual chat. This feature prevents real-world problems (late pickups, missed deadlines).

**How:** Hybrid approach - keyword filter (fast, free) catches 80% as normal, GPT-4 (slow, paid) analyzes remaining 20% with context for accuracy.

**Result:** Red borders on critical messages, yellow on high priority, collapsible banner for urgent messages, global urgent messages tab.

**Time:** 2-3 hours (45 min Cloud Function, 15 min models, 20 min service, 60 min UI, 30 min testing)

---

## Decision Framework (2 minutes)

### Should You Build This Feature?

**Build it if:**
- ✅ You have 2-3 hours available
- ✅ PR#14 (Cloud Functions) is 100% complete
- ✅ PR#16 (Decision Summarization) complete or in progress (similar AI pattern)
- ✅ You want a high-impact safety feature (prevents missing urgent messages)
- ✅ You're comfortable with GPT-4 integration and hybrid approaches

**Skip/defer it if:**
- ❌ Time-constrained (<2 hours available)
- ❌ PR#14 not complete (HARD DEPENDENCY - needs Cloud Functions infrastructure)
- ❌ Not comfortable with AI/ML concepts (keyword classification, confidence scores)
- ❌ Want to focus on other AI features first (this is medium priority after calendar + decision summarization)

**Decision Aid:**
- If unsure about AI/ML complexity: This PR builds on PR#14 and PR#16 patterns - if those made sense, this will too
- If worried about cost: Hybrid approach keeps costs low (~$1-2/month/user vs $10-20 with full GPT-4 on every message)
- If concerned about false negatives: Keyword filter over-captures (false positives OK, false negatives NOT OK)

**Recommendation:** Build it after PR#14 and PR#16. This is a safety feature that solves a real problem (parents missing urgent messages). The hybrid approach is clever and cost-effective.

---

## Prerequisites (5 minutes)

### Required (Must Have)
- [ ] ✅ PR#14 complete (Cloud Functions + OpenAI setup)
  - Cloud Functions deployed to Firebase
  - OpenAI API key configured
  - processAI router working
- [ ] Swift/Xcode basics (extensions, enums, SwiftUI views)
- [ ] Basic AI/ML concepts (classification, confidence scores)
- [ ] Firebase Functions experience (from PR#14/PR#15/PR#16)

### Recommended (Nice to Have)
- [ ] ✅ PR#16 complete (Decision Summarization - similar AI pattern)
- [ ] Understanding of false positives vs false negatives
- [ ] Experience with hybrid approaches (fast path + slow path)

### Setup Commands
```bash
# 1. Verify PR#14 infrastructure
firebase functions:list
# Should show "processAI" function

# 2. Check OpenAI API key configured
firebase functions:config:get
# Should show "openai.key"

# 3. Create feature branch
git checkout -b feature/pr17-priority-highlighting

# 4. Verify Xcode project builds
# Open in Xcode, Cmd+B to build
```

### Knowledge Prerequisites
- **Urgency Classification:** Understanding that some messages require immediate action (critical), some need attention soon (high), and most can wait (normal)
- **Hybrid Approaches:** Cheap fast filter (keyword detection) + expensive accurate analysis (GPT-4) for best cost/performance balance
- **False Negatives vs False Positives:** Missing an urgent message (false negative) is worse than flagging a normal message as urgent (false positive)

---

## Getting Started (First Hour)

### Step 1: Read Documentation (45 minutes)
- [ ] Read this quick start guide (10 min)
- [ ] Skim main specification `PR17_PRIORITY_HIGHLIGHTING.md` (20 min)
  - Focus on: Architecture Overview, Key Design Decisions
- [ ] Review implementation checklist `PR17_IMPLEMENTATION_CHECKLIST.md` (15 min)
  - Understand 8 phases and time estimates
- [ ] Note any questions or concerns

**Key Concepts to Understand:**
- **Hybrid Detection:** Keyword filter → GPT-4 (only if keywords detected)
- **3-Level Urgency:** Critical (red, immediate), High (orange, soon), Normal (no indicator)
- **UI Hierarchy:** Border (catches eye) + Badge (confirms type) + Banner (collects urgent messages)

---

### Step 2: Set Up Environment (10 minutes)
- [ ] Verify Cloud Functions working:
  ```bash
  cd functions
  npm run build
  # Should compile without errors
  ```
- [ ] Check OpenAI integration:
  - Open `functions/src/ai/processAI.ts`
  - Verify OpenAI client initialization exists (from PR#14)
- [ ] Open Xcode project:
  ```bash
  open messAI.xcodeproj
  ```
- [ ] Build project (Cmd+B):
  - Should build successfully (0 errors)

---

### Step 3: Start Phase 1 - Cloud Function (45 minutes)
- [ ] Create `functions/src/ai/priorityDetection.ts`
- [ ] Implement keyword detection (15 min):
  - Critical keywords: "urgent", "emergency", "asap", "immediately", "right now"
  - High keywords: "important", "soon", "today", "deadline", "due"
  - Time-sensitive patterns: "pickup at 2pm today", "meeting at 3pm"
- [ ] Implement GPT-4 fallback (20 min):
  - Context-aware analysis for ambiguous messages
  - Structured prompt with clear classification criteria
- [ ] Add route to processAI (10 min):
  - Feature: "priority_detection"
  - Returns: priorityLevel, confidence, reason, keywords

**Checkpoint:** Cloud Function compiles and can classify "urgent" → critical, "thanks" → normal

**Quick Test:**
```typescript
// In Node.js console or test file
const result = await keywordBasedDetection("urgent pickup at 2pm today");
console.log(result);
// Expected: { priorityLevel: 'critical', confidence: 0.9, ... }
```

---

## Daily Progress Template

### Day 1 Goals (2-3 hours) - COMPLETE IN ONE SESSION!

**Morning (45 min): Cloud Function**
- [ ] Create priorityDetection.ts
- [ ] Implement keyword filter
- [ ] Implement GPT-4 fallback
- [ ] Add route to processAI
- **Checkpoint:** Function classifies urgency correctly

**Mid-Day (35 min): iOS Models + Service**
- [ ] Create PriorityLevel enum (colors, icons, border widths)
- [ ] Extend AIMetadata with priority fields
- [ ] Add detectPriority() to AIService
- **Checkpoint:** iOS can call Cloud Function and parse response

**Afternoon (90 min): UI Implementation**
- [ ] Enhance MessageBubbleView (border + badge) - 30 min
- [ ] Create PriorityBannerView (collapsible urgent section) - 30 min
- [ ] Add detection logic to ChatViewModel - 30 min
- **Checkpoint:** UI shows priority indicators for test messages

**End of Day (30 min): Testing**
- [ ] Test keyword detection with 10 real messages
- [ ] Test GPT-4 with ambiguous messages
- [ ] Verify UI in light and dark mode
- [ ] Calculate accuracy metrics
- **Checkpoint:** >80% accuracy, <5% false negatives

**Result:** Feature complete, working end-to-end, ready to deploy!

---

## Common Issues & Solutions

### Issue 1: Cloud Function returns "normal" for obviously urgent message
**Symptoms:** Message with "urgent" keyword classified as normal  
**Cause:** Keyword detection not triggering, or GPT-4 overriding with low confidence  
**Solution:**
```typescript
// Add debugging to priorityDetection.ts
console.log('Keyword detection result:', keywordResult);
console.log('GPT-4 detection result:', gpt4Result);

// Check if keyword in list
const CRITICAL_KEYWORDS = [
  'urgent', 'emergency', 'asap', // Make sure your keyword is here!
  ...
];
```

**Prevention:** Test keyword detection separately before GPT-4 integration

---

### Issue 2: All messages classified as critical (false positives)
**Symptoms:** Every message gets red border, even casual chat  
**Cause:** Keyword list too broad, or confidence threshold too low  
**Solution:**
```typescript
// Adjust confidence threshold in detectPriority()
if (keywordResult.level === 'normal' && keywordResult.confidence > 0.8) {
  // Was 0.7, increase to 0.8 or 0.85 to reduce false positives
  return keywordResult;
}

// Or remove overly-broad keywords
const HIGH_KEYWORDS = [
  // Remove: 'please', 'needs' (too common)
  'important', 'soon', 'today', 'deadline'
];
```

**Prevention:** Test with diverse real-world messages, calculate false positive rate

---

### Issue 3: GPT-4 timeout or slow response
**Symptoms:** Priority detection takes 10-30s, or times out  
**Cause:** GPT-4 API slow, network issues, or prompt too complex  
**Solution:**
```typescript
// Add timeout to GPT-4 call
const completion = await Promise.race([
  openai.chat.completions.create({
    model: 'gpt-4',
    messages: [...],
    temperature: 0.3,
    max_tokens: 200
  }),
  new Promise((_, reject) => 
    setTimeout(() => reject(new Error('GPT-4 timeout')), 5000) // 5s timeout
  )
]);
```

**Prevention:** Use GPT-3.5-turbo for faster responses (slightly lower accuracy), or increase timeout to 10s

---

### Issue 4: Priority border not displaying on message bubble
**Symptoms:** Message has aiMetadata.priorityLevel but no red/yellow border  
**Cause:** Overlay not applied, or priority checking wrong field  
**Solution:**
```swift
// In MessageBubbleView.swift, check overlay is applied
.background(bubbleBackground)
.overlay(priorityBorder) // ← Make sure this is here!
.clipShape(RoundedRectangle(cornerRadius: 18))

// Check priority field exists
private var priorityBorder: some View {
    Group {
        if let priority = message.aiMetadata?.priorityLevel {
            print("DEBUG: Priority level: \(priority.rawValue)") // Add debug
            if priority != .normal {
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(priority.color, lineWidth: priority.borderWidth)
            }
        } else {
            print("DEBUG: No priority level on message \(message.id)")
        }
    }
}
```

**Prevention:** Test with manual priority assignment before implementing AI detection

---

### Issue 5: Priority banner doesn't appear
**Symptoms:** Urgent messages exist but banner not showing  
**Cause:** urgentMessages array not updating, or banner conditional wrong  
**Solution:**
```swift
// In ChatViewModel, add debug logging
private var computedUrgentMessages: [Message] {
    let urgent = messages.filter { message in
        guard let priority = message.aiMetadata?.priorityLevel else { return false }
        guard priority != .normal else { return false }
        guard message.aiMetadata?.priorityDismissed != true else { return false }
        print("DEBUG: Urgent message found: \(message.id), priority: \(priority.rawValue)")
        return true
    }
    print("DEBUG: Total urgent messages: \(urgent.count)")
    return urgent
}

// In ChatView, check conditional
if !viewModel.urgentMessages.isEmpty {
    print("DEBUG: Showing banner with \(viewModel.urgentMessages.count) messages")
    PriorityBannerView(...)
} else {
    print("DEBUG: No urgent messages, banner hidden")
}
```

**Prevention:** Test with manual priority assignment, verify state updates correctly

---

### Issue 6: High API costs (>$5/day)
**Symptoms:** Firebase billing alert, or OpenAI usage spike  
**Cause:** GPT-4 called on every message (keyword filter not working)  
**Solution:**
```typescript
// Verify keyword filter working
async function detectPriority(messageText: string, ...): Promise<...> {
  console.log('Starting detection for:', messageText);
  
  const keywordResult = await keywordBasedDetection(messageText);
  console.log('Keyword result:', keywordResult);
  
  if (keywordResult.level === 'normal' && keywordResult.confidence > 0.8) {
    console.log('FAST PATH: Skipping GPT-4 (keyword filter: normal)');
    return keywordResult; // ← Should hit this 80% of the time!
  }
  
  console.log('SLOW PATH: Calling GPT-4 for context analysis');
  const gpt4Result = await gpt4BasedDetection(...);
  return gpt4Result;
}
```

**Check logs:** 80% should say "FAST PATH", 20% "SLOW PATH"

**Prevention:** Monitor Firebase Functions logs, set billing alerts at $10/day

---

## Quick Reference

### Key Files
- `functions/src/ai/priorityDetection.ts` - Cloud Function (keyword + GPT-4)
- `Models/PriorityLevel.swift` - Urgency enum (critical/high/normal)
- `Services/AIService.swift` - detectPriority() method
- `Views/Chat/MessageBubbleView.swift` - Border + badge display
- `Views/Chat/PriorityBannerView.swift` - In-chat urgent section

### Key Functions
- `detectPriority(messageText, recentMessages, conversationId)` - Main Cloud Function
- `keywordBasedDetection(text)` - Fast keyword filter
- `gpt4BasedDetection(text, context, keywords)` - Slow context analysis
- `AIService.detectPriority(message, recentMessages)` - iOS wrapper

### Key Concepts
- **Hybrid Approach:** Keyword filter (80% of messages, <100ms, free) + GPT-4 (20% of messages, 2-3s, ~$0.002/call)
- **3 Priority Levels:** Critical (red, 3pt border, 🚨), High (orange, 2pt border, ⚠️), Normal (no indicators)
- **False Negatives NOT OK:** Better to flag too many as urgent than miss a critical message

### Useful Commands
```bash
# Build Cloud Functions
cd functions && npm run build

# Deploy to Firebase
firebase deploy --only functions:processAI

# Test locally (if supported)
firebase emulators:start --only functions

# Check logs
firebase functions:log --only processAI

# View API usage (OpenAI dashboard)
# Visit: https://platform.openai.com/usage
```

---

## Success Metrics

**You'll know it's working when:**

### Functional (Must Work)
- [ ] Message with "urgent" keyword gets red border + 🚨 badge
- [ ] Message with "important" keyword gets orange border + ⚠️ badge
- [ ] Message with "thanks" stays normal (no indicators)
- [ ] Priority banner appears when critical messages exist
- [ ] Banner expands/collapses smoothly
- [ ] Tap message in banner scrolls to message in chat
- [ ] Mark as seen dismisses urgent indicators

### Performance (Must Hit Targets)
- [ ] Keyword detection <100ms (test with 10 messages)
- [ ] GPT-4 detection <3s (test with 5 messages)
- [ ] 80% of messages skip GPT-4 (check logs)
- [ ] Cost <$2/month/user at 100 messages/day

### Accuracy (Target Metrics)
- [ ] True positive rate >80% (urgent messages flagged)
- [ ] False negative rate <5% (urgent messages not missed)
- [ ] False positive rate <20% (normal messages wrongly flagged - acceptable)

### Quality (Polish)
- [ ] UI works in light and dark mode
- [ ] Accessibility: Border + icon (colorblind friendly)
- [ ] No console errors or warnings
- [ ] Smooth animations (expand/collapse)
- [ ] Clear visual hierarchy (critical stands out more than high)

---

## Testing Checklist

### Quick Smoke Test (5 min)
- [ ] Send message with "urgent pickup at 2pm"
  - Should get red border + 🚨 badge
  - Should appear in priority banner
- [ ] Send message with "thanks everyone"
  - Should stay normal (no indicators)
- [ ] Tap banner → should expand and show urgent message
- [ ] Tap message in banner → should scroll to message in chat
- [ ] Tap "Mark all as seen" → should dismiss banner

### Comprehensive Test (20 min)
- [ ] Test critical keywords:
  - "urgent", "emergency", "asap", "immediately", "right now"
  - All should get critical level
- [ ] Test high keywords:
  - "important", "soon", "today", "deadline", "due"
  - All should get high level
- [ ] Test time-sensitive patterns:
  - "pickup at 2pm today", "meeting at 3pm", "due by tonight"
  - All should get critical level
- [ ] Test normal messages:
  - "sounds good", "thanks!", "anyone bringing cookies Friday?"
  - All should stay normal
- [ ] Test ambiguous messages:
  - "Noah needs something by this afternoon"
  - Should use GPT-4 context, likely high or critical
- [ ] Calculate accuracy:
  - True positives / Total urgent messages = ___% (target >80%)
  - False negatives / Total urgent messages = ___% (target <5%)

---

## Help & Support

### Stuck on Cloud Function?
- Review PR#14 implementation (same pattern)
- Review PR#15 or PR#16 AI features (similar structure)
- Check Firebase Functions logs: `firebase functions:log`
- Test locally with Firebase emulators

### Stuck on iOS Integration?
- Review PR#15 (CalendarCardView similar to PriorityBannerView)
- Review PR#16 (DecisionSummaryCardView similar UI pattern)
- Check AIService implementation from PR#14
- Test with manual priority assignment before AI

### Stuck on UI Layout?
- Check existing MessageBubbleView implementation
- Review SwiftUI overlay and clipShape modifiers
- Test with different priority levels manually
- Check light and dark mode appearance

### Want to Skip?
- This is a safety feature - skipping means parents might miss urgent messages
- If time-constrained: Implement just keyword detection (skip GPT-4) for MVP
- Can always add GPT-4 later for improved accuracy

### Running Out of Time?
- Priority 1: Keyword detection + border display (45 min)
- Priority 2: Priority banner (30 min)
- Priority 3: GPT-4 context analysis (20 min)
- Priority 4: Global urgent tab (skip for MVP, add later)

---

## Motivation

**You've got this!** 💪

You're building a feature that prevents real-world problems. When a parent's phone buzzes with "Pickup changed to 2pm TODAY" buried in 50 casual messages, your AI will flag it in red so they see it before it's too late.

**This is a safety feature.** Parents will tell their friends "This app saved me from being late for pickup!" That's word-of-mouth growth right there.

The hybrid approach is clever - keyword filter handles 80% of messages instantly (free), GPT-4 analyzes the tricky 20% with full context. Cost-effective AND accurate.

You've already built the Cloud Functions infrastructure (PR#14) and similar AI features (PR#15, PR#16). This follows the same pattern - you know how to do this!

**Remember:** False positives are OK (extra red borders don't hurt), false negatives are NOT OK (missing urgent messages causes problems). Tune for safety.

---

## Next Steps

**When ready to start:**

1. **Review prerequisites** (5 min)
   - PR#14 complete?
   - OpenAI API working?
   - Understand hybrid approach?

2. **Read main spec** (20 min)
   - `PR17_PRIORITY_HIGHLIGHTING.md`
   - Focus on Architecture and Design Decisions

3. **Start Phase 1** (45 min)
   - Create `priorityDetection.ts`
   - Implement keyword filter
   - Implement GPT-4 fallback
   - Add route to processAI

4. **Test as you go** (continuous)
   - After keyword filter: Test with "urgent" → critical
   - After GPT-4: Test with ambiguous message
   - After UI: Test with real messages

5. **Deploy and validate** (30 min)
   - Deploy Cloud Functions
   - Test end-to-end from iOS
   - Calculate accuracy metrics
   - Verify cost estimates

**Status:** Ready to build! 🚀

**Next PR:** After PR#17, consider PR#18 (RSVP Tracking) or PR#19 (Deadline Extraction)

---

*"Never miss an urgent message buried in 100+ daily group chat messages. AI flags what needs attention NOW vs what can wait."*
