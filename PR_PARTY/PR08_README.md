# PR#8: Contact Selection & New Chat - Quick Start

---

## TL;DR (30 seconds)

**What:** Contact picker interface that lets users start new one-on-one conversations

**Why:** Critical path for user engagement - users need a way to initiate chats

**Time:** 2-3 hours estimated

**Complexity:** MEDIUM (ViewModels + UI + service integration)

**Status:** 📋 PLANNED (documentation complete, ready to implement)

---

## Decision Framework (2 minutes)

### Should You Build This?

**Green Lights (Build it!):**
- ✅ PR #7 (Chat List View) is complete
- ✅ You have 2-3 hours available
- ✅ You want users to be able to start conversations
- ✅ Core messaging flow (send/receive) coming next (PR #9-10)

**Red Lights (Skip/defer it!):**
- ❌ PR #7 not complete (dependency required)
- ❌ Time-constrained (<2 hours available)
- ❌ Want to test existing chats first before adding new chat creation

**Decision Aid:** 
This PR is **essential** for MVP. Without it, users can't start conversations. Only skip if you're focusing purely on testing existing features first. But for a complete messaging app, this is a must-have.

---

## What You're Building

### The Big Picture

**User Flow:**
```
ChatListView
    ↓ (Tap "+" button)
ContactsListView (Sheet)
    ↓ (Tap a contact)
Conversation Created/Found
    ↓ (Sheet dismisses)
Back to ChatListView
    → (PR #9 will navigate to chat)
```

### What Gets Created

**5 Files Created:**
1. `Services/ChatService.swift` - Add 2 methods (40 lines)
2. `ViewModels/ContactsViewModel.swift` - Search + conversation logic (200 lines)
3. `Views/Contacts/ContactRowView.swift` - Contact row component (80 lines)
4. `Views/Contacts/ContactsListView.swift` - Main picker view (180 lines)

**2 Files Modified:**
1. `Views/Chat/ChatListView.swift` - Add button + sheet (+30 lines)
2. `ViewModels/ChatListViewModel.swift` - Add conversation starter (+20 lines)

**Total:** ~530 lines of code

---

## Prerequisites (5 minutes)

### Required - Must Have
- [x] PR #4 complete (Models: User, Conversation)
- [x] PR #5 complete (ChatService: createConversation)
- [x] PR #7 complete (ChatListView to integrate with)
- [x] Firebase authenticated and connected
- [x] At least 2 test users registered in Firebase

### Setup Commands
```bash
# 1. Ensure on latest main
git checkout main
git pull origin main

# 2. Create feature branch
git checkout -b feature/pr08-contact-selection

# 3. Open project
open messAI.xcodeproj

# 4. Verify Firebase connection
# - Run app
# - Sign in
# - Check console for Firebase initialization
```

### Knowledge Required
- Basic SwiftUI (VStack, HStack, List)
- @StateObject and @Published patterns
- Async/await syntax
- Sheet presentation modifiers
- Firestore querying (basic)

---

## Getting Started (First Hour)

### Step 1: Read Documentation (30 minutes)
- [ ] Read this quick start (10 min)
- [ ] Skim main specification `PR08_CONTACT_SELECTION.md` (20 min)
  - Focus on "Technical Design" section
  - Review code examples in "Implementation Details"
  - Understand conversation creation flow

**Key Concepts to Understand:**
1. **Check-Then-Create Pattern:** Always check for existing conversation before creating new
2. **Client-Side Search:** Filter users in ViewModel (fast, works offline)
3. **Sheet Presentation:** Modal picker over chat list
4. **Dependency Injection:** Pass ChatService and currentUserId to ViewModel

---

### Step 2: Set Up Environment (15 minutes)
- [ ] Open Xcode project
- [ ] Verify all previous PRs merged to main
- [ ] Create feature branch
- [ ] Run app to confirm it builds and runs
- [ ] Sign in with test account
- [ ] Verify Firebase connected (check console logs)

**Checkpoint:** App runs, you're authenticated ✓

---

### Step 3: Start Phase 1 (ChatService Extensions) (30 minutes)
- [ ] Open implementation checklist
- [ ] Jump to "Phase 1: ChatService Extensions"
- [ ] Add `findExistingConversation()` method
- [ ] Add `fetchAllUsers()` method
- [ ] Test that methods compile
- [ ] Commit changes

**Checkpoint:** ChatService has 2 new methods ✓

---

## Daily Progress Template

### Day 1 Goals (2-3 hours)

**Morning Session (1.5 hours):**
- [ ] Phase 1: ChatService extensions (30-45 min)
- [ ] Phase 2: ContactsViewModel (45-60 min)
- [ ] **Checkpoint:** ViewModel compiles and loads users

**Afternoon Session (1 hour):**
- [ ] Phase 3: ContactRowView (30 min)
- [ ] Phase 4: ContactsListView (45-60 min)
- [ ] **Checkpoint:** Contact picker displays in preview

**Evening Session (30 min):**
- [ ] Phase 5: ChatListView integration (30 min)
- [ ] Quick manual test (contact selection works)
- [ ] Commit and push

**End of Day Checkpoint:** 
Users can tap "+", see contacts, tap contact, conversation created ✓

---

## Common Issues & Solutions

### Issue 1: Contacts Don't Load

**Symptoms:**
- Contact picker shows loading spinner forever
- Console error: "Failed to load contacts"
- Empty state appears immediately

**Cause:** Firestore query failing or no users in database

**Solution:**
```swift
// 1. Check Firebase Console → Firestore
// Verify /users collection exists and has documents

// 2. Check console for specific error
// Look for: "Error fetching users: [error message]"

// 3. Verify ChatService.fetchAllUsers() is being called
// Add print statement:
func fetchAllUsers(excludingUserId: String) async throws -> [User] {
    print("🔍 Fetching all users except: \(excludingUserId)")
    // ... rest of method
}

// 4. Test with simpler query first
let snapshot = try await db.collection("users").getDocuments()
print("📊 Found \(snapshot.documents.count) users")
```

---

### Issue 2: Search Doesn't Filter

**Symptoms:**
- Typing in search bar doesn't change displayed users
- All users always visible regardless of search query

**Cause:** `filteredUsers` computed property not being observed, or search binding incorrect

**Solution:**
```swift
// 1. Verify searchQuery is @Published
@Published var searchQuery: String = ""

// 2. Check filteredUsers is used in view (not allUsers)
ForEach(viewModel.filteredUsers) { user in  // ✅ Correct
    ContactRowView(user: user)
}

// Not:
ForEach(viewModel.allUsers) { user in  // ❌ Wrong
    ContactRowView(user: user)
}

// 3. Test filter logic in isolation
print("Search query: '\(searchQuery)'")
print("All users: \(allUsers.count)")
print("Filtered users: \(filteredUsers.count)")
```

---

### Issue 3: Duplicate Conversations Created

**Symptoms:**
- Tapping same user twice creates 2 conversations
- Firebase shows multiple conversations with same participants

**Cause:** `findExistingConversation()` not working or not being called

**Solution:**
```swift
// 1. Verify findExisting is called FIRST
func startConversation(with user: User) async throws -> Conversation {
    print("🔍 Checking for existing conversation...")
    
    if let existing = try await chatService.findExistingConversation(
        participants: [currentUserId, user.id]
    ) {
        print("✅ Found existing: \(existing.id)")
        return existing
    }
    
    print("➕ Creating new conversation...")
    let new = try await chatService.createConversation(/*...*/)
    print("✅ Created new: \(new.id)")
    return new
}

// 2. Verify participants array is sorted in query
let sortedParticipants = participants.sorted()  // ✅ Important!
// Firestore array equality requires exact order

// 3. Check Firestore security rules allow read
// In firebase/firestore.rules:
match /conversations/{conversationId} {
    allow read: if request.auth.uid in resource.data.participants;
}
```

---

### Issue 4: Sheet Doesn't Dismiss After Selection

**Symptoms:**
- User taps contact, but sheet stays open
- Conversation created but UI doesn't update

**Cause:** `onContactSelected` callback not dismissing sheet

**Solution:**
```swift
// In ContactsListView.handleContactTap:
private func handleContactTap(_ user: User) {
    onContactSelected(user)
    dismiss()  // ✅ Add this if missing
}

// In ChatListView.handleContactSelected:
private func handleContactSelected(_ user: User) {
    Task {
        // ... create conversation ...
        showingContactPicker = false  // ✅ Dismiss sheet
    }
}
```

---

### Issue 5: Current User Appears in List

**Symptoms:**
- Searching shows current user as a contact option
- Can tap own profile and create conversation with self

**Cause:** Filter not excluding current user ID

**Solution:**
```swift
// In ChatService.fetchAllUsers:
let users = snapshot.documents
    .compactMap { try? User.fromFirestore($0.data()) }
    .filter { $0.id != excludingUserId }  // ✅ Verify this line exists

// Verify excludingUserId is passed correctly:
allUsers = try await chatService.fetchAllUsers(
    excludingUserId: currentUserId  // ✅ Pass current user's ID
)
```

---

### Issue 6: Profile Pictures Don't Load

**Symptoms:**
- All users show placeholder initials
- AsyncImage never loads actual photos

**Cause:** Invalid photo URL or Firebase Storage rules

**Solution:**
```swift
// 1. Check user photoURL in Firebase Console
// Should be: "https://firebasestorage.googleapis.com/..."
// Not: "" or nil

// 2. Verify AsyncImage URL is valid
if let photoURL = user.photoURL, !photoURL.isEmpty {
    print("📸 Loading image from: \(photoURL)")
    AsyncImage(url: URL(string: photoURL)) { phase in
        switch phase {
        case .success(let image):
            print("✅ Image loaded successfully")
        case .failure(let error):
            print("❌ Image failed to load: \(error)")
        case .empty:
            print("⏳ Image loading...")
        @unknown default:
            print("❓ Unknown image phase")
        }
    }
}

// 3. Check Firebase Storage rules (if images are there)
// In firebase.storage.rules:
match /profile_pictures/{userId} {
    allow read: if request.auth != null;
}
```

---

## Quick Reference

### Key Files and Their Roles

| File | Purpose | Lines |
|------|---------|-------|
| `ChatService.swift` | Fetch users, find conversations | +40 |
| `ContactsViewModel.swift` | State management, search logic | 200 |
| `ContactRowView.swift` | Individual contact row UI | 80 |
| `ContactsListView.swift` | Main picker interface | 180 |
| `ChatListView.swift` | Integration point (+ button, sheet) | +30 |

---

### Key Methods

**ChatService:**
```swift
findExistingConversation(participants:) -> Conversation?
fetchAllUsers(excludingUserId:) -> [User]
```

**ContactsViewModel:**
```swift
loadUsers() async -> Void
startConversation(with: User) async throws -> Conversation
filteredUsers -> [User] (computed)
```

**ContactsListView:**
```swift
init(chatService:currentUserId:onContactSelected:)
handleContactTap(_ user: User) -> Void
```

---

### Key Concepts

**Check-Then-Create Pattern:**
```swift
// Always check for existing conversation first
if let existing = try await findExisting() {
    return existing  // Reuse
}
return try await createNew()  // Only create if needed
```

**Client-Side Search:**
```swift
var filteredUsers: [User] {
    if searchQuery.isEmpty { return allUsers }
    return allUsers.filter {
        $0.displayName.localizedCaseInsensitiveContains(searchQuery)
    }
}
```

**Sheet Presentation:**
```swift
.sheet(isPresented: $showingPicker) {
    ContactsListView(...) { selectedUser in
        // Handle selection
        showingPicker = false  // Dismiss
    }
}
```

---

## Testing Checklist (Quick)

**Critical Tests (15 minutes):**
- [ ] Tap "+", contact picker appears
- [ ] Search bar filters users correctly
- [ ] Tap user, conversation created
- [ ] Tap same user again, reuses conversation (no duplicate)
- [ ] Current user not in list
- [ ] Empty state shows when no users

**Full Testing:** See `PR08_TESTING_GUIDE.md` for comprehensive test cases

---

## Success Metrics

**You'll know it's working when:**
- [ ] Contact picker loads in <2 seconds
- [ ] Search results appear instantly (<100ms)
- [ ] Tapping contact creates conversation and dismisses sheet
- [ ] No duplicate conversations in Firebase
- [ ] Smooth scrolling with 50+ users (60fps)
- [ ] Memory usage <50MB

---

## Performance Targets

| Metric | Target | How to Measure |
|--------|--------|----------------|
| Load time | <2 seconds | Time from sheet open to users displayed |
| Search speed | <100ms | Time from keystroke to filtered results |
| Memory | <50MB | Xcode Instruments → Memory Profiler |
| Scroll FPS | 60fps | Xcode Debug → View Debugging → FPS |

---

## Help & Support

### Stuck on Implementation?
1. Check `PR08_IMPLEMENTATION_CHECKLIST.md` for step-by-step tasks
2. Review code examples in `PR08_CONTACT_SELECTION.md`
3. Check "Common Issues" section above
4. Search console logs for error messages

### Want to Skip Some Features?
**Can skip:**
- Search functionality (show all users only) - saves 30 min
- Profile picture loading (show initials only) - saves 15 min
- Empty state customization (use basic text) - saves 10 min

**Cannot skip:**
- Contact loading (core feature)
- Conversation creation (critical path)
- Duplicate prevention (data integrity)

**Impact:** Skipping search and pictures = 45 min saved, but noticeably worse UX

---

### Running Out of Time?
**Minimum Viable PR #8 (1.5 hours):**
1. Add ChatService methods (30 min)
2. Basic ContactsViewModel (30 min)
3. Simple ContactsListView (no search, basic UI) (30 min)
4. ChatListView integration (30 min)

**Skip:**
- Search functionality
- Fancy profile pictures
- Empty state polish
- Extensive error handling

**Result:** Users can pick contacts and start chats, but UX is basic

---

## Motivation

**Why This Matters:**

This PR unlocks the entire messaging flow. Without it, users are stuck - they have no way to start conversations. It's the **critical enabler** for:
- PR #9: Chat View (needs conversations to display)
- PR #10: Real-Time Messaging (needs conversations to send messages)
- MVP completion (can't demo without starting chats)

**You're Building:** The bridge between authentication and messaging. After this PR, users can actually **use** the app!

---

## What's Next

**After PR #8:**
→ **PR #9:** Chat View UI Components
   - Message bubbles
   - Message input field
   - Typing indicators
   - Scroll to bottom

**Then:**
→ **PR #10:** Real-Time Messaging
   - Actual message sending
   - Real-time delivery
   - Status tracking

**MVP Complete After:** PR #10 (basic one-on-one messaging working end-to-end!)

---

## Immediate Next Actions

**When Ready to Start:**

**Step 1 (now):** Read this guide (10 min)

**Step 2 (now):** Review main spec (20 min)
```bash
open PR_PARTY/PR08_CONTACT_SELECTION.md
```

**Step 3 (now):** Create branch and open project (5 min)
```bash
git checkout -b feature/pr08-contact-selection
open messAI.xcodeproj
```

**Step 4 (first implementation):** Start Phase 1 from checklist (30 min)
```bash
open PR_PARTY/PR08_IMPLEMENTATION_CHECKLIST.md
# Jump to "Phase 1: ChatService Extensions"
```

---

## Quick Start Commands

```bash
# Setup
git checkout main
git pull
git checkout -b feature/pr08-contact-selection

# During Development
git add .
git commit -m "[PR #8] [Description of what you did]"

# Testing
# Run app: Cmd + R
# Open preview: Cmd + Option + P
# Build only: Cmd + B

# Completion
git push origin feature/pr08-contact-selection
```

---

**Status:** Ready to build! 🚀

**Confidence Level:** HIGH (clear requirements, good examples)

**Recommendation:** Build it! Essential for MVP, well-planned, 2-3 hours investment

---

*"Great software is built one feature at a time. This feature unlocks the entire messaging experience."*

**You've got this!** 💪

---

**Next Step:** Open `PR08_IMPLEMENTATION_CHECKLIST.md` and start Phase 1.

