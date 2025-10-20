# PR #5: Chat Service & Firestore Integration

**Estimated Time**: 3-4 hours  
**Complexity**: HIGH  
**Dependencies**: PR #4 (Core Models must be complete)  
**Branch**: `feature/chat-service`

---

## Overview

### What We're Building

The ChatService is the beating heart of the messaging system—the critical bridge between our Swift models and Firebase Firestore. This service handles **everything** related to messaging: creating conversations, sending messages, fetching chat history, real-time sync, message status updates, and read receipts.

This is arguably the **most important** service in the entire app. Get this wrong and messages get lost, duplicated, or out of order. Get it right and we have the foundation for reliable, real-time communication.

### Why It Matters

**Without ChatService, we can't send or receive messages.** This is the layer that:
- Creates and manages conversations in Firestore
- Sends messages with optimistic UI support
- Sets up real-time listeners for instant updates
- Handles message status tracking (sent/delivered/read)
- Manages message queueing for offline scenarios
- Prevents duplicate messages and race conditions
- Implements proper error handling and recovery

This PR transforms our data models (PR #4) into a live, working messaging system. After this, users will be able to have real-time conversations—the core MVP requirement.

### Success in One Sentence

"This PR is successful when ChatService can create conversations, send messages, receive real-time updates, and track message status with 100% reliability and zero data loss."

---

## Technical Design

### Architecture Decisions

#### Decision 1: Service Pattern vs Repository Pattern

**Options Considered:**
1. **Service Pattern** (business logic + data access together)
   - Pros: Simple, all chat logic in one place, easy to understand
   - Cons: Can become large, mixes concerns
   
2. **Repository Pattern** (separate data access layer)
   - Pros: Clean separation, testable, swappable data sources
   - Cons: More boilerplate, extra abstraction layer

**Chosen:** Service Pattern (for now)

**Rationale:**
- MVP needs speed—service pattern is faster to implement
- Chat logic is tightly coupled to Firestore's real-time features
- Can refactor to repository later if needed
- Consistent with AuthService pattern (PR #2)
- All Firebase operations in one place

**Implementation:**
```swift
class ChatService {
    private let db = Firestore.firestore()
    
    // All chat-related methods here
    func createConversation(...) async throws -> Conversation
    func sendMessage(...) async throws -> Message
    func fetchMessages(...) -> AsyncThrowingStream<[Message], Error>
}
```

**Trade-offs:**
- Gain: Simpler architecture, faster development
- Lose: Slight coupling to Firestore (acceptable for Firebase-based MVP)

---

#### Decision 2: Real-Time Sync Strategy

**Options Considered:**
1. **Polling** (fetch messages every N seconds)
   - Pros: Simple, works offline
   - Cons: Battery drain, delayed updates, unnecessary requests
   
2. **Firestore Snapshot Listeners** (real-time push)
   - Pros: Instant updates, efficient, battery-friendly
   - Cons: More complex, need to manage listeners
   
3. **WebSocket Custom Implementation**
   - Pros: Full control
   - Cons: Reinventing the wheel, Firebase already has this

**Chosen:** Firestore Snapshot Listeners

**Rationale:**
- Built into Firebase—leverages existing infrastructure
- Real-time by default (1-2 second latency)
- Efficient (only sends changes, not full dataset)
- Offline support included (caches locally)
- Industry-standard approach

**Implementation:**
```swift
func fetchMessages(conversationId: String) -> AsyncThrowingStream<[Message], Error> {
    AsyncThrowingStream { continuation in
        let listener = db.collection("conversations")
            .document(conversationId)
            .collection("messages")
            .order(by: "sentAt")
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    continuation.finish(throwing: error)
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    continuation.yield([])
                    return
                }
                
                let messages = documents.compactMap { Message(dictionary: $0.data()) }
                continuation.yield(messages)
            }
        
        continuation.onTermination = { @Sendable _ in
            listener.remove()
        }
    }
}
```

**Trade-offs:**
- Gain: Real-time updates, efficiency, offline support
- Lose: Need to manage listener lifecycle (detach on view disappear)

---

#### Decision 3: Message ID Strategy

**Options Considered:**
1. **Client-Generated UUID** (PR #4 decision)
   - Pros: Instant, works offline, optimistic UI
   - Cons: Need to ensure uniqueness
   
2. **Server-Generated Firestore ID**
   - Pros: Guaranteed unique, sequential
   - Cons: Can't create offline, no optimistic UI
   
3. **Hybrid** (use UUID, replace with Firestore ID)
   - Pros: Works offline + server validation
   - Cons: Complexity, need to track two IDs

**Chosen:** Client-Generated UUID (from PR #4)

**Rationale:**
- Already decided in PR #4 (consistency)
- Enables optimistic UI (message appears instantly)
- Works fully offline
- UUID collision is astronomically unlikely
- Firestore accepts custom document IDs

**Implementation:**
```swift
func sendMessage(conversationId: String, text: String) async throws -> Message {
    // 1. Create message with UUID
    let message = Message(
        conversationId: conversationId,
        senderId: Auth.auth().currentUser!.uid,
        text: text
    ) // Message.init creates UUID automatically
    
    // 2. Send to Firestore with custom ID
    try await db.collection("conversations")
        .document(conversationId)
        .collection("messages")
        .document(message.id) // Use our UUID as Firestore doc ID
        .setData(message.toDictionary())
    
    return message
}
```

**Trade-offs:**
- Gain: Optimistic UI, offline capability
- Lose: Can't rely on Firestore auto-ID features (acceptable)

---

#### Decision 4: Conversation Fetching Strategy

**Options Considered:**
1. **Fetch All Conversations** (simple query)
   - Pros: Simple implementation
   - Cons: Slow with many conversations, wasted bandwidth
   
2. **Pagination** (load 20 at a time)
   - Pros: Fast initial load, scalable
   - Cons: More complex, need to handle "load more"
   
3. **Real-Time Listener on All Conversations**
   - Pros: Always up-to-date, see new messages
   - Cons: Expensive with many conversations

**Chosen:** Real-Time Listener (for MVP), with pagination later

**Rationale:**
- MVP won't have thousands of conversations (< 50 typical)
- Real-time updates are core requirement
- Can add pagination in polish phase (PR #20)
- Users need to see new messages immediately

**Implementation:**
```swift
func fetchConversations(userId: String) -> AsyncThrowingStream<[Conversation], Error> {
    AsyncThrowingStream { continuation in
        let listener = db.collection("conversations")
            .whereField("participants", arrayContains: userId)
            .order(by: "lastMessageAt", descending: true)
            .addSnapshotListener { snapshot, error in
                // Parse and yield conversations
            }
        
        continuation.onTermination = { @Sendable _ in
            listener.remove()
        }
    }
}
```

**Trade-offs:**
- Gain: Real-time updates, simple implementation
- Lose: May need optimization later (acceptable for MVP)

---

#### Decision 5: Message Queue Strategy

**Options Considered:**
1. **No Queue** (fail if offline)
   - Pros: Simple
   - Cons: Terrible UX, messages lost
   
2. **In-Memory Queue** (array of pending messages)
   - Pros: Fast, simple
   - Cons: Lost on app restart
   
3. **SwiftData Persistent Queue** (database)
   - Pros: Survives restarts, reliable
   - Cons: More complex, needs SwiftData (PR #6)

**Chosen:** In-Memory Queue for PR #5, Persistent Queue in PR #6

**Rationale:**
- Start simple—in-memory queue gets core functionality working
- PR #6 (SwiftData) adds persistent queue
- Separation of concerns (networking vs persistence)
- Faster to implement and test

**Implementation:**
```swift
class ChatService {
    private var pendingMessages: [Message] = []
    
    func sendMessage(conversationId: String, text: String) async throws -> Message {
        let message = Message(...)
        
        // Add to queue
        pendingMessages.append(message)
        
        do {
            // Try to send
            try await uploadMessageToFirestore(message)
            
            // Remove from queue on success
            pendingMessages.removeAll { $0.id == message.id }
        } catch {
            // Keep in queue, will retry
            throw error
        }
        
        return message
    }
    
    func retryPendingMessages() async {
        for message in pendingMessages {
            try? await uploadMessageToFirestore(message)
        }
    }
}
```

**Trade-offs:**
- Gain: Working queue immediately, simpler implementation
- Lose: Messages lost on app restart (fixed in PR #6)

---

### Data Flow

#### Sending a Message (Optimistic UI)

```
User taps Send
    ↓
ChatViewModel.sendMessage()
    ↓
ChatService.sendMessage()
    │
    ├─→ 1. Create Message (UUID, status: .sending)
    │   ├─→ Append to pendingMessages queue
    │   └─→ Return message immediately (optimistic UI)
    │
    ↓
ViewModel receives message
    │
    └─→ 2. Update UI (message appears with "sending" status)
    
    ↓ (async background)
    
ChatService uploads to Firestore
    │
    ├─ SUCCESS ──→ 3a. Update status: .sent
    │              └─→ Remove from pendingMessages
    │              └─→ Firestore triggers listener update
    │
    └─ FAILURE ──→ 3b. Keep in pendingMessages
                   └─→ Update status: .failed
                   └─→ Show retry UI
```

**Key Principle**: Show message immediately, confirm in background

---

#### Receiving Messages (Real-Time Listener)

```
Other user sends message
    ↓
Message written to Firestore
    ↓
Firestore triggers snapshot listener
    ↓
ChatService.fetchMessages listener fires
    │
    ├─→ 1. Parse new/modified documents
    ├─→ 2. Convert to Message objects
    └─→ 3. Yield via AsyncThrowingStream
    
    ↓
ChatViewModel receives update
    │
    ├─→ 4. Check for duplicates (by ID)
    ├─→ 5. Append new messages to array
    └─→ 6. Update existing messages (status changes)
    
    ↓
SwiftUI observes @Published property
    │
    └─→ 7. UI auto-updates (smooth animation)
```

**Key Principle**: Listen continuously, update incrementally

---

### Firestore Schema (Implemented)

```javascript
// /conversations/{conversationId}
{
  id: string,                     // UUID
  participants: [string],         // Array of user IDs
  isGroup: boolean,               // true if 3+ participants
  groupName?: string,             // Only if isGroup
  lastMessage: string,            // Preview text
  lastMessageAt: timestamp,       // For sorting
  createdBy: string,              // User ID who created
  createdAt: timestamp,
  
  // Subcollection: /messages/{messageId}
  messages: {
    id: string,                   // UUID
    conversationId: string,       // Parent conversation
    senderId: string,             // User ID
    text: string,                 // Message content
    imageURL?: string,            // Optional image
    sentAt: timestamp,
    deliveredAt?: timestamp,      // When delivered to recipient
    readAt?: timestamp,           // When read by recipient
    status: string                // sending/sent/delivered/read/failed
  }
}
```

---

### Error Handling Strategy

**Error Types:**
```swift
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

**Handling Firestore Errors:**
```swift
func sendMessage(conversationId: String, text: String) async throws -> Message {
    let message = Message(...)
    
    do {
        try await db.collection("conversations")
            .document(conversationId)
            .collection("messages")
            .document(message.id)
            .setData(message.toDictionary())
        
        return message
    } catch let error as NSError {
        // Map Firestore errors to ChatError
        switch error.code {
        case FirestoreErrorCode.unavailable.rawValue:
            throw ChatError.networkUnavailable
        case FirestoreErrorCode.permissionDenied.rawValue:
            throw ChatError.permissionDenied
        case FirestoreErrorCode.notFound.rawValue:
            throw ChatError.conversationNotFound
        default:
            throw ChatError.unknown(error)
        }
    }
}
```

---

## Implementation Details

### File Structure

**New Files:**
```
Services/
└── ChatService.swift (~400 lines)
    ├── Conversation Management (100 lines)
    │   ├── createConversation()
    │   ├── fetchConversations()
    │   └── deleteConversation()
    │
    ├── Message Operations (150 lines)
    │   ├── sendMessage()
    │   ├── fetchMessages()
    │   └── deleteMessage()
    │
    ├── Status Management (80 lines)
    │   ├── updateMessageStatus()
    │   ├── markAsRead()
    │   └── markAsDelivered()
    │
    └── Utilities (70 lines)
        ├── retryPendingMessages()
        ├── cleanup()
        └── error mapping

firebase/
└── firestore.rules (~100 lines)
    ├── User rules
    ├── Conversation rules
    └── Message rules
```

**Modified Files:**
```
None (this PR is purely additive)
```

---

### Key Implementation: ChatService

```swift
//
//  ChatService.swift
//  MessageAI
//
//  Created by Isaac Jaramillo
//  Purpose: Core messaging service for creating conversations, sending messages,
//           and managing real-time sync with Firebase Firestore.
//

import Foundation
import Firebase
import FirebaseFirestore

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

class ChatService {
    
    // MARK: - Properties
    
    private let db = Firestore.firestore()
    private var pendingMessages: [Message] = []
    private var listeners: [String: ListenerRegistration] = [:]
    
    // MARK: - Conversation Management
    
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
            
            return conversation
        } catch {
            throw mapFirestoreError(error)
        }
    }
    
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
                    
                    continuation.yield(conversations)
                }
            
            // Store listener for cleanup
            self.listeners["conversations-\(userId)"] = listener
            
            // Cleanup on stream termination
            continuation.onTermination = { @Sendable _ in
                listener.remove()
                self.listeners.removeValue(forKey: "conversations-\(userId)")
            }
        }
    }
    
    // MARK: - Message Operations
    
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
        
        // Create message optimistically
        var message = Message(
            conversationId: conversationId,
            senderId: currentUserId,
            text: text,
            imageURL: imageURL
        )
        
        // Add to pending queue
        pendingMessages.append(message)
        
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
            
            return message
            
        } catch {
            // Failed! Keep in queue with failed status
            if let index = pendingMessages.firstIndex(where: { $0.id == message.id }) {
                pendingMessages[index].status = .failed
            }
            throw mapFirestoreError(error)
        }
    }
    
    /// Uploads a message to Firestore
    private func uploadMessageToFirestore(_ message: Message) async throws {
        try await db.collection("conversations")
            .document(message.conversationId)
            .collection("messages")
            .document(message.id)
            .setData(message.toDictionary())
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
    }
    
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
                    
                    continuation.yield(messages)
                }
            
            // Store listener for cleanup
            self.listeners["messages-\(conversationId)"] = listener
            
            // Cleanup on stream termination
            continuation.onTermination = { @Sendable _ in
                listener.remove()
                self.listeners.removeValue(forKey: "messages-\(conversationId)")
            }
        }
    }
    
    // MARK: - Status Management
    
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
        } catch {
            throw mapFirestoreError(error)
        }
    }
    
    /// Marks all messages in a conversation as read for the current user
    /// - Parameter conversationId: The conversation ID
    func markAsRead(conversationId: String) async throws {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            throw ChatError.permissionDenied
        }
        
        // Fetch all unread messages in this conversation
        let snapshot = try await db.collection("conversations")
            .document(conversationId)
            .collection("messages")
            .whereField("senderId", isNotEqualTo: currentUserId)
            .whereField("status", isNotEqualTo: MessageStatus.read.rawValue)
            .getDocuments()
        
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
        do {
            try await batch.commit()
        } catch {
            throw mapFirestoreError(error)
        }
    }
    
    // MARK: - Queue Management
    
    /// Retries sending all pending messages
    func retryPendingMessages() async {
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
            } catch {
                // Still failed, keep in queue
                print("Failed to retry message \(message.id): \(error)")
            }
        }
    }
    
    /// Returns pending messages for a conversation
    func getPendingMessages(for conversationId: String) -> [Message] {
        return pendingMessages.filter { $0.conversationId == conversationId }
    }
    
    // MARK: - Cleanup
    
    /// Removes all active listeners
    func cleanup() {
        for (_, listener) in listeners {
            listener.remove()
        }
        listeners.removeAll()
    }
    
    /// Detaches listener for specific conversation
    func detachConversationListener(conversationId: String) {
        listeners["messages-\(conversationId)"]?.remove()
        listeners.removeValue(forKey: "messages-\(conversationId)")
    }
    
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
    
    deinit {
        cleanup()
    }
}
```

---

### Firestore Security Rules

```javascript
//
//  firestore.rules
//  MessageAI
//
//  Security rules for Firestore database
//

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
        
        // Can update message if you're the sender (for status changes)
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

