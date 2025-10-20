# MessageAI MVP - Task List & PR Breakdown

## Project File Structure

```
MessageAI/
├── MessageAI.xcodeproj
├── MessageAI/
│   ├── MessageAIApp.swift
│   ├── GoogleService-Info.plist
│   │
│   ├── Models/
│   │   ├── User.swift
│   │   ├── Conversation.swift
│   │   ├── Message.swift
│   │   ├── MessageStatus.swift
│   │   └── TypingStatus.swift
│   │
│   ├── ViewModels/
│   │   ├── AuthViewModel.swift
│   │   ├── ChatListViewModel.swift
│   │   ├── ChatViewModel.swift
│   │   ├── GroupViewModel.swift
│   │   ├── ProfileViewModel.swift
│   │   └── ContactsViewModel.swift
│   │
│   ├── Views/
│   │   ├── Auth/
│   │   │   ├── LoginView.swift
│   │   │   ├── SignUpView.swift
│   │   │   └── ProfileSetupView.swift
│   │   │
│   │   ├── Chat/
│   │   │   ├── ChatListView.swift
│   │   │   ├── ChatView.swift
│   │   │   ├── MessageBubbleView.swift
│   │   │   ├── MessageInputView.swift
│   │   │   └── TypingIndicatorView.swift
│   │   │
│   │   ├── Contacts/
│   │   │   ├── ContactsListView.swift
│   │   │   └── ContactRowView.swift
│   │   │
│   │   ├── Group/
│   │   │   ├── NewGroupView.swift
│   │   │   ├── GroupInfoView.swift
│   │   │   └── ParticipantSelectionView.swift
│   │   │
│   │   └── Profile/
│   │       ├── ProfileView.swift
│   │       └── EditProfileView.swift
│   │
│   ├── Services/
│   │   ├── FirebaseService.swift
│   │   ├── AuthService.swift
│   │   ├── ChatService.swift
│   │   ├── PresenceService.swift
│   │   ├── StorageService.swift
│   │   ├── NotificationService.swift
│   │   └── NetworkMonitor.swift
│   │
│   ├── Persistence/
│   │   ├── MessageEntity.swift
│   │   ├── ConversationEntity.swift
│   │   ├── LocalDataManager.swift
│   │   └── SyncManager.swift
│   │
│   ├── Utilities/
│   │   ├── ImagePicker.swift
│   │   ├── ImageCompressor.swift
│   │   ├── DateFormatter+Extensions.swift
│   │   ├── String+Extensions.swift
│   │   └── Constants.swift
│   │
│   └── Assets.xcassets/
│       ├── AppIcon
│       ├── Colors/
│       └── Images/
│
├── firebase/
│   ├── functions/
│   │   ├── index.js
│   │   ├── package.json
│   │   └── sendNotification.js
│   │
│   └── firestore.rules
│
└── README.md
```

---

## PR Breakdown & Task List

### PR #1: Project Setup & Firebase Configuration
**Branch**: `feature/project-setup`  
**Goal**: Initialize Xcode project and configure Firebase integration  
**Estimated Time**: 1-2 hours

#### Tasks:
- [ ] **Create Xcode Project**
  - Create new iOS App project in Xcode
  - Name: MessageAI
  - Interface: SwiftUI
  - Language: Swift
  - Minimum iOS: 16.0
  - Files created: `MessageAIApp.swift`, project structure

- [ ] **Set up Firebase Project**
  - Create Firebase project at console.firebase.google.com
  - Enable Authentication (Email/Password provider)
  - Create Firestore database (test mode initially)
  - Enable Firebase Storage
  - Download `GoogleService-Info.plist`

- [ ] **Add Firebase SDK**
  - Add Firebase via Swift Package Manager
  - Packages: FirebaseAuth, FirebaseFirestore, FirebaseStorage, FirebaseMessaging
  - Add `GoogleService-Info.plist` to project root

- [ ] **Configure Firebase in App**
  - **File**: `MessageAIApp.swift`
  - Import FirebaseCore
  - Add `FirebaseApp.configure()` in init
  - Test app launches without errors

- [ ] **Create Basic File Structure**
  - Create folders: Models, ViewModels, Views, Services, Utilities, Persistence
  - Create subfolder: Views/Auth, Views/Chat, Views/Contacts, Views/Group, Views/Profile

- [ ] **Add Constants File**
  - **File**: `Utilities/Constants.swift`
  - Define app-wide constants (colors, strings, config values)

- [ ] **Create README**
  - **File**: `README.md`
  - Project description, setup instructions, Firebase config steps

**Files Created/Modified:**
- `MessageAIApp.swift` ✏️
- `GoogleService-Info.plist` ➕
- `Utilities/Constants.swift` ➕
- `README.md` ➕

---

### PR #2: Authentication - Models & Services
**Branch**: `feature/auth-services`  
**Goal**: Implement authentication logic and user management  
**Estimated Time**: 2-3 hours

#### Tasks:
- [ ] **Create User Model**
  - **File**: `Models/User.swift`
  - Properties: id, email, displayName, photoURL, fcmToken, isOnline, lastSeen, createdAt
  - Codable conformance for Firestore
  - Initializers and helper methods

- [ ] **Create AuthService**
  - **File**: `Services/AuthService.swift`
  - Sign up method (email, password, displayName)
  - Login method (email, password)
  - Logout method
  - Password reset method
  - Current user getter
  - Create user document in Firestore on signup

- [ ] **Create FirebaseService Base**
  - **File**: `Services/FirebaseService.swift`
  - Firestore reference getters
  - Helper methods for document creation
  - Error handling utilities
  - Timestamp helpers

- [ ] **Create AuthViewModel**
  - **File**: `ViewModels/AuthViewModel.swift`
  - @Published properties: currentUser, isAuthenticated, errorMessage, isLoading
  - Methods: signUp, login, logout, checkAuthState
  - Observe Firebase auth state changes
  - Handle authentication errors

- [ ] **Add Info.plist Entries**
  - **File**: `Info.plist`
  - Add camera usage description
  - Add photo library usage description

**Files Created/Modified:**
- `Models/User.swift` ➕
- `Services/AuthService.swift` ➕
- `Services/FirebaseService.swift` ➕
- `ViewModels/AuthViewModel.swift` ➕
- `Info.plist` ✏️

---

### PR #3: Authentication - UI Views
**Branch**: `feature/auth-ui`  
**Goal**: Build login and signup screens  
**Estimated Time**: 2-3 hours

#### Tasks:
- [ ] **Create LoginView**
  - **File**: `Views/Auth/LoginView.swift`
  - Email and password text fields
  - Login button
  - "Don't have an account?" link to signup
  - Error message display
  - Loading state during login
  - Form validation

