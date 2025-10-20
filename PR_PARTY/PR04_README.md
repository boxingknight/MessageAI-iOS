# PR #4: Core Models & Data Structure - Quick Start

---

## TL;DR (30 seconds)

**What:** Creating the fundamental data models (Message, Conversation, MessageStatus, TypingStatus) that power the entire messaging system.

**Why:** These models define how we structure, store, and sync chat data. Everything else builds on this foundation.

**Time:** 1-2 hours estimated

**Complexity:** LOW-MEDIUM (straightforward structs, but needs careful design)

**Status:** 📋 PLANNED

---

## Decision Framework (2 minutes)

### Should You Build This?

**Green Lights (Build it!):**
- ✅ PR #2 complete (User model pattern established)
- ✅ You understand Swift structs and protocols
- ✅ You have 1-2 hours available
- ✅ You're ready to build the core messaging foundation
- ✅ You want to learn Firestore data modeling

**Red Lights (Skip/defer it!):**
- ❌ PR #2 not complete (need User model pattern first)
- ❌ Don't have time (this blocks all messaging features)
- ❌ Uncomfortable with Swift optionals/protocols
- ❌ Want to see UI first (models are backend/data layer)

**Decision Aid:** This PR is **critical path** for messaging. Without these models, you can't build chat services or UI. It's also relatively quick (1-2 hours) and low-risk. **Strong recommendation: Build it now.**

---

## Prerequisites (5 minutes)

### Required
- [x] PR #2 deployed and working (User model exists)
- [x] Firebase SDK integrated
- [x] FirebaseFirestore package available in Xcode
- [x] Understanding of Swift structs, protocols, optionals
- [x] Basic knowledge of Firestore data structure

### Helpful to Know
- Swift Codable protocol (for JSON/Firestore conversion)
- SwiftUI @Published / ObservableObject patterns (models will work with these)
- Firestore Timestamp type
- Swift optionals and nil coalescing

### Setup Commands
```bash
# 1. Pull latest from main
git checkout main
git pull origin main

# 2. Create feature branch
git checkout -b feature/core-models

# 3. Open Xcode project
open messAI.xcodeproj

# 4. Verify Firebase imports work
# In Xcode: Build (⌘B) - should succeed
```

---

## Getting Started (First Hour)

### Step 1: Read Documentation (45 minutes)
- [ ] Read this quick start (10 min)
- [ ] Read main specification (`PR04_CORE_MODELS.md`) (35 min)
  - Focus on "Data Models" section
  - Understand Firestore conversion patterns
  - Review decisions (struct vs class, ID generation, etc.)
- [ ] Note any questions

**Key Concepts to Understand:**
- **Why structs?** Value types, SwiftUI-friendly, thread-safe
- **Why UUID?** Enables optimistic UI, works offline
- **Why Date instead of Timestamp?** Native Swift, type-safe
- **Why enums?** Type-safe, autocomplete, compile-time checks

### Step 2: Set Up Environment (5 minutes)
- [ ] Open Xcode
- [ ] Navigate to `Models/` folder
- [ ] Verify User.swift from PR #2 is there
- [ ] Ready to create new files

### Step 3: Start Phase 1 - MessageStatus (10 minutes)
- [ ] Open implementation checklist
- [ ] Create `MessageStatus.swift`
- [ ] Define enum with cases
- [ ] Add display properties
- [ ] Build and verify
- [ ] Commit

**You should have:** A working MessageStatus enum that compiles

---

## Daily Progress Template

### Hour 1: MessageStatus + Message Model (60 minutes)
- [ ] Phase 1: MessageStatus enum (15 min)
  - Create file
  - Define enum
  - Add computed properties
  - Test and commit
- [ ] Phase 2: Message model (45 min)
  - Create file
  - Define struct
  - Add initializers
  - Add Firestore conversion
  - Test and commit

**Checkpoint:** MessageStatus and Message models working, can create instances

---

### Hour 2: Conversation + TypingStatus (60 minutes)
- [ ] Phase 3: Conversation model (30 min)
  - Create file
  - Define struct
  - Add 1-on-1 and group initializers
  - Add computed properties
  - Add Firestore conversion
  - Test and commit
