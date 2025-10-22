//
//  ChatService.swift
//  messAI
//
//  Created by Isaac Jaramillo on October 20, 2025.
//  Purpose: Core messaging service for creating conversations, sending messages,
//           and managing real-time sync with Firebase Firestore.
//

import Foundation
import FirebaseAuth
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
    
    // MARK: - Initialization
    
    init() {
        // Configure Firestore settings if needed
        print("[ChatService] Initialized")
    }
    
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
        
        // Validate: minimum 2 participants
        guard allParticipants.count >= 2 else {
            throw ChatError.invalidData
        }
        
        // Create conversation model
        let conversation: Conversation
        if isGroup {
            // Group conversation
            conversation = Conversation(
                participants: Array(allParticipants),
                groupName: groupName ?? "Unnamed Group",
                createdBy: currentUserId
            )
        } else {
            // 1-on-1 conversation
            let participantsArray = Array(allParticipants)
            let otherUser = participantsArray.first(where: { $0 != currentUserId }) ?? participantsArray[0]
            conversation = Conversation(
                participant1: currentUserId,
                participant2: otherUser,
                createdBy: currentUserId
            )
        }
        
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
    
    /// Fetches all conversations for a user with real-time updates
    /// - Parameter userId: The user whose conversations to fetch
    /// - Returns: AsyncThrowingStream of conversation arrays
    func fetchConversations(userId: String) -> AsyncThrowingStream<[Conversation], Error> {
        AsyncThrowingStream { [weak self] continuation in
            guard let self = self else { return }
            
            let listener = db.collection("conversations")
                .whereField("participants", arrayContains: userId)
                .order(by: "lastMessageAt", descending: true)
                .addSnapshotListener { [weak self] snapshot, error in
                    
                    if let error = error {
                        continuation.finish(throwing: self?.mapFirestoreError(error) ?? ChatError.unknown(error))
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
            continuation.onTermination = { @Sendable [weak self] _ in
                listener.remove()
                Task { @MainActor in
                    self?.listeners.removeValue(forKey: "conversations-\(userId)")
                }
                print("[ChatService] Detached conversations listener for user: \(userId)")
            }
        }
    }
    
    // MARK: - Message Operations
    
    /// Sends a message to a conversation
    /// - Parameters:
    ///   - conversationId: ID of the conversation
    ///   - text: Message text content
    ///   - imageURL: Optional image URL
    ///   - messageId: Optional message ID (for optimistic UI - PR #10 bug fix)
    /// - Returns: Created Message object with server confirmation
    func sendMessage(
        conversationId: String,
        text: String,
        imageURL: String? = nil,
        messageId: String? = nil
    ) async throws -> Message {
        
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            throw ChatError.permissionDenied
        }
        
        // Validate input
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ChatError.invalidData
        }
        
        // Use provided ID or generate new one
        let id = messageId ?? UUID().uuidString
        
        // Create message with specific ID
        let message = Message(
            id: id,
            conversationId: conversationId,
            senderId: currentUserId,
            text: text,
            imageURL: imageURL,
            sentAt: Date(),
            status: .sending
        )
        
        // Add to pending queue
        pendingMessages.append(message)
        print("[ChatService] Queued message: \(message.id)")
        
        // Try to upload to Firestore
        do {
            try await uploadMessageToFirestore(message)
            
            // Success! Update status to .sent in Firestore
            try await db.collection("conversations")
                .document(conversationId)
                .collection("messages")
                .document(message.id)
                .updateData([
                    "status": MessageStatus.sent.rawValue
                ])
            
            // Update local status and remove from queue
            var updatedMessage = message
            updatedMessage.status = MessageStatus.sent
            pendingMessages.removeAll { $0.id == message.id }
            
            // Update conversation's lastMessage
            try await updateConversationLastMessage(
                conversationId: conversationId,
                lastMessage: text,
                senderId: currentUserId
            )
            
            print("[ChatService] Sent message successfully: \(updatedMessage.id) with status: sent")
            return updatedMessage
            
        } catch {
            // Failed! Keep in queue with failed status
            if let index = pendingMessages.firstIndex(where: { $0.id == message.id }) {
                pendingMessages[index].status = .failed
            }
            print("[ChatService] Failed to send message: \(message.id)")
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
        
        print("[ChatService] Uploaded message: \(message.id)")
    }
    
    /// Updates conversation's last message preview
    private func updateConversationLastMessage(
        conversationId: String,
        lastMessage: String,
        senderId: String
    ) async throws {
        try await db.collection("conversations")
            .document(conversationId)
            .updateData([
                "lastMessage": lastMessage,
                "lastMessageAt": FieldValue.serverTimestamp(),
                "lastMessageSenderId": senderId  // PR#17.1: Required for toast notifications
            ])
        
        print("[ChatService] Updated last message for conversation: \(conversationId) (sender: \(senderId))")
    }
    
    /// Fetch messages in real-time using Firestore snapshot listener (PR #10)
    /// Now uses documentChanges for better performance (bug fix)
    /// - Parameter conversationId: ID of the conversation
    /// - Returns: AsyncThrowingStream of message arrays as they update
    func fetchMessagesRealtime(
        conversationId: String
    ) async throws -> AsyncThrowingStream<[Message], Error> {
        
        print("🎧 [ChatService] Setting up real-time listener for conversation: \(conversationId)")
        
        return AsyncThrowingStream { continuation in
            let listener = db.collection("conversations")
                .document(conversationId)
                .collection("messages")
                .order(by: "sentAt", descending: false)
                .addSnapshotListener { [weak self] snapshot, error in
                    if let error = error {
                        print("❌ [ChatService] Real-time listener error: \(error)")
                        continuation.finish(throwing: self?.mapFirestoreError(error) ?? ChatError.unknown(error))
                        return
                    }
                    
                    guard let snapshot = snapshot else {
                        print("📭 [ChatService] No snapshot")
                        continuation.yield([])
                        return
                    }
                    
                    // Process only changed documents (Firestore automatically includes all as .added on first load)
                    // This is more efficient than processing all documents every time
                    let changedMessages = snapshot.documentChanges.compactMap { change -> Message? in
                        var data = change.document.data()
                        data["id"] = change.document.documentID
                        
                        guard let message = Message(dictionary: data) else {
                            return nil
                        }
                        
                        // Log the type of change WITH DETAILED INFO
                        switch change.type {
                        case .added:
                            print("➕ [ChatService] New message: \(message.id)")
                        case .modified:
                            print("✏️ [ChatService] Modified message: \(message.id)")
                            print("   deliveredTo: \(message.deliveredTo)")
                            print("   readBy: \(message.readBy)")
                            print("   status: \(message.status)")
                        case .removed:
                            print("🗑️ [ChatService] Removed message: \(message.id)")
                        }
                        
                        return message
                    }
                    
                    print("📨 [ChatService] Received \(changedMessages.count) changed messages")
                    continuation.yield(changedMessages)
                }
            
            // Cleanup when stream is cancelled
            continuation.onTermination = { @Sendable _ in
                listener.remove()
                print("🛑 [ChatService] Real-time listener removed for conversation: \(conversationId)")
            }
        }
    }
    
    /// Fetches messages for a conversation with real-time updates
    /// - Parameter conversationId: The conversation ID
    /// - Returns: AsyncThrowingStream of message arrays
    func fetchMessages(conversationId: String) -> AsyncThrowingStream<[Message], Error> {
        AsyncThrowingStream { [weak self] continuation in
            guard let self = self else { return }
            
            let listener = db.collection("conversations")
                .document(conversationId)
                .collection("messages")
                .order(by: "sentAt", descending: false)
                .addSnapshotListener { [weak self] snapshot, error in
                    
                    if let error = error {
                        continuation.finish(throwing: self?.mapFirestoreError(error) ?? ChatError.unknown(error))
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
            continuation.onTermination = { @Sendable [weak self] _ in
                listener.remove()
                Task { @MainActor in
                    self?.listeners.removeValue(forKey: "messages-\(conversationId)")
                }
                print("[ChatService] Detached messages listener for conversation: \(conversationId)")
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
            
            print("[ChatService] Updated message \(messageId) status to: \(status)")
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
    
    // MARK: - Recipient Tracking (PR #11)
    
    /// Mark message as delivered to a specific user
    /// - Parameters:
    ///   - conversationId: The conversation ID
    ///   - messageId: The message ID
    ///   - userId: The user ID who received the message
    func markMessageAsDelivered(
        conversationId: String,
        messageId: String,
        userId: String
    ) async throws {
        do {
            let messageRef = db.collection("conversations")
                .document(conversationId)
                .collection("messages")
                .document(messageId)
            
            try await messageRef.updateData([
                "deliveredTo": FieldValue.arrayUnion([userId]),
                "deliveredAt": FieldValue.serverTimestamp()
            ])
            
            print("[ChatService] ✅ Message \(messageId) delivered to \(userId)")
        } catch {
            throw mapFirestoreError(error)
        }
    }
    
    /// Mark message as read by a specific user
    /// - Parameters:
    ///   - conversationId: The conversation ID
    ///   - messageId: The message ID
    ///   - userId: The user ID who read the message
    func markMessageAsRead(
        conversationId: String,
        messageId: String,
        userId: String
    ) async throws {
        do {
            let messageRef = db.collection("conversations")
                .document(conversationId)
                .collection("messages")
                .document(messageId)
            
            try await messageRef.updateData([
                "readBy": FieldValue.arrayUnion([userId]),
                "readAt": FieldValue.serverTimestamp()
            ])
            
            print("[ChatService] ✅ Message \(messageId) read by \(userId)")
        } catch {
            throw mapFirestoreError(error)
        }
    }
    
    /// Batch mark all messages in conversation as read (conversation-level tracking)
    /// - Parameters:
    ///   - conversationId: The conversation ID
    ///   - userId: The user ID marking messages as read
    func markAllMessagesAsRead(
        conversationId: String,
        userId: String
    ) async throws {
        do {
            print("📖 [ChatService] markAllMessagesAsRead called for user: \(userId)")
            
            // Query messages not sent by current user (simplified to match markMessagesAsDelivered)
            let messagesQuery = db.collection("conversations")
                .document(conversationId)
                .collection("messages")
                .whereField("senderId", isNotEqualTo: userId)
            
            let snapshot = try await messagesQuery.getDocuments()
            
            guard !snapshot.documents.isEmpty else {
                print("[ChatService] No messages to mark as read")
                return
            }
            
            print("📨 [ChatService] Found \(snapshot.documents.count) messages from other users")
            
            let batch = db.batch()
            var updatedCount = 0
            
            for document in snapshot.documents {
                let messageRef = document.reference
                let messageId = document.documentID
                
                // Only update if not already read by this user
                let readBy = document.data()["readBy"] as? [String] ?? []
                let deliveredTo = document.data()["deliveredTo"] as? [String] ?? []
                print("   Message \(messageId): deliveredTo=\(deliveredTo), readBy=\(readBy)")
                
                var needsUpdate = false
                var updates: [String: Any] = [:]
                
                // Add to deliveredTo if not already there
                if !deliveredTo.contains(userId) {
                    print("   ➕ Adding \(userId) to deliveredTo")
                    updates["deliveredTo"] = FieldValue.arrayUnion([userId])
                    needsUpdate = true
                }
                
                // Add to readBy if not already there
                if !readBy.contains(userId) {
                    print("   ➕ Adding \(userId) to readBy")
                    updates["readBy"] = FieldValue.arrayUnion([userId])
                    updates["readAt"] = FieldValue.serverTimestamp()
                    needsUpdate = true
                }
                
                if needsUpdate {
                    batch.updateData(updates, forDocument: messageRef)
                    updatedCount += 1
                } else {
                    print("   ✅ Already delivered + read by \(userId)")
                }
            }
            
            try await batch.commit()
            print("[ChatService] ✅ Marked \(updatedCount)/\(snapshot.documents.count) messages as delivered + read for \(userId)")
            
        } catch {
            print("[ChatService] ❌ Error marking messages as read: \(error)")
            throw mapFirestoreError(error)
        }
    }
    
    /// Mark specific messages as delivered only (PR #11 Fix)
    /// Used when message arrives on device (device-level receipt)
    /// - Parameters:
    ///   - conversationId: The conversation ID
    ///   - messageIds: Array of specific message IDs to mark
    ///   - userId: The user ID who received the messages
    func markSpecificMessagesAsDelivered(
        conversationId: String,
        messageIds: [String],
        userId: String
    ) async throws {
        do {
            print("📦 [ChatService] markSpecificMessagesAsDelivered called for \(messageIds.count) messages")
            
            let batch = db.batch()
            var updatedCount = 0
            
            for messageId in messageIds {
                let messageRef = db.collection("conversations")
                    .document(conversationId)
                    .collection("messages")
                    .document(messageId)
                
                // Fetch current data to check if already marked
                let document = try await messageRef.getDocument()
                guard document.exists else {
                    print("   ⚠️ Message \(messageId) not found")
                    continue
                }
                
                let data = document.data() ?? [:]
                let deliveredTo = data["deliveredTo"] as? [String] ?? []
                
                // Only update if not already delivered to this user
                if !deliveredTo.contains(userId) {
                    print("   ➕ Adding \(userId) to deliveredTo for message \(messageId)")
                    batch.updateData([
                        "deliveredTo": FieldValue.arrayUnion([userId]),
                        "deliveredAt": FieldValue.serverTimestamp()
                    ], forDocument: messageRef)
                    updatedCount += 1
                } else {
                    print("   ✅ Already delivered to \(userId)")
                }
            }
            
            try await batch.commit()
            print("[ChatService] ✅ Marked \(updatedCount)/\(messageIds.count) messages as delivered")
            
        } catch {
            print("[ChatService] ❌ Error marking specific messages as delivered: \(error)")
            throw mapFirestoreError(error)
        }
    }
    
    /// Mark specific messages as delivered + read (PR #11 Fix)
    /// Used for real-time read receipts when chat is visible
    /// - Parameters:
    ///   - conversationId: The conversation ID
    ///   - messageIds: Array of specific message IDs to mark
    ///   - userId: The user ID marking messages as read
    func markSpecificMessagesAsRead(
        conversationId: String,
        messageIds: [String],
        userId: String
    ) async throws {
        do {
            print("🔔 [ChatService] markSpecificMessagesAsRead called for \(messageIds.count) messages")
            
            let batch = db.batch()
            var updatedCount = 0
            
            for messageId in messageIds {
                let messageRef = db.collection("conversations")
                    .document(conversationId)
                    .collection("messages")
                    .document(messageId)
                
                // Fetch current data to check if already marked
                let document = try await messageRef.getDocument()
                guard document.exists else {
                    print("   ⚠️ Message \(messageId) not found")
                    continue
                }
                
                let data = document.data() ?? [:]
                let deliveredTo = data["deliveredTo"] as? [String] ?? []
                let readBy = data["readBy"] as? [String] ?? []
                
                var needsUpdate = false
                var updates: [String: Any] = [:]
                
                // Add to deliveredTo if not already there
                if !deliveredTo.contains(userId) {
                    print("   ➕ Adding \(userId) to deliveredTo for message \(messageId)")
                    updates["deliveredTo"] = FieldValue.arrayUnion([userId])
                    needsUpdate = true
                }
                
                // Add to readBy if not already there
                if !readBy.contains(userId) {
                    print("   ➕ Adding \(userId) to readBy for message \(messageId)")
                    updates["readBy"] = FieldValue.arrayUnion([userId])
                    updates["readAt"] = FieldValue.serverTimestamp()
                    needsUpdate = true
                }
                
                if needsUpdate {
                    batch.updateData(updates, forDocument: messageRef)
                    updatedCount += 1
                }
            }
            
            try await batch.commit()
            print("[ChatService] ✅ Marked \(updatedCount)/\(messageIds.count) messages as delivered + read")
            
        } catch {
            print("[ChatService] ❌ Error marking specific messages: \(error)")
            throw mapFirestoreError(error)
        }
    }
    
    /// Mark messages as delivered when conversation opened (background operation)
    /// - Parameters:
    ///   - conversationId: The conversation ID
    ///   - userId: The user ID who opened the conversation
    func markMessagesAsDelivered(
        conversationId: String,
        userId: String
    ) async throws {
        do {
            print("🔔 [ChatService] markMessagesAsDelivered called for user: \(userId)")
            
            // Query messages not sent by current user
            let messagesQuery = db.collection("conversations")
                .document(conversationId)
                .collection("messages")
                .whereField("senderId", isNotEqualTo: userId)
            
            let snapshot = try await messagesQuery.getDocuments()
            
            guard !snapshot.documents.isEmpty else {
                print("[ChatService] No messages to mark as delivered")
                return
            }
            
            print("📨 [ChatService] Found \(snapshot.documents.count) messages from other users")
            
            let batch = db.batch()
            var updatedCount = 0
            
            for document in snapshot.documents {
                let messageRef = document.reference
                let messageId = document.documentID
                
                // Only update if not already delivered to this user
                let deliveredTo = document.data()["deliveredTo"] as? [String] ?? []
                print("   Message \(messageId): deliveredTo = \(deliveredTo)")
                
                if !deliveredTo.contains(userId) {
                    print("   ➕ Adding \(userId) to deliveredTo array")
                    batch.updateData([
                        "deliveredTo": FieldValue.arrayUnion([userId])
                    ], forDocument: messageRef)
                    updatedCount += 1
                } else {
                    print("   ✅ Already delivered to \(userId)")
                }
            }
            
            try await batch.commit()
            print("[ChatService] ✅ Marked \(updatedCount)/\(snapshot.documents.count) messages as delivered for \(userId)")
            
        } catch {
            print("[ChatService] ❌ Error marking messages as delivered: \(error)")
            throw mapFirestoreError(error)
        }
    }
    
    // MARK: - Queue Management
    
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
                    lastMessage: message.text,
                    senderId: message.senderId
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
    
    // MARK: - User & Conversation Discovery (PR #8)
    
    /// Find existing conversation between two users
    /// Returns nil if no conversation exists
    /// - Parameter participants: Array of user IDs to search for
    /// - Returns: Existing Conversation or nil
    func findExistingConversation(
        participants: [String]
    ) async throws -> Conversation? {
        // Sort participants for consistent querying
        let sortedParticipants = participants.sorted()
        
        do {
            // Query conversations with exactly these participants
            let snapshot = try await db.collection("conversations")
                .whereField("participants", isEqualTo: sortedParticipants)
                .whereField("isGroup", isEqualTo: false)
                .limit(to: 1)
                .getDocuments()
            
            // Return nil if no conversation found
            guard let document = snapshot.documents.first else {
                print("[ChatService] No existing conversation found for participants: \(participants)")
                return nil
            }
            
            // Convert Firestore document to Conversation
            let conversation = Conversation(dictionary: document.data())
            print("[ChatService] Found existing conversation: \(conversation?.id ?? "nil")")
            return conversation
            
        } catch {
            print("[ChatService] Error finding existing conversation: \(error)")
            throw mapFirestoreError(error)
        }
    }
    
    /// Fetch all registered users except specified user
    /// Returns users sorted alphabetically by display name
    /// - Parameter excludingUserId: User ID to exclude from results (typically current user)
    /// - Returns: Array of User objects
    func fetchAllUsers(excludingUserId: String) async throws -> [User] {
        do {
            let snapshot = try await db.collection("users")
                .order(by: "displayName")
                .getDocuments()
            
            // Convert documents to User objects and filter out specified user
            let users = snapshot.documents
                .compactMap { document -> User? in
                    User(from: document.data())
                }
                .filter { $0.id != excludingUserId }
            
            print("[ChatService] Fetched \(users.count) users (excluding \(excludingUserId))")
            return users
            
        } catch {
            print("[ChatService] Error fetching users: \(error)")
            throw mapFirestoreError(error)
        }
    }
    
    /// Fetch a single user by ID (PR #17.1: for toast notifications)
    /// - Parameter userId: The user ID to fetch
    /// - Returns: User object or nil if not found
    func fetchUser(userId: String) async throws -> User? {
        do {
            let document = try await db.collection("users").document(userId).getDocument()
            
            guard document.exists, let data = document.data() else {
                print("[ChatService] User not found: \(userId)")
                return nil
            }
            
            let user = User(from: data)
            print("[ChatService] Fetched user: \(user?.displayName ?? "Unknown")")
            return user
            
        } catch {
            print("[ChatService] Error fetching user: \(error)")
            throw mapFirestoreError(error)
        }
    }
    
    // MARK: - Group Management (PR #13)
    
    /// Create a new group conversation with 3-50 participants
    /// - Parameters:
    ///   - participants: Array of user IDs (3-50, including creator)
    ///   - groupName: Optional name for the group
    /// - Returns: Created group Conversation
    func createGroup(
        participants: [String],
        groupName: String?
    ) async throws -> Conversation {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            throw ChatError.permissionDenied
        }
        
        // Ensure current user is in participants
        var allParticipants = Set(participants)
        allParticipants.insert(currentUserId)
        
        // Validate: 3-50 participants
        guard allParticipants.count >= 3 && allParticipants.count <= 50 else {
            throw ChatError.invalidData
        }
        
        // Create group conversation
        let conversation = Conversation(
            participants: Array(allParticipants),
            groupName: groupName ?? "",
            createdBy: currentUserId
        )
        
        // Upload to Firestore
        try await db.collection("conversations")
            .document(conversation.id)
            .setData(conversation.toDictionary())
        
        print("[ChatService] Created group: \(conversation.id) with \(allParticipants.count) participants")
        return conversation
    }
    
    /// Add participants to an existing group
    /// - Parameters:
    ///   - conversationId: The group conversation ID
    ///   - userIds: Array of user IDs to add
    ///   - currentUserId: The user performing the action (must be admin)
    func addParticipants(
        to conversationId: String,
        userIds: [String],
        currentUserId: String
    ) async throws {
        // Fetch conversation to verify admin status
        let conversationDoc = try await db.collection("conversations")
            .document(conversationId)
            .getDocument()
        
        guard let conversationData = conversationDoc.data(),
              let conversation = Conversation(dictionary: conversationData) else {
            throw ChatError.conversationNotFound
        }
        
        // Verify user is admin
        guard conversation.isAdmin(userId: currentUserId) else {
            throw ChatError.permissionDenied
        }
        
        // Verify it's a group
        guard conversation.isGroup else {
            throw ChatError.invalidData
        }
        
        // Verify won't exceed 50 participants
        let newTotal = conversation.participants.count + userIds.count
        guard newTotal <= 50 else {
            throw ChatError.invalidData
        }
        
        // Add participants
        try await db.collection("conversations")
            .document(conversationId)
            .updateData([
                "participants": FieldValue.arrayUnion(userIds)
            ])
        
        print("[ChatService] Added \(userIds.count) participants to group: \(conversationId)")
    }
    
    /// Remove a participant from a group
    /// - Parameters:
    ///   - conversationId: The group conversation ID
    ///   - userId: User ID to remove
    ///   - currentUserId: The user performing the action (must be admin)
    func removeParticipant(
        from conversationId: String,
        userId: String,
        currentUserId: String
    ) async throws {
        // Fetch conversation to verify admin status
        let conversationDoc = try await db.collection("conversations")
            .document(conversationId)
            .getDocument()
        
        guard let conversationData = conversationDoc.data(),
              let conversation = Conversation(dictionary: conversationData) else {
            throw ChatError.conversationNotFound
        }
        
        // Verify user is admin
        guard conversation.isAdmin(userId: currentUserId) else {
            throw ChatError.permissionDenied
        }
        
        // Can't remove the creator
        guard userId != conversation.createdBy else {
            throw ChatError.permissionDenied
        }
        
        // Remove participant
        try await db.collection("conversations")
            .document(conversationId)
            .updateData([
                "participants": FieldValue.arrayRemove([userId]),
                "admins": FieldValue.arrayRemove([userId]) // Remove from admins too if admin
            ])
        
        print("[ChatService] Removed participant \(userId) from group: \(conversationId)")
    }
    
    /// Leave a group conversation
    /// - Parameters:
    ///   - conversationId: The group conversation ID
    ///   - userId: User ID leaving the group
    func leaveGroup(
        conversationId: String,
        userId: String
    ) async throws {
        // Fetch conversation
        let conversationDoc = try await db.collection("conversations")
            .document(conversationId)
            .getDocument()
        
        guard let conversationData = conversationDoc.data(),
              let conversation = Conversation(dictionary: conversationData) else {
            throw ChatError.conversationNotFound
        }
        
        // Creator cannot leave (must transfer ownership first)
        guard userId != conversation.createdBy else {
            throw ChatError.permissionDenied
        }
        
        // Remove user from participants and admins
        try await db.collection("conversations")
            .document(conversationId)
            .updateData([
                "participants": FieldValue.arrayRemove([userId]),
                "admins": FieldValue.arrayRemove([userId])
            ])
        
        print("[ChatService] User \(userId) left group: \(conversationId)")
    }
    
    /// Update group name
    /// - Parameters:
    ///   - conversationId: The group conversation ID
    ///   - groupName: New group name
    ///   - currentUserId: The user performing the action (must be admin)
    func updateGroupName(
        conversationId: String,
        groupName: String,
        currentUserId: String
    ) async throws {
        // Fetch conversation to verify admin status
        let conversationDoc = try await db.collection("conversations")
            .document(conversationId)
            .getDocument()
        
        guard let conversationData = conversationDoc.data(),
              let conversation = Conversation(dictionary: conversationData) else {
            throw ChatError.conversationNotFound
        }
        
        // Verify user is admin
        guard conversation.isAdmin(userId: currentUserId) else {
            throw ChatError.permissionDenied
        }
        
        // Update name
        try await db.collection("conversations")
            .document(conversationId)
            .updateData([
                "groupName": groupName
            ])
        
        print("[ChatService] Updated group name to: \(groupName)")
    }
    
    /// Update group photo URL
    /// - Parameters:
    ///   - conversationId: The group conversation ID
    ///   - photoURL: New group photo URL
    ///   - currentUserId: The user performing the action (must be admin)
    func updateGroupPhoto(
        conversationId: String,
        photoURL: String,
        currentUserId: String
    ) async throws {
        // Fetch conversation to verify admin status
        let conversationDoc = try await db.collection("conversations")
            .document(conversationId)
            .getDocument()
        
        guard let conversationData = conversationDoc.data(),
              let conversation = Conversation(dictionary: conversationData) else {
            throw ChatError.conversationNotFound
        }
        
        // Verify user is admin
        guard conversation.isAdmin(userId: currentUserId) else {
            throw ChatError.permissionDenied
        }
        
        // Update photo
        try await db.collection("conversations")
            .document(conversationId)
            .updateData([
                "groupPhotoURL": photoURL
            ])
        
        print("[ChatService] Updated group photo")
    }
    
    /// Promote a participant to admin
    /// - Parameters:
    ///   - conversationId: The group conversation ID
    ///   - userId: User ID to promote
    ///   - currentUserId: The user performing the action (must be admin)
    func promoteToAdmin(
        conversationId: String,
        userId: String,
        currentUserId: String
    ) async throws {
        // Fetch conversation to verify admin status
        let conversationDoc = try await db.collection("conversations")
            .document(conversationId)
            .getDocument()
        
        guard let conversationData = conversationDoc.data(),
              let conversation = Conversation(dictionary: conversationData) else {
            throw ChatError.conversationNotFound
        }
        
        // Verify user is admin
        guard conversation.isAdmin(userId: currentUserId) else {
            throw ChatError.permissionDenied
        }
        
        // Verify target user is participant
        guard conversation.participants.contains(userId) else {
            throw ChatError.invalidData
        }
        
        // Promote to admin
        try await db.collection("conversations")
            .document(conversationId)
            .updateData([
                "admins": FieldValue.arrayUnion([userId])
            ])
        
        print("[ChatService] Promoted \(userId) to admin in group: \(conversationId)")
    }
    
    /// Demote an admin to regular participant
    /// - Parameters:
    ///   - conversationId: The group conversation ID
    ///   - userId: User ID to demote
    ///   - currentUserId: The user performing the action (must be admin)
    func demoteFromAdmin(
        conversationId: String,
        userId: String,
        currentUserId: String
    ) async throws {
        // Fetch conversation to verify admin status
        let conversationDoc = try await db.collection("conversations")
            .document(conversationId)
            .getDocument()
        
        guard let conversationData = conversationDoc.data(),
              let conversation = Conversation(dictionary: conversationData) else {
            throw ChatError.conversationNotFound
        }
        
        // Verify user is admin
        guard conversation.isAdmin(userId: currentUserId) else {
            throw ChatError.permissionDenied
        }
        
        // Can't demote the creator
        guard userId != conversation.createdBy else {
            throw ChatError.permissionDenied
        }
        
        // Demote from admin
        try await db.collection("conversations")
            .document(conversationId)
            .updateData([
                "admins": FieldValue.arrayRemove([userId])
            ])
        
        print("[ChatService] Demoted \(userId) from admin in group: \(conversationId)")
    }
    
    // MARK: - Conversation Deletion
    
    /// Deletes a conversation and all its messages from Firebase
    /// - Parameter conversationId: The ID of the conversation to delete
    func deleteConversation(conversationId: String) async throws {
        do {
            print("🗑️ Deleting conversation: \(conversationId)")
            
            // Delete all messages in this conversation
            let messagesSnapshot = try await db.collection("conversations")
                .document(conversationId)
                .collection("messages")
                .getDocuments()
            
            // Use batch to delete messages efficiently
            let messageBatch = db.batch()
            for messageDoc in messagesSnapshot.documents {
                messageBatch.deleteDocument(messageDoc.reference)
            }
            try await messageBatch.commit()
            
            print("   Deleted \(messagesSnapshot.documents.count) messages")
            
            // Delete the conversation document
            try await db.collection("conversations")
                .document(conversationId)
                .delete()
            
            print("✅ Successfully deleted conversation: \(conversationId)")
            
        } catch {
            print("❌ Error deleting conversation: \(error)")
            throw mapFirestoreError(error)
        }
    }
    
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
    
    // MARK: - AI Metadata Updates (PR #15)
    
    /// Update message with AI metadata (calendar events, decisions, etc.)
    func updateMessageAIMetadata(
        conversationId: String,
        messageId: String,
        aiMetadata: AIMetadata
    ) async throws {
        print("📝 [ChatService] Updating message \(messageId) with AI metadata")
        
        let messageRef = db.collection("conversations")
            .document(conversationId)
            .collection("messages")
            .document(messageId)
        
        // Encode AI metadata to dictionary
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(aiMetadata)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
            
            try await messageRef.updateData([
                "aiMetadata": json,
                "updatedAt": FieldValue.serverTimestamp()
            ])
            
            print("✅ [ChatService] Updated message with AI metadata")
        } catch {
            print("❌ [ChatService] Failed to update message AI metadata: \(error)")
            throw mapFirestoreError(error)
        }
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