- [ ] **Create SignUpView**
  - **File**: `Views/Auth/SignUpView.swift`
  - Display name text field
  - Email and password text fields
  - Password confirmation field
  - Sign up button
  - "Already have an account?" link to login
  - Error message display
  - Form validation

- [ ] **Create ProfileSetupView**
  - **File**: `Views/Auth/ProfileSetupView.swift`
  - Profile picture upload (optional for MVP)
  - Display name confirmation
  - "Get Started" button
  - Navigate to main app after setup

- [ ] **Update App Entry Point**
  - **File**: `MessageAIApp.swift`
  - Check authentication state
  - Show LoginView if not authenticated
  - Show ChatListView if authenticated
  - Use @StateObject for AuthViewModel

- [ ] **Add Auth Flow Navigation**
  - Handle navigation between Login/SignUp/ProfileSetup
  - Dismiss auth views on successful authentication

**Files Created/Modified:**
- `Views/Auth/LoginView.swift` ➕
- `Views/Auth/SignUpView.swift` ➕
- `Views/Auth/ProfileSetupView.swift` ➕
- `MessageAIApp.swift` ✏️

**Testing:**
- Sign up new user → verify user created in Firestore
- Login with existing user → verify authentication works
- Logout → verify returns to login screen

---

### PR #4: Core Models & Data Structure
**Branch**: `feature/core-models`  
**Goal**: Create data models for messages and conversations  
**Estimated Time**: 1-2 hours

#### Tasks:
- [ ] **Create Message Model**
  - **File**: `Models/Message.swift`
  - Properties: id, conversationId, senderId, text, imageURL, sentAt, deliveredAt, readAt, status
  - MessageStatus enum: sending, sent, delivered, read
  - Codable conformance
  - Computed properties: isSent, isDelivered, isRead
  - Initialize from Firestore document

- [ ] **Create MessageStatus Enum**
  - **File**: `Models/MessageStatus.swift`
  - Cases: sending, sent, delivered, read, failed
  - Icon and color for each status
  - String raw values for Firestore

- [ ] **Create Conversation Model**
  - **File**: `Models/Conversation.swift`
  - Properties: id, participants, isGroup, groupName, groupIcon, lastMessage, lastMessageAt, createdBy, createdAt
  - Codable conformance
  - Helper methods: isOneOnOne, otherParticipant(currentUserId)
  - Computed properties for display

- [ ] **Create TypingStatus Model**
  - **File**: `Models/TypingStatus.swift`
  - Properties: userId, conversationId, isTyping, timestamp
  - Helper method to check if still typing (within 3 seconds)

**Files Created/Modified:**
- `Models/Message.swift` ➕
- `Models/MessageStatus.swift` ➕
- `Models/Conversation.swift` ➕
- `Models/TypingStatus.swift` ➕

---

### PR #5: Chat Service & Firestore Integration
**Branch**: `feature/chat-service`  
**Goal**: Implement core messaging logic with Firestore  
**Estimated Time**: 3-4 hours

#### Tasks:
- [ ] **Create ChatService**
  - **File**: `Services/ChatService.swift`
  - Method: createConversation(participants, isGroup, groupName)
  - Method: sendMessage(conversationId, text, imageURL)
  - Method: fetchConversations(userId) with real-time listener
  - Method: fetchMessages(conversationId) with real-time listener
  - Method: updateMessageStatus(messageId, status)
  - Method: markMessagesAsRead(conversationId, userId)
  - Handle optimistic message creation
  - Generate unique message IDs

- [ ] **Add Firestore Listeners**
  - Implement snapshot listeners for real-time updates
  - Handle listener cleanup (detach on deinit)
  - Parse Firestore documents to models
  - Handle errors and connection states

- [ ] **Implement Message Queueing**
  - Queue for messages pending send
  - Retry logic for failed sends
  - Update local message status on success/failure

- [ ] **Add Firestore Security Rules**
  - **File**: `firebase/firestore.rules`
  - Rules for authenticated users only
  - Users can only read/write their own conversations
  - Users can only send messages to conversations they're in
  - Deploy rules: `firebase deploy --only firestore:rules`

**Files Created/Modified:**
- `Services/ChatService.swift` ➕
- `firebase/firestore.rules` ➕

---

### PR #6: Local Persistence with SwiftData
**Branch**: `feature/local-persistence`  
**Goal**: Implement local data storage for offline support  
**Estimated Time**: 2-3 hours

#### Tasks:
- [ ] **Create MessageEntity**
  - **File**: `Persistence/MessageEntity.swift`
  - SwiftData @Model class
  - Properties matching Message model
  - Additional: isSynced (Bool), syncAttempts (Int)
  - Relationships to ConversationEntity

- [ ] **Create ConversationEntity**
  - **File**: `Persistence/ConversationEntity.swift`
  - SwiftData @Model class
  - Properties matching Conversation model
  - @Relationship with MessageEntity (one-to-many)
  - Cascade delete rule for messages

- [ ] **Create LocalDataManager**
  - **File**: `Persistence/LocalDataManager.swift`
  - SwiftData ModelContainer and ModelContext
  - Methods: saveMessage, fetchMessages, updateMessage, deleteMessage
  - Methods: saveConversation, fetchConversations, updateConversation
  - Batch operations for sync
  - Query helpers with predicates

- [ ] **Create SyncManager**
  - **File**: `Persistence/SyncManager.swift`
  - Sync local messages to Firestore
  - Sync Firestore messages to local storage
  - Handle conflicts (server timestamp wins)
  - Queue unsynced messages for retry
  - Background sync on app foreground

- [ ] **Configure SwiftData in App**
  - **File**: `MessageAIApp.swift`
  - Add ModelContainer modifier
  - Pass ModelContext to environment
  - Configure persistence store

**Files Created/Modified:**
- `Persistence/MessageEntity.swift` ➕
- `Persistence/ConversationEntity.swift` ➕
- `Persistence/LocalDataManager.swift` ➕
- `Persistence/SyncManager.swift` ➕
- `MessageAIApp.swift` ✏️

---

### PR #7: Chat List View
**Branch**: `feature/chat-list`  
**Goal**: Display list of conversations  
**Estimated Time**: 2-3 hours

#### Tasks:
- [ ] **Create ChatListViewModel**
  - **File**: `ViewModels/ChatListViewModel.swift`
  - @Published property: conversations (array)
  - @Published property: isLoading
  - Method: loadConversations()
  - Method: deleteConversation(id)
  - Attach Firestore listener for real-time updates
  - Sort conversations by lastMessageAt
  - Map User data for participant names/photos

