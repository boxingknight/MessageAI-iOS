# PR#13: Group Chat Functionality

**Estimated Time:** 3-4 hours  
**Complexity:** HIGH  
**Dependencies:** PR #4 (Models), PR #5 (ChatService), PR #7 (ChatListView), PR #9 (ChatView), PR #10 (Real-Time Messaging), PR #11 (Message Status), PR #12 (Presence/Typing)

---

## Overview

### What We're Building

Group chat transforms one-on-one messaging into **collaborative communication**—enabling teams, families, and friend groups to coordinate seamlessly in one conversation. This PR implements:
- **Group Creation**: Select 2+ participants, name the group, create conversation
- **Group Management**: View participants, add/remove members, leave group
- **Group Messaging**: Send messages to all participants with real-time delivery
- **Group Read Receipts**: Aggregate status (show when all/some have read)
- **Group Identity**: Group name, optional group photo, participant list
- **Group Notifications**: All participants receive messages and updates

Think: WhatsApp groups, iMessage group texts, Slack channels (but simpler).

### Why It Matters

Group chat is **essential** for modern communication—most meaningful conversations involve 3+ people:
- **Work Coordination**: Project teams, departments, committees
- **Family Communication**: Parents, siblings, extended family
- **Social Planning**: Friend groups, event coordination, game nights
- **Community Building**: Interest groups, local organizations, study groups

**Usage Statistics:**
- 65% of WhatsApp users are in at least one group chat
- Average user in 3.2 groups
- Groups have 2x message volume of one-on-one chats
- 87% of users say groups are "essential" or "very important"

**Without group chat:**
- ❌ Can't coordinate with teams/families efficiently
- ❌ Have to send same message multiple times (copy-paste hell)
- ❌ Separate conversations fragment context
- ❌ Can't include everyone in decisions
- ❌ App feels limited, missing core feature

**With group chat:**
- ✅ One message reaches everyone instantly
- ✅ Shared context keeps everyone aligned
- ✅ Inclusive communication (no one left out)
- ✅ Persistent group memory (scroll back to see history)
- ✅ Feature-complete messaging app

### Success in One Sentence

"This PR is successful when users can create group conversations with 3+ participants, send messages that everyone receives in real-time, see aggregated read receipts, view/manage participants, and use all existing features (typing, presence, status) seamlessly in groups."

---

## Technical Design

### Architecture Decisions

#### Decision 1: Group Storage Model

**Options Considered:**
1. **Conversation Model with isGroup Flag** - Extend existing Conversation model
   - Pros: Reuse existing code, simple, consistent API
   - Cons: Mixing 1-on-1 and group logic, could get messy

2. **Separate GroupConversation Model** - New model hierarchy
   - Pros: Clean separation, group-specific fields clear
   - Cons: Duplicate code, inconsistent API, more complex

3. **Hybrid: Conversation + GroupMetadata** - Base model + extension
   - Pros: Shared base, specialized fields, flexible
   - Cons: Two documents to manage, sync complexity

**Chosen:** Conversation Model with isGroup Flag (Option 1)

**Rationale:**
- **Code Reuse**: 80% of group logic same as 1-on-1 (messages, status, typing)
- **Consistent API**: Same ChatService methods work for both
- **SwiftUI Compatibility**: Same view models, just conditional logic
- **Firestore Structure**: Groups and 1-on-1s in same collection (simpler queries)
- **MVP Speed**: Don't duplicate code unnecessarily
- **Extensibility**: Can add group-specific fields easily

**Conversation Model Changes:**
```swift
struct Conversation {
    let id: String
    var participants: [String]         // Existing: 2 for 1-on-1, 3+ for groups
    var isGroup: Bool                  // Existing: distinguish group vs 1-on-1
    var groupName: String?             // NEW: nil for 1-on-1, required for groups
    var groupPhotoURL: String?         // NEW: optional group image
    var createdBy: String              // Existing: group creator
    var admins: [String]?              // NEW: admin user IDs (creator is auto-admin)
    var lastMessage: String
    var lastMessageAt: Date
    var createdAt: Date
}
```

**Trade-offs:**
- Gain: Reuse code, simpler API, faster MVP
- Lose: Slight complexity in conditional logic (acceptable)

---

#### Decision 2: Group Creation Flow

**Options Considered:**
1. **Inline in Chat List** - Tap "+", choose "New Group", select contacts
   - Pros: Consistent with 1-on-1 creation
   - Cons: Many screens (contacts → name → create), long flow

2. **Dedicated Group Creator Modal** - Full-screen group setup wizard
   - Pros: Dedicated focus, clear steps, can show progress
   - Cons: Heavy UI, feels separate from main app

3. **Sheet-Based Flow** - Sheets for each step (select → name → create)
   - Pros: iOS-native, clear hierarchy, dismissible
   - Cons: Multiple sheets (could be confusing)

**Chosen:** Sheet-Based Flow (Option 3) with simplified steps

**Rationale:**
- **iOS Native**: Sheets are standard iOS pattern (feels familiar)
- **Clear Hierarchy**: ChatListView → ContactSheet → GroupSetupSheet → Done
- **Dismissible**: User can cancel at any step (tap outside or X button)
- **Consistent**: Matches existing contact selection sheet pattern
- **Lightweight**: Doesn't take over full screen

**Flow:**
```
ChatListView
  └─ Tap "+" button
       └─ Action Sheet: "New Message" or "New Group"
            └─ Select "New Group"
                 └─ Sheet: ParticipantSelectionView (select 2+ contacts)
                      └─ Sheet: GroupSetupView (enter name, optional photo)
                           └─ Create group
                                └─ Navigate to ChatView
```

**Trade-offs:**
- Gain: Native feel, clear steps, easy to cancel
- Lose: Multiple sheets (but iOS users expect this)

---

#### Decision 3: Group Read Receipts Strategy

