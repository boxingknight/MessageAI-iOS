# PR#19: Deadline Extraction - Quick Start Guide

**Status**: 📋 PLANNED (Documentation complete, ready to implement!)  
**Estimated Time**: 3-4 hours  
**Complexity**: MEDIUM-HIGH

---

## TL;DR (30 seconds)

**What**: AI-powered deadline detection that automatically extracts deadlines from messages and displays them in a visual timeline.

**Why**: Busy parents miss important deadlines buried in group chats. This saves 10-15 minutes/day + prevents missed deadlines.

**Time**: 3-4 hours estimated

**Complexity**: MEDIUM-HIGH (Cloud Function + GPT-4 + iOS models + views)

**Status**: Ready to build - all planning complete! 🚀

**Example**: 
- Message: "Permission slip due Wednesday by 3pm"
- Result: Deadline card in chat + Global deadline list with countdown

---

## Decision Framework (2 minutes)

### Should You Build This Feature?

**✅ Build it if:**
- [x] You have 3-4 hours available
- [x] PR#14 (Cloud Functions) is 100% complete
- [x] PR#15 (Calendar Extraction) is complete (GPT-4 date parsing patterns established)
- [x] You want the 5th of 5 required AI features
- [x] You understand the value (prevents missed deadlines)

**❌ Skip it if:**
- [ ] Time-constrained (<3 hours available)
- [ ] PR#14 not complete (hard dependency)
- [ ] Other priorities more urgent
- [ ] Not interested in deadline tracking

**Decision Aid**: This is the **5th of 5 required AI features**. After this, you'll have ALL required AI features complete! Only advanced agent (PR#20) and polish PRs remain.

---

## Prerequisites (5 minutes)

### Required (MUST have)
- [x] **PR#14 Complete**: Cloud Functions + OpenAI deployed ✅
- [x] **PR#15 Complete**: Calendar Extraction (GPT-4 date parsing) ✅
- [x] **OpenAI API key**: Configured in Cloud Functions
- [x] **Firebase billing**: Blaze plan enabled

### Knowledge (Should know)
- GPT-4 function calling basics
- SwiftUI List and filtering
- Firestore real-time listeners
- Async/await patterns

### Tools
- Xcode 15+
- Firebase CLI installed
- iOS Simulator or physical device

### Setup Commands

```bash
# 1. Verify dependencies
cd /Users/ijaramil/Documents/GauntletAI/Week2/messAI

# 2. Check Cloud Functions deployed
firebase functions:list
# Should see: processAI (deployed)

# 3. Verify OpenAI key configured
cat functions/.env
# Should see: OPENAI_API_KEY=sk-...

# 4. Create feature branch
git checkout main
git pull origin main
git checkout -b feature/pr19-deadline-extraction
```

---

## Getting Started (First Hour)

### Step 1: Read Documentation (45 minutes)

**Priority Reading Order**:
1. This quick start (10 min) ✅ You're here!
2. Main specification: `PR19_DEADLINE_EXTRACTION.md` (30 min)
3. Testing guide: `PR19_TESTING_GUIDE.md` (5 min)

**What to Focus On**:
- Hybrid detection approach (keyword → GPT-4)
- Data model (Firestore `/deadlines` collection)
- UI pattern (in-chat cards + global tab)
- Key decisions (why hybrid? why separate collection?)

**Questions to Answer**:
- How does keyword pre-filter work?
- What's the Firestore structure?
- How do deadline cards display?
- What actions can users take?

---

### Step 2: Set Up Environment (10 minutes)

**2.1: Open Files in Xcode**
- `functions/src/ai/` folder
- `messAI/Models/` folder
- `messAI/ViewModels/` folder
- `messAI/Views/Deadline/` folder (create if needed)

**2.2: Verify Cloud Functions Setup**
```bash
cd functions
npm run build
# Should compile successfully
```

**2.3: Test OpenAI Connection** (optional)
```typescript
// Create functions/test/testOpenAI.ts
import { openai } from '../src/config/openai';

async function test() {
  const response = await openai.chat.completions.create({
    model: "gpt-4",
    messages: [{ role: "user", content: "Say hello" }]
  });
  console.log(response.choices[0].message.content);
}

test();
```

---

### Step 3: Start Phase 1 - Cloud Function (First Task)

**Task**: Create `deadlineExtraction.ts` with keyword pre-filter