- [ ] **Create ChatListView**
  - **File**: `Views/Chat/ChatListView.swift`
  - Navigation title: "Messages"
  - List of conversation rows
  - Pull-to-refresh
  - Empty state view (no conversations yet)
  - Navigation to ChatView on row tap
  - Toolbar with "New Message" button
  - Search bar (optional for MVP)

- [ ] **Create Conversation Row Component**
  - Display participant profile picture
  - Display conversation name (participant name or group name)
  - Display last message preview (truncated)
  - Display timestamp (relative: "2m ago", "Yesterday")
  - Unread indicator/badge
  - Swipe actions: Delete (optional)

- [ ] **Add Date Formatter Extension**
  - **File**: `Utilities/DateFormatter+Extensions.swift`
  - Relative time formatter ("Just now", "5m ago", "Yesterday", "Jan 3")
  - Helper methods for message timestamps

**Files Created/Modified:**
- `ViewModels/ChatListViewModel.swift` ➕
- `Views/Chat/ChatListView.swift` ➕
- `Utilities/DateFormatter+Extensions.swift` ➕

**Testing:**
- View should show empty state initially
- Create conversation manually in Firestore → verify appears in list

---

### PR #8: Contact Selection & New Chat
**Branch**: `feature/contacts`  
**Goal**: Allow users to select contacts and start conversations  
**Estimated Time**: 2 hours

#### Tasks:
- [ ] **Create ContactsViewModel**
  - **File**: `ViewModels/ContactsViewModel.swift`
  - @Published property: users (all registered users)
  - @Published property: filteredUsers (search results)
  - Method: loadUsers() - fetch from Firestore
  - Method: searchUsers(query) - filter by name
  - Exclude current user from list

- [ ] **Create ContactsListView**
  - **File**: `Views/Contacts/ContactsListView.swift`
  - Search bar at top
  - List of all users
  - User row: profile picture, display name, online status
  - Tap user to start conversation
  - Navigation back after selection

- [ ] **Create ContactRowView**
  - **File**: `Views/Contacts/ContactRowView.swift`
  - Reusable user row component
  - Profile picture (circular)
  - Display name
  - Online status indicator (green/gray dot)
  - Optional: last seen text

- [ ] **Integrate New Chat Flow**
  - **File**: `Views/Chat/ChatListView.swift`
  - Add "+" button in toolbar
  - Present ContactsListView as sheet
  - On contact selection:
    - Check if conversation exists with user
    - If exists: navigate to existing conversation
    - If not: create new conversation, navigate to it

- [ ] **Update ChatListViewModel**
  - **File**: `ViewModels/ChatListViewModel.swift`
  - Method: getOrCreateConversation(otherUserId)
  - Create conversation in Firestore if doesn't exist
  - Return conversation ID for navigation

**Files Created/Modified:**
- `ViewModels/ContactsViewModel.swift` ➕
- `Views/Contacts/ContactsListView.swift` ➕
- `Views/Contacts/ContactRowView.swift` ➕
- `Views/Chat/ChatListView.swift` ✏️
- `ViewModels/ChatListViewModel.swift` ✏️

**Testing:**
- Tap "+" → see list of users
- Tap user → create conversation → navigate to chat

---

### PR #9: Chat View - UI Components
**Branch**: `feature/chat-ui`  
**Goal**: Build chat interface with message bubbles  
**Estimated Time**: 3-4 hours

#### Tasks:
- [ ] **Create ChatViewModel**
  - **File**: `ViewModels/ChatViewModel.swift`
  - @Published property: messages (array)
  - @Published property: conversation
  - @Published property: otherUser (for one-on-one)
  - @Published property: messageText (input binding)
  - Method: loadMessages() with real-time listener
  - Method: sendMessage(text)
  - Method: sendImage(image)
  - Handle optimistic UI (add message locally before confirmation)
  - Update message status on Firestore updates

- [ ] **Create ChatView**
  - **File**: `Views/Chat/ChatView.swift`
  - Navigation title: other user's name (or group name)
  - ScrollView with messages
  - Auto-scroll to bottom on new messages
  - MessageInputView at bottom
  - Typing indicator above input
  - Pull-to-refresh for loading history (optional)

- [ ] **Create MessageBubbleView**
  - **File**: `Views/Chat/MessageBubbleView.swift`
  - Different styles for sent (blue, right) vs received (gray, left)
  - Display message text
  - Display timestamp below message
  - Display status indicators (checkmarks) for sent messages
  - Display sender name for group messages
  - Handle image messages (show thumbnail)
  - Tail on bubble pointing to sender/recipient

- [ ] **Create MessageInputView**
  - **File**: `Views/Chat/MessageInputView.swift`
  - Text field for message input
  - Send button (disabled if empty)
  - "+" button for attachments
  - Auto-resize text field (multi-line support)
  - Clear input after send

- [ ] **Create TypingIndicatorView**
  - **File**: `Views/Chat/TypingIndicatorView.swift`
  - Animated "..." indicator
  - Display "{Name} is typing..."
  - Fade in/out animation

- [ ] **Add String Extensions**
  - **File**: `Utilities/String+Extensions.swift`
  - Trim whitespace
  - Validate non-empty
  - Character count helpers

**Files Created/Modified:**
- `ViewModels/ChatViewModel.swift` ➕
- `Views/Chat/ChatView.swift` ➕
- `Views/Chat/MessageBubbleView.swift` ➕
- `Views/Chat/MessageInputView.swift` ➕
- `Views/Chat/TypingIndicatorView.swift` ➕
- `Utilities/String+Extensions.swift` ➕

---

### PR #10: Real-Time Messaging & Optimistic UI
**Branch**: `feature/realtime-messaging`  
**Goal**: Implement message sending with instant feedback  
**Estimated Time**: 2-3 hours

#### Tasks:
- [ ] **Implement Optimistic UI in ChatViewModel**
  - **File**: `ViewModels/ChatViewModel.swift`
  - When user sends message:
    - Create local Message object with status: .sending
    - Append to messages array immediately
    - Save to SwiftData
    - Send to Firestore in background
  - On Firestore confirmation:
    - Update local message status to .sent
    - Update message with server-generated ID and timestamp
  - On error:
    - Update status to .failed
    - Show retry option

- [ ] **Update ChatService for Optimistic Sends**
  - **File**: `Services/ChatService.swift`
  - Return temporary message ID immediately
  - Send to Firestore asynchronously
  - Return completion with server message ID
  - Handle send failures with error callback

- [ ] **Implement Real-Time Listener**
  - Listen to messages collection with `.addSnapshotListener()`
  - Handle document changes: added, modified, removed
  - Update local messages array
  - Sync to SwiftData
  - Sort messages by sentAt timestamp

