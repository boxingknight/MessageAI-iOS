# PR#6: Local Persistence with SwiftData - Quick Start

---

## TL;DR (30 seconds)

**What:** Add Core Data persistence layer for offline-first messaging

**Why:** Messages must survive app restarts and work offline (MVP requirements #3 and #10)

**Time:** 2-3 hours estimated

**Complexity:** MEDIUM (Core Data setup + CRUD operations + sync logic)

**Status:** 📋 PLANNED (documentation complete, ready to implement)

---

## Decision Framework (2 minutes)

### Should You Build This?

**Green Lights (Build it!):**
- ✅ PR #4 is complete (Core Models exist)
- ✅ You have 2-3 hours available
- ✅ Comfortable with Core Data (or willing to learn)
- ✅ Ready for database/persistence work
- ✅ Understand offline-first architecture

**Red Lights (Skip/defer it!):**
- ❌ PR #4 not complete (need Message and Conversation models first)
- ❌ Time-constrained (<2 hours available)
- ❌ Unfamiliar with Core Data and no time to learn
- ❌ Want to focus on UI first (can defer, but risky)

**Decision Aid:** 

This PR is **critical for MVP**. Without persistence:
- Messages disappear on app restart (fails MVP requirement #3)
- No offline message composition (fails MVP requirement #10)
- User trust eroded (data loss feels broken)

**Recommendation:** Build now. It's foundational. Everything after this depends on reliable persistence.

---

## Prerequisites (5 minutes)

### Required
- [ ] **PR #4 complete** - Message and Conversation models exist in `Models/`
- [ ] **Xcode 15+** - Core Data support
- [ ] **Firebase SDK** - Already installed from PR #1
- [ ] **iOS 16.0+** - Target deployment (set in PR #1)

### Knowledge Requirements
- **Core Data basics** - Entities, relationships, NSManagedObjectContext
- **Swift** - Classes, protocols, error handling
- **Combine** - @Published properties (light usage)
- **Network monitoring** - NWPathMonitor basics

### Nice to Have
- Experience with Core Data migrations (for future)
- Understanding of offline-first architecture
- Familiarity with data sync patterns

---

## Setup Commands

```bash
# 1. Ensure you're on main with latest changes
git checkout main
git pull origin main

# 2. Verify PR #4 is merged (check for model files)
ls messAI/Models/
# Should show: Message.swift, Conversation.swift, MessageStatus.swift, etc.

# 3. Create feature branch
git checkout -b feature/local-persistence

# 4. Open Xcode project
open messAI.xcodeproj

# 5. Verify Firebase SDK (should already be installed from PR #1)
# In Xcode: File > Packages > Resolve Package Versions
```

---

## Getting Started (First Hour)

### Step 1: Read Documentation (45 minutes)

- [ ] **Read this quick start** (10 min) - You're here!
- [ ] **Read main specification** `PR06_LOCAL_PERSISTENCE_SWIFTDATA.md` (35 min)
  - Focus on "Technical Design" section
  - Review code examples (especially PersistenceController and LocalDataManager)
  - Understand sync strategy

### Step 2: Set Up Core Data Model (15 minutes)

- [ ] **Create `.xcdatamodeld` file** in Xcode
  - File > New > File > Data Model
  - Name: `MessageAI.xcdatamodeld`
  - Location: `messAI/Persistence/` (create folder if needed)

- [ ] **Define entities visually**:
  - MessageEntity: 13 attributes
  - ConversationEntity: 9 attributes
  - Relationship: conversation ↔ messages (one-to-many)

- [ ] **Add indexes** for performance:
  - MessageEntity: `conversationId`, `isSynced`
  - ConversationEntity: `lastMessageAt`

**Expected Result:** Visual data model complete in Xcode's Core Data editor

---

## Implementation Strategy (2-3 hours)

### Phase 1: Core Data Foundation (1 hour)
**Goal:** Core Data stack set up and entity classes created

**Tasks:**
1. Create Core Data model file (`.xcdatamodeld`)
2. Generate entity classes manually (set Codegen to "Manual/None")
3. Create PersistenceController for Core Data stack
4. Test: Build and run, verify "✅ Core Data loaded" in console

**Checkpoint:** App launches with Core Data initialized

---

### Phase 2: Data Manager (1 hour)
**Goal:** Full CRUD operations for messages and conversations

**Tasks:**
1. Create LocalDataManager class
2. Implement message operations:
   - `saveMessage(_:isSynced:)`
   - `fetchMessages(conversationId:)`
   - `updateMessageStatus(id:status:)`
   - `deleteMessage(id:)`
3. Implement conversation operations:
   - `saveConversation(_:)`
   - `fetchConversations()`
   - `deleteConversation(id:)`
4. Add sync query operations:
   - `fetchUnsyncedMessages()`
   - `markAsSynced(messageId:)`
   - `incrementSyncAttempts(messageId:error:)`

**Checkpoint:** Can save and retrieve test messages/conversations

---

### Phase 3: Sync & Network (30-45 minutes)
**Goal:** Offline queue and network-aware sync

**Tasks:**
1. Create NetworkMonitor for connection detection
2. Create SyncManager for queue management
3. Implement network observer (sync when online detected)
4. Implement queue operations (add to queue, sync pending)
5. Test: Simulate offline → queue message → go online → verify sync

**Checkpoint:** Messages queue when offline and sync automatically when online

---

### Phase 4: Integration & Testing (15-30 minutes)
**Goal:** Integrated into app and verified working

**Tasks:**
1. Inject PersistenceController into app environment
2. Manual testing (save/fetch/delete)
3. Persistence testing (restart app, verify data survives)
4. Performance testing (1000 messages insert/fetch)
5. Cleanup test code

**Checkpoint:** All tests passing, performance acceptable

---

## Daily Progress Template

### Day 1 Goals (2-3 hours)

#### Morning Session (1 hour)
- [ ] Read all documentation
- [ ] Set up Core Data model
- [ ] Create entity classes
- [ ] Create PersistenceController
- [ ] **Checkpoint:** Core Data loading successfully

#### Afternoon Session (1 hour)
- [ ] Create LocalDataManager
- [ ] Implement message CRUD
- [ ] Implement conversation CRUD
- [ ] **Checkpoint:** Can save and fetch messages

#### Evening Session (45 minutes)
- [ ] Create NetworkMonitor
- [ ] Create SyncManager
- [ ] Implement sync logic
- [ ] Test offline queueing
- [ ] **Checkpoint:** Offline queue working

**End of Day:** PR #6 complete, messages persist, offline works!

---

## Common Issues & Solutions

### Issue 1: Core Data Model Not Found
**Symptoms:** 
- `fatalError("Core Data failed to load")`
- Container can't find `.xcdatamodeld`

**Cause:** Model file not added to app target

**Solution:**
1. Select `.xcdatamodeld` file in Xcode
2. File Inspector (right pane) > Target Membership
3. Check ✅ `messAI` target
4. Clean build folder (Cmd+Shift+K)
5. Build again

---

### Issue 2: Entity Classes Not Generated
**Symptoms:**
- `Cannot find 'MessageEntity' in scope`
- Compiler errors on entity names

**Cause:** Codegen not set to "Manual/None"

**Solution:**
1. Open `.xcdatamodeld`
2. Select MessageEntity
3. Data Model Inspector > Codegen: "Manual/None"
4. Repeat for ConversationEntity
5. Create entity class files manually (see checklist)

---

### Issue 3: Context Save Fails
**Symptoms:**
- `Failed to save context: <error>`
- Messages not persisting

**Cause:** 
- Required field not set
- Invalid relationship
- Context merge conflict

**Solution:**
1. Check console for specific error
2. Verify all non-optional fields have values
3. Check relationship setup (cascade delete rules)
4. Add debug breakpoint in `save()` method
5. Inspect entity state before save

**Debug Code:**
```swift
func save() {
    let context = container.viewContext
    
    if context.hasChanges {
        do {
            // Debug: Check what changed
            print("🔍 Changed objects: \(context.insertedObjects.count) inserted, \(context.updatedObjects.count) updated")
            
            try context.save()
            print("✅ Context saved successfully")
        } catch {
            // Debug: Print full error
            print("❌ Failed to save context: \(error)")
            print("Details: \(error.localizedDescription)")
        }
    }
}
```

---

### Issue 4: NetworkMonitor Not Detecting Changes
**Symptoms:**
- Console doesn't show "🟢 Online" / "🔴 Offline"
- Sync not triggering when connection restored

**Cause:**
- Simulator network detection limited
- NWPathMonitor not started properly

**Solution:**
1. **Use Network Link Conditioner:**
   - macOS: System Preferences > Developer > Network Link Conditioner
   - Enable "100% Loss" for offline simulation
   
2. **Test on physical device** (more reliable):
   - Enable airplane mode
   - Verify console logs
   
3. **Check NetworkMonitor initialization:**
   ```swift
   // In messAIApp.swift or first view
   let monitor = NetworkMonitor.shared
   
   // Verify in console
   print("Network monitor started: \(monitor.isConnected)")
   ```

---

### Issue 5: Messages Not Syncing After Going Online
**Symptoms:**
- Messages stay in queue (`isSynced: false`)
- No sync triggered when connection restored

**Cause:**
- Network observer not set up
- ChatService integration missing (expected for PR #6)

**Solution:**
1. **Verify NetworkMonitor is publishing:**
   ```swift
   networkMonitor.$isConnected
       .sink { isConnected in
           print("🔔 Network state changed: \(isConnected)")
       }
       .store(in: &cancellables)
   ```

2. **Manually trigger sync** (for testing):
   ```swift
   Task {
       await syncManager.syncPendingMessages()
   }
   ```

3. **Note:** Full sync integration happens in PR #5 with ChatService

---

### Issue 6: Performance Slow with Many Messages
**Symptoms:**
- Fetch takes >1 second for 1000 messages
- UI lags when scrolling message list

**Cause:**
- Missing indexes
- Fetching too much data at once
- Not using batching

**Solution:**
1. **Add indexes** (if missing):
   - Open `.xcdatamodeld`
   - Select MessageEntity > Indexes tab
   - Add index on `conversationId`
   - Add compound index on `conversationId, sentAt`

2. **Use batch fetch limits:**
   ```swift
   func fetchMessages(conversationId: String, limit: Int = 50) throws -> [Message] {
       let fetchRequest: NSFetchRequest<MessageEntity> = MessageEntity.fetchRequest()
       fetchRequest.predicate = NSPredicate(format: "conversationId == %@", conversationId)
       fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \MessageEntity.sentAt, ascending: true)]
       fetchRequest.fetchLimit = limit  // ← Add this
       
       let entities = try context.fetch(fetchRequest)
       return entities.map { $0.toMessage() }
   }
   ```

3. **Profile with Instruments:**
   - Xcode > Product > Profile
   - Choose "Core Data" template
   - Identify slow queries

---

## Quick Reference

### Key Files Created (9 files)

```
messAI/Persistence/
├── MessageAI.xcdatamodeld                      (~50 lines - Core Data model)
├── MessageEntity+CoreDataClass.swift           (~80 lines)
├── MessageEntity+CoreDataProperties.swift      (~60 lines)
├── ConversationEntity+CoreDataClass.swift      (~80 lines)
├── ConversationEntity+CoreDataProperties.swift (~60 lines)
├── PersistenceController.swift                 (~120 lines)
├── LocalDataManager.swift                      (~300 lines)
└── SyncManager.swift                           (~200 lines)

messAI/Utilities/
└── NetworkMonitor.swift                        (~80 lines)
```

**Total:** ~1,030 lines

---

### Key Classes

**PersistenceController:**
- Core Data stack setup
- Persistent container management
- In-memory store for previews/tests
- Singleton: `PersistenceController.shared`

**LocalDataManager:**
- CRUD operations for messages and conversations
- Sync query operations (unsynced, mark synced, retry)
- Batch operations
- Usage: `let manager = LocalDataManager()`

**SyncManager:**
- Queue messages for sync
- Sync pending messages when online
- Network-aware automatic sync
- Retry failed messages with exponential backoff
- Usage: `let syncManager = SyncManager(localDataManager: manager)`

**NetworkMonitor:**
- Detect online/offline state
- Identify connection type (WiFi/cellular)
- Publish connection changes
- Singleton: `NetworkMonitor.shared`

---

### Key Concepts

**Offline-First:**
- Always save to local storage first (instant)
- Sync to Firebase in background (when online)
- User never waits for network

**Optimistic UI:**
- Message appears immediately when sent
- Marked as `isSynced: false`
- Background sync updates to `isSynced: true`
- Status updates follow (sent → delivered → read)

**Sync Strategy:**
- Save local: `isSynced = false`
- Trigger sync immediately if online
- If offline: queue for later
- When connection restored: auto-sync
- Retry on failure (max 5 attempts)

**Entity Conversion:**
```swift
// Swift Model → Core Data Entity
let entity = MessageEntity(context: context, from: message)

// Core Data Entity → Swift Model
let message = entity.toMessage()
```

---

## Testing Checklist

### Must Test Before Marking Complete

- [ ] **Core Data Setup**
  - App launches without crash
  - Console shows "✅ Core Data loaded"
  - No fatal errors

- [ ] **Save & Fetch**
  - Save message locally
  - Fetch message by conversation ID
  - Message data matches exactly

- [ ] **Persistence**
  - Save message
  - Force quit app
  - Restart app
  - Fetch messages
  - Verify message still exists

- [ ] **Offline Queue**
  - Go offline (airplane mode)
  - Queue message (`isSynced: false`)
  - Verify saved locally
  - Go online
  - Verify sync triggered (console logs)

- [ ] **Network Detection**
  - Monitor console for "🟢 Online"
  - Enable airplane mode
  - Verify "🔴 Offline"
  - Disable airplane mode
  - Verify "🟢 Online"

- [ ] **Performance**
  - Insert 1000 messages (<2 seconds)
  - Fetch 1000 messages (<500ms)
  - No UI lag or freezing

---

## Success Metrics

**You'll know it's working when:**

- [ ] ✅ Messages save to Core Data successfully
- [ ] ✅ Messages fetch correctly by conversation ID
- [ ] ✅ Messages persist through app restarts
- [ ] ✅ Offline messages queue locally
- [ ] ✅ NetworkMonitor detects online/offline correctly
- [ ] ✅ Sync triggered automatically when going online
- [ ] ✅ Performance targets met (<2s insert, <500ms fetch)
- [ ] ✅ No console errors or crashes

**Performance Targets:**
- Insert message: <2ms per message
- Fetch messages: <500ms for 1000 messages
- Batch insert: <2 seconds for 1000 messages
- Memory usage: <50MB for 10k messages

**Quality Gates:**
- Zero Core Data crashes
- Zero data loss
- Handles 1000+ messages per conversation
- Works completely offline

---

## Help & Support

### Stuck?
1. Check "Common Issues & Solutions" section above
2. Review main planning doc (`PR06_LOCAL_PERSISTENCE_SWIFTDATA.md`)
3. Examine code examples in main spec
4. Check Apple's Core Data documentation
5. Review PR #4 models (may need adjustments)

### Want to Skip Features?
**What can be skipped:**
- Performance optimization (can defer to PR #21)
- Retry logic details (can simplify to 1 attempt)
- Network type detection (WiFi/cellular - just online/offline is enough)

**What CANNOT be skipped:**
- Core Data setup (foundational)
- Message/conversation CRUD (MVP requirement)
- Persistence through restarts (MVP requirement)
- Offline queueing (MVP requirement)

### Running Out of Time?
**Priority order:**
1. ⚠️ CRITICAL: Core Data setup + PersistenceController
2. ⚠️ CRITICAL: LocalDataManager (save, fetch messages)
3. ⚠️ HIGH: NetworkMonitor + basic SyncManager
4. 🟡 MEDIUM: Retry logic and error handling
5. 🟢 LOW: Performance optimization

**Minimum viable PR:**
- Core Data working
- Messages save and fetch
- Persist through restarts
- (Can add sync in integration with PR #5)

---

## Motivation

**You've Got This!** 💪

This PR is the foundation of offline-first messaging. It's what makes your app feel reliable and trustworthy.

**What You're Building:**
- WhatsApp-level reliability
- Zero data loss guarantee
- Seamless offline experience
- Foundation for real-time sync

**Impact:**
- Users trust your app with their messages
- Works perfectly on airplanes, subways, poor connections
- Fast app launch (local-first)
- Competitive advantage (many apps fail here)

---

## Next Steps

**When Ready:**

1. ⏯️ **Start Phase 1** (Core Data setup)
   - Read checklist: `PR06_IMPLEMENTATION_CHECKLIST.md`
   - Create `.xcdatamodeld` file
   - Define entities visually
   - Create PersistenceController

2. 📝 **Use Checklist as Guide**
   - `PR06_IMPLEMENTATION_CHECKLIST.md` is your step-by-step todo list
   - Check off tasks as you complete them
   - Commit after each phase

3. 🧪 **Test Throughout**
   - Don't wait until the end
   - Test after each phase
   - Use `TestPersistenceView` (in checklist)

4. 📊 **Track Progress**
   - Update memory bank after completion
   - Write complete summary
   - Extract lessons learned

---

**Status:** Ready to build! 🚀

**Next PR:** PR #7 (Chat List View - will use LocalDataManager)

**Timeline:** 2-3 hours (same session or split across days)

---

*Remember: "Offline-first is not a feature, it's a philosophy." This PR embeds that philosophy into your app.*