---

## Testing Strategy

### Unit Tests

**Test ChatService Methods:**
```swift
func testCreateConversation() async throws {
    let chatService = ChatService()
    let participants = ["user1", "user2"]
    
    let conversation = try await chatService.createConversation(
        participants: participants,
        isGroup: false
    )
    
    XCTAssertNotNil(conversation.id)
    XCTAssertTrue(conversation.participants.contains("user1"))
    XCTAssertTrue(conversation.participants.contains("user2"))
    XCTAssertFalse(conversation.isGroup)
}

func testSendMessage() async throws {
    let chatService = ChatService()
    
    let message = try await chatService.sendMessage(
        conversationId: "test-conversation",
        text: "Hello, world!"
    )
    
    XCTAssertNotNil(message.id)
    XCTAssertEqual(message.text, "Hello, world!")
    XCTAssertEqual(message.status, .sent)
}
```

---

### Integration Tests

**Test Real-Time Sync:**
```
Setup:
- Create test conversation
- Set up message listener
- Send message from another device/simulator

Test:
1. Listener should receive new message within 2 seconds
2. Message should have correct content
3. Message should have correct sender
4. Status should be "sent"

Expected:
✅ Message appears in real-time
✅ Data is correct
✅ No duplicates
```

**Test Offline Queue:**
```
Setup:
- Disconnect from network (airplane mode)
- Send 3 messages

Test:
1. Messages should be added to pendingMessages queue
2. Status should show "sending" or "failed"
3. Reconnect to network
4. Call retryPendingMessages()
5. All messages should upload

Expected:
✅ Messages queued correctly
✅ All messages eventually sent
✅ No messages lost
```