**Options Considered:**
1. **Individual Read Indicators** - Show checkmarks per participant
   - Pros: Maximum detail (see who read, who didn't)
   - Cons: UI clutter in large groups, complex rendering

2. **Aggregate Read Status** - Show worst status (if 1 unread, show unread)
   - Pros: Simple, consistent with 1-on-1, clean UI
   - Cons: Less information (can't tell who read)

3. **Hybrid: Aggregate + Detail View** - Aggregate in bubble, tap for detail
   - Pros: Clean default, detail on demand
   - Cons: More complex to implement

**Chosen:** Aggregate Read Status (Option 2) for MVP

**Rationale:**
- **Simplicity**: Reuse existing status logic from PR #11
- **Clean UI**: No clutter, especially in large groups (10+ people)
- **Consistent UX**: Same checkmark patterns as 1-on-1
- **MVP Speed**: Don't need detail view yet
- **User Expectation**: WhatsApp also shows aggregate (not per-person)
- **Can Upgrade**: PR #23 can add tap-to-see-details

**Status Aggregation Logic:**
```swift
extension Message {
    func statusForGroup(currentUserId: String) -> MessageStatus {
        // Sender's perspective
        if senderId == currentUserId {
            if readBy.count == participants.count - 1 {
                return .read  // All others read
            } else if deliveredTo.count == participants.count - 1 {
                return .delivered  // All others received
            } else if deliveredTo.count > 0 {
                return .delivered  // At least one received
            } else {
                return .sent  // No one received yet
            }
        }
        // Recipient's perspective
        return readBy.contains(currentUserId) ? .read : .delivered
    }
}
```

**Visual Indicator:**
- Gray single checkmark: Sent to server
- Gray double checkmark: Delivered to at least one participant
- Blue double checkmark: Read by all participants

**Trade-offs:**
- Gain: Simple, clean, reuses existing code
- Lose: Can't see individual read status (can add later)

---

#### Decision 4: Group Admin Permissions

**Options Considered:**
1. **No Admins (Everyone Equal)** - All participants can add/remove anyone
   - Pros: Democratic, simple
   - Cons: Chaos potential (anyone can kick anyone)

2. **Creator Only Admin** - Only group creator has admin powers
   - Pros: Simple, clear authority
   - Cons: What if creator leaves? Group becomes unmanageable

3. **Multiple Admins** - Creator + promoted admins
   - Pros: Flexible, redundancy, real-world model
   - Cons: More complex permission logic

**Chosen:** Multiple Admins (Option 3) with creator as first admin

**Rationale:**
- **Real-World Pattern**: WhatsApp, Telegram use this model
- **Flexibility**: Creator can delegate admin duties
- **Redundancy**: If creator leaves, other admins can manage
- **Extensibility**: PR #23 can add permission granularity
- **User Expectation**: Users understand admin concept

**Admin Permissions:**
- Add participants
- Remove participants (except other admins)
- Promote participants to admin
- Change group name
- Change group photo
- (Creator only: Delete group)

**Participant Permissions:**
- Send messages
- View messages
- Leave group (self-remove)

**Implementation:**
```swift
struct Conversation {
    var admins: [String]?  // Admin user IDs
    var createdBy: String   // Creator (auto-admin)
    
    func isAdmin(_ userId: String) -> Bool {
        return userId == createdBy || (admins?.contains(userId) ?? false)
    }
}
```

**Trade-offs:**
- Gain: Flexible, resilient, matches user expectations
- Lose: Slightly more complex permission checks (acceptable)

---

#### Decision 5: Group Participant Limit

**Options Considered:**
1. **Unlimited** - No limit on group size
   - Pros: Maximum flexibility
   - Cons: Performance issues (100+ people typing), Firestore cost explosion

2. **256 Participants (WhatsApp Model)** - Industry standard
   - Pros: Proven scale, handles most use cases
   - Cons: Requires optimization for large groups

3. **50 Participants (Practical Limit)** - Conservative for MVP
   - Pros: Performant, manageable, covers 99% of use cases
   - Cons: May disappoint power users

**Chosen:** 50 Participants (Option 3) for MVP

**Rationale:**
- **Performance**: Firestore queries scale well to 50 participants
- **Real-World Usage**: 95% of groups have <20 participants
- **MVP Scope**: Don't optimize for edge cases yet
- **Firestore Cost**: 50 participants × 10 messages/day = 500 reads (manageable)
- **Can Increase**: PR #23 can optimize for larger groups (pagination, etc.)

**Enforcement:**
```swift
func validateGroupSize(participants: [String]) throws {
    guard participants.count >= 3 else {
        throw ChatError.groupTooSmall  // Min 3 (creator + 2 others)
    }
    guard participants.count <= 50 else {
        throw ChatError.groupTooLarge  // Max 50 for MVP
    }
}
```

**UI Feedback:**
- Contact selection: Show count "3 of 50 selected"
- At 50: Disable further selection, show message "Maximum 50 participants"

**Trade-offs:**
- Gain: Performant, manageable, covers 99% of use cases
- Lose: Power users can't create mega-groups (can add later)

---

#### Decision 6: Group Naming Strategy

**Options Considered:**
1. **Auto-Generated Names** - "Alice, Bob, Charlie" (participant names)
   - Pros: No input required, always has a name
   - Cons: Long names (5+ people), unclear for large groups

2. **Required Name Input** - Must enter name to create group
   - Pros: Clear identity, user choice
   - Cons: Friction (one more step), user might skip

3. **Optional Name with Fallback** - User can name, auto-generate if empty
   - Pros: Best of both worlds, flexible
   - Cons: Slightly more complex logic

**Chosen:** Optional Name with Fallback (Option 3)

**Rationale:**
- **Flexibility**: Power users can name, casual users can skip
- **No Friction**: Don't block group creation on name input
- **Clear Identity**: Groups always have a display name
- **User Expectation**: WhatsApp uses this pattern
- **Progressive Enhancement**: Can improve auto-names later

**Name Generation Logic:**
```swift
func generateGroupName(participants: [User], currentUser: User) -> String {
    let otherUsers = participants.filter { $0.id != currentUser.id }
    
    switch otherUsers.count {
    case 0...2:
        // "Alice, Bob"
        return otherUsers.map { $0.displayName }.joined(separator: ", ")
    case 3...4:
        // "Alice, Bob, Charlie, Diana"
        return otherUsers.map { $0.displayName }.joined(separator: ", ")
    default:
        // "Alice, Bob, Charlie, and 5 others"
        let first3 = otherUsers.prefix(3).map { $0.displayName }.joined(separator: ", ")
        let remaining = otherUsers.count - 3
        return "\(first3), and \(remaining) other\(remaining == 1 ? "" : "s")"
    }
}
```

**Trade-offs:**
- Gain: No friction, always has name, flexible
- Lose: Auto-generated names can be long (acceptable)

---

### Data Model Changes

#### Modified: Conversation Model

```swift
// Models/Conversation.swift
import Foundation

struct Conversation: Codable, Identifiable, Equatable, Hashable {
    let id: String
    var participants: [String]
    var isGroup: Bool
    var groupName: String?          // NEW: Optional group name
    var groupPhotoURL: String?      // NEW: Optional group photo
    var admins: [String]?           // NEW: Admin user IDs
    let createdBy: String
    var lastMessage: String
    var lastMessageAt: Date
    let createdAt: Date
    
    // MARK: - Group Helpers
    
    /// Check if user is admin (creator or promoted admin)
    func isAdmin(_ userId: String) -> Bool {
        return userId == createdBy || (admins?.contains(userId) ?? false)
    }
    
    /// Display name for conversation (1-on-1 or group)
    func displayName(currentUserId: String, users: [String: User]) -> String {
        if isGroup {
            if let groupName = groupName, !groupName.isEmpty {
                return groupName
            } else {
                // Auto-generate from participants
                return generateAutoName(currentUserId: currentUserId, users: users)
            }
        } else {
            // 1-on-1: other user's name
            let otherUserId = participants.first { $0 != currentUserId } ?? ""
            return users[otherUserId]?.displayName ?? "Unknown"
        }
    }
    
    private func generateAutoName(currentUserId: String, users: [String: User]) -> String {
        let otherParticipants = participants.filter { $0 != currentUserId }
        let names = otherParticipants.compactMap { users[$0]?.displayName }
        
        switch names.count {
        case 0: return "Empty Group"
        case 1...3: return names.joined(separator: ", ")
        default:
            let first3 = names.prefix(3).joined(separator: ", ")
            let remaining = names.count - 3
            return "\(first3), and \(remaining) other\(remaining == 1 ? "" : "s")"
        }
    }
    
    /// Count of unread messages (placeholder for future)
    var unreadCount: Int {
        return 0  // TODO: Implement in PR #14
    }
    
    // MARK: - Firestore Conversion
    
    func toFirestore() -> [String: Any] {
        var data: [String: Any] = [
            "participants": participants,
            "isGroup": isGroup,
            "createdBy": createdBy,
            "lastMessage": lastMessage,
            "lastMessageAt": lastMessageAt,
            "createdAt": createdAt
        ]
        
        if let groupName = groupName {
            data["groupName"] = groupName
        }
        if let groupPhotoURL = groupPhotoURL {
            data["groupPhotoURL"] = groupPhotoURL
        }
        if let admins = admins {
            data["admins"] = admins
        }
        
        return data
    }
    
    static func fromFirestore(_ data: [String: Any], id: String) -> Conversation? {
        guard let participants = data["participants"] as? [String],
              let isGroup = data["isGroup"] as? Bool,
              let createdBy = data["createdBy"] as? String,
              let lastMessage = data["lastMessage"] as? String,
              let lastMessageTimestamp = data["lastMessageAt"] as? Timestamp,
              let createdAtTimestamp = data["createdAt"] as? Timestamp else {
            return nil
        }
        
        return Conversation(
            id: id,
            participants: participants,
            isGroup: isGroup,
            groupName: data["groupName"] as? String,
            groupPhotoURL: data["groupPhotoURL"] as? String,
            admins: data["admins"] as? [String],
            createdBy: createdBy,
            lastMessage: lastMessage,
            lastMessageAt: lastMessageTimestamp.dateValue(),
            createdAt: createdAtTimestamp.dateValue()
        )
    }
}
```

#### Modified: Message Model

```swift
// Models/Message.swift - Add group status aggregation

extension Message {
    /// Status for sender in group chat (aggregate all recipients)
    func statusForGroup(in conversation: Conversation, currentUserId: String) -> MessageStatus {
        guard conversation.isGroup else {
            // Not a group, use existing logic
            return status
        }
        
        // Sender's perspective
        if senderId == currentUserId {
            let otherParticipants = conversation.participants.filter { $0 != currentUserId }
            let totalRecipients = otherParticipants.count
            
            if totalRecipients == 0 { return .sent }
            
            // Check if all recipients read
            if readBy.count >= totalRecipients {
                return .read
            }
            
            // Check if all recipients received
            if deliveredTo.count >= totalRecipients {
                return .delivered
            }
            
            // Check if at least one received
            if deliveredTo.count > 0 {
                return .delivered
            }
            
            return .sent
        }
        
        // Recipient's perspective (same as 1-on-1)
        if readBy.contains(currentUserId) {
            return .read
        } else if deliveredTo.contains(currentUserId) {
            return .delivered
        } else {
            return .sent
        }
    }
}
```

---

### API Design

#### Modified: ChatService (Group Operations)

```swift
// Services/ChatService.swift - Add group methods

// MARK: - Group Management

/// Create a new group conversation
func createGroupConversation(
    participants: [String],
    groupName: String?,
    createdBy: String
) async throws -> Conversation {
    // Validation
    guard participants.count >= 3 else {
        throw ChatError.groupTooSmall
    }
    guard participants.count <= 50 else {
        throw ChatError.groupTooLarge
    }
    
    // Ensure creator is in participants
    var allParticipants = participants
    if !allParticipants.contains(createdBy) {
        allParticipants.append(createdBy)
    }
    
    // Sort for consistency
    allParticipants.sort()
    
    // Create conversation document
    let conversationRef = db.collection("conversations").document()
    let conversation = Conversation(
        id: conversationRef.documentID,
        participants: allParticipants,
        isGroup: true,
        groupName: groupName,
        groupPhotoURL: nil,
        admins: [createdBy],  // Creator is first admin
        createdBy: createdBy,
        lastMessage: "Group created",
        lastMessageAt: Date(),
        createdAt: Date()
    )
    
    try await conversationRef.setData(conversation.toFirestore())
    
    return conversation
}

/// Update group name
func updateGroupName(_ conversationId: String, name: String) async throws {
    try await db.collection("conversations").document(conversationId)
        .updateData(["groupName": name])
}

/// Update group photo URL
func updateGroupPhoto(_ conversationId: String, photoURL: String) async throws {
    try await db.collection("conversations").document(conversationId)
        .updateData(["groupPhotoURL": photoURL])
}

/// Add participant to group
func addParticipant(_ conversationId: String, userId: String) async throws {
    try await db.collection("conversations").document(conversationId)
        .updateData([
            "participants": FieldValue.arrayUnion([userId])
        ])
}

/// Remove participant from group
func removeParticipant(_ conversationId: String, userId: String) async throws {
    try await db.collection("conversations").document(conversationId)
        .updateData([
            "participants": FieldValue.arrayRemove([userId])
        ])
}

/// Leave group (self-remove)
func leaveGroup(_ conversationId: String, userId: String) async throws {
    try await removeParticipant(conversationId, userId: userId)
}

/// Promote user to admin
func promoteToAdmin(_ conversationId: String, userId: String) async throws {
    try await db.collection("conversations").document(conversationId)
        .updateData([
            "admins": FieldValue.arrayUnion([userId])
        ])
}

/// Demote admin to regular participant
func demoteFromAdmin(_ conversationId: String, userId: String) async throws {
    try await db.collection("conversations").document(conversationId)
        .updateData([
            "admins": FieldValue.arrayRemove([userId])
        ])
}
```

---

### Component Hierarchy

```
ChatListView (existing)
├── "+" Button (modified)
│   └── Action Sheet (NEW)
│       ├── "New Message" → ContactsListView (existing)
│       └── "New Group" → ParticipantSelectionView (NEW)
│
ParticipantSelectionView (NEW)
├── Search bar
├── Selected participants (horizontal scroll)
├── Contact list (multi-select)
└── "Next" button → GroupSetupView
│
GroupSetupView (NEW)
├── Group name input (optional)
├── Add group photo button (optional)
├── Participant list preview
└── "Create Group" button → ChatView
│
ChatView (existing, modified)
├── Navigation Title (modified for groups)
│   ├── Group name (or auto-generated)
│   ├── Subtitle: "X participants" (tap to view)
│   └── Tap → GroupInfoView
│
├── MessageBubbleView (existing)
│   └── Sender name (NEW for groups)
│       └── Shows above message if group
│
└── TypingIndicatorView (existing)
    └── Shows "Alice, Bob are typing..." (group)
│
GroupInfoView (NEW)
├── Group photo (large)
├── Group name (editable if admin)
├── Participant list
│   ├── Each participant row
│   │   ├── Profile picture
│   │   ├── Display name
│   │   ├── "Admin" badge (if admin)
│   │   └── Actions (if you're admin)
│   │       ├── Promote to admin
│   │       ├── Remove from group
│   └── "Add Participants" button (if admin)
├── "Leave Group" button (destructive)
└── "Delete Group" button (creator only, destructive)
```

---

## Implementation Details

### File Structure

**New Files:**
```
messAI/
├── ViewModels/
│   └── GroupViewModel.swift              (~200 lines)
│
└── Views/
    └── Group/
        ├── ParticipantSelectionView.swift (~200 lines)
        ├── GroupSetupView.swift           (~150 lines)
        └── GroupInfoView.swift            (~300 lines)
```

**Modified Files:**
```
messAI/
├── Models/
│   ├── Conversation.swift                (+100 lines)
│   │   └── Add groupName, groupPhotoURL, admins, helpers
│   │
│   └── Message.swift                     (+50 lines)
│       └── Add statusForGroup() method
│
├── Services/
│   └── ChatService.swift                 (+200 lines)
│       └── Add group management methods
│
├── ViewModels/
│   ├── ChatListViewModel.swift           (+30 lines)
│   │   └── Add action sheet for new group
│   │
│   └── ChatViewModel.swift               (+50 lines)
│       └── Add group info navigation
│
└── Views/Chat/
    ├── ChatListView.swift                (+40 lines)
    │   └── Add "New Group" action
    │
    ├── MessageBubbleView.swift           (+30 lines)
    │   └── Show sender name for group messages
    │
    └── ChatView.swift                    (+50 lines)
        └── Update navigation for groups
```

**Total Estimate:**
- New files: ~850 lines
- Modified files: ~550 lines
- **Total: ~1,400 lines** across 13 files

---

### Key Implementation Steps

#### Phase 1: Group Data Model & Service (60-90 minutes)

**Step 1.1: Update Conversation Model** (30 minutes)
1. Open `Models/Conversation.swift`
2. Add new properties: `groupName`, `groupPhotoURL`, `admins`
3. Add `isAdmin()` helper method
4. Add `displayName()` with auto-generation logic
5. Update `toFirestore()` and `fromFirestore()` with new fields
6. Test: Create Conversation instances with group fields

**Commit:** `[PR #13] Add group fields to Conversation model`

---

**Step 1.2: Add Group Methods to ChatService** (30-60 minutes)
1. Open `Services/ChatService.swift`
2. Add method: `createGroupConversation()`
   - Validate participant count (3-50)
   - Create Firestore document with isGroup=true
   - Set creator as first admin
3. Add method: `updateGroupName()`
4. Add method: `updateGroupPhoto()`
5. Add method: `addParticipant()`
6. Add method: `removeParticipant()`
7. Add method: `leaveGroup()`
8. Add method: `promoteToAdmin()` and `demoteFromAdmin()`
9. Add error cases: `.groupTooSmall`, `.groupTooLarge`, `.notAdmin`

**Checkpoint:** ChatService compiles with group methods

**Commit:** `[PR #13] Implement group management methods in ChatService`

---

#### Phase 2: Participant Selection UI (60-75 minutes)

**Step 2.1: Create ParticipantSelectionView** (45 minutes)
1. Create `Views/Group/ParticipantSelectionView.swift`
2. Implement multi-select contact list:
   - Reuse ContactRowView with checkmark
   - `@State var selectedUserIds: Set<String>`
   - Search bar at top
   - Selected participants in horizontal ScrollView
   - Contact list below with checkboxes
3. Add validation:
   - Minimum 2 (+ current user = 3 total)
   - Maximum 49 (+ current user = 50 total)
   - Show count: "3 of 50 selected"
4. Add "Next" button (disabled until 2+ selected)
5. Add dismiss button (X)

**Visual:**
```
┌─────────────────────────────────────┐
│ ← Select Participants            X │
│                                     │
│ 🔍 Search contacts...               │
│                                     │
│ ┌─────────────────────────────┐   │
│ │ [👤 Alice] [👤 Bob] [👤 Cl] │   │  ← Selected (horizontal scroll)
│ └─────────────────────────────┘   │
│                                     │
│ ☑ Alice Thompson                   │
│ ☑ Bob Martinez                     │
│ ☑ Claire Johnson                   │
│ ☐ David Lee                        │
│ ☐ Emma Wilson                      │
│                                     │
│        [Next (3 selected)]          │
└─────────────────────────────────────┘
```

**Commit:** `[PR #13] Create ParticipantSelectionView for group creation`

---

**Step 2.2: Integrate with ChatListView** (30 minutes)
1. Open `Views/Chat/ChatListView.swift`
2. Change "+" button to show Action Sheet:
   ```swift
   .confirmationDialog("New Conversation", isPresented: $showNewConversationOptions) {
       Button("New Message") {
           showContactsSheet = true
       }
       Button("New Group") {
           showParticipantSelection = true
       }
       Button("Cancel", role: .cancel) {}
   }
   ```
3. Add state: `@State private var showParticipantSelection = false`
4. Add sheet presentation:
   ```swift
   .sheet(isPresented: $showParticipantSelection) {
       ParticipantSelectionView(
           onNext: { selectedUsers in
               self.selectedGroupParticipants = selectedUsers
               self.showGroupSetup = true
           }
       )
   }
   ```

**Commit:** `[PR #13] Integrate participant selection in ChatListView`

---

#### Phase 3: Group Setup UI (45-60 minutes)

**Step 3.1: Create GroupSetupView** (45 minutes)
1. Create `Views/Group/GroupSetupView.swift`
2. Implement group setup form:
   - Group name text field (optional, placeholder: "Group Name")
   - Group photo button (MVP: skip, can add in PR #14)
   - Participant list preview (read-only)
   - "Create Group" button
3. Add GroupViewModel for state management:
   ```swift
   @StateObject private var viewModel = GroupViewModel()
   ```
4. Call `viewModel.createGroup()` on button tap
5. On success: dismiss sheets, navigate to ChatView
6. On error: show alert

**Visual:**
```
┌─────────────────────────────────────┐
│ ← New Group                      X │
│                                     │
│ ┌─────────────────────────────┐   │
│ │ Group Name (Optional)        │   │
│ └─────────────────────────────┘   │
│                                     │
│ Add Group Photo (Optional)         │
│                                     │
│ PARTICIPANTS (3)                   │
│ • Alice Thompson                   │
│ • Bob Martinez                     │
│ • Claire Johnson                   │
│                                     │
│         [Create Group]              │
└─────────────────────────────────────┘
```

**Commit:** `[PR #13] Create GroupSetupView for finalizing group`

---

**Step 3.2: Create GroupViewModel** (15 minutes)
1. Create `ViewModels/GroupViewModel.swift`
2. Implement:
   ```swift
   @MainActor
   class GroupViewModel: ObservableObject {
       @Published var groupName: String = ""
       @Published var selectedParticipants: [User] = []
       @Published var isLoading = false
       @Published var errorMessage: String?
       
       private let chatService = ChatService()
       private let authService = AuthService()
       
       func createGroup() async throws -> Conversation {
           isLoading = true
           defer { isLoading = false }
           
           guard let currentUserId = authService.currentUser?.id else {
               throw ChatError.notAuthenticated
           }
           
           let participantIds = selectedParticipants.map { $0.id }
           
           let conversation = try await chatService.createGroupConversation(
               participants: participantIds,
               groupName: groupName.isEmpty ? nil : groupName,
               createdBy: currentUserId
           )
           
           return conversation
       }
   }
   ```

**Commit:** `[PR #13] Create GroupViewModel for group creation logic`

---

#### Phase 4: Group Message Display (30-45 minutes)

**Step 4.1: Update MessageBubbleView for Groups** (20 minutes)
1. Open `Views/Chat/MessageBubbleView.swift`
2. Add parameter: `conversation: Conversation?`
3. If group message AND not from current user:
   - Show sender name above bubble
   - Font: `.caption.bold()`, color: accent color
4. Use `conversation?.displayName()` to get sender's name
5. Add `users: [String: User]` parameter to look up names

**Visual (Group Message):**
```
┌────────────────────────────┐
│ Alice Thompson    [Gray]   │  ← Sender name
│ Hey, are you free?         │  ← Message
│                       14:23│
└────────────────────────────┘
```

**Commit:** `[PR #13] Display sender name in group message bubbles`

---

**Step 4.2: Update Message Status for Groups** (25 minutes)
1. Open `Models/Message.swift`
2. Add method: `statusForGroup(in:currentUserId:)`
3. Aggregate read receipts:
   - If all read: blue double-check
   - If all delivered: gray double-check
   - If partial: gray double-check
4. Update MessageBubbleView to use `statusForGroup()` if conversation is group

**Commit:** `[PR #13] Implement aggregate read receipts for groups`

---

#### Phase 5: Group Info & Management (75-90 minutes)

**Step 5.1: Create GroupInfoView** (60 minutes)
1. Create `Views/Group/GroupInfoView.swift`
2. Implement group info screen:
   - Group photo (large, 200x200)
   - Group name (editable if admin)
   - Participant list:
     - Profile picture + name
     - "Admin" badge if admin
     - Swipe to remove (if you're admin)
   - "Add Participants" button (if admin)
   - "Leave Group" button (everyone)
   - "Delete Group" button (creator only)
3. Use GroupViewModel for actions
4. Add confirmation alerts for destructive actions

**Visual:**
```
┌─────────────────────────────────────┐
│ ← Group Info                        │
│                                     │
│       [Group Photo]                 │
│       Project Team                  │
│       15 participants               │
│                                     │
│ PARTICIPANTS                        │
│ 👤 Alice Thompson         Admin    │
│ 👤 Bob Martinez                    │
│ 👤 Claire Johnson                  │
│ 👤 David Lee              Admin    │
│ ...                                 │
│                                     │
│ [+ Add Participants]      (admin)  │
│                                     │
│ [Leave Group]             (red)    │
└─────────────────────────────────────┘
```

**Commit:** `[PR #13] Create GroupInfoView for group management`

---

**Step 5.2: Integrate in ChatView** (15 minutes)
1. Open `Views/Chat/ChatView.swift`
2. Update navigation title for groups:
   - Show group name (or auto-generated)
   - Subtitle: "X participants"
   - Make tappable → present GroupInfoView
3. Add state: `@State private var showGroupInfo = false`
4. Add sheet:
   ```swift
   .sheet(isPresented: $showGroupInfo) {
       if viewModel.conversation.isGroup {
           GroupInfoView(conversation: viewModel.conversation)
       }
   }
   ```

**Commit:** `[PR #13] Integrate group info navigation in ChatView`

---

**Step 5.3: Implement Group Management in GroupViewModel** (15 minutes)
1. Open `ViewModels/GroupViewModel.swift`
2. Add methods:
   - `updateGroupName()`
   - `addParticipant()`
   - `removeParticipant()`
   - `leaveGroup()`
   - `promoteToAdmin()`
   - `deleteGroup()` (creator only)
3. Call corresponding ChatService methods
4. Handle errors and update UI state

**Commit:** `[PR #13] Implement group management methods in GroupViewModel`

---

#### Phase 6: Firestore Security Rules (15 minutes)

**Step 6.1: Update firestore.rules for Groups** (15 minutes)
1. Open `firebase/firestore.rules`
2. Update conversation rules:
   ```javascript
   // Group participants can read conversation
   match /conversations/{conversationId} {
     allow read: if request.auth != null 
                 && request.auth.uid in resource.data.participants;
     
     // Create group (anyone authenticated)
     allow create: if request.auth != null
                   && request.auth.uid in request.resource.data.participants
                   && request.resource.data.isGroup == true
                   && request.resource.data.createdBy == request.auth.uid;
     
     // Update group (admins only)
     allow update: if request.auth != null
                   && request.auth.uid in resource.data.participants
                   && (request.auth.uid in resource.data.admins 
                       || request.auth.uid == resource.data.createdBy);
     
     // Group messages
     match /messages/{messageId} {
       allow read: if request.auth != null
                   && request.auth.uid in get(/databases/$(database)/documents/conversations/$(conversationId)).data.participants;
       
       allow create: if request.auth != null
                     && request.auth.uid in get(/databases/$(database)/documents/conversations/$(conversationId)).data.participants
                     && request.resource.data.senderId == request.auth.uid;
     }
   }
   ```
3. Deploy rules:
   ```bash
   firebase deploy --only firestore:rules
   ```

**Commit:** `[PR #13] Update Firestore security rules for group conversations`

---

## Testing Strategy

### Test Categories

#### Unit Tests (Model & Service Logic)

**Test 1: Conversation Model - Group Helpers**
```swift
func testIsAdmin_Creator() {
    let conversation = Conversation(
        id: "conv123",
        participants: ["user1", "user2", "user3"],
        isGroup: true,
        groupName: "Team",
        groupPhotoURL: nil,
        admins: nil,
        createdBy: "user1",
        lastMessage: "",
        lastMessageAt: Date(),
        createdAt: Date()
    )
    
    XCTAssertTrue(conversation.isAdmin("user1"))   // Creator
    XCTAssertFalse(conversation.isAdmin("user2"))  // Regular participant
}

func testIsAdmin_PromotedAdmin() {
    var conversation = Conversation(...)
    conversation.admins = ["user2"]
    
    XCTAssertTrue(conversation.isAdmin("user2"))   // Promoted admin
    XCTAssertFalse(conversation.isAdmin("user3"))  // Not admin
}

func testDisplayName_GroupWithCustomName() {
    let conversation = Conversation(..., groupName: "Project Team")
    let users: [String: User] = [:]
    
    let name = conversation.displayName(currentUserId: "user1", users: users)
    XCTAssertEqual(name, "Project Team")
}

func testDisplayName_GroupAutoGenerated() {
    let conversation = Conversation(..., groupName: nil, participants: ["user1", "user2", "user3"])
    let users: [String: User] = [
        "user2": User(id: "user2", displayName: "Alice", email: ""),
        "user3": User(id: "user3", displayName: "Bob", email: "")
    ]
    
    let name = conversation.displayName(currentUserId: "user1", users: users)
    XCTAssertEqual(name, "Alice, Bob")
}
```

**Test 2: ChatService - Group Creation**
```swift
func testCreateGroupConversation_Success() async throws {
    let chatService = ChatService()
    let participants = ["user1", "user2", "user3"]
    
    let conversation = try await chatService.createGroupConversation(
        participants: participants,
        groupName: "Test Group",
        createdBy: "user1"
    )
    
    XCTAssertTrue(conversation.isGroup)
    XCTAssertEqual(conversation.groupName, "Test Group")
    XCTAssertEqual(conversation.participants.count, 3)
    XCTAssertEqual(conversation.createdBy, "user1")
    XCTAssertTrue(conversation.isAdmin("user1"))
}

func testCreateGroupConversation_TooFewParticipants() async {
    let chatService = ChatService()
    let participants = ["user1"]  // Only 1
    
    do {
        _ = try await chatService.createGroupConversation(
            participants: participants,
            groupName: "Test Group",
            createdBy: "user1"
        )
        XCTFail("Should throw groupTooSmall error")
    } catch ChatError.groupTooSmall {
        // Expected
    } catch {
        XCTFail("Wrong error thrown")
    }
}

func testCreateGroupConversation_TooManyParticipants() async {
    let chatService = ChatService()
    let participants = Array(repeating: "user", count: 51)  // 51 participants
    
    do {
        _ = try await chatService.createGroupConversation(
            participants: participants,
            groupName: "Test Group",
            createdBy: "user1"
        )
        XCTFail("Should throw groupTooLarge error")
    } catch ChatError.groupTooLarge {
        // Expected
    } catch {
        XCTFail("Wrong error thrown")
    }
}
```

**Test 3: Message - Group Status Aggregation**
```swift
func testStatusForGroup_AllRead() {
    let conversation = Conversation(..., participants: ["user1", "user2", "user3"])
    var message = Message(senderId: "user1", ...)
    message.readBy = ["user2", "user3"]  // All others read
    
    let status = message.statusForGroup(in: conversation, currentUserId: "user1")
    XCTAssertEqual(status, .read)
}

func testStatusForGroup_PartiallyDelivered() {
    let conversation = Conversation(..., participants: ["user1", "user2", "user3"])
    var message = Message(senderId: "user1", ...)
    message.deliveredTo = ["user2"]  // Only one delivered
    
    let status = message.statusForGroup(in: conversation, currentUserId: "user1")
    XCTAssertEqual(status, .delivered)  // Show delivered if at least one
}

func testStatusForGroup_NoneDelivered() {
    let conversation = Conversation(..., participants: ["user1", "user2", "user3"])
    let message = Message(senderId: "user1", ...)
    // deliveredTo and readBy are empty
    
    let status = message.statusForGroup(in: conversation, currentUserId: "user1")
    XCTAssertEqual(status, .sent)
}
```

---

#### Integration Tests (End-to-End Flows)

**Test 4: Create Group and Send Message**
1. User A creates group with User B, User C
2. Enter group name: "Test Group"
3. Tap "Create Group"
4. ChatView opens with group conversation
5. User A sends message: "Hello group!"
6. Within 2 seconds: User B and User C receive message
7. Both see sender name "User A" above message
8. User A sees gray double-check (delivered to at least one)
9. User B reads message
10. User C reads message
11. User A sees blue double-check (all read)

**Expected:** Group creation → messaging → read receipts work end-to-end

---

**Test 5: Add Participant to Existing Group**
1. Group exists with User A (admin), User B, User C
2. User A opens GroupInfoView
3. Taps "Add Participants"
4. Selects User D from contact list
5. Confirms addition
6. User D added to group
7. User D receives past messages? (NO for MVP - only new messages)
8. User D can send messages
9. All participants see User D's messages

**Expected:** Adding participants works, new member can participate

---

**Test 6: Remove Participant from Group**
1. Group with User A (admin), User B, User C
2. User A opens GroupInfoView
3. Swipes left on User C's row
4. Taps "Remove"
5. Confirms removal
6. User C removed from group
7. User C no longer sees group in chat list
8. Users A and B see "User C was removed" system message (optional for MVP)
9. User C cannot send messages to group (blocked by security rules)

**Expected:** Removing participants works, security enforced

---

**Test 7: Leave Group (Self-Remove)**
1. Group with User A, User B, User C
2. User B opens GroupInfoView
3. Scrolls to bottom, taps "Leave Group"
4. Confirms action
5. User B removed from participants
6. User B's chat list no longer shows group
7. Users A and C see "User B left the group" system message (optional)
8. Group continues to function for remaining members

**Expected:** Leaving group works, doesn't break group

---

**Test 8: Group with Auto-Generated Name**
1. User A creates group with User B, User C
2. Leaves "Group Name" field empty
3. Tap "Create Group"
4. Chat list shows: "Bob, Charlie" (auto-generated from other participants)
5. ChatView title shows: "Bob, Charlie"
6. User A can still open GroupInfoView
7. Can edit name later if desired

**Expected:** Auto-generated names work as fallback

---

**Test 9: Large Group (50 Participants)**
1. User A creates group with 49 other users (50 total)
2. Successfully creates group
3. User A sends message
4. All 49 recipients receive within 5 seconds (some delay acceptable)
5. Read receipts aggregate correctly
6. Typing indicators still work (show up to 3 users typing)
7. Performance: scrolling stays at 60fps

**Expected:** Maximum group size works, performance acceptable

---

**Test 10: Group Status Aggregation - Mixed Read States**
1. Group with User A (sender), User B, User C, User D
2. User A sends message
3. User B reads immediately
4. User C delivers but doesn't read
5. User D offline (no delivery)
6. User A sees: gray double-check (delivered to some, not all read)
7. User C reads message
8. User A sees: gray double-check still (User D still hasn't received)
9. User D comes online, receives message
10. User A sees: gray double-check (all delivered, not all read)
11. User D reads message
12. User A sees: blue double-check (all read)

**Expected:** Status accurately reflects aggregate state at each step

---

#### Edge Cases

**Test 11: Admin Permissions - Non-Admin Cannot Remove**
1. Group with User A (admin), User B, User C
2. User B opens GroupInfoView
3. User B tries to remove User C (should not see option)
4. If they hack the API call, Firestore rules block it
5. Error: "Permission denied"

**Expected:** Non-admins cannot remove participants (UI + security)

---

**Test 12: Creator Leaves Group - Admin Transfer**
1. Group with User A (creator/admin), User B (admin), User C
2. User A leaves group
3. User B becomes sole admin
4. User B can still manage group (add/remove participants)
5. Group continues to function normally

**Expected:** Group survives creator leaving if other admins exist

---

**Test 13: Last Admin Leaves Group**
1. Group with User A (admin), User B, User C
2. User A (only admin) leaves group
3. Group becomes "unmanaged" (no admins)
4. Users B and C can still message
5. But no one can add/remove participants or change settings
6. (Optional: Auto-promote longest-standing member to admin)

**Expected:** Group continues to work for messaging, but management locked

---

**Test 14: Duplicate Group Creation Prevention**
1. User A tries to create group with exact same participants as existing group
2. System checks for existing group with same participant set
3. If found: navigate to existing group (don't create duplicate)
4. If not found: create new group

**Expected:** No duplicate groups with identical participants

---

**Test 15: Group Message Ordering with Multiple Senders**
1. Group with User A, User B, User C
2. User A sends message at T+0s
3. User B sends message at T+1s
4. User C sends message at T+2s
5. All users see messages in correct order (A → B → C)
6. Timestamps reflect server time (consistent across devices)

**Expected:** Message order preserved in groups

---

**Test 16: Group with Offline Participant**
1. Group with User A, User B (online), User C (offline)
2. User A sends message
3. User B receives immediately
4. User C's device is offline (message queued in Firestore)
5. User C comes online
6. User C receives all missed messages in order
7. Read receipts update for User A

**Expected:** Offline participants receive messages when they reconnect

---

**Test 17: Group Photo Upload (Future: PR #14)**
1. User A (admin) opens GroupInfoView
2. Taps "Change Group Photo"
3. Selects image from library
4. Image compresses and uploads
5. All participants see new group photo
6. Photo displays in chat list and ChatView

**Expected:** Group photos work (deferred to PR #14 if time-constrained)

---

**Test 18: Group with 1 Active Participant (Everyone Else Left)**
1. Group with User A, User B, User C
2. User B leaves
3. User C leaves
4. Only User A remains
5. User A can still see group in chat list
6. User A can read old messages
7. User A cannot send messages (no one to receive)
8. (Optional: Show "You're the only member" message)

**Expected:** Single-member group handled gracefully

---

### Performance Tests

**Test 19: Group Creation Speed**
1. Create group with 10 participants
2. Measure: Time from "Create Group" tap to ChatView appearing
3. Target: <2 seconds

**Expected:** Group creation feels instant

---

**Test 20: Large Group Message Delivery**
1. Group with 50 participants
2. User A sends message
3. Measure: Time until all online participants receive
4. Target: <5 seconds for 50 participants

**Expected:** Message delivery scales reasonably

---

**Test 21: Group List Rendering with 100 Groups**
1. User has 100 group conversations
2. Open ChatListView
3. Measure: Scroll performance
4. Target: 60fps scrolling

**Expected:** LazyVStack handles many groups efficiently

---

### Acceptance Criteria Tests

**Test 22: Full Group Flow (Manual)**
**Scenario:** End-to-end group creation and usage
1. User A opens ChatListView
2. Taps "+" button
3. Selects "New Group"
4. Selects 3 contacts: User B, User C, User D
5. Taps "Next"
6. Enters group name: "Weekend Plans"
7. Taps "Create Group"
8. ChatView opens with group conversation
9. User A sends: "Hey everyone!"
10. Users B, C, D receive within 2 seconds
11. All see "User A" above message
12. User B replies: "Hey!"
13. User A sees "User B" above reply
14. User A taps group name in navigation
15. GroupInfoView opens
16. Shows 4 participants
17. User A taps "Leave Group"
18. Confirms
19. Returns to ChatListView
20. Group no longer in list

**Expected:** ✅ Complete group lifecycle works flawlessly

---

## Success Criteria

**Feature is complete when:**

### Functional Requirements
- [ ] Users can create groups with 3-50 participants
- [ ] Group name is optional (auto-generated fallback)
- [ ] Groups appear in chat list with correct name/photo
- [ ] Group messages deliver to all participants in real-time (<2s)
- [ ] Sender name displays above each message in groups
- [ ] Read receipts aggregate correctly (blue when all read)
- [ ] Group info view shows participants and settings
- [ ] Admins can add/remove participants
- [ ] Admins can change group name
- [ ] Participants can leave group
- [ ] Creator can delete group (optional for MVP)
- [ ] Typing indicators work in groups (multiple users)
- [ ] Presence still works for individual participants

### Technical Requirements
- [ ] Conversation model has group fields
- [ ] ChatService has group management methods
- [ ] Firestore security rules enforce group permissions
- [ ] No duplicate groups with same participants
- [ ] Groups support up to 50 participants
- [ ] Performance acceptable with 50-member groups

### Visual Requirements
- [ ] ParticipantSelectionView with multi-select
- [ ] GroupSetupView with name input
- [ ] GroupInfoView with participant list
- [ ] Sender names display in group messages
- [ ] Group icon/photo (or initials) in chat list
- [ ] "X participants" subtitle in ChatView
- [ ] Admin badges on participant rows
- [ ] "Leave Group" button (destructive style)

### Quality Gates
- [ ] Zero crashes or fatal errors
- [ ] All tests passing (22 test scenarios)
- [ ] No console errors or warnings
- [ ] Firestore rules deployed and working
- [ ] Code review complete
- [ ] Documentation updated

---

## Risk Assessment

### Risk 1: Performance with Large Groups (50 Participants)
**Likelihood:** MEDIUM (will have 50-member groups)  
**Impact:** HIGH (slow performance = bad UX)  
**Mitigation:**
- LazyVStack for efficient rendering
- Pagination for participant lists (load 20 at a time)
- Optimize Firestore queries (limit, caching)
- Monitor with Instruments Time Profiler
- Can reduce limit to 30 if performance issues

**Status:** 🟡 MEDIUM (need to test with 50 users)

---

### Risk 2: Read Receipt Complexity
**Likelihood:** MEDIUM (aggregate logic is tricky)  
**Impact:** MEDIUM (confusing status indicators)  
**Mitigation:**
- Use conservative aggregation (show delivered until all read)
- Clear visual indicators (same checkmarks as 1-on-1)
- Test thoroughly with multiple participants
- Can add detail view later (tap to see per-person status)

**Status:** 🟡 MEDIUM (test aggregation thoroughly)

---

### Risk 3: Admin Permission Edge Cases
**Likelihood:** HIGH (complex permission logic)  
**Impact:** MEDIUM (wrong person can delete group)  
**Mitigation:**
- Firestore rules enforce permissions (security layer)
- UI also checks permissions (UX layer)
- Test: non-admin tries to remove participant (should fail)
- Test: admin leaves, group still manageable
- Comprehensive test scenarios

**Status:** 🟡 MEDIUM (require thorough testing)

---

### Risk 4: Group Without Admins (All Left)
**Likelihood:** LOW (rare scenario)  
**Impact:** MEDIUM (unmanageable group)  
**Mitigation:**
- Auto-promote longest-standing member when last admin leaves
- Or: group becomes "locked" (messaging only, no management)
- Document behavior clearly
- Can improve in PR #23

**Status:** 🟢 LOW (defer to post-MVP)

---

### Risk 5: Notification Spam in Large Groups
**Likelihood:** HIGH (50 people × 10 messages/day = 500 notifications)  
**Impact:** MEDIUM (user annoyance, disable notifications)  
**Mitigation:**
- Group notifications on by default
- PR #17 (Notifications) adds mute/unmute per group
- Summary notifications: "5 new messages in Weekend Plans"
- User can disable per-group in settings

**Status:** 🟡 MEDIUM (address in PR #17)

---

## Open Questions

### Question 1: Should groups have a maximum inactive period before auto-deletion?
**Options:**
- A: No auto-deletion (groups persist forever)
- B: Delete groups with no activity for 90 days
- C: Archive groups, user can reactivate

**Recommendation:** A (no auto-deletion) for MVP

**Rationale:** Keep simple, users can manually delete. Can add archival in PR #23.

**Decision Needed By:** Not in PR #13 scope

---

### Question 2: Can participants change group name, or only admins?
**Options:**
- A: Only admins can change name
- B: Any participant can change name

**Recommendation:** A (admins only)

**Rationale:** Prevents chaos, matches WhatsApp model, clear authority

**Decision Needed By:** Phase 5, Step 5.1

---

### Question 3: What happens to messages when someone is removed from group?
**Options:**
- A: Removed user loses access to all messages (including history)
- B: Removed user keeps messages they already received, can't get new ones

**Recommendation:** A (lose all access) for security

**Rationale:**
- Firestore rules prevent access to conversation
- Cleaner security model
- Can't read new messages or old ones
- If user wants history, they should leave (not be removed)

**Decision Needed By:** Phase 5, Step 5.3

---

## Timeline

**Total Estimate:** 3-4 hours

| Phase | Task | Time | Status |
|-------|------|------|--------|
| 1 | Group Data Model & Service | 60-90m | ⏳ |
| 2 | Participant Selection UI | 60-75m | ⏳ |
| 3 | Group Setup UI | 45-60m | ⏳ |
| 4 | Group Message Display | 30-45m | ⏳ |
| 5 | Group Info & Management | 75-90m | ⏳ |
| 6 | Firestore Security Rules | 15m | ⏳ |
| **Total** | | **285-375 min** | **~5-6 hours** |

**Note:** Initial estimate was 3-4 hours, but comprehensive implementation will take 5-6 hours. Adjust expectations.

**Contingency:** +1 hour for unexpected issues (group edge cases, permission bugs)

---

## Dependencies

### Requires (Must be complete first):
- [x] PR #4: Core Models ✅
- [x] PR #5: ChatService ✅
- [x] PR #7: ChatListView ✅
- [x] PR #9: ChatView ✅
- [x] PR #10: Real-Time Messaging ✅
- [x] PR #11: Message Status ✅
- [ ] PR #12: Presence & Typing (nice to have, not blocking)

### Blocks (Waiting on this PR):
- PR #14: Image Sharing (group photos)
- PR #17: Push Notifications (group notification settings)

---

## References

### Related PRs
- PR #4: Conversation model foundation
- PR #5: ChatService patterns
- PR #11: Read receipt logic (extend for groups)
- PR #12: Typing indicators (extend for groups)

### Design Inspiration
- WhatsApp: Group creation flow, participant management
- iMessage: Group naming, auto-generated names
- Telegram: Large group support, admin permissions
- Signal: Privacy-focused group features

---

*This specification provides everything needed to implement group chat functionality. Follow the implementation steps sequentially, test thoroughly at each phase, and commit frequently.*

