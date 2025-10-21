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
        var message: Message
        if let imageURL = imageURL {
            // Use full initializer for messages with images
            message = Message(
                id: UUID().uuidString,
                conversationId: conversationId,
                senderId: currentUserId,
                text: text,
                imageURL: imageURL
            )
        } else {
            // Use convenience initializer for text-only messages
            message = Message(
                conversationId: conversationId,
                senderId: currentUserId,
                text: text
            )
        }
        
        // Add to pending queue
        pendingMessages.append(message)
        print("[ChatService] Queued message: \(message.id)")
        
        // Try to upload to Firestore
        do {
            try await uploadMessageToFirestore(message)
            
            // Success! Update status and remove from queue
            message.status = MessageStatus.sent
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
    
    /// Fetch messages in real-time using Firestore snapshot listener (PR #10)
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
                    
                    guard let documents = snapshot?.documents else {
                        print("📭 [ChatService] No documents in snapshot")
                        continuation.yield([])
                        return
                    }
                    
                    // Convert Firestore documents to Message objects
                    let messages = documents.compactMap { doc -> Message? in
                        var data = doc.data()
                        data["id"] = doc.documentID // Add document ID to data
                        
                        return Message(dictionary: data)
                    }
                    
                    print("📨 [ChatService] Received \(messages.count) messages from real-time listener")
                    continuation.yield(messages)
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