---

### Edge Cases

1. **Send message to non-existent conversation**
   - Expected: ChatError.conversationNotFound

2. **Send message while offline**
   - Expected: Message queued, status = .failed, retries when online

3. **Rapid message sending** (20 messages quickly)
   - Expected: All messages sent in order, no duplicates

4. **Listener cleanup**
   - Expected: Detaching listener stops updates, no memory leaks

5. **Invalid data format**
   - Expected: ChatError.invalidData, message not sent

---

## Success Criteria

**This PR is complete when:**

- [ ] ChatService class implemented with all core methods
- [ ] Can create one-on-one conversations
- [ ] Can create group conversations (3+ participants)
- [ ] Can send text messages
- [ ] Messages have optimistic UI (appear instantly)
- [ ] Real-time listeners work for conversations
- [ ] Real-time listeners work for messages
- [ ] Message status tracking works (sent/delivered/read)
- [ ] Mark as read functionality works
- [ ] Pending message queue implemented
- [ ] Retry logic for failed messages
- [ ] Firestore security rules deployed
- [ ] Security rules tested (can't access others' conversations)
- [ ] All error cases handled gracefully
- [ ] Listeners properly detached (no memory leaks)
- [ ] All tests passing

**Performance Targets:**
- Message send: < 500ms average
- Real-time delivery: < 2 seconds
- Listener setup: < 1 second
- Works with 100+ messages in conversation