- [ ] Phase 4: TypingStatus model (15 min)
  - Create file
  - Define struct
  - Add Firestore conversion
  - Test and commit
- [ ] Phase 5: Testing & validation (15 min)
  - Create test function
  - Test all models
  - Test Firestore round-trip
  - Test edge cases
  - Remove test code

**Checkpoint:** All 4 models complete, tested, and validated

---

## Common Issues & Solutions

### Issue 1: "Cannot find 'Timestamp' in scope"
**Symptoms:** Xcode error when using `Timestamp(date: someDate)`  
**Cause:** FirebaseFirestore not imported  
**Solution:**
```swift
import FirebaseFirestore
```

---

### Issue 2: "Cannot find 'Auth' in scope"
**Symptoms:** Error in Message.isFromCurrentUser computed property  
**Cause:** FirebaseAuth not imported  
**Solution:**
```swift
import FirebaseAuth
```

---

### Issue 3: Optional unwrapping crashes
**Symptoms:** App crashes when accessing optional fields  
**Cause:** Force unwrapping with `!`  
**Solution:** Use safe unwrapping
```swift
// ❌ BAD
let url = message.imageURL!  // Crashes if nil

// ✅ GOOD
if let url = message.imageURL {
    // Use url safely
}

// ✅ ALSO GOOD
let url = message.imageURL ?? "default.jpg"
```

---

### Issue 4: Firestore conversion returns nil
**Symptoms:** `Message(dictionary: dict)` returns nil  
**Cause:** Missing required field or type mismatch  
**Solution:** Check all guard conditions
```swift
// Verify all these are present in dictionary:
// - id: String
// - conversationId: String
// - senderId: String
// - text: String
// - sentAt: Timestamp
// - status: String (valid MessageStatus raw value)
```

---

### Issue 5: UUID not unique enough?
**Symptoms:** Worried about UUID collisions  
**Cause:** Misunderstanding UUID probability  
**Solution:** UUID collision probability is astronomically low (2^-122). You're more likely to win the lottery 10 times in a row. Use UUID confidently.

---

### Issue 6: Confusion about var vs let
**Symptoms:** Can't mutate properties  
**Cause:** Marked as `let` instead of `var`  
**Solution:**
```swift
// Use let for immutable (never changes)
let id: String
let senderId: String

// Use var for mutable (will change)
var status: MessageStatus      // Changes as message delivers
var deliveredAt: Date?          // Set later
```

---

## Quick Reference

### Key Files Created
1. **MessageStatus.swift** (~40 lines)
   - Enum with 5 cases: sending, sent, delivered, read, failed
   - Display properties: displayText, iconName, color

2. **Message.swift** (~200 lines)
   - Main message model
   - Firestore conversion methods
   - Computed properties for UI

3. **Conversation.swift** (~250 lines)
   - Conversation model (1-on-1 and group)
   - Display name/photo helpers
   - Group admin management

4. **TypingStatus.swift** (~60 lines)
   - Real-time typing indicators
   - Staleness detection

### Key Concepts

**Identifiable:**
- Provides `id` property
- SwiftUI can track items in lists

**Codable:**
- Can encode/decode to JSON
- Used for local storage later

**Equatable:**
- Can compare with `==`
- SwiftUI uses for change detection

**Hashable:**
- Can use in Set/Dictionary
- Enables efficient lookups

### Firestore Conversion Pattern

**To Firestore:**
```swift
func toDictionary() -> [String: Any] {
    var dict: [String: Any] = [
        "requiredField": value,
        "dateField": Timestamp(date: dateValue)
    ]
    
    if let optional = optionalField {
        dict["optionalField"] = optional
    }
    
    return dict
}
```

**From Firestore:**
```swift
init?(dictionary: [String: Any]) {
    guard
        let required = dictionary["requiredField"] as? String,
        let timestamp = dictionary["dateField"] as? Timestamp
    else {
        return nil  // Missing required field
    }
    
    self.requiredField = required
    self.dateField = timestamp.dateValue()
    self.optionalField = dictionary["optionalField"] as? String
}
```

### Testing Pattern

```swift
// Create instance
let message = Message(conversationId: "c1", senderId: "u1", text: "Hello")

// Convert to Firestore and back
let dict = message.toDictionary()
let recovered = Message(dictionary: dict)

// Verify
print("Success: \(recovered != nil)")
print("Text matches: \(recovered?.text == message.text)")
```