**What You'll Build** (30 min):
```typescript
// Keyword patterns
const DEADLINE_KEYWORDS = ['due', 'deadline', 'by', 'before', ...];

// Pre-filter function
function containsDeadlineKeywords(text: string): boolean {
  // Returns true if message likely has deadline
}

// GPT-4 extraction
export async function extractDeadline(messageText: string) {
  // 1. Keyword filter
  // 2. GPT-4 function calling
  // 3. Parse response
  // 4. Return structured deadline
}
```

**Success Criteria**:
- [ ] File created: `functions/src/ai/deadlineExtraction.ts`
- [ ] Keyword filter implemented
- [ ] GPT-4 extraction function complete
- [ ] Compiles without errors

**Test It**:
```bash
npm run build
# Should succeed
```

**Checkpoint**: If you reach here in 1 hour, you're on track! ✅

---

## Daily Progress Template

### Day 1 Goals (3-4 hours total)

**Morning Session** (1.5-2 hours):
- [ ] Phase 1: Cloud Function (60-90 min)
  - Create deadlineExtraction.ts
  - Add route to processAI.ts
  - Deploy and test

**Checkpoint**: Cloud Function deployed and tested

**Afternoon Session** (1.5-2 hours):
- [ ] Phase 2: iOS Models (45-60 min)
  - Create Deadline.swift
  - Create DeadlineStatus.swift
- [ ] Phase 3: Deadline Service (30-45 min)
  - Create DeadlineService.swift with CRUD

**Checkpoint**: Models and service complete

**Evening Session** (optional, if needed):
- [ ] Phase 4: ViewModels (45-60 min)
- [ ] Phase 5: SwiftUI Views (60-90 min)
- [ ] Phase 6: Integration (30-45 min)

**End-of-Day Checkpoint**: All phases complete, ready to test

---

## Common Issues & Solutions

### Issue 1: Keyword Filter Not Triggering

**Symptoms**: Messages with deadlines not detected

**Cause**: Keyword list incomplete or date pattern not matching

**Solution**: 
```typescript
// Add more deadline keywords
const DEADLINE_KEYWORDS = [
  'due', 'deadline', 'by', 'before', 'closes', 'ends',
  'submit', 'turn in', 'expires', 'last day', 'final day',
  'no later than', 'cut-off', 'must', 'need to', 'has to'
];

// Add more date patterns
const DATE_PATTERNS = [
  /\b(monday|tuesday|wednesday|thursday|friday|saturday|sunday)\b/i,
  /\b(today|tomorrow|this week|next week)\b/i,
  /\b\d{1,2}\/\d{1,2}\b/, // MM/DD format
  /\b(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\s+\d{1,2}/i
];
```

---

### Issue 2: GPT-4 Returns Invalid Date

**Symptoms**: Date parsing fails, deadline not created

**Cause**: GPT-4 returning non-ISO 8601 format

**Solution**:
```typescript
// Validate and parse date
function parseDeadlineDate(dateString: string): Date | null {
  try {
    const date = new Date(dateString);
    if (isNaN(date.getTime())) {
      console.error('Invalid date:', dateString);
      return null;
    }
    return date;
  } catch (error) {
    console.error('Date parsing error:', error);
    return null;
  }
}
```

---

### Issue 3: Firestore Permission Denied

**Symptoms**: Error when saving deadline to Firestore

**Cause**: Missing security rules for `/deadlines` collection

**Solution**:
```javascript
// firebase/firestore.rules
match /deadlines/{deadlineId} {
  // Users can read their own deadlines
  allow read: if request.auth != null 
              && request.auth.uid == resource.data.extractedBy;
  
  // Users can create deadlines
  allow create: if request.auth != null 
                && request.auth.uid == request.resource.data.extractedBy;
  
  // Users can update/delete their own deadlines
  allow update, delete: if request.auth != null 
                         && request.auth.uid == resource.data.extractedBy;
}
```

Deploy: `firebase deploy --only firestore:rules`

---

### Issue 4: Deadline Card Not Displaying

**Symptoms**: Deadline extracted but card doesn't appear in chat

**Cause**: ChatView not listening to extractedDeadlines array

**Solution**:
```swift
// In ChatView.swift
ForEach(viewModel.messages) { message in
    MessageBubbleView(message: message, ...)
    
    // Check if deadline exists for this message
    if let deadline = viewModel.extractedDeadlines.first(where: { $0.messageId == message.id }) {
        DeadlineCardView(deadline: deadline, viewModel: viewModel)
            .padding(.horizontal)
            .padding(.top, 4)
    }
}
```

---

### Issue 5: Duplicate Deadlines Created

**Symptoms**: Same deadline detected multiple times