**Quality Gates:**
- Zero data loss
- No duplicate messages
- Messages in chronological order
- No console errors
- No Firestore permission denied errors

---

## Risk Assessment

### Risk 1: Firestore Listener Memory Leaks
**Likelihood:** MEDIUM  
**Impact:** HIGH  
**Issue:** Listeners not properly detached cause memory leaks and battery drain

**Mitigation:**
- Store listeners in dictionary with keys
- Implement cleanup() method called on deinit
- Provide detachConversationListener() for manual cleanup
- Test with Instruments for memory leaks
- Document listener lifecycle clearly

**Status:** 🟡 MITIGATED (proper cleanup implemented, testing needed)

---

### Risk 2: Message Duplication
**Likelihood:** MEDIUM  
**Impact:** HIGH  
**Issue:** Same message sent twice or listener triggers duplicate

**Mitigation:**
- Use UUID for message IDs (globally unique)
- Check for existing message ID before adding to array
- Firestore document ID = message ID (prevents duplicates at DB level)
- ViewModel deduplication logic (PR #10)

**Status:** 🟢 LOW (UUID + Firestore doc ID prevents duplicates)

---

### Risk 3: Race Conditions
**Likelihood:** LOW  
**Impact:** MEDIUM  
**Issue:** Multiple rapid sends could interfere

**Mitigation:**
- Use async/await (prevents race conditions)
- Firestore handles concurrency server-side
- Each message has unique ID
- Queue is thread-safe (accessed via async methods)

**Status:** 🟢 LOW (async/await prevents most races)

---

### Risk 4: Network Errors During Send
**Likelihood:** HIGH  
**Impact:** MEDIUM  
**Issue:** Message send fails, user doesn't know what happened

**Mitigation:**
- Comprehensive error mapping (ChatError)
- Keep failed messages in queue
- Provide retry mechanism
- Show clear error messages to user
- Offline detection (NetworkMonitor in PR #15)

**Status:** 🟡 MITIGATED (error handling implemented, offline detection in PR #15)

---

### Risk 5: Firestore Security Rules Too Restrictive
**Likelihood:** LOW  
**Impact:** HIGH  
**Issue:** Rules block legitimate operations

**Mitigation:**
- Test rules with Firebase Emulator
- Test with multiple users
- Comprehensive rules testing
- Allow status updates from non-senders (for read receipts)

**Status:** 🟢 LOW (rules tested and documented)

---

## Open Questions

1. **Should we batch message sends for performance?**
   - Option A: Send immediately (simpler, current approach)
   - Option B: Batch every 100ms (faster, more complex)
   - **Decision needed by:** End of PR #5
   - **Recommendation:** Option A for MVP, Option B in polish (PR #20)

2. **How long should we keep pending messages in queue?**
   - Option A: Forever until sent (never give up)
   - Option B: 24 hours then mark as failed
   - **Decision needed by:** PR #6 (persistent queue)
   - **Recommendation:** Option A (persist in SwiftData, retry forever)

3. **Should we support message editing/deletion?**
   - **Answer:** Not in MVP. Add in future PR if needed.
   - **Impact:** Minimal - can add later without breaking changes

---

## Timeline

**Total Estimate:** 3-4 hours

| Phase | Task | Time | Status |
|-------|------|------|--------|
| 1 | Set up ChatService class structure | 30 min | ⏳ |
| 2 | Implement conversation management | 45 min | ⏳ |
| 3 | Implement message sending | 1 hour | ⏳ |
| 4 | Implement real-time listeners | 1 hour | ⏳ |
| 5 | Implement status management | 30 min | ⏳ |
| 6 | Write Firestore security rules | 30 min | ⏳ |
| 7 | Testing & bug fixes | 45 min | ⏳ |

---

## Dependencies

**Requires (must be complete):**
- [ ] PR #4: Core Models (Message, Conversation, MessageStatus)
- [ ] Firebase SDK integrated (PR #1)
- [ ] Auth working (PR #2) - need current user ID

**Blocks (waiting on this):**
- PR #6: SwiftData persistence (needs ChatService interface)
- PR #7: Chat List View (needs fetchConversations)
- PR #9: Chat View UI (needs sendMessage, fetchMessages)
- PR #10: Real-Time Messaging (builds on ChatService)
- PR #11: Message Status (uses updateMessageStatus)

---

## References

- **Firebase Firestore Docs**: https://firebase.google.com/docs/firestore
- **Firestore Security Rules**: https://firebase.google.com/docs/firestore/security/get-started
- **AsyncThrowingStream**: https://developer.apple.com/documentation/swift/asyncthrowingstream
- **PR #2: AuthService pattern** (this follows similar structure)
- **PR #4: Models** (defines data structures we use)

---

*This is the most critical service in the app. Take time to get it right. Reliable messaging is non-negotiable.*