- [ ] **Add Message Deduplication**
  - Check if message already exists locally before adding
  - Use message ID as unique identifier
  - Prevent duplicate messages on listener updates

- [ ] **Handle Scroll to Bottom**
  - **File**: `Views/Chat/ChatView.swift`
  - Scroll to last message on view appear
  - Scroll to bottom when new message arrives (if already near bottom)
  - Add "scroll to bottom" button if user scrolls up

**Files Created/Modified:**
- `ViewModels/ChatViewModel.swift` ✏️
- `Services/ChatService.swift` ✏️
- `Views/Chat/ChatView.swift` ✏️

**Testing:**
- Send message → appears instantly
- Check Firestore → message saved
- Second device → message appears within 2 seconds

---

### PR #11: Message Status Indicators
**Branch**: `feature/message-status`  
**Goal**: Track and display message delivery status  
**Estimated Time**: 2 hours

#### Tasks:
- [ ] **Update ChatService for Status Tracking**
  - **File**: `Services/ChatService.swift`
  - Method: updateMessageDelivered(messageId, conversationId)
  - Method: markMessagesAsRead(conversationId, userId)
  - Call updateMessageDelivered when message received
  - Call markMessagesAsRead when user opens conversation

- [ ] **Implement Status Update Logic in ChatViewModel**
  - **File**: `ViewModels/ChatViewModel.swift`
  - On view appear: mark all messages as read
  - Listen for status changes from Firestore
  - Update local message status

- [ ] **Add Status Indicators to MessageBubbleView**
  - **File**: `Views/Chat/MessageBubbleView.swift`
  - Show checkmark icons for sent messages only
  - Status icons:
    - Sending: single gray checkmark
    - Sent: single checkmark
    - Delivered: double checkmarks
    - Read: blue double checkmarks
  - Position below message text, right-aligned

- [ ] **Update Message Model**
  - **File**: `Models/Message.swift`
  - Add computed property: statusIcon (returns SF Symbol name)
  - Add computed property: statusColor (returns Color)

**Files Created/Modified:**
- `Services/ChatService.swift` ✏️
- `ViewModels/ChatViewModel.swift` ✏️
- `Views/Chat/MessageBubbleView.swift` ✏️
- `Models/Message.swift` ✏️

**Testing:**
- Send message → see single checkmark
- Message received on server → double checkmarks
- Recipient opens chat → blue double checkmarks

---

### PR #12: Presence & Typing Indicators
**Branch**: `feature/presence-typing`  
**Goal**: Show online status and typing indicators  
**Estimated Time**: 2-3 hours

#### Tasks:
- [ ] **Create PresenceService**
  - **File**: `Services/PresenceService.swift`
  - Method: updatePresence(userId, isOnline)
  - Method: observePresence(userId, callback)
  - Update Firestore on app foreground/background
  - Listen to other users' presence
  - Update lastSeen timestamp

- [ ] **Integrate Presence in App Lifecycle**
  - **File**: `MessageAIApp.swift`
  - Use `.onAppear()` and `.onChange(of: scenePhase)`
  - Set user online on foreground
  - Set user offline on background
  - Update lastSeen timestamp

- [ ] **Add Typing Indicator Logic to ChatViewModel**
  - **File**: `ViewModels/ChatViewModel.swift`
  - @Published property: isOtherUserTyping
  - Method: sendTypingIndicator()
  - Method: observeTypingStatus()
  - Debounce typing indicator (send after 0.5s of typing)
  - Clear after 3 seconds of no activity
  - Update Firestore typingStatus collection

- [ ] **Implement Typing Indicator in ChatService**
  - **File**: `Services/ChatService.swift`
  - Method: updateTypingStatus(conversationId, userId, isTyping)
  - Method: observeTypingStatus(conversationId, callback)
  - Store in separate `typingStatus/{conversationId}` document

- [ ] **Update MessageInputView for Typing Detection**
  - **File**: `Views/Chat/MessageInputView.swift`
  - Add `.onChange(of: text)` modifier
  - Call ViewModel's sendTypingIndicator() on text change
  - Debounce to avoid excessive updates

- [ ] **Display Presence in ChatView**
  - **File**: `Views/Chat/ChatView.swift`
  - Show online/offline status in navigation bar
  - Show "last seen" if offline
  - Show typing indicator when other user is typing

- [ ] **Display Presence in ChatListView**
  - **File**: `Views/Chat/ChatListView.swift`
  - Show green/gray dot next to conversation names
  - Update in real-time as users go online/offline

**Files Created/Modified:**
- `Services/PresenceService.swift` ➕
- `MessageAIApp.swift` ✏️
- `ViewModels/ChatViewModel.swift` ✏️
- `Services/ChatService.swift` ✏️
- `Views/Chat/MessageInputView.swift` ✏️
- `Views/Chat/ChatView.swift` ✏️
- `Views/Chat/ChatListView.swift` ✏️

**Testing:**
- User goes online → green dot appears
- User backgrounds app → status changes to offline
- User types → other user sees "typing..."

---

### PR #13: Group Chat Functionality
**Branch**: `feature/group-chat`  
**Goal**: Create and participate in group conversations  
**Estimated Time**: 3-4 hours

#### Tasks:
- [ ] **Create GroupViewModel**
  - **File**: `ViewModels/GroupViewModel.swift`
  - @Published property: selectedParticipants (array)
  - @Published property: groupName (String)
  - Method: createGroup() - create conversation in Firestore
  - Method: addParticipants(userIds)
  - Validation for group name and participants (min 3 users)

- [ ] **Create NewGroupView**
  - **File**: `Views/Group/NewGroupView.swift`
  - Group name text field
  - "Add Participants" button → navigate to ParticipantSelectionView
  - List of selected participants (removable)
  - "Create Group" button
  - Navigation back to chat list on creation

- [ ] **Create ParticipantSelectionView**
  - **File**: `Views/Group/ParticipantSelectionView.swift`
  - List of all users with checkboxes
  - Search bar to filter users
  - "Done" button to confirm selection
  - Show count of selected participants
  - Multi-select functionality

- [ ] **Create GroupInfoView**
  - **File**: `Views/Group/GroupInfoView.swift`
  - Display group name
  - Display group icon (optional)
  - List all participants with profile pictures
  - Show participant count
  - "Leave Group" button (optional for MVP)

- [ ] **Update ChatService for Groups**
  - **File**: `Services/ChatService.swift`
  - Modify createConversation to handle groups
  - Ensure isGroup flag set correctly
  - Store groupName in conversation document
  - Store all participant IDs

- [ ] **Update ChatView for Groups**
  - **File**: `Views/Chat/ChatView.swift`
  - Show sender name above each message bubble
  - Show sender profile picture next to bubbles
  - Update navigation title to show group name
  - Add info button → navigate to GroupInfoView