**Cause**: Detection triggered on every message update

**Solution**:
```swift
// In ChatViewModel.swift
private var processedMessageIds = Set<String>()

func detectMessageDeadline(for message: Message) {
    // Skip if already processed
    guard !processedMessageIds.contains(message.id) else { return }
    
    // ... extraction logic ...
    
    // Mark as processed
    processedMessageIds.insert(message.id)
}
```

---

### Issue 6: High API Costs

**Symptoms**: OpenAI bill higher than expected

**Cause**: Keyword filter not effective, too many GPT-4 calls

**Solution**:
```typescript
// More aggressive pre-filtering
function containsDeadlineKeywords(text: string): boolean {
    const lowerText = text.toLowerCase();
    
    // BOTH conditions must be true
    const hasKeyword = DEADLINE_KEYWORDS.some(kw => lowerText.includes(kw));
    const hasDate = DATE_PATTERNS.some(pattern => pattern.test(text));
    
    return hasKeyword && hasDate; // Both required
}

// Log filter stats
console.log('Keyword filter pass rate:', passCount / totalCount);
// Target: 20-30% pass rate (70-80% filtered out)
```

---

## Quick Reference

### Key Files

**Cloud Function**:
- `functions/src/ai/deadlineExtraction.ts` - GPT-4 extraction logic (~300 lines)
- `functions/src/ai/processAI.ts` - Add deadline route (~20 lines)

**iOS Models**:
- `messAI/Models/Deadline.swift` - Deadline data structure (~200 lines)
- `messAI/Models/DeadlineStatus.swift` - Status enums (~50 lines)

**iOS Services**:
- `messAI/Services/DeadlineService.swift` - Firestore CRUD (~150 lines)
- `messAI/Services/AIService.swift` - extractDeadline() method (~80 lines)

**iOS ViewModels**:
- `messAI/ViewModels/DeadlineViewModel.swift` - Global state (~200 lines)
- `messAI/ViewModels/ChatViewModel.swift` - Detection logic (~100 lines)

**iOS Views**:
- `messAI/Views/Deadline/DeadlineCardView.swift` - In-chat card (~250 lines)
- `messAI/Views/Deadline/DeadlineListView.swift` - Global list (~300 lines)
- `messAI/Views/Deadline/DeadlineRowView.swift` - List rows (~100 lines)

---

### Key Concepts

**Hybrid Detection**:
- Keyword filter (client-side, <100ms, free)
- GPT-4 extraction (server-side, ~2s, ~$0.003)
- 70-80% of messages filtered out before GPT-4
- Result: Cost-effective + accurate

**Deadline Status**:
- `upcoming`: > 1 day away
- `today`: Due today
- `overdue`: Past due date
- `completed`: User marked complete

**Priority Levels**:
- `high`: Urgent or important
- `medium`: Normal deadline
- `low`: Flexible deadline

**Urgency Calculation**:
```swift
if isOverdue { return .critical }
else if isToday { return .urgent }
else if daysRemaining <= 2 { return .high }
else if daysRemaining <= 7 { return .medium }
else { return .low }
```

---

### Useful Commands

**Build & Deploy Cloud Functions**:
```bash
cd functions
npm run build          # Compile TypeScript
firebase deploy --only functions  # Deploy
firebase functions:list  # Verify deployed
```

**Test Cloud Function**:
```bash
# Get auth token from Firebase
firebase login:ci

# Call function
curl -X POST \
  https://us-central1-messageai-95c8f.cloudfunctions.net/processAI \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "feature": "deadline_extraction",
    "messageText": "Permission slip due Wednesday by 3pm",
    "conversationId": "test_123"
  }'
```

**Build iOS App**:
```bash
# In Xcode
# Product → Build (Cmd+B)
# Product → Run (Cmd+R)
```

**Check Firestore**:
```bash
# Firebase Console → Firestore → deadlines collection
# Should see documents with structure:
{
  id: "abc123",
  title: "Permission slip",
  dueDate: Timestamp,
  conversationId: "conv_xyz",
  ...
}
```

---

## Success Metrics

**You'll know it's working when:**

1. **Keyword Filter** ✅
   - [ ] 70-80% of messages filtered out
   - [ ] <100ms response time
   - [ ] Console logs show filter stats

2. **GPT-4 Extraction** ✅
   - [ ] Structured deadline returned
   - [ ] Date in ISO 8601 format
   - [ ] Confidence score 0.0-1.0
   - [ ] <3 seconds response time

