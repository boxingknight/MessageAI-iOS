# PR #5: Implementation Checklist - Chat Service & Firestore Integration

**Use this as your daily todo list.** Check off items as you complete them.

---

## Pre-Implementation Setup (15 minutes)

- [ ] Read PR05_CHAT_SERVICE.md main specification (~45 min)
- [ ] Verify PR #4 is complete (Core Models exist)
- [ ] Verify Firebase is configured (PR #1)
- [ ] Verify Auth is working (PR #2, #3)
- [ ] Create git branch
  ```bash
  git checkout main
  git pull
  git checkout -b feature/chat-service
  ```
- [ ] Open Xcode project
- [ ] Verify project builds with 0 errors

---

## Phase 1: ChatService Foundation (30-45 minutes)

### 1.1: Create ChatService File (10 minutes)

- [ ] Create new file: `Services/ChatService.swift`
- [ ] Add file header and imports
  ```swift
  //
  //  ChatService.swift
  //  MessageAI
  //
  //  Created by Isaac Jaramillo
  //  Purpose: Core messaging service for Firestore integration
  //
  
  import Foundation
  import Firebase
  import FirebaseFirestore
  ```

- [ ] Define ChatError enum
  ```swift
  /// Errors specific to chat operations
  enum ChatError: LocalizedError {
      case conversationNotFound
      case messageNotSent
      case invalidData
      case networkUnavailable
      case permissionDenied
      case unknown(Error)
      
      var errorDescription: String? {
          switch self {
          case .conversationNotFound:
              return "Conversation not found. It may have been deleted."
          case .messageNotSent:
              return "Failed to send message. Check your connection and try again."
          case .invalidData:
              return "Invalid message data. Please try again."
          case .networkUnavailable:
              return "No internet connection. Message will send when online."
          case .permissionDenied:
              return "You don't have permission to access this conversation."
          case .unknown(let error):
              return "Something went wrong: \(error.localizedDescription)"
          }
      }
  }
  ```

- [ ] Create ChatService class structure
  ```swift
  class ChatService {
      
      // MARK: - Properties
      
      private let db = Firestore.firestore()
      private var pendingMessages: [Message] = []
      private var listeners: [String: ListenerRegistration] = [:]
      
      // MARK: - Initialization
      
      init() {
          // Configure Firestore settings if needed
      }
      
      // Methods will go here...
      
      deinit {
          cleanup()
      }
  }
  ```

- [ ] Build project to verify no errors

**Checkpoint:** ChatService file created with basic structure ✓

**Commit:** `git commit -m "feat(chat): create ChatService foundation with error types"`

---

### 1.2: Add Error Mapping Helper (10 minutes)

- [ ] Add error mapping method at bottom of class
  ```swift
  // MARK: - Error Mapping
  
  /// Maps Firestore errors to ChatError
  private func mapFirestoreError(_ error: Error) -> ChatError {
      let nsError = error as NSError
      
      switch nsError.code {
      case FirestoreErrorCode.unavailable.rawValue:
          return .networkUnavailable
      case FirestoreErrorCode.permissionDenied.rawValue:
          return .permissionDenied
      case FirestoreErrorCode.notFound.rawValue:
          return .conversationNotFound
      case FirestoreErrorCode.invalidArgument.rawValue:
          return .invalidData
      default:
          return .unknown(error)
      }
  }
  ```

- [ ] Test error mapping compiles

**Checkpoint:** Error handling foundation complete ✓

---

### 1.3: Add Cleanup Methods (15 minutes)

- [ ] Add cleanup methods
  ```swift
  // MARK: - Cleanup
  
  /// Removes all active listeners
  func cleanup() {
      for (_, listener) in listeners {
          listener.remove()
      }
      listeners.removeAll()
      print("[ChatService] Cleaned up \(listeners.count) listeners")
  }
  
  /// Detaches listener for specific conversation
  func detachConversationListener(conversationId: String) {
      listeners["messages-\(conversationId)"]?.remove()
      listeners.removeValue(forKey: "messages-\(conversationId)")
  }
  
  /// Detaches listener for conversations list
  func detachConversationsListener(userId: String) {
      listeners["conversations-\(userId)"]?.remove()
      listeners.removeValue(forKey: "conversations-\(userId)")
  }
  ```

- [ ] Build and verify no errors

**Checkpoint:** Phase 1 complete - Foundation ready ✓

**Commit:** `git commit -m "feat(chat): add error mapping and listener cleanup"`

---

## Phase 2: Conversation Management (45-60 minutes)

### 2.1: Implement createConversation (20 minutes)

- [ ] Add conversation management section marker
  ```swift
  // MARK: - Conversation Management
  ```

- [ ] Implement createConversation method
  ```swift
  /// Creates a new conversation
  /// - Parameters:
  ///   - participants: Array of user IDs (including current user)
  ///   - isGroup: Whether this is a group chat (3+ participants)
  ///   - groupName: Optional name for group chats
  /// - Returns: Created Conversation object
  func createConversation(
      participants: [String],
      isGroup: Bool,
      groupName: String? = nil
  ) async throws -> Conversation {
      
      guard let currentUserId = Auth.auth().currentUser?.uid else {
          throw ChatError.permissionDenied
      }
      
      // Ensure current user is in participants
      var allParticipants = Set(participants)
      allParticipants.insert(currentUserId)
      
      // Validate: minimum 2 participants
      guard allParticipants.count >= 2 else {
          throw ChatError.invalidData
      }
      
      // Create conversation model
      let conversation = Conversation(
          participants: Array(allParticipants),
          isGroup: isGroup,
          groupName: groupName,
          createdBy: currentUserId
      )
      
      // Upload to Firestore
      do {
          try await db.collection("conversations")
              .document(conversation.id)
              .setData(conversation.toDictionary())
          
          print("[ChatService] Created conversation: \(conversation.id)")
          return conversation
      } catch {
          throw mapFirestoreError(error)
      }
  }
  ```

- [ ] Build and test - should compile without errors

**Test Case:**
- [ ] Can create conversation with 2 participants
- [ ] Current user automatically added
- [ ] Conversation ID is valid UUID
- [ ] Firestore document exists after creation

**Checkpoint:** Can create conversations ✓

---

### 2.2: Implement fetchConversations (25 minutes)

- [ ] Add fetchConversations method with real-time listener
  ```swift
  /// Fetches all conversations for a user with real-time updates
  /// - Parameter userId: The user whose conversations to fetch
  /// - Returns: AsyncThrowingStream of conversation arrays
  func fetchConversations(userId: String) -> AsyncThrowingStream<[Conversation], Error> {
      AsyncThrowingStream { continuation in
          
          let listener = db.collection("conversations")
              .whereField("participants", arrayContains: userId)
              .order(by: "lastMessageAt", descending: true)
              .addSnapshotListener { snapshot, error in
                  
                  if let error = error {
                      continuation.finish(throwing: self.mapFirestoreError(error))
                      return
                  }
                  
                  guard let documents = snapshot?.documents else {
                      continuation.yield([])
                      return
                  }
                  
                  let conversations = documents.compactMap { doc -> Conversation? in
                      Conversation(dictionary: doc.data())
                  }
                  
                  print("[ChatService] Fetched \(conversations.count) conversations for user: \(userId)")
                  continuation.yield(conversations)
              }
          
          // Store listener for cleanup
          self.listeners["conversations-\(userId)"] = listener
          
          // Cleanup on stream termination
          continuation.onTermination = { @Sendable _ in
              listener.remove()
              self.listeners.removeValue(forKey: "conversations-\(userId)")
              print("[ChatService] Detached conversations listener for user: \(userId)")
          }
      }
  }
  ```

- [ ] Build and verify no errors

**Test Case:**
- [ ] Listener yields empty array if no conversations
- [ ] Listener yields conversations array if data exists
- [ ] Listener updates when new conversation added
- [ ] Listener properly detaches on termination

**Checkpoint:** Can fetch conversations with real-time updates ✓

**Commit:** `git commit -m "feat(chat): implement conversation creation and fetching"`

---

## Phase 3: Message Operations (60-75 minutes)

### 3.1: Implement Private Upload Helper (15 minutes)

- [ ] Add message operations section marker
  ```swift
  // MARK: - Message Operations
  ```

- [ ] Add private upload helper
  ```swift
  /// Uploads a message to Firestore
  private func uploadMessageToFirestore(_ message: Message) async throws {
      try await db.collection("conversations")
          .document(message.conversationId)
          .collection("messages")
          .document(message.id)
          .setData(message.toDictionary())
      
      print("[ChatService] Uploaded message: \(message.id)")
  }
  
  /// Updates conversation's last message preview
  private func updateConversationLastMessage(
      conversationId: String,
      lastMessage: String
  ) async throws {
      try await db.collection("conversations")
          .document(conversationId)
          .updateData([
              "lastMessage": lastMessage,
              "lastMessageAt": FieldValue.serverTimestamp()
          ])
      
      print("[ChatService] Updated last message for conversation: \(conversationId)")
  }
  ```

- [ ] Build and verify

**Checkpoint:** Upload helpers created ✓

---

### 3.2: Implement sendMessage (30 minutes)

- [ ] Implement sendMessage method
  ```swift
  /// Sends a message to a conversation
  /// - Parameters:
  ///   - conversationId: ID of the conversation
  ///   - text: Message text content
  ///   - imageURL: Optional image URL
  /// - Returns: Created Message object (optimistic)
  func sendMessage(
      conversationId: String,
      text: String,
      imageURL: String? = nil
  ) async throws -> Message {
      
      guard let currentUserId = Auth.auth().currentUser?.uid else {
          throw ChatError.permissionDenied
      }
      
      // Validate input
      guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
          throw ChatError.invalidData
      }
      
      // Create message optimistically
      var message = Message(
          conversationId: conversationId,
          senderId: currentUserId,
          text: text,
          imageURL: imageURL
      )
      
      // Add to pending queue
      pendingMessages.append(message)
      print("[ChatService] Queued message: \(message.id)")
      
      // Try to upload to Firestore
      do {
          try await uploadMessageToFirestore(message)
          
          // Success! Update status and remove from queue
          message.status = .sent
          pendingMessages.removeAll { $0.id == message.id }
          
          // Update conversation's lastMessage
          try await updateConversationLastMessage(
              conversationId: conversationId,
              lastMessage: text
          )
          
          print("[ChatService] Sent message successfully: \(message.id)")
          return message
          
      } catch {
          // Failed! Keep in queue with failed status
          if let index = pendingMessages.firstIndex(where: { $0.id == message.id }) {
              pendingMessages[index].status = .failed
          }
          print("[ChatService] Failed to send message: \(message.id)")
          throw mapFirestoreError(error)
      }
  }
  ```

- [ ] Build and verify no errors

**Test Cases:**
- [ ] Can send message with text
- [ ] Empty text throws error
- [ ] Message gets UUID
- [ ] Message added to pendingMessages
- [ ] Successful send removes from queue
- [ ] Failed send keeps in queue with .failed status

**Checkpoint:** Can send messages ✓

---

### 3.3: Implement fetchMessages (30 minutes)

- [ ] Implement fetchMessages with real-time listener
  ```swift
  /// Fetches messages for a conversation with real-time updates
  /// - Parameter conversationId: The conversation ID
  /// - Returns: AsyncThrowingStream of message arrays
  func fetchMessages(conversationId: String) -> AsyncThrowingStream<[Message], Error> {
      AsyncThrowingStream { continuation in
          
          let listener = db.collection("conversations")
              .document(conversationId)
              .collection("messages")
              .order(by: "sentAt", descending: false)
              .addSnapshotListener { snapshot, error in
                  
                  if let error = error {
                      continuation.finish(throwing: self.mapFirestoreError(error))
                      return
                  }
                  
                  guard let documents = snapshot?.documents else {
                      continuation.yield([])
                      return
                  }
                  
                  let messages = documents.compactMap { doc -> Message? in
                      Message(dictionary: doc.data())
                  }
                  
                  print("[ChatService] Fetched \(messages.count) messages for conversation: \(conversationId)")
                  continuation.yield(messages)
              }
          
          // Store listener for cleanup
          self.listeners["messages-\(conversationId)"] = listener
          
          // Cleanup on stream termination
          continuation.onTermination = { @Sendable _ in
              listener.remove()
              self.listeners.removeValue(forKey: "messages-\(conversationId)")
              print("[ChatService] Detached messages listener for conversation: \(conversationId)")
          }
      }
  }
  ```

- [ ] Build and verify

**Test Cases:**
- [ ] Yields empty array for new conversation
- [ ] Yields messages in chronological order (oldest first)
- [ ] Updates when new message added
- [ ] Listener detaches properly

**Checkpoint:** Can fetch messages with real-time updates ✓

**Commit:** `git commit -m "feat(chat): implement message sending and fetching"`

---

## Phase 4: Status Management (30-45 minutes)

### 4.1: Implement updateMessageStatus (20 minutes)

- [ ] Add status management section marker
  ```swift
  // MARK: - Status Management
  ```

- [ ] Implement updateMessageStatus method
  ```swift
  /// Updates message status (sent/delivered/read)
  /// - Parameters:
  ///   - messageId: The message ID
  ///   - conversationId: The conversation ID
  ///   - status: New status to set
  func updateMessageStatus(
      messageId: String,
      conversationId: String,
      status: MessageStatus
  ) async throws {
      
      var updateData: [String: Any] = ["status": status.rawValue]
      
      // Add timestamp for status
      switch status {
      case .delivered:
          updateData["deliveredAt"] = FieldValue.serverTimestamp()
      case .read:
          updateData["readAt"] = FieldValue.serverTimestamp()
      default:
          break
      }
      
      do {
          try await db.collection("conversations")
              .document(conversationId)
              .collection("messages")
              .document(messageId)
              .updateData(updateData)
          
          print("[ChatService] Updated message \(messageId) status to: \(status)")
      } catch {
          throw mapFirestoreError(error)
      }
  }
  ```

- [ ] Build and verify

**Test Cases:**
- [ ] Can update status to .delivered
- [ ] Can update status to .read
- [ ] Timestamps added correctly
- [ ] Real-time listener receives update

**Checkpoint:** Can update message status ✓

---

### 4.2: Implement markAsRead (25 minutes)

- [ ] Implement batch read marking
  ```swift
  /// Marks all messages in a conversation as read for the current user
  /// - Parameter conversationId: The conversation ID
  func markAsRead(conversationId: String) async throws {
      guard let currentUserId = Auth.auth().currentUser?.uid else {
          throw ChatError.permissionDenied
      }
      
      do {
          // Fetch all unread messages in this conversation (not sent by current user)
          let snapshot = try await db.collection("conversations")
              .document(conversationId)
              .collection("messages")
              .whereField("senderId", isNotEqualTo: currentUserId)
              .whereField("status", in: [MessageStatus.sent.rawValue, MessageStatus.delivered.rawValue])
              .getDocuments()
          
          guard !snapshot.documents.isEmpty else {
              print("[ChatService] No messages to mark as read")
              return
          }
          
          // Batch update to mark as read
          let batch = db.batch()
          
          for document in snapshot.documents {
              let ref = db.collection("conversations")
                  .document(conversationId)
                  .collection("messages")
                  .document(document.documentID)
              
              batch.updateData([
                  "status": MessageStatus.read.rawValue,
                  "readAt": FieldValue.serverTimestamp()
              ], forDocument: ref)
          }
          
          // Commit batch
          try await batch.commit()
          print("[ChatService] Marked \(snapshot.documents.count) messages as read")
          
      } catch {
          throw mapFirestoreError(error)
      }
  }
  ```

- [ ] Build and verify

**Test Cases:**
- [ ] Marks all unread messages as read
- [ ] Only marks messages from others (not own messages)
- [ ] Batch operation succeeds
- [ ] Handles empty conversation gracefully

**Checkpoint:** Can mark messages as read ✓

**Commit:** `git commit -m "feat(chat): implement message status tracking"`

---

## Phase 5: Queue Management (20-30 minutes)

### 5.1: Implement Retry Logic (15 minutes)

- [ ] Add queue management section marker
  ```swift
  // MARK: - Queue Management
  ```

- [ ] Implement retry method
  ```swift
  /// Retries sending all pending messages
  func retryPendingMessages() async {
      guard !pendingMessages.isEmpty else {
          print("[ChatService] No pending messages to retry")
          return
      }
      
      print("[ChatService] Retrying \(pendingMessages.count) pending messages...")
      
      for message in pendingMessages {
          do {
              try await uploadMessageToFirestore(message)
              
              // Success! Remove from queue
              pendingMessages.removeAll { $0.id == message.id }
              
              // Update conversation
              try await updateConversationLastMessage(
                  conversationId: message.conversationId,
                  lastMessage: message.text
              )
              
              print("[ChatService] Successfully retried message: \(message.id)")
          } catch {
              print("[ChatService] Failed to retry message \(message.id): \(error)")
          }
      }
  }
  
  /// Returns pending messages for a conversation
  func getPendingMessages(for conversationId: String) -> [Message] {
      return pendingMessages.filter { $0.conversationId == conversationId }
  }
  
  /// Returns all pending messages
  func getAllPendingMessages() -> [Message] {
      return pendingMessages
  }
  ```

- [ ] Build and verify

**Test Cases:**
- [ ] Retry succeeds for pending messages
- [ ] Can get pending messages for specific conversation
- [ ] Can get all pending messages

**Checkpoint:** Queue management complete ✓

**Commit:** `git commit -m "feat(chat): implement message retry and queue management"`

---

## Phase 6: Firestore Security Rules (30 minutes)

### 6.1: Create Firestore Rules File (20 minutes)

- [ ] Create directory: `firebase/` at project root
- [ ] Create file: `firebase/firestore.rules`
- [ ] Add security rules
  ```javascript
  rules_version = '2';
  service cloud.firestore {
    match /databases/{database}/documents {
      
      // Helper function: Check if user is authenticated
      function isAuthenticated() {
        return request.auth != null;
      }
      
      // Helper function: Check if user is participant in conversation
      function isParticipant(conversationId) {
        return isAuthenticated() && 
               request.auth.uid in get(/databases/$(database)/documents/conversations/$(conversationId)).data.participants;
      }
      
      // Users collection
      match /users/{userId} {
        // Anyone authenticated can read user profiles
        allow read: if isAuthenticated();
        
        // Users can only write their own profile
        allow write: if isAuthenticated() && request.auth.uid == userId;
      }
      
      // Conversations collection
      match /conversations/{conversationId} {
        // Can read if you're a participant
        allow read: if isAuthenticated() && 
                       request.auth.uid in resource.data.participants;
        
        // Can create if you include yourself as participant
        allow create: if isAuthenticated() && 
                         request.auth.uid in request.resource.data.participants &&
                         request.resource.data.participants is list &&
                         request.resource.data.participants.size() >= 2;
        
        // Can update if you're a participant (for lastMessage, etc.)
        allow update: if isAuthenticated() && 
                         request.auth.uid in resource.data.participants;
        
        // Can delete if you created it
        allow delete: if isAuthenticated() && 
                         request.auth.uid == resource.data.createdBy;
        
        // Messages subcollection
        match /messages/{messageId} {
          // Can read messages if you're in the conversation
          allow read: if isParticipant(conversationId);
          
          // Can create message if:
          // - You're in the conversation
          // - You're the sender
          // - Message has required fields
          allow create: if isParticipant(conversationId) &&
                           request.auth.uid == request.resource.data.senderId &&
                           request.resource.data.text is string &&
                           request.resource.data.sentAt is timestamp;
          
          // Can update message if you're the sender OR updating status fields
          allow update: if isParticipant(conversationId) &&
                           (request.auth.uid == resource.data.senderId || 
                            request.resource.data.keys().hasOnly(['status', 'deliveredAt', 'readAt']));
          
          // Can delete if you're the sender
          allow delete: if isParticipant(conversationId) &&
                           request.auth.uid == resource.data.senderId;
        }
      }
      
      // Deny everything else
      match /{document=**} {
        allow read, write: if false;
      }
    }
  }
  ```

- [ ] Save file

**Checkpoint:** Firestore rules defined ✓

---

### 6.2: Deploy Firestore Rules (10 minutes)

- [ ] Open terminal
- [ ] Navigate to project root
- [ ] Install Firebase CLI if needed
  ```bash
  npm install -g firebase-tools
  ```
- [ ] Login to Firebase
  ```bash
  firebase login
  ```
- [ ] Initialize Firebase (if not done)
  ```bash
  firebase init firestore
  # Select existing project
  # Use firebase/firestore.rules as rules file
  ```
- [ ] Deploy rules
  ```bash
  firebase deploy --only firestore:rules
  ```
- [ ] Verify deployment success in console output

**Checkpoint:** Firestore rules deployed ✓

**Commit:** `git commit -m "feat(firebase): add and deploy Firestore security rules"`

---

## Testing Phase (30-45 minutes)

### Test 1: Create Conversation

- [ ] Run app on simulator
- [ ] Log in with test user
- [ ] Trigger conversation creation (will need UI from later PRs, or test programmatically)
- [ ] Check Firestore console for conversation document
- [ ] Verify participants array is correct
- [ ] Verify timestamps exist

**Expected:**
- ✅ Conversation created in Firestore
- ✅ All fields present and valid
- ✅ Current user included in participants

---

### Test 2: Send Message

- [ ] Create or use existing conversation
- [ ] Send test message
- [ ] Check Firestore console for message document
- [ ] Verify message appears in messages subcollection
- [ ] Verify conversation lastMessage updated

**Expected:**
- ✅ Message created with UUID
- ✅ Status is "sent"
- ✅ Timestamps are correct
- ✅ Conversation preview updated

---

### Test 3: Real-Time Listener

- [ ] Set up fetchMessages listener
- [ ] Send message from another device/simulator
- [ ] Verify listener receives update within 2 seconds
- [ ] Check console logs for listener triggers

**Expected:**
- ✅ Listener fires on new message
- ✅ Message data is correct
- ✅ Latency < 2 seconds

---

### Test 4: Offline Queue

- [ ] Enable airplane mode in simulator
- [ ] Try to send message
- [ ] Verify message added to pending queue
- [ ] Disable airplane mode
- [ ] Call retryPendingMessages()
- [ ] Verify message uploads

**Expected:**
- ✅ Message queued while offline
- ✅ Message sent when online
- ✅ No errors or crashes

---

### Test 5: Status Updates

- [ ] Send message
- [ ] Update status to .delivered
- [ ] Verify Firestore document updated
- [ ] Update status to .read
- [ ] Verify readAt timestamp added

**Expected:**
- ✅ Status updates work
- ✅ Timestamps added correctly
- ✅ Real-time listener receives updates

---

### Test 6: Batch Mark as Read

- [ ] Create conversation with multiple unread messages
- [ ] Call markAsRead()
- [ ] Verify all messages marked as read
- [ ] Check Firestore console

**Expected:**
- ✅ All messages updated
- ✅ Batch operation succeeds
- ✅ Only other user's messages marked

---

### Test 7: Security Rules

- [ ] Try to access conversation you're not part of (should fail)
- [ ] Try to send message to conversation you're not in (should fail)
- [ ] Try to read another user's messages (should fail)
- [ ] Verify legitimate operations succeed

**Expected:**
- ✅ Unauthorized operations rejected
- ✅ Error messages clear
- ✅ Authorized operations succeed

---

### Test 8: Listener Cleanup

- [ ] Create listener
- [ ] Verify listener fires
- [ ] Call detachConversationListener()
- [ ] Verify listener no longer fires
- [ ] Check console for cleanup messages

**Expected:**
- ✅ Listener detaches properly
- ✅ No memory leaks (check Instruments)
- ✅ Console shows cleanup messages

---

## Bug Fixing (Variable Time)

### If Bugs Found:

- [ ] Document bug symptoms
- [ ] Identify root cause
- [ ] Implement fix
- [ ] Re-test affected functionality
- [ ] Update code comments if needed

**Common Issues:**
1. **Listener not triggering**: Check Firestore query syntax
2. **Permission denied**: Verify security rules
3. **Message not sending**: Check network, validate data
4. **Duplicate messages**: Verify UUID uniqueness, check deduplication logic

---

## Documentation Phase (20 minutes)

- [ ] Add code comments to complex methods
- [ ] Document any deviations from plan
- [ ] Update PR_PARTY/README.md with PR #5 status
- [ ] Update memory-bank/activeContext.md with current state
- [ ] Update memory-bank/progress.md with completion

---

## Completion Checklist

### Code Complete
- [ ] All methods implemented
- [ ] All error cases handled
- [ ] Logging added for debugging
- [ ] No compiler warnings
- [ ] Code formatted consistently

### Testing Complete
- [ ] All 8 test scenarios passed
- [ ] Security rules tested
- [ ] Listener cleanup verified
- [ ] No console errors
- [ ] Firestore operations confirmed in console

### Documentation Complete
- [ ] Code comments added
- [ ] PR_PARTY README updated
- [ ] Memory bank updated
- [ ] Any bugs documented

---

## Final Commits

```bash
# Commit all changes
git add .
git commit -m "feat(chat): complete ChatService with all features

- Conversation creation and fetching
- Message sending with optimistic UI
- Real-time listeners for conversations and messages
- Message status tracking (sent/delivered/read)
- Batch mark as read functionality
- Message retry queue
- Firestore security rules deployed
- All tests passing

Estimated: 3-4 hours
Actual: [X hours]
Files: ChatService.swift (~400 lines), firestore.rules (~100 lines)"

# Push to GitHub
git push -u origin feature/chat-service
```

---

## Merge to Main

- [ ] Create pull request on GitHub
- [ ] Review changes
- [ ] Merge to main
- [ ] Delete feature branch
- [ ] Pull main locally

```bash
git checkout main
git pull
git branch -d feature/chat-service
```

---

## Post-Completion

- [ ] Write PR05_COMPLETE_SUMMARY.md (if significant bugs/learnings)
- [ ] Update memory bank with final state
- [ ] Celebrate! 🎉 **Core messaging service is complete!**
- [ ] Plan next PR (PR #6: Local Persistence)

---

**Status:** Ready to implement! 🚀  
**Remember:** This is the heart of the messaging system. Take time to test thoroughly!