- [ ] **Update MessageBubbleView for Groups**
  - **File**: `Views/Chat/MessageBubbleView.swift`
  - Show sender name for received messages
  - Show small profile picture for received messages
  - Different layout for group vs one-on-one

- [ ] **Add Group Chat Entry Point**
  - **File**: `Views/Chat/ChatListView.swift`
  - Update "+" button to show action sheet
  - Options: "New Message" (one-on-one) or "New Group"
  - Navigate to NewGroupView on "New Group"

**Files Created/Modified:**
- `ViewModels/GroupViewModel.swift` ➕
- `Views/Group/NewGroupView.swift` ➕
- `Views/Group/ParticipantSelectionView.swift` ➕
- `Views/Group/GroupInfoView.swift` ➕
- `Services/ChatService.swift` ✏️
- `Views/Chat/ChatView.swift` ✏️
- `Views/Chat/MessageBubbleView.swift` ✏️
- `Views/Chat/ChatListView.swift` ✏️

**Testing:**
- Create group with 3 users
- Send message in group → all participants receive
- Verify sender names appear correctly

---

### PR #14: Image Sharing - Storage Integration
**Branch**: `feature/image-sharing`  
**Goal**: Upload and download images via Firebase Storage  
**Estimated Time**: 2-3 hours

#### Tasks:
- [ ] **Create StorageService**
  - **File**: `Services/StorageService.swift`
  - Method: uploadImage(image, path) → returns Storage URL
  - Method: uploadMessageImage(image, conversationId, messageId)
  - Method: uploadProfilePicture(image, userId)
  - Method: downloadImage(url) → returns UIImage
  - Generate unique filenames with UUID
  - Handle upload progress (optional)

- [ ] **Create ImageCompressor Utility**
  - **File**: `Utilities/ImageCompressor.swift`
  - Method: compress(image, maxSizeMB) → returns compressed UIImage
  - Resize to reasonable dimensions (max 1920px width)
  - Compress to JPEG with quality 0.7
  - Generate thumbnail (200x200) for chat display

- [ ] **Create ImagePicker Utility**
  - **File**: `Utilities/ImagePicker.swift`
  - UIViewControllerRepresentable wrapper for UIImagePickerController
  - Support photo library and camera
  - Return selected image via binding
  - Handle cancellation

- [ ] **Update ChatViewModel for Images**
  - **File**: `ViewModels/ChatViewModel.swift`
  - @Published property: isUploadingImage
  - @Published property: uploadProgress
  - Method: sendImageMessage(image)
  - Compress image before upload
  - Upload to Storage
  - Create message with imageURL
  - Show loading state during upload

- [ ] **Update MessageBubbleView for Images**
  - **File**: `Views/Chat/MessageBubbleView.swift`
  - Detect if message has imageURL
  - Display AsyncImage for image messages
  - Show loading spinner while image loads
  - Tap to view full-screen
  - Fallback placeholder if image fails to load

- [ ] **Add Image Viewer Modal**
  - **File**: `Views/Chat/ImageViewerView.swift`
  - Full-screen image viewer
  - Pinch to zoom
  - Dismiss gesture (swipe down)
  - Share/save button (optional)

- [ ] **Update MessageInputView for Image Selection**
  - **File**: `Views/Chat/MessageInputView.swift`
  - Add "+" button next to text field
  - Present ImagePicker on tap
  - Show selected image preview before sending
  - "Send" button for image
  - Loading indicator during upload

**Files Created/Modified:**
- `Services/StorageService.swift` ➕
- `Utilities/ImageCompressor.swift` ➕
- `Utilities/ImagePicker.swift` ➕
- `ViewModels/ChatViewModel.swift` ✏️
- `Views/Chat/MessageBubbleView.swift` ✏️
- `Views/Chat/ImageViewerView.swift` ➕
- `Views/Chat/MessageInputView.swift` ✏️

**Testing:**
- Select image from library → uploads → appears in chat
- Take photo with camera → uploads → appears in chat
- Recipient receives image → can view full-screen

---

### PR #15: Offline Support & Network Monitoring
**Branch**: `feature/offline-support`  
**Goal**: Handle offline scenarios and queue messages  
**Estimated Time**: 2-3 hours

#### Tasks:
- [ ] **Create NetworkMonitor**
  - **File**: `Services/NetworkMonitor.swift`
  - Use NWPathMonitor to detect connectivity
  - @Published property: isConnected (Bool)
  - @Published property: connectionType (wifi/cellular/none)
  - Start monitoring on init
  - Publish connectivity changes

- [ ] **Enable Firestore Offline Persistence**
  - **File**: `Services/FirebaseService.swift`
  - Configure Firestore settings
  - Enable offline persistence: `settings.isPersistenceEnabled = true`
  - Set cache size limit

- [ ] **Update SyncManager for Offline Queue**
  - **File**: `Persistence/SyncManager.swift`
  - Method: queueMessage(message) - store unsynced message
  - Method: syncQueuedMessages() - send all queued messages
  - Listen to NetworkMonitor connectivity changes
  - Auto-sync when connection restored
  - Update message status from "sending" to "sent" on sync

- [ ] **Update ChatViewModel for Offline Handling**
  - **File**: `ViewModels/ChatViewModel.swift`
  - Inject NetworkMonitor
  - When offline: save messages to queue only
  - Show "No connection" banner in UI
  - When online: trigger sync automatically

- [ ] **Add Connection Status Banner to ChatView**
  - **File**: `Views/Chat/ChatView.swift`
  - Display banner at top when offline
  - Show "Waiting for connection..." message
  - Show "Reconnecting..." when coming back online
  - Auto-hide when connected

- [ ] **Update ChatListView for Offline Indicator**
  - **File**: `Views/Chat/ChatListView.swift`
  - Show offline indicator in navigation bar
  - Disable "New Message" when offline

- [ ] **Test Offline Scenarios**
  - Turn off WiFi → send message → message queued
  - Turn on WiFi → message syncs automatically
  - App restart while offline → messages still queued

**Files Created/Modified:**
- `Services/NetworkMonitor.swift` ➕
- `Services/FirebaseService.swift` ✏️
- `Persistence/SyncManager.swift` ✏️
- `ViewModels/ChatViewModel.swift` ✏️
- `Views/Chat/ChatView.swift` ✏️
- `Views/Chat/ChatListView.swift` ✏️

**Testing:**
- Enable airplane mode → send message → message queued locally
- Disable airplane mode → message syncs to Firestore
- Verify message appears on other device after sync

---

