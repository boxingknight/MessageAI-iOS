# PR#7: Chat List View - Quick Start

---

## TL;DR (30 seconds)

**What:** Build the main conversation list screen—the hub of the messaging app where users see all their chats

**Why:** First screen after login, must load instantly and update in real-time

**Time:** 2-3 hours estimated

**Complexity:** MEDIUM (real-time listeners, local-first architecture)

**Status:** 📋 PLANNED - Ready to implement after PR #6

---

## Decision Framework (2 minutes)

### Should You Build This?

**Green Lights (Build it!):**
- ✅ PR #6 is complete (LocalDataManager available)
- ✅ PR #5 is complete (ChatService available)
- ✅ PR #4 is complete (Conversation model exists)
- ✅ You have 2-3 hours available
- ✅ You understand MVVM pattern
- ✅ You're comfortable with SwiftUI and Combine

**Red Lights (Skip/defer it!):**
- ❌ PR #6 not complete (Core Data dependency required)
- ❌ Time-constrained (<2 hours available)
- ❌ Not familiar with async/await or Firestore listeners
- ❌ Prefer to wait for full backend (PR #6)

**Decision Aid:** This is a **critical path PR**. You can't proceed to PR #8, #9, #10 without this. If you're going to build the messaging app, you need this now.

---

## Prerequisites (5 minutes)

### Required (Must Have)
- [ ] PR #4 complete (Conversation model)
- [ ] PR #5 complete (ChatService with fetchConversations)
- [ ] PR #6 complete (LocalDataManager with fetchConversations)
- [ ] Firebase Auth working (current user ID available)
- [ ] Xcode 15+ installed
- [ ] Physical device or simulator ready

### Nice to Have (Helpful)
- [ ] Test conversations in Firestore (for testing)
- [ ] Second device for real-time testing
- [ ] Xcode Instruments (for performance testing)

### Setup Commands

```bash
# 1. Ensure on main branch with latest
cd /path/to/messAI
git checkout main
git pull origin main

# 2. Verify dependencies
# Open Xcode and verify:
# - Models/Conversation.swift exists (PR #4)
# - Services/ChatService.swift exists (PR #5)
# - Persistence/LocalDataManager.swift exists (PR #6)

# 3. Create feature branch
git checkout -b feature/chat-list-view

# 4. Open in Xcode
open messAI.xcodeproj
```

---

## Getting Started (First Hour)

### Step 1: Read Documentation (45 minutes)
- [ ] Read this quick start (10 min) ✓
- [ ] Read main specification `PR07_CHAT_LIST_VIEW.md` (35 min)
  - Focus on: Architecture Decisions, Data Flow, Component Hierarchy
  - Skim: Implementation details (you'll reference during coding)
- [ ] Note any questions or concerns

### Step 2: Set Up Environment (10 minutes)
- [ ] Create feature branch (see setup commands above)
- [ ] Open Xcode project
- [ ] Build project (Cmd+B) - verify clean build
- [ ] Run app in simulator - verify auth works
- [ ] Close any unnecessary files

### Step 3: Start Phase 1 - Date Formatter (5 minutes)
- [ ] Open implementation checklist: `PR07_IMPLEMENTATION_CHECKLIST.md`
- [ ] Navigate to Phase 1
- [ ] Create `DateFormatter+Extensions.swift`
- [ ] Begin implementation

**Checkpoint:** By end of Hour 1, you should have date formatter complete and tested ✓

---

## Hour-by-Hour Roadmap

### Hour 1: Date Formatter + ViewModel Setup (60 minutes)
**Goals:**
- [ ] Complete Phase 1: Date Formatter (30 min)
- [ ] Start Phase 2: ChatListViewModel properties (30 min)

**What You'll Build:**
- `DateFormatter+Extensions.swift` (~80 lines)
- ChatListViewModel class skeleton with properties

**Checkpoint:** Date formatting works, ViewModel compiles

---

### Hour 2: ViewModel Logic + UI Components (60 minutes)
**Goals:**
- [ ] Complete Phase 2: ChatListViewModel methods (30 min)
- [ ] Complete Phase 3: ConversationRowView (30 min)

**What You'll Build:**
- ViewModel methods: load, listen, refresh (~170 lines)
- ConversationRowView component (~120 lines)

**Checkpoint:** ViewModel complete, row component previews look good

---

### Hour 3: Main View + Testing (60 minutes)
**Goals:**
- [ ] Complete Phase 4: ChatListView (45 min)
- [ ] Complete Phase 5: Integration & Testing (15 min)

**What You'll Build:**
- ChatListView with NavigationStack (~180 lines)
- Integration with ContentView
- Manual testing

**Checkpoint:** App shows conversation list, all tests pass ✓

---

## Daily Progress Template

### Day 1 Goals (2-3 hours)
- [ ] Phase 1: Date Formatter (30 min)
- [ ] Phase 2: ChatListViewModel (1 hour)
- [ ] Phase 3: ConversationRowView (45 min)
- [ ] Phase 4: ChatListView (45 min)
- [ ] Phase 5: Integration & Testing (30 min)

**Checkpoint:** ChatListView complete, conversation list displays

---

## Common Issues & Solutions

### Issue 1: "Cannot find 'LocalDataManager' in scope"
**Symptoms:** Compiler error when creating ChatListViewModel  
**Cause:** PR #6 not complete or not imported  
**Solution:**
```bash
# Verify PR #6 is complete
ls messAI/Persistence/
# Should show: LocalDataManager.swift

# If missing, complete PR #6 first
git checkout feature/local-persistence
# Complete PR #6, then return to PR #7
```

---

### Issue 2: "Type 'Conversation' has no member 'lastMessageAt'"
**Symptoms:** Compiler error when accessing conversation properties  
**Cause:** PR #4 model doesn't match expected structure  
**Solution:**
- Open `Models/Conversation.swift`
- Verify these properties exist:
  - `let id: String`
  - `var lastMessage: String`
  - `var lastMessageAt: Date`
- If missing, update Conversation model

---

### Issue 3: Real-time listener never fires
**Symptoms:** List doesn't update with new conversations  
**Cause:** Firestore listener not set up correctly in ChatService  
**Solution:**
- Verify ChatService.fetchConversations returns `AsyncThrowingStream`
- Check Firebase Console for conversations matching current user
- Add debug print in listener: `print("🔥 Firestore update: \(conversations.count)")`
- Verify Firestore rules allow read access

---

### Issue 4: App crashes on view disappear
**Symptoms:** Crash when navigating away from ChatListView  
**Cause:** Firestore listener not cancelled properly  
**Solution:**
```swift
// In ChatListView.body
.onDisappear {
    viewModel.stopListening()
}

// In ChatListViewModel
func stopListening() {
    firestoreTask?.cancel()
    firestoreTask = nil
}
```

---

### Issue 5: Empty state never shows
**Symptoms:** Blank screen instead of empty state message  
**Cause:** Loading state never set to false  
**Solution:**
- Check `loadConversations()` sets `isLoading = false`
- Add debug: `print("Conversations: \(conversations.count), Loading: \(isLoading)")`
- Verify `sortedConversations.isEmpty` logic

---

### Issue 6: Timestamps show wrong format
**Symptoms:** Shows "Dec 25" instead of "5m ago"  
**Cause:** Date calculation issue or timezone  
**Solution:**
- Test `relativeDateString()` in playground
- Print actual date: `print("Date: \(conversation.lastMessageAt)")`
- Verify Firestore timestamp conversion in Conversation model

---

## Quick Reference

### Key Files in This PR
```
messAI/
├── Utilities/
│   └── DateFormatter+Extensions.swift   (~80 lines) - Smart timestamps
├── ViewModels/
│   └── ChatListViewModel.swift          (~250 lines) - State management
└── Views/
    └── Chat/
        ├── ConversationRowView.swift    (~120 lines) - Row component
        └── ChatListView.swift           (~180 lines) - Main view
```

### Key Concepts

**1. Local-First Architecture**
- Load from Core Data first (instant display)
- Start Firestore listener in background
- Update UI when Firestore syncs
- Result: Fast app launch + always-current data

**2. Real-Time Listeners**
```swift
// AsyncThrowingStream from ChatService
for try await conversations in chatService.fetchConversations(...) {
    // Update UI automatically
    self.conversations = conversations
}
```

**3. Optimistic UI**
- Show data immediately (from local)
- Sync in background (from Firestore)
- User never waits

**4. Smart Timestamps**
```swift
// "2m ago", "Yesterday", "Mon", "Dec 25"
conversation.lastMessageAt.relativeDateString()
```

### Useful Debug Commands

```swift
// Check conversations loading
print("📥 Loaded \(conversations.count) conversations")

// Check Firestore listener
print("🔥 Firestore update: \(conversations.count)")

// Check date formatting
print("📅 Timestamp: \(date.relativeDateString())")

// Check lifecycle
print("👋 View appeared")
print("🛑 View disappeared, stopping listener")
```

### Performance Targets
- Initial load: <1 second (from Core Data)
- Firestore sync: <2 seconds
- Real-time update: <2 seconds
- Scroll: 60fps with 100+ conversations

---

## Success Metrics

### You'll know it's working when:
- [ ] App launches and shows conversations instantly (<1 second)
- [ ] Conversations sorted by most recent first
- [ ] Each row shows: name, last message, timestamp
- [ ] Profile pictures display (placeholder OK for now)
- [ ] Empty state shows when no conversations
- [ ] Tap row navigates to placeholder ChatView
- [ ] Pull-to-refresh triggers sync
- [ ] New message in Firestore updates list within 2 seconds
- [ ] Offline mode shows local conversations
- [ ] No memory leaks (test with Instruments)

### Quality Checklist
- [ ] Zero compiler warnings
- [ ] Zero console errors
- [ ] Smooth 60fps scrolling
- [ ] No crashes during testing
- [ ] Listener cleanup works (no leaks)
- [ ] Timestamps display correctly

---

## Help & Support

### Stuck on Phase 1 (Date Formatter)?
- Check: Is the file in the right folder?
- Check: Did you import Foundation?
- Test: Try in playground first
- Reference: Apple's DateFormatter docs

### Stuck on Phase 2 (ViewModel)?
- Check: Are all dependencies available? (ChatService, LocalDataManager)
- Check: Is @MainActor on class?
- Check: Are @Published properties correct type?
- Test: Build project after each method

### Stuck on Phase 3 (ConversationRow)?
- Check: Does Conversation model have all properties?
- Check: Is AsyncImage handling all phases?
- Test: Run SwiftUI preview (Cmd+Option+Enter)
- Reference: ConversationRowView_Previews

### Stuck on Phase 4 (ChatListView)?
- Check: Is NavigationStack set up correctly?
- Check: Is LazyVStack inside ScrollView?
- Check: Are lifecycle methods (.onAppear/.onDisappear) present?
- Test: Does preview compile?

### Stuck on Phase 5 (Integration)?
- Check: Is ChatListView added to ContentView?
- Check: Is ViewModel initialized with correct dependencies?
- Check: Are there test conversations in Firestore?
- Test: Run on simulator/device

---

## What Can Be Skipped?

### Can Skip (Won't Break MVP):
- Unread count badge (implement in PR #11)
- Online indicators (implement in PR #12)
- User names/photos (implement in PR #8)
- Unit tests (optional for MVP)
- Complex animations

### Cannot Skip (Required):
- Date formatter (timestamps are essential)
- ChatListViewModel (app won't work without it)
- ConversationRowView (need something to display)
- ChatListView (main screen!)
- Real-time listener (core messaging requirement)
- Listener cleanup (prevents memory leaks)

---

## Running Out of Time?

### Minimum Viable PR #7 (90 minutes):

**Phase 1:** Date Formatter (20 min)
- Just the basic relativeDateString() function
- Skip fancy formatting, just return ISO string if needed

**Phase 2:** Simplified ViewModel (40 min)
- Load from Firestore only (skip local-first)
- Basic listener, no error handling
- Minimal helper methods

**Phase 3:** Basic ConversationRow (15 min)
- Just text (name + message), skip images
- Skip online indicator, unread badge

**Phase 4:** Basic ChatListView (15 min)
- Simple List instead of LazyVStack
- Skip empty state, just show nothing
- Skip pull-to-refresh

**Result:** Functional but not polished. Can enhance later.

---

## Motivation

**You've got this!** 💪

By the end of this PR, you'll have the main screen of your messaging app working. Users will see their conversations, tap to open them, and experience real-time updates. This is the hub that ties everything together.

**What you're building:**
- The first screen users see after login
- Real-time conversation list with automatic updates
- Foundation for PR #8 (Contact Selection) and PR #9 (ChatView)
- Offline-capable architecture (works without internet)

**Why this matters:**
- Chat list = 50% of user's time in messaging apps
- Fast load time = great first impression
- Real-time updates = modern messaging experience
- Local-first = WhatsApp-level reliability

**Previous PR velocity:**
- PR #5: Estimated 3-4h, actual 1h (3x faster!)
- PR #3: Estimated 2h, actual 2h (on target!)
- PR #2: Estimated 2-3h, actual 2.5h (on target!)

**Planning pays off:** Good docs = fast implementation ✅

---

## Next Steps

**When ready:**
1. ✅ Prerequisites checked (PR #4, #5, #6 complete)
2. ✅ Branch created (`feature/chat-list-view`)
3. ✅ Documentation read (this + main spec)
4. 🚀 Open `PR07_IMPLEMENTATION_CHECKLIST.md`
5. 🚀 Start Phase 1: Date Formatter

**Estimated time:** 2-3 hours total

**Pro tip:** Set a timer for each phase. If you go over, take a quick break and reassess. Don't get stuck—check "Common Issues" section or move forward with simplified version.

---

**Status:** Ready to build! 🚀  
**Difficulty:** Medium (real-time + local-first = some complexity)  
**Reward:** Main screen working, big milestone! 🎉

