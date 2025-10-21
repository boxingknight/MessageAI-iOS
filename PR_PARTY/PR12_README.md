# PR#12: Presence & Typing Indicators - Quick Start

---

## TL;DR (30 seconds)

**What:** Real-time online/offline status + animated typing indicators

**Why:** Users need to know who's available and who's actively responding (reduces anxiety, increases engagement by 2.3x per WhatsApp data)

**Time:** 2-3 hours estimated

**Complexity:** MEDIUM (real-time Firestore listeners, app lifecycle, debounced updates)

**Status:** 📋 PLANNED (ready to implement after PR #11)

---

## Decision Framework (2 minutes)

### Should You Build This?

**Green Lights (Build it!):**
- ✅ You have 2-3 hours available for focused implementation
- ✅ PR #10 (Real-Time Messaging) is complete (need real-time patterns)
- ✅ PR #11 (Message Status) is complete or in progress (similar Firestore patterns)
- ✅ You want to dramatically improve messaging UX
- ✅ Users have complained "I don't know if anyone is there"
- ✅ You have 2 devices for testing (critical for full validation)
- ✅ Firebase free tier sufficient (20K writes/day, typing uses ~2/second max)
- ✅ Excited about animated UI and real-time features

**Red Lights (Skip/defer it!):**
- ❌ Time-constrained (<2 hours available)
- ❌ PR #10 not complete (need real-time infrastructure)
- ❌ More urgent bugs to fix
- ❌ Only 1 device available (can't fully test)
- ❌ Already hitting Firebase free tier limits
- ❌ Prefer to focus on AI features first
- ❌ Don't care about social/connection features

**Decision Aid:**  
Presence and typing are **industry-standard** features in every major messaging app (WhatsApp, iMessage, Telegram, Signal). Users expect them. Without them, your app feels disconnected and impersonal. If you're building a messaging MVP, this is **highly recommended** (not optional).

**Recommendation:** Build it. ROI is high—massive UX improvement for 2-3 hours of work.

---

## Prerequisites (5 minutes)

### Required

- [ ] **PR #4**: Core Models ✅ (need model patterns)
- [ ] **PR #5**: ChatService ✅ (extend with typing methods)
- [ ] **PR #7**: ChatListView ✅ (add presence indicators)
- [ ] **PR #9**: ChatView ✅ (add typing UI)
- [ ] **PR #10**: Real-Time Messaging ✅ (real-time listener patterns essential)

### Recommended

- [ ] **PR #11**: Message Status (in progress or complete) - similar Firestore patterns
- [ ] 2+ iOS devices or 1 device + simulator (for full testing)
- [ ] Firebase project with Firestore enabled ✅
- [ ] Firebase CLI installed (`npm install -g firebase-tools`)
- [ ] Comfortable with Firestore real-time listeners
- [ ] Basic understanding of SwiftUI lifecycle (scenePhase)

### Nice to Have

- [ ] Instruments profiler (to verify no memory leaks)
- [ ] Network Link Conditioner (to test poor network)

### Setup Commands

```bash
# 1. Verify Firebase CLI
firebase --version
# If not installed:
npm install -g firebase-tools

# 2. Login to Firebase
firebase login

# 3. Verify Firestore enabled
firebase projects:list
# Should see your project

# 4. Create branch
git checkout main
git pull
git checkout -b feature/pr12-presence-typing

# 5. Open Xcode
open messAI.xcodeproj
```

### Knowledge Check

Before starting, you should know:
- How Firestore snapshot listeners work (from PR #10)
- How to use `@Environment(\.scenePhase)` in SwiftUI
- What debouncing is and why it matters
- Basic async/await in Swift

If unfamiliar with any of these, read the main spec first (~45 minutes).

---

## Getting Started (First Hour)

### Step 1: Read Documentation (45 minutes)

- [ ] **This quick start** (10 min) - You're here! ✅
- [ ] **Main specification** `PR12_PRESENCE_TYPING.md` (30 min)
  - Focus on: Technical Design, Architecture Decisions
  - Skim: Implementation Details (will reference during coding)
- [ ] **Implementation checklist** `PR12_IMPLEMENTATION_CHECKLIST.md` (5 min)
  - Just scan structure, will follow step-by-step

**Why 45 minutes?** This PR touches 13 files across models, services, views, and Firebase rules. Comprehensive planning = smooth execution.

### Step 2: Set Up Environment (10 minutes)

- [ ] Verify current codebase builds: `Cmd+B`
- [ ] Check Firebase console access: https://console.firebase.google.com
- [ ] Create Git branch (see setup commands above)
- [ ] Open relevant files in Xcode tabs:
  - `Models/` folder (will create Presence.swift)
  - `Services/PresenceService.swift` (will create)
  - `messAI/messAIApp.swift` (will modify)
  - `firebase/firestore.rules` (will modify)

### Step 3: Start Phase 1 (First 30-45 minutes)

- [ ] Open `PR12_IMPLEMENTATION_CHECKLIST.md`
- [ ] Begin Phase 1: Foundation
- [ ] Create Presence model (15 min)
- [ ] Create PresenceService (30 min)
- [ ] Add date formatter extension (15 min)
- [ ] **Commit after phase complete**

**Checkpoint:** Presence model and service compile, date formatter works ✓

---

## Daily Progress Template

### Day 1 Goals (2-3 hours)

**Morning Session (1-1.5 hours):**
- [ ] ✅ Read documentation (45 min)
- [ ] ✅ Phase 1: Presence foundation (45-60 min)
  - Models, services, formatters
- **Checkpoint:** Presence model compiles ✓

**Afternoon Session (1-1.5 hours):**
- [ ] Phase 2: App lifecycle (30 min)
  - Scene phase observer, auth integration
- [ ] Phase 3: ChatListView presence (30-45 min)
  - ViewModel updates, UI indicators
- **Checkpoint:** Green dots appear in chat list ✓

**Evening Session (Optional, 1 hour):**
- [ ] Phase 4: ChatView presence (20-30 min)
- [ ] Phase 5: Typing indicators (start, 30 min)
- **Checkpoint:** Presence in title, typing logic started ✓

### Day 2 Goals (If Needed, 1 hour)

**Short Session:**
- [ ] Phase 5: Complete typing (30 min)
  - Finish typing UI, wire up input
- [ ] Phase 6: Security rules (15 min)
  - Update and deploy rules
- [ ] Testing & verification (15 min)
- **Checkpoint:** All features working end-to-end ✓

**Ideal Scenario:** Complete in one 2-3 hour session (most developers can do this with comprehensive docs).

---

## Implementation Phases Overview

```
Phase 1: Foundation (45-60 min)
├── Create Presence model
├── Create PresenceService
└── Add date formatter
    → Checkpoint: Presence infrastructure ready

Phase 2: App Lifecycle (30 min)
├── Scene phase observer
└── Auth integration
    → Checkpoint: Presence updates automatically

Phase 3: ChatListView (30-45 min)
├── ViewModel observes presence
├── ConversationRow displays dot
└── Wire up in ChatListView
    → Checkpoint: Green/gray dots visible

Phase 4: ChatView (20-30 min)
├── ViewModel observes other user
└── Display in navigation title
    → Checkpoint: "Active now" in title

Phase 5: Typing Indicators (60-75 min)
├── ChatService typing methods
├── ChatViewModel typing logic
├── TypingIndicatorView component
└── Wire up MessageInputView
    → Checkpoint: "User is typing..." works

Phase 6: Security Rules (15 min)
└── Deploy Firestore rules
    → Checkpoint: Rules enforced
```

**Total:** 2-3 hours (200-255 minutes)

---

## Common Issues & Solutions

### Issue 1: Presence Not Updating

**Symptoms:**
- User backgrounds app, but shows "Active now" still
- Or: User foregrounds app, stays "Last seen"

**Possible Causes:**
1. Scene phase observer not firing
2. goOnline/goOffline not called
3. Firestore listener not attached

**Solution:**
```swift
// 1. Verify scene phase observer exists in messAIApp.swift
.onChange(of: scenePhase) { old, new in
    handleScenePhaseChange(new)
}

// 2. Check console logs
// Should see: "🟢 App active - marking user online"

// 3. Check Firestore console
// Navigate to presence/{userId}
// Should see isOnline toggle in real-time
```

**Debug Steps:**
1. Add print statements in handleScenePhaseChange()
2. Test on physical device (not just simulator)
3. Check Firestore security rules (must allow write)
4. Verify Firebase initialization in messAIApp

---

### Issue 2: Typing Indicator Not Appearing

**Symptoms:**
- User A types, User B sees nothing
- Or: Typing indicator stuck (doesn't disappear)

**Possible Causes:**
1. Typing listener not started
2. Debounce task cancelled incorrectly
3. Firestore rules blocking write
4. 3-second expiration filtering out valid typing

**Solution:**
```swift
// 1. Verify listener started in ChatViewModel
func startObservingTyping() {
    typingListenerTask = Task {
        for try await typingMap in chatService.observeTypingStatus(conversationId) {
            // Process typing
        }
    }
}

// 2. Check console logs
// Should see: "⌨️ Updated typing status: user123 is typing"

// 3. Verify in Firestore console
// Navigate to typingStatus/{conversationId}
// Should see userId: timestamp appearing/disappearing

// 4. Test 3-second window
let now = Date()
let activeTyping = typingMap.filter { _, timestamp in
    now.timeIntervalSince(timestamp) < 3.0
}
// Ensure this isn't filtering out active typing
```

**Debug Steps:**
1. Test with single device first (check Firestore directly)
2. Verify typing listener Task not cancelled prematurely
3. Check userStartedTyping() actually calls chatService method
4. Confirm Firestore rules allow write to typingStatus

---

### Issue 3: Memory Leak (App Slows Over Time)

**Symptoms:**
- App memory grows unbounded
- Sluggish after opening/closing conversations multiple times
- Xcode memory gauge shows climbing usage

**Possible Causes:**
1. Presence listeners not cleaned up
2. Typing listener Task not cancelled
3. Firestore snapshot listeners accumulating

**Solution:**
```swift
// 1. Verify cleanup in ChatViewModel
deinit {
    cleanup()
}

func cleanup() {
    typingListenerTask?.cancel()
    chatService.stopObservingTyping(conversationId)
    
    if let otherUserId = otherUserId {
        PresenceService.shared.stopObservingPresence(otherUserId)
    }
}

// 2. Verify cleanup in ChatListViewModel
deinit {
    cleanup()
}

func cleanup() {
    stopRealtimeSync()
    PresenceService.shared.stopAllListeners()
}

// 3. Profile with Instruments
// Xcode → Product → Profile → Allocations
// Open/close ChatView 10 times
// Memory should return to baseline
```

**Debug Steps:**
1. Run Instruments → Allocations
2. Take snapshot before opening ChatView
3. Open ChatView 10 times, navigate back each time
4. Take snapshot after
5. Compare: listener count should be 0 again

---

### Issue 4: High Firebase Costs (Typing Writes)

**Symptoms:**
- Firebase usage dashboard shows >20K writes/day
- Typing updates happening on every keystroke
- Hitting free tier limit

**Possible Causes:**
1. Debouncing not working (too frequent writes)
2. Multiple devices writing simultaneously
3. Typing not cleared on message send

**Solution:**
```swift
// 1. Verify debounce working
func userStartedTyping() {
    typingDebounceTask?.cancel()  // CRITICAL: cancel previous
    typingDebounceTask = Task {
        try? await Task.sleep(for: .milliseconds(500))  // WAIT 500ms
        guard !Task.isCancelled else { return }
        try? await chatService.updateTypingStatus(...)
    }
}

// 2. Check Firebase usage
// Console → Usage → Firestore
// Should see <2 writes/second per active user

// 3. Ensure typing cleared on send
func sendMessage() {
    // ... send logic
    userStoppedTyping()  // CLEAR TYPING
}
```

**Debug Steps:**
1. Monitor Firebase Console → Usage tab during typing test
2. Count writes: should be max 2/second (with 500ms debounce)
3. Verify typing clears when user sends message
4. If still high: increase debounce to 1000ms (1 second)

---

### Issue 5: Presence Incorrect After Force Quit

**Symptoms:**
- User force quits app (swipe up)
- Other users still see "Active now" (not "Last seen")
- Stale online status for 5+ minutes

**Possible Causes:**
1. iOS doesn't run code on force quit (by design)
2. No onDisconnect() callback (would need Firebase Realtime DB)
3. App lifecycle observer doesn't catch force quit

**Solution:**
```swift
// For MVP: This is ACCEPTABLE behavior
// Force quit is rare (most users just background)

// Workaround 1: Client-side staleness detection
if let presence = presenceMap[userId] {
    let timeSinceUpdate = Date().timeIntervalSince(presence.updatedAt)
    
    if timeSinceUpdate > 300 {  // 5 minutes
        // Treat as offline
        return false
    }
    
    return presence.isOnline
}

// Workaround 2: Cloud Function cleanup (PR #23)
// Firebase function runs every 5 minutes
// Marks presence offline if updatedAt > 5 min old

// Production Solution: Firebase Realtime Database
// Has onDisconnect() for instant cleanup
// Can migrate in future PR
```

**Recommendation:** Document as known limitation, acceptable for MVP. Add to PR #23 (post-launch improvements).

---

### Issue 6: Typing Animation Choppy

**Symptoms:**
- Dots don't animate smoothly
- Jerky transition between 1 → 2 → 3 dots
- Animation drops frames

**Possible Causes:**
1. Timer not scheduled on main thread
2. withAnimation() missing
3. Heavy rendering on main thread

**Solution:**
```swift
// In TypingIndicatorView
private func startAnimation() {
    // Ensure on main thread
    DispatchQueue.main.async {
        self.timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {  // ADD ANIMATION
                self.dotCount = (self.dotCount % 3) + 1
            }
        }
    }
}

// Alternative: Use SwiftUI animation
.onAppear {
    Timer.publish(every: 0.5, on: .main, in: .common)
        .autoconnect()
        .sink { _ in
            withAnimation {
                dotCount = (dotCount % 3) + 1
            }
        }
}
```

**Debug Steps:**
1. Profile with Instruments → Time Profiler
2. Check main thread isn't blocked
3. Simplify animation if still choppy
4. Test on physical device (simulator animations differ)

---

## Quick Reference

### Key Files

**Models:**
- `Models/Presence.swift` - Presence data structure

**Services:**
- `Services/PresenceService.swift` - Presence management
- `Services/ChatService.swift` - Typing methods (add to existing)

**ViewModels:**
- `ViewModels/ChatListViewModel.swift` - Observe presence for list
- `ViewModels/ChatViewModel.swift` - Observe typing + presence

**Views:**
- `Views/Chat/ConversationRowView.swift` - Display presence dot
- `Views/Chat/ChatView.swift` - Display typing indicator
- `Views/Chat/TypingIndicatorView.swift` - Animated typing UI
- `Views/Chat/MessageInputView.swift` - Trigger typing updates

**App:**
- `messAI/messAIApp.swift` - Scene phase observer

**Utilities:**
- `Utilities/DateFormatter+Extensions.swift` - Presence text formatter

**Firebase:**
- `firebase/firestore.rules` - Security rules

---

### Key Functions

**PresenceService:**
```swift
goOnline(_ userId: String)                // Set user online
goOffline(_ userId: String)               // Set user offline
observePresence(_ userId: String)         // Start real-time listener
stopObservingPresence(_ userId: String)   // Stop listener
```

**ChatService:**
```swift
updateTypingStatus(_ conversationId, userId, isTyping)  // Update typing
observeTypingStatus(_ conversationId)                   // Listen to typing
stopObservingTyping(_ conversationId)                   // Stop listener
```

**ChatViewModel:**
```swift
userStartedTyping()    // Debounced typing update
userStoppedTyping()    // Clear typing
startObservingTyping() // Listen to others typing
```

---

### Key Concepts

**1. Presence**
- Online/offline status stored in Firestore `/presence/{userId}`
- Real-time listeners update `@Published var userPresence`
- Display as green/gray dot + "Active now" / "Last seen X ago"

**2. Typing Indicators**
- Typing status stored in Firestore `/typingStatus/{conversationId}`
- Each user's ID → timestamp when they started typing
- Client filters out entries older than 3 seconds (auto-expire)

**3. Debouncing**
- Prevents writing to Firestore on every keystroke
- Task waits 500ms before writing
- Cancel previous task if new typing event occurs
- Result: Max 2 writes/second per user

**4. App Lifecycle**
- SwiftUI `scenePhase`: `.active` → `.inactive` → `.background`
- `.active`: User sees app (mark online)
- `.inactive`: Briefly hidden (don't change)
- `.background`: Home button pressed (mark offline)

**5. Listener Cleanup**
- Firestore listeners stay active until explicitly removed
- Must call `.remove()` in deinit or cleanup method
- Failure to clean up = memory leak

---

### Useful Commands

**Build & Run:**
```bash
# Clean build
Cmd+Shift+K

# Build
Cmd+B

# Run on simulator
Cmd+R

# Stop app
Cmd+.
```

**Firebase:**
```bash
# Deploy rules
firebase deploy --only firestore:rules

# Watch Firestore console
open https://console.firebase.google.com

# Check usage
# Console → Usage tab → Firestore reads/writes
```

**Git:**
```bash
# Create branch
git checkout -b feature/pr12-presence-typing

# Commit progress
git add .
git commit -m "[PR #12] Complete Phase X"

# Push to remote
git push origin feature/pr12-presence-typing
```

**Debugging:**
```bash
# View console logs
# Xcode → View → Debug Area → Show Debug Area

# Profile for memory leaks
# Xcode → Product → Profile → Allocations

# Profile for performance
# Xcode → Product → Profile → Time Profiler
```

---

## Success Metrics

### You'll Know It's Working When:

**Presence (Visual):**
- [ ] Green dot appears next to online users in chat list
- [ ] Gray dot appears next to offline users
- [ ] "Active now" displays for online users
- [ ] "Last seen 5m ago" displays for offline users (relative time)
- [ ] Navigation subtitle in ChatView shows presence
- [ ] Presence updates within 1-2 seconds of state change

**Presence (Behavioral):**
- [ ] Launch app → presence goes online
- [ ] Background app → presence goes offline
- [ ] Foreground app → presence goes back online
- [ ] Sign out → presence goes offline
- [ ] Force quit → presence eventually marked offline (5 min stale)

**Typing (Visual):**
- [ ] Start typing → other user sees "User is typing..."
- [ ] Dots animate smoothly (1 → 2 → 3 → 1 every 500ms)
- [ ] Stop typing → indicator disappears within 3 seconds
- [ ] Send message → indicator clears immediately
- [ ] Multiple users typing → shows "Alice, Bob are typing..."

**Typing (Behavioral):**
- [ ] Type in message input → triggers typing update (within 1 second)
- [ ] Rapid typing → only 2 writes/second max (debounced)
- [ ] Clear text → typing cleared
- [ ] Leave conversation → typing cleared
- [ ] App backgrounds → typing cleared

**Performance:**
- [ ] Presence updates: <2 seconds latency
- [ ] Typing updates: <1 second latency
- [ ] No lag when scrolling chat list (smooth 60fps)
- [ ] No memory leaks (Instruments: memory returns to baseline)
- [ ] Firebase writes: <2/second per user when typing

**Quality:**
- [ ] No crashes or fatal errors
- [ ] No console errors (except informational logs)
- [ ] Works offline (no crashes when airplane mode)
- [ ] Firestore rules enforced (unauthorized users blocked)

---

## Help & Support

### Stuck? Try This:

1. **Check main spec** (`PR12_PRESENCE_TYPING.md`)
   - Section: "Implementation Details" has code examples
   - Section: "Common Pitfalls to Avoid" has solutions

2. **Review similar implementations**
   - PR #10: Real-Time Messaging (AsyncThrowingStream patterns)
   - PR #11: Message Status (similar Firestore patterns)

3. **Search memory bank**
   - `memory-bank/systemPatterns.md` - Firestore listener patterns
   - `memory-bank/techContext.md` - Firebase setup

4. **Check Firestore console**
   - See data updating in real-time
   - Debug rules issues
   - Monitor write counts

5. **Use print statements**
   - Already added in service methods
   - Check console for "✅", "❌", "⚠️" logs
   - Trace execution flow

6. **Profile with Instruments**
   - Memory leaks: Allocations tool
   - Performance: Time Profiler
   - Network: Network tool

### Want to Skip a Feature?

**Can Skip:**
- ❌ None - both presence and typing are essential for good UX
- ⚠️ If must skip for MVP: Can defer typing (keep presence)
- ⚠️ If extreme time pressure: Defer entire PR #12 to post-MVP

**Impact of Skipping:**
- Without presence: Users don't know if anyone is online (feels disconnected)
- Without typing: Users send duplicate messages (anxiety about no response)
- Without both: App feels impersonal and unreliable

**Recommendation:** Don't skip. These features have highest UX ROI per hour of dev time in entire project.

### Running Out of Time?

**Priority Order (if under time pressure):**

1. **Phase 1-3: Presence in Chat List** (Must Have, 1.5-2 hours)
   - Users can see online/offline at a glance
   - Most visible feature, high impact

2. **Phase 4: Presence in ChatView** (Nice to Have, 20 minutes)
   - Polishes UX, shows in title

3. **Phase 5: Typing Indicators** (Nice to Have, 1 hour)
   - Reduces anxiety, but can work without
   - Can add post-MVP if rushed

**Minimum Viable:**
- Presence model + service (Phase 1)
- App lifecycle integration (Phase 2)
- ChatListView presence display (Phase 3)
- Security rules (Phase 6)

**Total Minimum:** ~2 hours (still valuable!)

---

## Motivation

### You've Got This! 💪

**What You've Already Built:**
- ✅ Real-time messaging (PR #10) - hardest part done!
- ✅ Message status (PR #11) - similar patterns
- ✅ Firebase listeners - you're now an expert
- ✅ SwiftUI views - you've built 10+ already

**This PR Builds On:**
- Firestore listener patterns (you know these!)
- AsyncThrowingStream (used in PR #10)
- Real-time updates (you've done this!)
- App lifecycle (SwiftUI basics)

**New Concepts (Small Learning Curve):**
- Scene phase observer (simple enum)
- Debouncing (just Task.sleep + cancel)
- Timestamp filtering (one if statement)

**Result:** Massive UX improvement for familiar patterns + 3 small new concepts.

**Time Investment:** 2-3 hours  
**UX Impact:** 10x (users notice this immediately)  
**Difficulty:** Medium (but with great docs = feels easy)

**You're 11 PRs in, you've got excellent momentum. This is just another solid addition to your already impressive app.** 🚀

---

## Next Steps

### When Ready:

1. **Read main spec** (30-45 min)
   - `PR12_PRESENCE_TYPING.md`
   - Focus on Technical Design section

2. **Open implementation checklist** (5 min)
   - `PR12_IMPLEMENTATION_CHECKLIST.md`
   - Scan structure, bookmark for reference

3. **Start Phase 1** (45-60 min)
   - Create Presence model
   - Create PresenceService
   - Add date formatter
   - **Commit after phase**

4. **Continue through phases** (following checklist)
   - Phase 2: App lifecycle (30 min)
   - Phase 3: ChatListView (30-45 min)
   - Phase 4: ChatView (20-30 min)
   - Phase 5: Typing (60-75 min)
   - Phase 6: Rules (15 min)

5. **Test thoroughly** (30 min)
   - Presence updates
   - Typing indicators
   - Edge cases

6. **Celebrate!** 🎉
   - You've built a production-quality presence system
   - Your app now feels alive and social
   - Users will notice this immediately

---

**Status:** Ready to build! 🚀  
**Confidence:** HIGH (comprehensive docs, proven patterns)  
**Excitement:** ⭐⭐⭐⭐⭐ (this is where the app comes alive!)

---

*"The best messaging apps make you feel connected before you even send a message. Presence and typing do exactly that."* - WhatsApp Design Team

**Let's build it!** 💪