### PR #16: Profile Management
**Branch**: `feature/profile-management`  
**Goal**: View and edit user profile  
**Estimated Time**: 2 hours

#### Tasks:
- [ ] **Create ProfileViewModel**
  - **File**: `ViewModels/ProfileViewModel.swift`
  - @Published property: currentUser
  - @Published property: isEditingProfile
  - Method: updateDisplayName(name)
  - Method: updateProfilePicture(image)
  - Method: logout()
  - Load current user data from Firestore

- [ ] **Create ProfileView**
  - **File**: `Views/Profile/ProfileView.swift`
  - Display profile picture (large, circular)
  - Display display name
  - Display email (read-only)
  - "Edit Profile" button
  - "Logout" button
  - Account creation date

- [ ] **Create EditProfileView**
  - **File**: `Views/Profile/EditProfileView.swift`
  - Editable profile picture (tap to change)
  - Editable display name text field
  - "Save" button
  - "Cancel" button
  - Show loading state during save
  - Validate name is not empty

- [ ] **Update ProfilePicture Upload**
  - Use StorageService to upload image
  - Update user document in Firestore with new photoURL
  - Update local cached user data

- [ ] **Add Tab Navigation**
  - **File**: `MessageAIApp.swift` or create `MainTabView.swift`
  - TabView with 3 tabs: Chats, Contacts, Profile
  - Icons for each tab
  - Default to Chats tab

**Files Created/Modified:**
- `ViewModels/ProfileViewModel.swift` ➕
- `Views/Profile/ProfileView.swift` ➕
- `Views/Profile/EditProfileView.swift` ➕
- `MessageAIApp.swift` ✏️ (or create `MainTabView.swift` ➕)

**Testing:**
- Navigate to Profile tab
- Edit display name → save → verify updates everywhere
- Upload profile picture → verify appears in chats

---

### PR #17: Push Notifications - Firebase Cloud Messaging
**Branch**: `feature/push-notifications`  
**Goal**: Receive notifications for new messages  
**Estimated Time**: 3-4 hours

#### Tasks:
- [ ] **Configure APNs in Firebase**
  - Generate APNs authentication key in Apple Developer portal
  - Upload to Firebase Console (Project Settings → Cloud Messaging)
  - Enable Push Notifications capability in Xcode

- [ ] **Create NotificationService**
  - **File**: `Services/NotificationService.swift`
  - Request notification permissions on app launch
  - Register for remote notifications
  - Store FCM token in user document
  - Handle token refresh
  - Method: updateFCMToken(userId, token)

- [ ] **Update MessageAIApp for Notifications**
  - **File**: `MessageAIApp.swift`
  - Import UserNotifications and FirebaseMessaging
  - Request permission in `.onAppear()`
  - Register for remote notifications
  - Handle notification tap (deep link to conversation)

- [ ] **Add AppDelegate for Notification Handling**
  - **File**: `AppDelegate.swift` (create if needed)
  - Implement UNUserNotificationCenterDelegate
  - Handle foreground notifications
  - Handle background notification tap
  - Extract conversationId from notification payload

- [ ] **Create Cloud Function for Notifications**
  - **File**: `firebase/functions/index.js`
  - Initialize Firebase Functions
  - Create Firestore trigger on new messages
  - Fetch recipient's FCM token
  - Send notification via FCM admin SDK
  - Include sender name and message preview in payload

- [ ] **Create sendNotification Cloud Function**
  - **File**: `firebase/functions/sendNotification.js`
  - Function: onMessageCreated trigger
  - Get conversation participants
  - Exclude sender from notification recipients
  - Fetch each recipient's FCM token
  - Send push notification with:
    - Title: sender name
    - Body: message text preview
    - Badge: increment unread count
    - Data: conversationId for deep linking

- [ ] **Deploy Cloud Functions**
  - Initialize Firebase Functions: `firebase init functions`
  - Install dependencies: `npm install` in functions/
  - Deploy: `firebase deploy --only functions`

- [ ] **Handle Notification Deep Linking**
  - Parse notification payload for conversationId
  - Navigate to ChatView with conversationId
  - Mark messages as read on open

- [ ] **Add Info.plist Entries**
  - **File**: `Info.plist`
  - Add background modes: remote-notification

**Files Created/Modified:**
- `Services/NotificationService.swift` ➕
- `MessageAIApp.swift` ✏️
- `AppDelegate.swift` ➕ (if needed)
- `firebase/functions/index.js` ➕
- `firebase/functions/sendNotification.js` ➕
- `firebase/functions/package.json` ➕
- `Info.plist` ✏️

**Testing:**
- Send message while recipient app is in foreground → banner appears
- Send message while recipient app is backgrounded → notification appears
- Tap notification → opens to correct conversation

---

### PR #18: App Lifecycle & Background Handling
**Branch**: `feature/app-lifecycle`  
**Goal**: Handle app states (foreground, background, terminated)  
**Estimated Time**: 1-2 hours

#### Tasks:
- [ ] **Update MessageAIApp for Scene Phase**
  - **File**: `MessageAIApp.swift`
  - Import SwiftUI Environment
  - @Environment(\.scenePhase) var scenePhase
  - `.onChange(of: scenePhase)` modifier
  - Handle .active, .inactive, .background states

- [ ] **Handle Foreground State**
  - Set user presence to online
  - Refresh conversations and messages
  - Trigger sync for queued messages
  - Mark visible messages as read

- [ ] **Handle Background State**
  - Set user presence to offline
  - Update lastSeen timestamp
  - Save pending data to local storage
  - Detach Firestore listeners (optional for battery)

- [ ] **Handle Inactive State**
  - Pause non-critical operations
  - Save current state

- [ ] **Test App Lifecycle**
  - Background app → verify presence updates
  - Kill app → reopen → verify data persists
  - Background app → receive message → verify notification

- [ ] **Add Background Fetch (Optional)**
  - Enable background fetch capability
  - Fetch new messages in background
  - Update badge count

**Files Created/Modified:**
- `MessageAIApp.swift` ✏️
- `Services/PresenceService.swift` ✏️
- `Persistence/SyncManager.swift` ✏️

**Testing:**
- Foreground app → check online status updates
- Background app → send message from another device → verify notification
- Force quit app → reopen → verify all data intact

---

### PR #19: Error Handling & Loading States
**Branch**: `feature/error-handling`  
**Goal**: Add comprehensive error handling and loading indicators  
**Estimated Time**: 2 hours

#### Tasks:
- [ ] **Create Error Models**
  - **File**: `Models/AppError.swift`
  - Custom error enum with cases
  - User-friendly error messages
  - Error recovery suggestions

