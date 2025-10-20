# PR #5: Chat Service & Firestore Integration - Quick Start

---

## TL;DR (30 seconds)

**What:** Build ChatService - the core messaging service that connects our Swift app to Firebase Firestore for real-time chat.

**Why:** This is the foundation of all messaging features. Without this, users can't send or receive messages.

**Time:** 3-4 hours

**Complexity:** HIGH (real-time listeners, async operations, error handling)

**Status:** 📋 PLANNED

---

## Decision Framework (2 minutes)

### Should You Build This?

**Green Lights (Build it!):**
- ✅ PR #4 (Core Models) is complete - Message and Conversation models exist
- ✅ You have 3-4 hours of focused time available
- ✅ Firebase is configured and working (PR #1)
- ✅ Auth is working (PR #2, #3)
- ✅ You understand async/await in Swift
- ✅ You're comfortable with Firestore basics

**Red Lights (Skip/defer it!):**
- ❌ PR #4 not complete (models are required)
- ❌ Time-constrained (< 3 hours available)
- ❌ Firebase not working
- ❌ Not familiar with async/await or AsyncThrowingStream
- ❌ Other critical bugs to fix first

**Decision Aid:**

If you have models (PR #4) and 3+ hours, **BUILD IT NOW**. This is the most important service in the app. Everything else depends on it.

If models aren't ready, finish PR #4 first (only 1-2 hours).

If you're unfamiliar with async/await, spend 30 minutes on Apple's documentation first. It's essential for this PR.

---

## Prerequisites (5 minutes)

### Required (must have)
- [ ] PR #1 complete (Firebase integrated)
- [ ] PR #2 complete (AuthService working)
- [ ] PR #3 complete (Auth UI working)
- [ ] PR #4 complete (Message, Conversation, MessageStatus models)
- [ ] Xcode 15+ installed
- [ ] Physical device or simulator ready
- [ ] Firebase project active

### Setup Commands
```bash
# 1. Pull latest code
git checkout main
git pull

# 2. Verify PR #4 is merged
ls messAI/Models/
# Should see: User.swift, Message.swift, Conversation.swift, MessageStatus.swift

# 3. Create branch
git checkout -b feature/chat-service

# 4. Open Xcode
open messAI.xcodeproj

# 5. Build to verify (Cmd+B)
# Should build with 0 errors
```

### Knowledge Prerequisites
- **Async/await**: You'll use `async throws` extensively
- **AsyncThrowingStream**: For real-time Firestore listeners
- **Firestore basics**: Collections, documents, queries
- **Error handling**: Do-catch, throwing functions

**Quick References:**
- [Swift Async/Await](https://docs.swift.org/swift-book/LanguageGuide/Concurrency.html)
- [AsyncThrowingStream](https://developer.apple.com/documentation/swift/asyncthrowingstream)
- [Firestore iOS](https://firebase.google.com/docs/firestore/quickstart)

---

## Getting Started (First Hour)

### Step 1: Read Documentation (45 minutes)
- [ ] Read this quick start (10 min)
- [ ] Read PR05_CHAT_SERVICE.md (35 min) - **IMPORTANT!**
  - Focus on "Architecture Decisions" section
  - Study the data flow diagrams
  - Review code examples
- [ ] Skim PR05_TESTING_GUIDE.md (10 min)

**Why this matters:** ChatService is complex. Understanding the architecture before coding saves hours of debugging.

---

### Step 2: Set Up Environment (15 minutes)
- [ ] Create `Services/ChatService.swift` file in Xcode
- [ ] Add to project target
- [ ] Add basic imports:
  ```swift
  import Foundation
  import Firebase
  import FirebaseFirestore
  ```
- [ ] Build (Cmd+B) to verify Firebase imports work
- [ ] Open Firebase Console in browser
- [ ] Navigate to Firestore Database

**Checkpoint:** File created, imports work, Firestore console open ✓

---

### Step 3: Start Phase 1 (Foundation)
- [ ] Open PR05_IMPLEMENTATION_CHECKLIST.md
- [ ] Begin Phase 1: ChatService Foundation
- [ ] Follow checklist step-by-step
- [ ] Check off each item as you complete it
- [ ] Commit after completing Phase 1

**Expected time:** 30-45 minutes

**Checkpoint:** ChatService class exists with error types and cleanup methods ✓

---

## Daily Progress Template

### Day 1 Goals (3-4 hours)

**Morning Session (2 hours):**
- [ ] Read planning docs (45 min)
- [ ] Phase 1: Foundation (45 min)
- [ ] Phase 2: Conversation Management (45 min)

**Break:** 15 minutes

**Afternoon Session (1.5-2 hours):**
- [ ] Phase 3: Message Operations (1 hour)
- [ ] Phase 4: Status Management (45 min)
- [ ] Start Phase 5: Queue Management

**Checkpoint:** Core functionality working (conversations, messages, status)

---

### Day 2 Goals (if needed)

**Session (1 hour):**
- [ ] Complete Phase 5: Queue Management
- [ ] Phase 6: Firestore Security Rules
- [ ] Testing Phase (30-45 min)
- [ ] Documentation updates

**Checkpoint:** All features complete, tested, and deployed ✓

---

## Common Issues & Solutions

### Issue 1: AsyncThrowingStream not compiling
**Symptoms:** Errors like "Cannot convert value" or "Expected AsyncSequence"

**Cause:** Incorrect closure syntax

**Solution:**
```swift
// ✅ CORRECT
AsyncThrowingStream { continuation in
    let listener = db.collection("messages")
        .addSnapshotListener { snapshot, error in
            // ...
        }
    
    continuation.onTermination = { @Sendable _ in
        listener.remove()
    }
}

// ❌ WRONG
AsyncThrowingStream { snapshot, error in
    // Missing continuation parameter
}
```

---

### Issue 2: Firestore listener not triggering
**Symptoms:** No console logs, data not updating

**Cause:** Query syntax error or listener not stored

**Solution:**
```swift
// Store the listener!
self.listeners["messages-\(conversationId)"] = listener

// Verify query syntax matches data structure
.order(by: "sentAt", descending: false) // Field name must match Firestore
```

---

### Issue 3: Permission denied errors
**Symptoms:** Firestore operations fail with "permission-denied"

**Cause:** Security rules too restrictive or not deployed

**Solution:**
```bash
# 1. Check Firestore rules in console (Rules tab)
# 2. Verify rules deployed:
firebase deploy --only firestore:rules

# 3. For testing, temporarily use test mode:
# (Firestore console → Rules tab → "Test mode" rules)
# Then tighten later
```

---

### Issue 4: Messages appearing out of order
**Symptoms:** New messages at wrong position in list

**Cause:** Incorrect sort order

**Solution:**
```swift
// ✅ CORRECT - Oldest first
.order(by: "sentAt", descending: false)

// ❌ WRONG - Newest first (awkward for chat)
.order(by: "sentAt", descending: true)
```

---

### Issue 5: Memory leak with listeners
**Symptoms:** App slows down, memory usage increases

**Cause:** Listeners not detached

**Solution:**
```swift
// Always implement deinit with cleanup
deinit {
    cleanup()
}

// Call detach when view disappears
func detachConversationListener(conversationId: String) {
    listeners["messages-\(conversationId)"]?.remove()
    listeners.removeValue(forKey: "messages-\(conversationId)")
}
```

---

## Quick Reference

### Key Files
- `Services/ChatService.swift` - Main service (~400 lines)
- `firebase/firestore.rules` - Security rules (~100 lines)
- `Models/Message.swift` - From PR #4
- `Models/Conversation.swift` - From PR #4

### Key Methods

**Conversation Management:**
```swift
func createConversation(participants: [String], isGroup: Bool, groupName: String?) async throws -> Conversation

func fetchConversations(userId: String) -> AsyncThrowingStream<[Conversation], Error>
```

**Message Operations:**
```swift
func sendMessage(conversationId: String, text: String, imageURL: String?) async throws -> Message

func fetchMessages(conversationId: String) -> AsyncThrowingStream<[Message], Error>
```

**Status Management:**
```swift
func updateMessageStatus(messageId: String, conversationId: String, status: MessageStatus) async throws

func markAsRead(conversationId: String) async throws
```

**Queue Management:**
```swift
func retryPendingMessages() async

func getPendingMessages(for conversationId: String) -> [Message]
```

### Key Concepts

**Optimistic UI:**
```
1. Create message locally (instant)
2. Show in UI immediately
3. Upload to Firestore (background)
4. Update status on success/failure
```

**Real-Time Listeners:**
```
1. Set up snapshot listener
2. Store listener reference
3. Yield data via AsyncThrowingStream
4. Detach on termination (cleanup)
```

**Error Mapping:**
```
Firestore Error → ChatError → User-Friendly Message
unavailable → networkUnavailable → "No internet connection"
permissionDenied → permissionDenied → "You don't have permission"
```

---

## Useful Commands

### Firebase CLI
```bash
# Login to Firebase
firebase login

# Initialize Firestore
firebase init firestore

# Deploy rules only
firebase deploy --only firestore:rules

# Check deployment status
firebase deploy --only firestore:rules --dry-run
```

### Git Workflow
```bash
# Commit frequently
git add Services/ChatService.swift
git commit -m "feat(chat): implement conversation management"

# After each major phase
git add .
git commit -m "feat(chat): implement message operations"

# Final commit
git commit -m "feat(chat): complete ChatService - all features working"
```

### Xcode Shortcuts
- **Build**: Cmd+B
- **Run**: Cmd+R
- **Stop**: Cmd+.
- **Clean**: Cmd+Shift+K
- **Show console**: Cmd+Shift+Y

---

## Success Metrics

**You'll know it's working when:**
- [ ] Can create conversation in Firestore (check console)
- [ ] Can send message (appears in Firestore messages subcollection)
- [ ] Real-time listener fires when new message added
- [ ] Console shows debug logs for all operations
- [ ] Pending messages queue when offline
- [ ] Status updates work (sent → delivered → read)
- [ ] Security rules deployed successfully
- [ ] No permission denied errors for valid operations

**Performance Targets:**
- Message send: < 500ms average
- Real-time delivery: < 2 seconds
- Listener setup: < 1 second

**Quality Gates:**
- Zero data loss
- No duplicate messages
- Messages in chronological order
- No console errors
- Listeners clean up properly

---

## Help & Support

### Stuck on Implementation?
1. Check PR05_IMPLEMENTATION_CHECKLIST.md for step-by-step instructions
2. Review code examples in PR05_CHAT_SERVICE.md
3. Check "Common Issues" section above
4. Search Firestore documentation
5. Test with Firebase Emulator first (optional but helpful)

### Stuck on Async/Await?
- Read [Swift Concurrency Book](https://docs.swift.org/swift-book/LanguageGuide/Concurrency.html)
- Key concepts: `async`, `await`, `Task`, `AsyncThrowingStream`
- Practice with simple async function first

### Stuck on Firestore?
- Check [Firestore iOS Quickstart](https://firebase.google.com/docs/firestore/quickstart)
- Review [Query documentation](https://firebase.google.com/docs/firestore/query-data/queries)
- Test queries in Firestore console first

### Want to Skip Security Rules?
**Don't!** Security rules are critical. But if you're stuck:
1. Use test mode temporarily (allows all operations)
2. Focus on getting core functionality working
3. Come back to rules before pushing to production

---

## What Can Be Skipped?

### Can Skip (Optional):
- ❌ Nothing! All features are required for MVP

### Can Simplify (Temporarily):
- ⚠️ Retry logic - basic version OK for now, improve in PR #6
- ⚠️ Queue management - in-memory OK, persistent in PR #6
- ⚠️ Detailed logging - add more in polish phase

### Must NOT Skip:
- ✅ Conversation creation
- ✅ Message sending
- ✅ Real-time listeners
- ✅ Status tracking
- ✅ Security rules
- ✅ Error handling

---

## Time Management

**If you're running out of time:**

### After 2 hours:
- Should have: Phases 1-2 complete (foundation + conversations)
- If not: Reduce logging, skip optional comments

### After 3 hours:
- Should have: Phases 1-4 complete (through status management)
- If not: Basic queue management, deploy rules, minimal testing

### After 4 hours:
- Should have: Everything complete including testing
- If not: Focus on core features, document TODOs

**Priority Order:**
1. Send/receive messages (P0 - must have)
2. Real-time listeners (P0 - must have)
3. Conversation management (P0 - must have)
4. Security rules (P0 - must have)
5. Status tracking (P1 - highly important)
6. Queue management (P1 - important, but can be in-memory)
7. Retry logic (P2 - nice to have, improve in PR #6)

---

## Motivation

**You've got this!** 💪

You've already built:
- ✅ Firebase integration (PR #1)
- ✅ Authentication (PR #2, #3)
- ✅ Data models (PR #4)

ChatService brings it all together. After this PR, users can have **real-time conversations**—the core of any messaging app!

This is complex, but follow the checklist step-by-step and you'll be fine. Break it into phases, test after each phase, and commit frequently.

**By the end of this PR:** Messages will flow in real-time between users. That's the magic moment when the app comes alive! 🎉

---

## Phases Summary

| Phase | Focus | Time | Complexity |
|-------|-------|------|------------|
| 1 | Foundation (errors, cleanup) | 30-45 min | LOW |
| 2 | Conversations (create, fetch) | 45-60 min | MEDIUM |
| 3 | Messages (send, fetch) | 60-75 min | HIGH |
| 4 | Status (update, mark read) | 30-45 min | MEDIUM |
| 5 | Queue (retry, pending) | 20-30 min | LOW |
| 6 | Security Rules (deploy) | 30 min | MEDIUM |
| 7 | Testing | 30-45 min | - |

**Total:** 3-4 hours

---

## Next Steps

**When ready:**

1. ☕ Grab coffee/tea (you'll need focus for 3-4 hours)
2. 📚 Read main spec: PR05_CHAT_SERVICE.md (45 min)
3. 📝 Open checklist: PR05_IMPLEMENTATION_CHECKLIST.md
4. 💻 Start Phase 1: Create ChatService.swift
5. ✅ Check off tasks as you go
6. 🚀 Commit after each phase
7. 🎉 Celebrate when tests pass!

**Pro tip:** Set a timer for each phase. If you're going over time, note what's taking longer and adjust expectations.

---

**Status:** Ready to build! 🚀  
**Complexity:** HIGH but manageable  
**Impact:** CRITICAL - this is the heart of the messaging system

**Remember:** Real-time messaging is what makes or breaks a chat app. Take the time to get this right. Everything else builds on this foundation.

---

*"Great things are done by a series of small things brought together." - Vincent Van Gogh*

Let's build the messaging service that brings everything together! 💪

