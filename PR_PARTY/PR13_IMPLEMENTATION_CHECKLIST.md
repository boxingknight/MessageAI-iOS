# PR#13: Group Chat Functionality - Implementation Checklist

**Use this as your daily todo list.** Check off items as you complete them.

**Estimated Time:** 5-6 hours  
**Complexity:** HIGH  
**Status:** ⏳ NOT STARTED

---

## Pre-Implementation Setup (15 minutes)

- [ ] Read main planning document `PR13_GROUP_CHAT.md` (~60 min)
- [ ] Prerequisites verified:
  - [ ] PR #1-12 complete and merged
  - [ ] Firebase project active
  - [ ] Xcode project builds successfully
- [ ] Dependencies confirmed:
  - [ ] ChatService has real-time listeners (PR #5, #10)
  - [ ] Message status indicators working (PR #11)
  - [ ] Presence/typing working (PR #12)
- [ ] Git branch created:
  ```bash
  git checkout -b feature/pr13-group-chat
  ```
- [ ] Open relevant files in Xcode:
  - [ ] `Models/Conversation.swift`
  - [ ] `Models/Message.swift`
  - [ ] `Services/ChatService.swift`
  - [ ] `Views/Chat/ChatListView.swift`
  - [ ] `Views/Chat/ChatView.swift`
  - [ ] `Views/Chat/MessageBubbleView.swift`

---

## Phase 1: Group Data Model & Service (60-90 minutes)

### 1.1: Update Conversation Model (30 minutes)

#### Add Group Fields
- [ ] Open `Models/Conversation.swift`
- [ ] Add new properties:
  ```swift
  var groupName: String?          // Optional group name
  var groupPhotoURL: String?      // Optional group photo
  var admins: [String]?           // Admin user IDs (creator + promoted)
  ```
- [ ] Verify existing fields:
  - [ ] `isGroup: Bool` exists (should be from PR #4)
  - [ ] `participants: [String]` exists
  - [ ] `createdBy: String` exists

#### Add Helper Methods
- [ ] Add method: `isAdmin(_ userId: String) -> Bool`
  ```swift
  func isAdmin(_ userId: String) -> Bool {
      return userId == createdBy || (admins?.contains(userId) ?? false)
  }
  ```
- [ ] Add method: `displayName(currentUserId:users:) -> String`
  - If `isGroup && groupName != nil`: return `groupName`
  - If `isGroup && groupName == nil`: auto-generate from participants
  - If `!isGroup`: return other user's name
- [ ] Add private helper: `generateAutoName(currentUserId:users:)`
  - 0 participants: "Empty Group"
  - 1-3 participants: "Alice, Bob, Charlie"
  - 4+ participants: "Alice, Bob, Charlie, and 5 others"

#### Update Firestore Conversion
- [ ] Update `toFirestore()` method:
  - [ ] Add `groupName` to dictionary (if not nil)
  - [ ] Add `groupPhotoURL` to dictionary (if not nil)
  - [ ] Add `admins` array to dictionary (if not nil)
- [ ] Update `fromFirestore()` method:
  - [ ] Parse `groupName` as optional String
  - [ ] Parse `groupPhotoURL` as optional String
  - [ ] Parse `admins` as optional [String]

#### Test
- [ ] Build project (⌘B)
- [ ] Fix any compilation errors
- [ ] Test in console (optional):
  ```swift
  let conv = Conversation(
      id: "test",
      participants: ["user1", "user2", "user3"],
      isGroup: true,
      groupName: "Test Group",
      groupPhotoURL: nil,
      admins: ["user1"],
      createdBy: "user1",
      lastMessage: "Hi",
      lastMessageAt: Date(),
      createdAt: Date()
  )
  print(conv.isAdmin("user1"))  // Should be true
  print(conv.displayName(currentUserId: "user1", users: [:]))
  ```

**Checkpoint:** Conversation model compiles with group fields ✓

**Commit:** 
```bash
git add Models/Conversation.swift
git commit -m "[PR #13] Add group fields and helpers to Conversation model"
```

---

### 1.2: Add Group Status to Message Model (20 minutes)

#### Add Group Status Method
- [ ] Open `Models/Message.swift`
- [ ] Add method: `statusForGroup(in:currentUserId:) -> MessageStatus`
  ```swift
  func statusForGroup(in conversation: Conversation, currentUserId: String) -> MessageStatus {
      guard conversation.isGroup else {
          return status  // Not a group, use regular status
      }
      
      if senderId == currentUserId {
          // Sender's perspective: aggregate all recipients
          let otherParticipants = conversation.participants.filter { $0 != currentUserId }
          let totalRecipients = otherParticipants.count
          
          if totalRecipients == 0 { return .sent }
          
          // All read?
          if readBy.count >= totalRecipients {
              return .read
          }
          
          // All delivered?
          if deliveredTo.count >= totalRecipients {
              return .delivered
          }
          
          // At least one delivered?
          if deliveredTo.count > 0 {
              return .delivered
          }
          
          return .sent
      } else {
          // Recipient's perspective: same as 1-on-1
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

#### Test
- [ ] Build project (⌘B)
- [ ] No compilation errors

**Checkpoint:** Message model has group status method ✓

**Commit:**
```bash
git add Models/Message.swift
git commit -m "[PR #13] Add group status aggregation to Message model"
```

---

### 1.3: Add Group Methods to ChatService (30-60 minutes)

#### Add Group Management Methods
- [ ] Open `Services/ChatService.swift`
- [ ] Add new error cases to `ChatError`:
  ```swift
  case groupTooSmall
  case groupTooLarge
  case notAdmin
  ```

#### Implement createGroupConversation()
- [ ] Add method signature:
  ```swift
  func createGroupConversation(
      participants: [String],
      groupName: String?,
      createdBy: String
  ) async throws -> Conversation
  ```
- [ ] Add validation:
  - [ ] Throw `.groupTooSmall` if `participants.count < 3`
  - [ ] Throw `.groupTooLarge` if `participants.count > 50`
- [ ] Ensure creator in participants:
  ```swift
  var allParticipants = participants
  if !allParticipants.contains(createdBy) {
      allParticipants.append(createdBy)
  }
  allParticipants.sort()  // Consistency
  ```
- [ ] Create conversation document:
  ```swift
  let conversationRef = db.collection("conversations").document()
  let conversation = Conversation(
      id: conversationRef.documentID,
      participants: allParticipants,
      isGroup: true,
      groupName: groupName,
      groupPhotoURL: nil,
      admins: [createdBy],
      createdBy: createdBy,
      lastMessage: "Group created",
      lastMessageAt: Date(),
      createdAt: Date()
  )
  try await conversationRef.setData(conversation.toFirestore())
  return conversation
  ```

#### Implement Other Group Methods
- [ ] Add `updateGroupName(_:name:)`:
  ```swift
  func updateGroupName(_ conversationId: String, name: String) async throws {
      try await db.collection("conversations").document(conversationId)
          .updateData(["groupName": name])
  }
  ```
- [ ] Add `updateGroupPhoto(_:photoURL:)`:
  ```swift
  func updateGroupPhoto(_ conversationId: String, photoURL: String) async throws {
      try await db.collection("conversations").document(conversationId)
          .updateData(["groupPhotoURL": photoURL])
  }
  ```
- [ ] Add `addParticipant(_:userId:)`:
  ```swift
  func addParticipant(_ conversationId: String, userId: String) async throws {
      try await db.collection("conversations").document(conversationId)
          .updateData(["participants": FieldValue.arrayUnion([userId])])
  }
  ```
- [ ] Add `removeParticipant(_:userId:)`:
  ```swift
  func removeParticipant(_ conversationId: String, userId: String) async throws {
      try await db.collection("conversations").document(conversationId)
          .updateData(["participants": FieldValue.arrayRemove([userId])])
  }
  ```
- [ ] Add `leaveGroup(_:userId:)`:
  ```swift
  func leaveGroup(_ conversationId: String, userId: String) async throws {
      try await removeParticipant(conversationId, userId: userId)
  }
  ```
- [ ] Add `promoteToAdmin(_:userId:)`:
  ```swift
  func promoteToAdmin(_ conversationId: String, userId: String) async throws {
      try await db.collection("conversations").document(conversationId)
          .updateData(["admins": FieldValue.arrayUnion([userId])])
  }
  ```
- [ ] Add `demoteFromAdmin(_:userId:)`:
  ```swift
  func demoteFromAdmin(_ conversationId: String, userId: String) async throws {
      try await db.collection("conversations").document(conversationId)
          .updateData(["admins": FieldValue.arrayRemove([userId])])
  }
  ```

#### Test
- [ ] Build project (⌘B)
- [ ] No compilation errors
- [ ] All ChatService methods compile

**Checkpoint:** ChatService has all group management methods ✓

**Commit:**
```bash
git add Services/ChatService.swift
git commit -m "[PR #13] Implement group management methods in ChatService"
```

---

## Phase 2: Participant Selection UI (60-75 minutes)

### 2.1: Create ParticipantSelectionView (45 minutes)

#### Create New File
- [ ] In Xcode: File → New → File → SwiftUI View
- [ ] Name: `ParticipantSelectionView`
- [ ] Location: `Views/Group/ParticipantSelectionView.swift`

#### Implement View Structure
- [ ] Add imports:
  ```swift
  import SwiftUI
  ```
- [ ] Add state properties:
  ```swift
  @State private var selectedUserIds: Set<String> = []
  @State private var searchText = ""
  @State private var allUsers: [User] = []
  @State private var isLoading = false
  @Environment(\.dismiss) var dismiss
  var onNext: ([String]) -> Void
  ```

#### Add Search Bar
- [ ] Add `.searchable(text: $searchText, prompt: "Search contacts")`

#### Add Selected Participants Section
- [ ] Add ScrollView (horizontal) for selected users:
  ```swift
  if !selectedUserIds.isEmpty {
      ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 12) {
              ForEach(selectedUsers) { user in
                  VStack(spacing: 4) {
                      AsyncImage(url: URL(string: user.photoURL ?? "")) { image in
                          image.resizable()
                      } placeholder: {
                          Circle().fill(Color.gray.opacity(0.3))
                      }
                      .frame(width: 60, height: 60)
                      .clipShape(Circle())
                      
                      Text(user.displayName.split(separator: " ").first ?? "")
                          .font(.caption2)
                          .lineLimit(1)
                  }
                  .frame(width: 70)
              }
          }
          .padding(.horizontal)
      }
      .frame(height: 100)
  }
  ```

#### Add Contact List
- [ ] Add List with checkmarks:
  ```swift
  List {
      ForEach(filteredUsers) { user in
          Button {
              toggleSelection(user.id)
          } label: {
              HStack {
                  AsyncImage(url: URL(string: user.photoURL ?? "")) { image in
                      image.resizable()
                  } placeholder: {
                      Circle().fill(Color.gray.opacity(0.3))
                              .overlay(
                                  Text(user.displayName.prefix(1))
                                      .font(.headline)
                                      .foregroundColor(.white)
                              )
                  }
                  .frame(width: 44, height: 44)
                  .clipShape(Circle())
                  
                  VStack(alignment: .leading, spacing: 4) {
                      Text(user.displayName)
                          .font(.body)
                      Text(user.email)
                          .font(.caption)
                          .foregroundColor(.secondary)
                  }
                  
                  Spacer()
                  
                  if selectedUserIds.contains(user.id) {
                      Image(systemName: "checkmark.circle.fill")
                          .foregroundColor(.blue)
                          .font(.title3)
                  } else {
                      Image(systemName: "circle")
                          .foregroundColor(.gray.opacity(0.3))
                          .font(.title3)
                  }
              }
              .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
      }
  }
  ```

#### Add Helper Methods
- [ ] Add computed property: `selectedUsers: [User]`
- [ ] Add computed property: `filteredUsers: [User]` (search filter)
- [ ] Add method: `toggleSelection(_ userId: String)`
  ```swift
  func toggleSelection(_ userId: String) {
      if selectedUserIds.contains(userId) {
          selectedUserIds.remove(userId)
      } else {
          if selectedUserIds.count < 49 {  // Max 50 total (49 + current user)
              selectedUserIds.insert(userId)
          }
      }
  }
  ```
- [ ] Add method: `loadUsers()` (fetch from Firestore)

#### Add Navigation Bar
- [ ] Add `.navigationTitle("Select Participants")`
- [ ] Add toolbar:
  ```swift
  .toolbar {
      ToolbarItem(placement: .navigationBarLeading) {
          Button("Cancel") {
              dismiss()
          }
      }
      
      ToolbarItem(placement: .navigationBarTrailing) {
          Button("Next (\(selectedUserIds.count))") {
              onNext(Array(selectedUserIds))
              dismiss()
          }
          .disabled(selectedUserIds.count < 2)
      }
  }
  ```

#### Test
- [ ] Build project (⌘B)
- [ ] Preview in canvas:
  ```swift
  #Preview {
      NavigationStack {
          ParticipantSelectionView(onNext: { _ in })
      }
  }
  ```

**Checkpoint:** ParticipantSelectionView compiles and previews ✓

**Commit:**
```bash
git add Views/Group/ParticipantSelectionView.swift
git commit -m "[PR #13] Create ParticipantSelectionView for multi-select contacts"
```

---

### 2.2: Integrate with ChatListView (30 minutes)

#### Add State Variables
- [ ] Open `Views/Chat/ChatListView.swift`
- [ ] Add state:
  ```swift
  @State private var showNewConversationOptions = false
  @State private var showContactsSheet = false
  @State private var showParticipantSelection = false
  @State private var selectedGroupParticipants: [String] = []
  @State private var showGroupSetup = false
  ```

#### Modify "+" Button
- [ ] Replace existing "+" button tap handler:
  ```swift
  .toolbar {
      ToolbarItem(placement: .navigationBarTrailing) {
          Button {
              showNewConversationOptions = true
          } label: {
              Image(systemName: "plus")
          }
      }
  }
  ```

#### Add Action Sheet
- [ ] Add confirmation dialog:
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

#### Add Sheet Presentations
- [ ] Add sheet for contacts (existing):
  ```swift
  .sheet(isPresented: $showContactsSheet) {
      // Existing ContactsListView
  }
  ```
- [ ] Add sheet for participant selection:
  ```swift
  .sheet(isPresented: $showParticipantSelection) {
      NavigationStack {
          ParticipantSelectionView { participants in
              selectedGroupParticipants = participants
              showGroupSetup = true
          }
      }
  }
  ```
- [ ] Add sheet for group setup (prepare for Phase 3):
  ```swift
  .sheet(isPresented: $showGroupSetup) {
      NavigationStack {
          GroupSetupView(
              selectedParticipants: selectedGroupParticipants,
              onGroupCreated: { conversation in
                  // Navigate to ChatView
                  showGroupSetup = false
              }
          )
      }
  }
  ```

#### Test
- [ ] Build project (⌘B)
- [ ] Run app in simulator
- [ ] Tap "+" button → should show action sheet
- [ ] Tap "New Group" → should show participant selection
- [ ] Select 2+ contacts → "Next" button enabled
- [ ] Tap "Next" → should close sheet (group setup not implemented yet)

**Checkpoint:** Action sheet and participant selection flow working ✓

**Commit:**
```bash
git add Views/Chat/ChatListView.swift
git commit -m "[PR #13] Integrate participant selection in ChatListView"
```

---

## Phase 3: Group Setup UI (45-60 minutes)

### 3.1: Create GroupViewModel (20 minutes)

#### Create New File
- [ ] In Xcode: File → New → File → Swift File
- [ ] Name: `GroupViewModel`
- [ ] Location: `ViewModels/GroupViewModel.swift`

#### Implement ViewModel
- [ ] Add imports:
  ```swift
  import Foundation
  import SwiftUI
  ```
- [ ] Create class:
  ```swift
  @MainActor
  class GroupViewModel: ObservableObject {
      @Published var groupName: String = ""
      @Published var selectedParticipants: [String] = []
      @Published var isLoading = false
      @Published var errorMessage: String?
      
      private let chatService = ChatService()
      private let authService = AuthService()
      
      func createGroup() async throws -> Conversation {
          isLoading = true
          errorMessage = nil
          defer { isLoading = false }
          
          guard let currentUserId = authService.currentUser?.id else {
              throw ChatError.notAuthenticated
          }
          
          let conversation = try await chatService.createGroupConversation(
              participants: selectedParticipants,
              groupName: groupName.isEmpty ? nil : groupName,
              createdBy: currentUserId
          )
          
          return conversation
      }
      
      func updateGroupName(_ conversationId: String, name: String) async throws {
          try await chatService.updateGroupName(conversationId, name: name)
      }
      
      func addParticipant(_ conversationId: String, userId: String) async throws {
          try await chatService.addParticipant(conversationId, userId: userId)
      }
      
      func removeParticipant(_ conversationId: String, userId: String) async throws {
          try await chatService.removeParticipant(conversationId, userId: userId)
      }
      
      func leaveGroup(_ conversationId: String, userId: String) async throws {
          try await chatService.leaveGroup(conversationId, userId: userId)
      }
      
      func promoteToAdmin(_ conversationId: String, userId: String) async throws {
          try await chatService.promoteToAdmin(conversationId, userId: userId)
      }
  }
  ```

#### Test
- [ ] Build project (⌘B)
- [ ] No compilation errors

**Checkpoint:** GroupViewModel compiles ✓

**Commit:**
```bash
git add ViewModels/GroupViewModel.swift
git commit -m "[PR #13] Create GroupViewModel for group management logic"
```

---

### 3.2: Create GroupSetupView (40 minutes)

#### Create New File
- [ ] In Xcode: File → New → File → SwiftUI View
- [ ] Name: `GroupSetupView`
- [ ] Location: `Views/Group/GroupSetupView.swift`

#### Implement View
- [ ] Add state:
  ```swift
  @StateObject private var viewModel = GroupViewModel()
  @State private var groupName = ""
  let selectedParticipants: [String]
  var onGroupCreated: (Conversation) -> Void
  @Environment(\.dismiss) var dismiss
  ```
- [ ] Add Form:
  ```swift
  Form {
      Section(header: Text("Group Name")) {
          TextField("Enter group name (optional)", text: $groupName)
              .autocorrectionDisabled()
      }
      
      Section(header: Text("Participants (\(selectedParticipants.count + 1))")) {
          ForEach(allParticipants) { user in
              HStack {
                  AsyncImage(url: URL(string: user.photoURL ?? "")) { image in
                      image.resizable()
                  } placeholder: {
                      Circle().fill(Color.gray.opacity(0.3))
                          .overlay(
                              Text(user.displayName.prefix(1))
                                  .foregroundColor(.white)
                          )
                  }
                  .frame(width: 40, height: 40)
                  .clipShape(Circle())
                  
                  VStack(alignment: .leading, spacing: 2) {
                      Text(user.displayName)
                          .font(.body)
                      Text(user.email)
                          .font(.caption)
                          .foregroundColor(.secondary)
                  }
              }
          }
      }
  }
  ```

#### Add Navigation Bar
- [ ] Add `.navigationTitle("New Group")`
- [ ] Add toolbar:
  ```swift
  .toolbar {
      ToolbarItem(placement: .navigationBarLeading) {
          Button("Cancel") {
              dismiss()
          }
      }
      
      ToolbarItem(placement: .navigationBarTrailing) {
          Button {
              createGroup()
          } label: {
              if viewModel.isLoading {
                  ProgressView()
              } else {
                  Text("Create")
                      .fontWeight(.semibold)
              }
          }
          .disabled(viewModel.isLoading)
      }
  }
  ```

#### Add Create Method
- [ ] Add method:
  ```swift
  func createGroup() {
      viewModel.selectedParticipants = selectedParticipants
      viewModel.groupName = groupName
      
      Task {
          do {
              let conversation = try await viewModel.createGroup()
              await MainActor.run {
                  onGroupCreated(conversation)
                  dismiss()
              }
          } catch {
              await MainActor.run {
                  viewModel.errorMessage = error.localizedDescription
              }
          }
      }
  }
  ```

#### Add Error Alert
- [ ] Add `.alert()` modifier for errors:
  ```swift
  .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
      Button("OK") {
          viewModel.errorMessage = nil
      }
  } message: {
      Text(viewModel.errorMessage ?? "")
  }
  ```

#### Test
- [ ] Build project (⌘B)
- [ ] Preview in canvas

**Checkpoint:** GroupSetupView compiles and previews ✓

**Commit:**
```bash
git add Views/Group/GroupSetupView.swift
git commit -m "[PR #13] Create GroupSetupView for finalizing group creation"
```

---

## Phase 4: Group Message Display (30-45 minutes)

### 4.1: Update MessageBubbleView for Sender Names (20 minutes)

#### Add Group Support
- [ ] Open `Views/Chat/MessageBubbleView.swift`
- [ ] Add parameters:
  ```swift
  let message: Message
  let conversation: Conversation?
  let currentUserId: String
  let users: [String: User]  // For looking up sender names
  ```

#### Add Sender Name Display
- [ ] Above message bubble, add conditional sender name:
  ```swift
  VStack(alignment: message.senderId == currentUserId ? .trailing : .leading, spacing: 4) {
      // Show sender name for group messages (not from current user)
      if let conversation = conversation,
         conversation.isGroup,
         message.senderId != currentUserId,
         let sender = users[message.senderId] {
          Text(sender.displayName)
              .font(.caption.bold())
              .foregroundColor(.blue)
              .padding(.leading, 8)
      }
      
      // Existing message bubble
      HStack {
          // ... existing bubble code
      }
  }
  ```

#### Test
- [ ] Build project (⌘B)
- [ ] Preview with sample group message

**Checkpoint:** Sender names display in group messages ✓

**Commit:**
```bash
git add Views/Chat/MessageBubbleView.swift
git commit -m "[PR #13] Display sender name in group message bubbles"
```

---

### 4.2: Update Message Status for Groups (25 minutes)

#### Modify StatusIcon Logic
- [ ] In `MessageBubbleView`, update status icon logic:
  ```swift
  var statusIcon: String {
      let displayStatus: MessageStatus
      
      if let conversation = conversation, conversation.isGroup {
          displayStatus = message.statusForGroup(in: conversation, currentUserId: currentUserId)
      } else {
          displayStatus = message.status
      }
      
      switch displayStatus {
      case .sending: return "clock"
      case .sent: return "checkmark"
      case .delivered: return "checkmark.circle"
      case .read: return "checkmark.circle.fill"
      case .failed: return "exclamationmark.circle"
      }
  }
  
  var statusColor: Color {
      let displayStatus: MessageStatus
      
      if let conversation = conversation, conversation.isGroup {
          displayStatus = message.statusForGroup(in: conversation, currentUserId: currentUserId)
      } else {
          displayStatus = message.status
      }
      
      switch displayStatus {
      case .sending: return .gray
      case .sent, .delivered: return .gray
      case .read: return .blue
      case .failed: return .red
      }
  }
  ```

#### Update ChatView Integration
- [ ] Open `Views/Chat/ChatView.swift`
- [ ] Update MessageBubbleView call:
  ```swift
  MessageBubbleView(
      message: message,
      conversation: viewModel.conversation,
      currentUserId: viewModel.currentUserId,
      users: viewModel.participantUsers
  )
  ```
- [ ] Add `participantUsers` to ChatViewModel:
  ```swift
  @Published var participantUsers: [String: User] = [:]
  
  func loadParticipantUsers() async {
      // Fetch User objects for all participants
      // Store in participantUsers dictionary
  }
  ```

#### Test
- [ ] Build project (⌘B)
- [ ] No compilation errors

**Checkpoint:** Group message status aggregation working ✓

**Commit:**
```bash
git add Views/Chat/MessageBubbleView.swift Views/Chat/ChatView.swift ViewModels/ChatViewModel.swift
git commit -m "[PR #13] Implement aggregate read receipts for group messages"
```

---

## Phase 5: Group Info & Management (75-90 minutes)

### 5.1: Create GroupInfoView (60 minutes)

#### Create New File
- [ ] In Xcode: File → New → File → SwiftUI View
- [ ] Name: `GroupInfoView`
- [ ] Location: `Views/Group/GroupInfoView.swift`

#### Add State
- [ ] Add properties:
  ```swift
  @StateObject private var viewModel = GroupViewModel()
  @State private var conversation: Conversation
  @State private var isEditingName = false
  @State private var newGroupName = ""
  @State private var showAddParticipants = false
  @State private var showLeaveConfirmation = false
  @State private var showDeleteConfirmation = false
  @Environment(\.dismiss) var dismiss
  let currentUserId: String
  let users: [String: User]
  ```

#### Implement View Structure
- [ ] Add ScrollView with sections:
  ```swift
  ScrollView {
      VStack(spacing: 20) {
          // Group Photo Section
          groupPhotoSection
          
          // Group Name Section
          groupNameSection
          
          // Participants Section
          participantsSection
          
          // Actions Section
          actionsSection
      }
      .padding()
  }
  ```

#### Add Group Photo Section
- [ ] Implement:
  ```swift
  var groupPhotoSection: some View {
      VStack {
          if let photoURL = conversation.groupPhotoURL {
              AsyncImage(url: URL(string: photoURL)) { image in
                  image.resizable()
              } placeholder: {
                  Circle().fill(Color.gray.opacity(0.3))
              }
              .frame(width: 200, height: 200)
              .clipShape(Circle())
          } else {
              Circle()
                  .fill(Color.blue.opacity(0.2))
                  .frame(width: 200, height: 200)
                  .overlay(
                      Text(conversation.groupName?.prefix(1).uppercased() ?? "G")
                          .font(.system(size: 80, weight: .bold))
                          .foregroundColor(.blue)
                  )
          }
          
          if conversation.isAdmin(currentUserId) {
              Button("Change Photo") {
                  // TODO: Implement in PR #14
              }
              .font(.subheadline)
          }
      }
  }
  ```

#### Add Group Name Section
- [ ] Implement editable name (if admin):
  ```swift
  var groupNameSection: some View {
      VStack(spacing: 8) {
          if isEditingName && conversation.isAdmin(currentUserId) {
              HStack {
                  TextField("Group Name", text: $newGroupName)
                      .textFieldStyle(.roundedBorder)
                  
                  Button("Save") {
                      saveGroupName()
                  }
                  .buttonStyle(.borderedProminent)
                  
                  Button("Cancel") {
                      isEditingName = false
                  }
              }
          } else {
              HStack {
                  Text(conversation.groupName ?? "Unnamed Group")
                      .font(.title2.bold())
                  
                  if conversation.isAdmin(currentUserId) {
                      Button {
                          newGroupName = conversation.groupName ?? ""
                          isEditingName = true
                      } label: {
                          Image(systemName: "pencil")
                              .font(.caption)
                      }
                  }
              }
          }
          
          Text("\(conversation.participants.count) participants")
              .font(.subheadline)
              .foregroundColor(.secondary)
      }
  }
  ```

#### Add Participants Section
- [ ] Implement list with admin badges:
  ```swift
  var participantsSection: some View {
      VStack(alignment: .leading, spacing: 12) {
          Text("PARTICIPANTS")
              .font(.caption.bold())
              .foregroundColor(.secondary)
          
          ForEach(conversation.participants, id: \.self) { participantId in
              if let user = users[participantId] {
                  HStack {
                      AsyncImage(url: URL(string: user.photoURL ?? "")) { image in
                          image.resizable()
                      } placeholder: {
                          Circle().fill(Color.gray.opacity(0.3))
                              .overlay(
                                  Text(user.displayName.prefix(1))
                                      .foregroundColor(.white)
                              )
                      }
                      .frame(width: 44, height: 44)
                      .clipShape(Circle())
                      
                      VStack(alignment: .leading, spacing: 2) {
                          HStack {
                              Text(user.displayName)
                                  .font(.body)
                              
                              if conversation.isAdmin(participantId) {
                                  Text("Admin")
                                      .font(.caption)
                                      .padding(.horizontal, 8)
                                      .padding(.vertical, 2)
                                      .background(Color.blue.opacity(0.2))
                                      .foregroundColor(.blue)
                                      .cornerRadius(4)
                              }
                          }
                          
                          Text(user.email)
                              .font(.caption)
                              .foregroundColor(.secondary)
                      }
                      
                      Spacer()
                      
                      if conversation.isAdmin(currentUserId) && participantId != currentUserId {
                          Menu {
                              if conversation.isAdmin(participantId) {
                                  Button("Demote from Admin") {
                                      demoteFromAdmin(participantId)
                                  }
                              } else {
                                  Button("Promote to Admin") {
                                      promoteToAdmin(participantId)
                                  }
                              }
                              
                              Button("Remove from Group", role: .destructive) {
                                  removeParticipant(participantId)
                              }
                          } label: {
                              Image(systemName: "ellipsis")
                                  .foregroundColor(.gray)
                          }
                      }
                  }
                  .padding(.vertical, 4)
              }
          }
          
          if conversation.isAdmin(currentUserId) {
              Button {
                  showAddParticipants = true
              } label: {
                  HStack {
                      Image(systemName: "plus.circle.fill")
                      Text("Add Participants")
                  }
                  .foregroundColor(.blue)
              }
              .padding(.vertical, 8)
          }
      }
      .padding()
      .background(Color(.systemGray6))
      .cornerRadius(12)
  }
  ```

#### Add Actions Section
- [ ] Implement leave/delete buttons:
  ```swift
  var actionsSection: some View {
      VStack(spacing: 12) {
          Button {
              showLeaveConfirmation = true
          } label: {
              HStack {
                  Image(systemName: "rectangle.portrait.and.arrow.right")
                  Text("Leave Group")
              }
              .frame(maxWidth: .infinity)
              .padding()
              .background(Color.red.opacity(0.1))
              .foregroundColor(.red)
              .cornerRadius(12)
          }
          
          if conversation.createdBy == currentUserId {
              Button {
                  showDeleteConfirmation = true
              } label: {
                  HStack {
                      Image(systemName: "trash")
                      Text("Delete Group")
                  }
                  .frame(maxWidth: .infinity)
                  .padding()
                  .background(Color.red.opacity(0.1))
                  .foregroundColor(.red)
                  .cornerRadius(12)
              }
          }
      }
  }
  ```

#### Add Action Methods
- [ ] Implement methods:
  ```swift
  func saveGroupName() {
      Task {
          do {
              try await viewModel.updateGroupName(conversation.id, name: newGroupName)
              conversation.groupName = newGroupName
              isEditingName = false
          } catch {
              // Show error
          }
      }
  }
  
  func promoteToAdmin(_ userId: String) {
      Task {
          do {
              try await viewModel.promoteToAdmin(conversation.id, userId: userId)
              // Update local conversation
          } catch {
              // Show error
          }
      }
  }
  
  func demoteFromAdmin(_ userId: String) {
      // Similar implementation
  }
  
  func removeParticipant(_ userId: String) {
      // Similar implementation
  }
  
  func leaveGroup() {
      Task {
          do {
              try await viewModel.leaveGroup(conversation.id, userId: currentUserId)
              dismiss()
          } catch {
              // Show error
          }
      }
  }
  ```

#### Add Confirmation Alerts
- [ ] Add `.confirmationDialog()` for leave:
  ```swift
  .confirmationDialog("Leave Group?", isPresented: $showLeaveConfirmation) {
      Button("Leave Group", role: .destructive) {
          leaveGroup()
      }
      Button("Cancel", role: .cancel) {}
  } message: {
      Text("Are you sure you want to leave this group? You won't be able to send or receive messages.")
  }
  ```

#### Test
- [ ] Build project (⌘B)
- [ ] Preview with sample conversation

**Checkpoint:** GroupInfoView compiles and previews ✓

**Commit:**
```bash
git add Views/Group/GroupInfoView.swift
git commit -m "[PR #13] Create GroupInfoView for group management UI"
```

---

### 5.2: Integrate in ChatView (15 minutes)

#### Add Navigation to GroupInfoView
- [ ] Open `Views/Chat/ChatView.swift`
- [ ] Add state:
  ```swift
  @State private var showGroupInfo = false
  ```
- [ ] Update navigation title (make tappable for groups):
  ```swift
  .toolbar {
      ToolbarItem(placement: .principal) {
          Button {
              if viewModel.conversation.isGroup {
                  showGroupInfo = true
              }
          } label: {
              VStack(spacing: 2) {
                  Text(viewModel.conversationName)
                      .font(.headline)
                  
                  if viewModel.conversation.isGroup {
                      Text("\(viewModel.conversation.participants.count) participants")
                          .font(.caption)
                          .foregroundColor(.secondary)
                  } else if let presence = viewModel.otherUserPresence {
                      Text(presence.presenceText)
                          .font(.caption)
                          .foregroundColor(.secondary)
                  }
              }
          }
          .buttonStyle(.plain)
      }
  }
  ```
- [ ] Add sheet:
  ```swift
  .sheet(isPresented: $showGroupInfo) {
      if viewModel.conversation.isGroup {
          NavigationStack {
              GroupInfoView(
                  conversation: viewModel.conversation,
                  currentUserId: viewModel.currentUserId,
                  users: viewModel.participantUsers
              )
          }
      }
  }
  ```

#### Test
- [ ] Build project (⌘B)
- [ ] Run app
- [ ] Open group conversation
- [ ] Tap navigation title → should open GroupInfoView

**Checkpoint:** GroupInfoView accessible from ChatView ✓

**Commit:**
```bash
git add Views/Chat/ChatView.swift
git commit -m "[PR #13] Integrate group info navigation in ChatView"
```

---

## Phase 6: Firestore Security Rules (15 minutes)

### 6.1: Update firestore.rules for Groups (15 minutes)

#### Open Rules File
- [ ] Open `firebase/firestore.rules`

#### Update Conversation Rules
- [ ] Modify conversation rules:
  ```javascript
  match /conversations/{conversationId} {
    // Anyone authenticated can read conversations they're in
    allow read: if request.auth != null 
                && request.auth.uid in resource.data.participants;
    
    // Create one-on-one conversation
    allow create: if request.auth != null
                  && request.auth.uid in request.resource.data.participants
                  && request.resource.data.isGroup == false;
    
    // Create group conversation
    allow create: if request.auth != null
                  && request.auth.uid in request.resource.data.participants
                  && request.resource.data.isGroup == true
                  && request.resource.data.createdBy == request.auth.uid
                  && request.resource.data.participants.size() >= 3
                  && request.resource.data.participants.size() <= 50;
    
    // Update conversation (admins only for groups)
    allow update: if request.auth != null
                  && request.auth.uid in resource.data.participants
                  && (resource.data.isGroup == false 
                      || request.auth.uid in resource.data.admins 
                      || request.auth.uid == resource.data.createdBy);
    
    // Group messages (same as before)
    match /messages/{messageId} {
      allow read: if request.auth != null
                  && request.auth.uid in get(/databases/$(database)/documents/conversations/$(conversationId)).data.participants;
      
      allow create: if request.auth != null
                    && request.auth.uid in get(/databases/$(database)/documents/conversations/$(conversationId)).data.participants
                    && request.resource.data.senderId == request.auth.uid;
      
      // Allow status updates by recipients
      allow update: if request.auth != null
                    && request.auth.uid in get(/databases/$(database)/documents/conversations/$(conversationId)).data.participants;
    }
  }
  ```

#### Deploy Rules
- [ ] Open Terminal
- [ ] Navigate to project directory:
  ```bash
  cd /Users/ijaramil/Documents/GauntletAI/Week2/messAI
  ```
- [ ] Deploy rules:
  ```bash
  firebase deploy --only firestore:rules
  ```
- [ ] Verify in Firebase Console: Firestore Database → Rules tab
- [ ] Check deployment timestamp (should be current)

#### Test Rules (Optional)
- [ ] In Firebase Console: Rules Playground
- [ ] Test: User creates group (should succeed)
- [ ] Test: Non-admin updates group (should fail)
- [ ] Test: Participant sends message (should succeed)
- [ ] Test: Non-participant reads messages (should fail)

**Checkpoint:** Firestore rules deployed and enforced ✓

**Commit:**
```bash
git add firebase/firestore.rules
git commit -m "[PR #13] Update Firestore security rules for group conversations"
```

---

## Testing Phase (60-90 minutes)

### Unit Tests (Optional for MVP, 20 minutes)
- [ ] Test `Conversation.isAdmin()`
- [ ] Test `Conversation.displayName()` with groups
- [ ] Test `Message.statusForGroup()` aggregation
- [ ] Test `ChatService.createGroupConversation()` validation

### Integration Tests (Manual, 40-60 minutes)

#### Test 1: Create Group Flow
- [ ] Open app on Device A
- [ ] Tap "+" button
- [ ] Select "New Group"
- [ ] Select 2+ contacts
- [ ] Enter group name: "Test Group"
- [ ] Tap "Create Group"
- [ ] Verify: ChatView opens with group conversation
- [ ] Verify: Title shows "Test Group"
- [ ] Verify: Subtitle shows "X participants"

#### Test 2: Send Group Message
- [ ] User A (Device A) sends message: "Hello group!"
- [ ] Verify on Device A:
  - [ ] Message appears immediately (blue bubble, right side)
  - [ ] No sender name above (it's your message)
  - [ ] Gray checkmark initially
- [ ] Verify on Device B (User B):
  - [ ] Message appears within 2 seconds (gray bubble, left side)
  - [ ] Sender name "User A" above message
  - [ ] Message readable
- [ ] Verify on Device C (User C):
  - [ ] Same as Device B

#### Test 3: Group Read Receipts
- [ ] User A sends message
- [ ] User B reads message (opens conversation)
- [ ] User A sees: Gray double-check (delivered, not all read)
- [ ] User C reads message
- [ ] User A sees: Blue double-check (all read)

#### Test 4: Group Info Navigation
- [ ] Open group conversation
- [ ] Tap navigation title (group name)
- [ ] Verify: GroupInfoView opens
- [ ] Verify: Shows group photo (or placeholder)
- [ ] Verify: Shows group name
- [ ] Verify: Shows participant list
- [ ] Verify: Shows admin badges correctly

#### Test 5: Edit Group Name (Admin)
- [ ] Admin user opens GroupInfoView
- [ ] Taps edit icon next to group name
- [ ] Enters new name: "Updated Group Name"
- [ ] Taps "Save"
- [ ] Verify: Name updates in GroupInfoView
- [ ] Verify: Name updates in ChatView navigation
- [ ] Verify: Name updates in ChatListView

#### Test 6: Add Participant (Admin)
- [ ] Admin opens GroupInfoView
- [ ] Taps "Add Participants"
- [ ] Selects 1 user
- [ ] Confirms
- [ ] Verify: New user added to participant list
- [ ] Verify: New user receives future messages
- [ ] Verify: Group count increases

#### Test 7: Remove Participant (Admin)
- [ ] Admin opens GroupInfoView
- [ ] Taps "..." menu on participant row
- [ ] Selects "Remove from Group"
- [ ] Confirms
- [ ] Verify: User removed from list
- [ ] Verify: Removed user no longer sees group
- [ ] Verify: Removed user cannot send messages (security rules block)

#### Test 8: Leave Group (Any Participant)
- [ ] Non-admin user opens GroupInfoView
- [ ] Scrolls to bottom
- [ ] Taps "Leave Group"
- [ ] Confirms
- [ ] Verify: Returns to ChatListView
- [ ] Verify: Group no longer in list
- [ ] Verify: Cannot send messages to group

#### Test 9: Large Group (10+ Participants)
- [ ] Create group with 10 participants
- [ ] Send message as User A
- [ ] Verify: All 10 receive within 5 seconds
- [ ] Verify: Scrolling is smooth (60fps)
- [ ] Verify: Read receipts aggregate correctly

#### Test 10: Auto-Generated Group Name
- [ ] Create group with 3 participants
- [ ] Leave "Group Name" field empty
- [ ] Verify: Chat list shows "Bob, Charlie"
- [ ] Verify: ChatView title shows "Bob, Charlie"
- [ ] Verify: Can edit name later

### Bug Fixes (As Encountered)
- [ ] Document any bugs found
- [ ] Fix bugs
- [ ] Re-test affected flows
- [ ] Commit bug fixes separately

---

## Documentation Phase (30-60 minutes)

### Update Memory Bank
- [ ] Open `memory-bank/activeContext.md`
- [ ] Update "What We're Working On" section
- [ ] Add PR #13 to completed PRs
- [ ] Update current focus

- [ ] Open `memory-bank/progress.md`
- [ ] Mark PR #13 tasks as complete
- [ ] Update progress percentages
- [ ] Update "What Works" section

### Update PR_PARTY README
- [ ] Open `PR_PARTY/README.md`
- [ ] Add PR #13 section under "Current PRs"
- [ ] Mark status as ✅ COMPLETE
- [ ] Add time taken (actual vs estimated)
- [ ] Add summary of what was built

### Write Complete Summary (Optional, 1-2 hours)
- [ ] Create `PR_PARTY/PR13_COMPLETE_SUMMARY.md`
- [ ] Document what was built
- [ ] List files created/modified
- [ ] Document bugs encountered and fixed
- [ ] Lessons learned
- [ ] Time breakdown

---

## Deployment Phase (15-30 minutes)

### Pre-Deploy Checklist
- [ ] All tests passing
- [ ] No console errors
- [ ] No console warnings (or documented why acceptable)
- [ ] Build successful: ⌘B
- [ ] No memory leaks (Instruments check)
- [ ] Firestore rules deployed
- [ ] Code reviewed (self-review against checklist)

### Deploy
- [ ] Commit any remaining changes:
  ```bash
  git add .
  git commit -m "[PR #13] Group chat functionality complete"
  ```
- [ ] Push to GitHub:
  ```bash
  git push origin feature/pr13-group-chat
  ```
- [ ] Create pull request (if using PR workflow)
- [ ] Merge to main:
  ```bash
  git checkout main
  git merge feature/pr13-group-chat
  git push origin main
  ```

### Post-Deploy
- [ ] Test on physical device (if possible)
- [ ] Verify group creation works end-to-end
- [ ] Verify messages deliver to all participants
- [ ] Monitor Firebase Console for errors
- [ ] Update documentation with any post-deploy findings

---

## Completion Checklist

### Functionality Complete
- [ ] Users can create groups (3-50 participants)
- [ ] Group messages deliver in real-time
- [ ] Sender names display in group messages
- [ ] Read receipts aggregate correctly
- [ ] Group info view accessible
- [ ] Admins can manage participants
- [ ] Participants can leave groups
- [ ] Auto-generated names work as fallback

### Code Quality
- [ ] All files compile without errors
- [ ] No compiler warnings (or documented)
- [ ] Code follows Swift style guide
- [ ] Consistent naming conventions
- [ ] Comments added for complex logic
- [ ] No duplicate code

### Documentation Complete
- [ ] Memory bank updated
- [ ] PR_PARTY README updated
- [ ] Complete summary written (optional)
- [ ] Inline code comments added

### Testing Complete
- [ ] Manual tests passed (10 scenarios)
- [ ] Bug fixes documented
- [ ] Performance acceptable
- [ ] Security rules working

### Deployment Complete
- [ ] Code committed to git
- [ ] Pushed to GitHub
- [ ] Merged to main
- [ ] Firebase rules deployed
- [ ] App runs on device

---

## Celebration! 🎉

- [ ] Take a break
- [ ] Reflect on what you learned
- [ ] Update PR status to COMPLETE
- [ ] Plan next PR (#14: Image Sharing)

**PR #13 Complete!** ✅

Group chat is now fully functional—users can coordinate with teams, families, and friends! 🚀

**Next Steps:**
- PR #14: Image Sharing (group photos, message images)
- PR #15: Offline Support (enhanced queuing)
- PR #17: Push Notifications (group notification settings)

---

**Remember:** Test thoroughly, commit frequently, and document as you go! Group chat is complex—take your time and verify each step works before moving on.