- [ ] **Update ViewModels with Error Handling**
  - Add @Published property: errorMessage (String?)
  - Add @Published property: isLoading (Bool)
  - Wrap network calls in do-catch
  - Set error messages on failures
  - Clear errors after displaying

- [ ] **Add Error Alert Modifier**
  - **File**: `Utilities/View+Extensions.swift`
  - Custom view modifier for error alerts
  - Reusable across all views
  - Auto-dismiss after timeout

- [ ] **Update ChatView Error States**
  - **File**: `Views/Chat/ChatView.swift`
  - Show error alert on send failures
  - Show "Failed to load messages" state
  - Retry button for failed operations

- [ ] **Update ChatListView Loading States**
  - **File**: `Views/Chat/ChatListView.swift`
  - Show loading spinner on initial load
  - Show skeleton loading for conversations
  - Pull-to-refresh indicator

- [ ] **Add Image Upload Error Handling**
  - **File**: `ViewModels/ChatViewModel.swift`
  - Catch upload failures
  - Show error message: "Failed to upload image"
  - Provide retry option

- [ ] **Add Authentication Error Handling**
  - **File**: `ViewModels/AuthViewModel.swift`
  - Parse Firebase auth errors
  - Show user-friendly messages:
    - "Invalid email or password"
    - "Email already in use"
    - "Network connection failed"

**Files Created/Modified:**
- `Models/AppError.swift` ➕
- `Utilities/View+Extensions.swift` ➕
- `ViewModels/ChatViewModel.swift` ✏️
- `ViewModels/AuthViewModel.swift` ✏️
- `Views/Chat/ChatView.swift` ✏️
- `Views/Chat/ChatListView.swift` ✏️

**Testing:**
- Turn off internet → trigger operations → verify error messages
- Try invalid login → verify error shown
- Upload oversized image → verify error handling

---

### PR #20: UI Polish & Animations
**Branch**: `feature/ui-polish`  
**Goal**: Add animations and improve overall UI/UX  
**Estimated Time**: 2-3 hours

#### Tasks:
- [ ] **Add Message Send Animation**
  - **File**: `Views/Chat/MessageBubbleView.swift`
  - Fade-in animation for new messages
  - Slide-in from bottom for sent messages
  - Scale animation on appear

- [ ] **Add Typing Indicator Animation**
  - **File**: `Views/Chat/TypingIndicatorView.swift`
  - Bouncing dots animation
  - Smooth fade in/out

- [ ] **Add Pull-to-Refresh**
  - **File**: `Views/Chat/ChatListView.swift`
  - SwiftUI refreshable modifier
  - Reload conversations on pull
  - Smooth animation

- [ ] **Add Smooth Scrolling**
  - **File**: `Views/Chat/ChatView.swift`
  - Animate scroll to bottom
  - Smooth scroll on new messages
  - ScrollViewReader for programmatic scrolling

- [ ] **Add Haptic Feedback**
  - Message sent: light haptic
  - Error occurred: error haptic
  - Button taps: selection haptic

- [ ] **Improve Image Loading**
  - Add skeleton loader for images
  - Fade-in animation when loaded
  - Placeholder while loading

- [ ] **Add Swipe Actions**
  - **File**: `Views/Chat/ChatListView.swift`
  - Swipe to delete conversation (optional)
  - Smooth swipe animation

- [ ] **Polish Color Scheme**
  - **File**: `Assets.xcassets/Colors/`
  - Define custom colors
  - Support light and dark mode
  - Consistent color usage throughout app

- [ ] **Add App Icon**
  - **File**: `Assets.xcassets/AppIcon.appiconset/`
  - Design simple app icon
  - Export all required sizes (1024x1024, etc.)

**Files Created/Modified:**
- `Views/Chat/MessageBubbleView.swift` ✏️
- `Views/Chat/TypingIndicatorView.swift` ✏️
- `Views/Chat/ChatListView.swift` ✏️
- `Views/Chat/ChatView.swift` ✏️
- `Assets.xcassets/Colors/` ➕
- `Assets.xcassets/AppIcon.appiconset/` ✏️

---

### PR #21: Testing & Bug Fixes
**Branch**: `bugfix/final-testing`  
**Goal**: Test all critical scenarios and fix bugs  
**Estimated Time**: 2-4 hours

#### Tasks:
- [ ] **Test Two-Device Real-Time Messaging**
  - Send messages between 2 physical devices
  - Verify instant delivery (under 2 seconds)
  - Test rapid-fire messages (20+ quickly)
  - Verify message ordering

- [ ] **Test Offline Scenarios**
  - Device A online, Device B offline (airplane mode)
  - Send messages from A to B
  - Device B comes online
  - Verify all messages sync correctly
  - Test bidirectional offline messaging

- [ ] **Test App Lifecycle**
  - Background app → receive message → verify notification
  - Force quit app → reopen → verify data persists
  - Kill app during message send → reopen → verify message sends

- [ ] **Test Group Chat**
  - Create group with 3+ users
  - Send messages from each user
  - Verify all participants receive messages
  - Verify message attribution (sender names)

- [ ] **Test Image Sharing**
  - Send image in one-on-one chat
  - Send image in group chat
  - Send large image (compression test)
  - Verify thumbnail and full-screen view

- [ ] **Test Poor Network Conditions**
  - Throttle connection (Network Link Conditioner)
  - Send messages with slow 3G
  - Verify eventual delivery
  - Test intermittent connection

- [ ] **Test Read Receipts**
  - Send message → verify "sent"
  - Recipient receives → verify "delivered"
  - Recipient opens chat → verify "read"
  - Test in group chat

- [ ] **Test Presence & Typing**
  - User goes online → verify status updates
  - User types → verify typing indicator
  - User stops typing → verify indicator clears

- [ ] **Bug Fixes**
  - Fix any crashes discovered
  - Fix UI layout issues
  - Fix data sync issues
  - Fix notification issues

- [ ] **Performance Optimization**
  - Check for memory leaks
  - Optimize Firestore listeners
  - Reduce unnecessary re-renders
  - Optimize image loading

**Testing Checklist:**
- [ ] Two devices real-time messaging ✓
- [ ] Offline message queue ✓
- [ ] App persistence ✓
- [ ] Group chat 3+ users ✓
- [ ] Image sharing ✓
- [ ] Read receipts ✓
- [ ] Presence indicators ✓
- [ ] Typing indicators ✓
- [ ] Push notifications ✓
- [ ] Poor network handling ✓

---

### PR #22: Documentation & Deployment Prep
**Branch**: `docs/final-docs`  
**Goal**: Complete documentation and prepare for submission  
**Estimated Time**: 1-2 hours