3. **In-Chat Display** ✅
   - [ ] Deadline card appears below message
   - [ ] Countdown text updates
   - [ ] Status color coding correct
   - [ ] Actions work (complete, remind, dismiss)

4. **Global Deadline List** ✅
   - [ ] All deadlines visible
   - [ ] Filter tabs work
   - [ ] Tap navigates to conversation
   - [ ] Badge shows count

5. **Automatic Detection** ✅
   - [ ] New messages auto-processed
   - [ ] No user action required
   - [ ] Works in 1-on-1 and groups

**Performance Targets**:
- Keyword filter: <100ms (95th percentile)
- GPT-4 extraction: <3s (95th percentile)
- UI update: <100ms after detection
- Cost per deadline: <$0.005

**Quality Targets**:
- Detection accuracy: >85% for explicit deadlines
- False positive rate: <10%
- No missed urgent deadlines
- Zero crashes

---

## Help & Support

### Stuck?

1. **Check main planning doc** (`PR19_DEADLINE_EXTRACTION.md`) for details
2. **Review PR#15** (Calendar Extraction) - similar GPT-4 date parsing
3. **Review PR#18** (RSVP Tracking) - similar hybrid detection approach
4. **Check memory bank** for project patterns

### Want to Skip a Feature?

**Can skip**:
- Manual deadline creation (future PR)
- iOS Reminders integration (future PR)
- Recurring deadlines (future PR)
- Notification reminders (PR#22)

**Cannot skip**:
- Automatic detection (core feature)
- In-chat cards (primary UX)
- Global list (essential for overview)
- Firestore persistence (data integrity)

### Running Out of Time?

**Prioritize**:
1. Cloud Function (1.5h) - CRITICAL
2. iOS Models (45m) - CRITICAL
3. Basic card view (30m) - HIGH
4. Global list (simplified) (45m) - MEDIUM

**Defer**:
- Advanced filtering
- Reminder functionality
- Manual creation
- Polish animations

**Minimum Viable**:
- Cloud Function working
- Deadline model
- Basic card in chat
- Can complete PRin 2-3 hours if focused

---

## Motivation

### You've Got This! 💪

**What You've Already Built**:
- ✅ PR#1-13: Complete messaging foundation
- ✅ PR#14: Cloud Functions + OpenAI infrastructure
- ✅ PR#15: Calendar extraction (GPT-4 date parsing)
- ✅ PR#16: Decision summarization (GPT-4 extraction)
- ✅ PR#17: Priority highlighting (hybrid detection)
- ✅ PR#18: RSVP tracking (hybrid approach)

**You've already**:
- Built GPT-4 function calling (PR#15)
- Implemented hybrid detection (PR#17, PR#18)
- Created complex SwiftUI views
- Integrated Cloud Functions
- Handled Firestore real-time listeners

**This PR is**:
- Similar patterns to PR#15-18
- Well-documented (you're reading it!)
- Tested approach (hybrid works!)
- Achievable in 3-4 hours

**After This PR**:
- ✅ 5 of 5 required AI features complete!
- ✅ 90% of AI features done!
- Only PR#20 (advanced agent) + polish remain!

**Why This Matters**:
- Prevents real-world problems (missed deadlines)
- Saves 10-15 minutes/day
- Reduces parent stress
- Core value proposition feature

---

## Next Steps

### When Ready:

**Phase 1** (60-90 min):
1. Create `deadlineExtraction.ts`
2. Add route to `processAI.ts`
3. Deploy and test

**Phase 2** (45-60 min):
1. Create iOS models
2. Implement Deadline service

**Phase 3-6** (2 hours):
1. ViewModels
2. SwiftUI views
3. Integration
4. Testing

**Total**: 3-4 hours to completion! 🚀

---

## Final Checklist

Before starting:
- [ ] Read main spec (30 min)
- [ ] Read this quick start (10 min)
- [ ] Verify PR#14 complete
- [ ] Verify PR#15 complete
- [ ] Create feature branch
- [ ] Open relevant files

During implementation:
- [ ] Follow checklist step-by-step
- [ ] Test after each phase
- [ ] Commit frequently
- [ ] Track time spent

After completion:
- [ ] All tests passing
- [ ] Documentation updated
- [ ] Memory bank updated
- [ ] Ready to merge!

---

**Status**: Ready to build! 🚀

**Value Proposition**: "Never miss a deadline buried in group chat. See all upcoming deadlines at a glance with automatic AI detection."

**You've got this!** Start with Phase 1 and follow the checklist. You'll have the 5th AI feature complete in 3-4 hours! 💪