---

## Success Metrics

**You'll know it's working when:**
- [ ] All 4 model files created and compile
- [ ] Can create instances: `Message(...)`, `Conversation(...)`, etc.
- [ ] Firestore conversion round-trip works (to dict and back)
- [ ] Computed properties return expected values
- [ ] No compilation errors or warnings
- [ ] Test function prints success messages

**Performance Targets:**
- Model creation: < 1ms (instant)
- Firestore conversion: < 1ms (instant)
- Zero memory leaks (structs are value types)

---

## Help & Support

### Stuck on Firestore Conversion?
1. Check the User model from PR #2 (same pattern)
2. Verify all required fields are `guard`ed
3. Use `print(dictionary)` to see what's in the dict
4. Ensure Timestamp conversion: `Timestamp(date:)` and `.dateValue()`

### Confused About Optionals?
- `String` = required, always has value
- `String?` = optional, might be nil
- Use `if let` or `??` to safely unwrap

### Want to See Examples?
- Look at `User.swift` from PR #2 (same patterns)
- Look at planning doc "Data Models" section (code examples)

### Running Out of Time?
**Priority order if you need to cut corners:**
1. **Must have:** MessageStatus, Message (core functionality)
2. **Should have:** Conversation (needed for PR #5)
3. **Nice to have:** TypingStatus (can add later)

But honestly, all 4 models are quick (15-30 min each). Do them all.

---

## What Comes After This?

**Immediate next PR:** PR #5 - Chat Service & Firestore Integration
- Will use these models to interact with Firestore
- Will implement real-time listeners
- Will handle message sending/receiving

**Why these models matter:**
- Every message in the app uses `Message` model
- Every chat uses `Conversation` model
- Status indicators use `MessageStatus` enum
- Real-time typing uses `TypingStatus` model

**What you're building:**
```
These models ARE your data layer.
     ↓
Services use models to talk to Firebase
     ↓
ViewModels use models for business logic
     ↓
Views use models for display
```

---

## Motivation

**You've got this!** 💪

This PR is **short and satisfying**. In 1-2 hours, you'll have:
- ✅ Solid data models
- ✅ Type-safe code
- ✅ Firestore integration foundation
- ✅ Foundation for all messaging features

These models will power **every message** in your app. You're building the skeleton of the entire messaging system.

Plus, models are **low risk** (just structs!) and **high value** (everything needs them).

---

## Next Steps

**When ready:**
1. Run prerequisites (5 min)
2. Read main spec (`PR04_CORE_MODELS.md`) (35 min)
3. Start Phase 1 from implementation checklist
4. Create MessageStatus enum (15 min)
5. Create Message model (30 min)
6. Create Conversation model (30 min)
7. Create TypingStatus model (15 min)
8. Test everything (15 min)
9. Commit and celebrate! 🎉

**Total time:** 1.5-2 hours

**Status:** Ready to build! 🚀

---

## Pro Tips

### Tip 1: Follow User Model Pattern
The User model from PR #2 is your blueprint. Same pattern:
- Struct with properties
- Conformances (Identifiable, Codable, etc.)
- toDictionary() method
- init?(dictionary:) method

Copy the pattern, adapt for each model.

### Tip 2: Use Xcode Autocomplete
After defining the struct, Xcode can generate:
- Memberwise initializer (if you don't define one)
- Codable conformance (synthesized by compiler)
- Equatable conformance (synthesized by compiler)

Let Xcode help you!

### Tip 3: Test As You Go
Don't wait until the end. After each model:
- Create an instance
- Print it
- Convert to dict
- Verify it works

Catch issues early.

### Tip 4: Think About the Future
These models will be used EVERYWHERE:
- In chat service (PR #5)
- In SwiftData (PR #6)
- In UI components (PRs #7-9)
- In real-time listeners (PR #10)

Spend the time to get them right now.

---

**Remember:** This is not a big PR. It's just 4 structs. But these 4 structs are the foundation of your entire messaging system. Build them with care. 🏗️

---

*Last updated: October 20, 2025*  
*Next update: After PR #4 implementation*