#### Tasks:
- [ ] **Update README.md**
  - **File**: `README.md`
  - Project description
  - Features list (MVP completed)
  - Tech stack breakdown
  - Setup instructions:
    - Prerequisites (Xcode, CocoaPods/SPM)
    - Firebase project setup steps
    - Clone and build instructions
    - Running on simulator and device
  - Firestore security rules deployment
  - Cloud Functions deployment
  - Known issues and limitations
  - Future improvements (AI features)

- [ ] **Add Architecture Documentation**
  - **File**: `ARCHITECTURE.md`
  - High-level system design
  - Firestore schema documentation
  - Data flow diagrams
  - Offline sync strategy explanation
  - SwiftData persistence explanation

- [ ] **Add Setup Guide**
  - **File**: `SETUP.md`
  - Step-by-step Firebase configuration
  - APNs certificate setup
  - Environment configuration
  - Common setup issues and solutions

- [ ] **Code Comments**
  - Add inline documentation to complex functions
  - Document all public methods
  - Add file header comments

- [ ] **Create .gitignore**
  - **File**: `.gitignore`
  - Ignore GoogleService-Info.plist
  - Ignore build artifacts
  - Ignore user-specific Xcode files

- [ ] **Verify All PRs Merged**
  - Check all feature branches merged to main
  - Resolve any merge conflicts
  - Ensure main branch is stable

- [ ] **Prepare Demo Video Script**
  - Outline key features to demonstrate
  - Write narration script
  - Plan device setup (2 phones visible)

**Files Created/Modified:**
- `README.md` ✏️
- `ARCHITECTURE.md` ➕
- `SETUP.md` ➕
- `.gitignore` ➕
- Code comments throughout project ✏️

---

### PR #23: TestFlight Deployment (Optional)
**Branch**: `release/testflight`  
**Goal**: Deploy app to TestFlight for testing  
**Estimated Time**: 1-2 hours

#### Tasks:
- [ ] **Configure App in Xcode**
  - Set bundle identifier
  - Set version and build number
  - Configure signing and capabilities
  - Add app icon

- [ ] **Create App Store Connect Record**
  - Log in to App Store Connect
  - Create new app record
  - Fill in app information
  - Upload screenshots (optional)

- [ ] **Archive and Upload**
  - Product → Archive in Xcode
  - Distribute to App Store Connect
  - Wait for processing

- [ ] **Create TestFlight Build**
  - Add internal testers
  - Add external testers (optional)
  - Provide testing instructions
  - Generate shareable TestFlight link

- [ ] **Test Installation**
  - Install via TestFlight on physical device
  - Verify all functionality works
  - Test push notifications on installed build

**Files Created/Modified:**
- Project settings in Xcode ✏️
- App Store Connect configuration

**Deliverable:**
- TestFlight link for submission

---

## Summary Checklist

### Core Features:
- [ ] User authentication (signup/login)
- [ ] One-on-one chat with real-time delivery
- [ ] Group chat (3+ participants)
- [ ] Message persistence (local storage)
- [ ] Optimistic UI (instant message display)
- [ ] Message status indicators (sent/delivered/read)
- [ ] Online/offline presence
- [ ] Typing indicators
- [ ] Image sharing
- [ ] Push notifications
- [ ] Offline support with message queuing

### Testing Completed:
- [ ] Two-device real-time messaging
- [ ] Offline scenarios
- [ ] App lifecycle (background/foreground/terminated)
- [ ] Group chat functionality
- [ ] Image upload/download
- [ ] Read receipts
- [ ] Poor network conditions
- [ ] Push notifications

### Documentation:
- [ ] README with setup instructions
- [ ] Architecture documentation
- [ ] Code comments
- [ ] Demo video recorded

### Deployment:
- [ ] Firebase backend deployed
- [ ] Cloud Functions deployed
- [ ] Firestore security rules deployed
- [ ] TestFlight build (optional)
- [ ] GitHub repository public

---

## Estimated Timeline

| PR # | Feature | Time | Cumulative |
|------|---------|------|------------|
| 1 | Project Setup | 1-2h | 2h |
| 2 | Auth Services | 2-3h | 5h |
| 3 | Auth UI | 2-3h | 8h |
| 4 | Core Models | 1-2h | 10h |
| 5 | Chat Service | 3-4h | 14h |
| 6 | Local Persistence | 2-3h | 17h |
| 7 | Chat List View | 2-3h | 20h |
| 8 | Contacts | 2h | 22h |
| 9 | Chat UI | 3-4h | 26h |
| 10 | Real-Time Messaging | 2-3h | 29h |
| 11 | Message Status | 2h | 31h |
| 12 | Presence/Typing | 2-3h | 34h |
| 13 | Group Chat | 3-4h | 38h |
| 14 | Image Sharing | 2-3h | 41h |
| 15 | Offline Support | 2-3h | 44h |
| 16 | Profile Management | 2h | 46h |
| 17 | Push Notifications | 3-4h | 50h |
| 18 | App Lifecycle | 1-2h | 52h |
| 19 | Error Handling | 2h | 54h |
| 20 | UI Polish | 2-3h | 57h |
| 21 | Testing & Bugs | 2-4h | 61h |
| 22 | Documentation | 1-2h | 63h |
| 23 | TestFlight | 1-2h | 65h |

**Total Estimated Time**: 60-65 hours of focused development

**For 24-Hour MVP**: Focus on PRs 1-15 (core messaging) = ~41 hours of work
**Strategy**: Parallelize where possible, cut optional features

---

## Git Workflow

### Branch Naming Convention:
- `feature/` - new features
- `bugfix/` - bug fixes
- `docs/` - documentation
- `release/` - deployment prep

### Commit Message Format:
```
[PR #X] Brief description

- Bullet point of changes
- Another change
- Fix for specific issue
```

### PR Template:
```
## What Changed
Brief description of changes

## Why
Reason for changes

## Testing
- [ ] Tested on simulator
- [ ] Tested on physical device
- [ ] All features working

## Screenshots (if UI changes)
```

---

## Priority Order for 24-Hour MVP

If you need to cut scope to meet 24-hour deadline, complete in this order:

**Critical (Must Have):**
1. PRs 1-5: Setup, Auth, Models, Chat Service
2. PRs 7, 9-10: Chat UI and Real-Time Messaging
3. PR 6: Local Persistence
4. PR 11: Message Status

**Important (Should Have):**
5. PR 12: Presence & Typing
6. PR 8: Contacts
7. PR 13: Group Chat
8. PR 15: Offline Support

**Nice to Have (If Time):**
9. PR 14: Image Sharing
10. PR 17: Push Notifications
11. PRs 16, 19-20: Profile, Error Handling, Polish

**Final Push:**
12. PR 21: Testing
13. PR 22: Documentation