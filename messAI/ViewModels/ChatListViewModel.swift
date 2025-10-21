//
//  ChatListViewModel.swift
//  messAI
//
//  Created by Isaac Jaramillo on 10/20/25.
//

import Foundation
import Combine
import SwiftUI

@MainActor
class ChatListViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var conversations: [Conversation] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var showError: Bool = false
    @Published var userPresence: [String: Presence] = [:]
    
    // MARK: - Private Properties
    
    private let chatService: ChatService
    private let localDataManager: LocalDataManager
    let currentUserId: String  // Internal access for ContactsListView integration (PR #8)
    private var firestoreTask: Task<Void, Never>?
    private let presenceService = PresenceService.shared
    
    // MARK: - Computed Properties
    
    /// Conversations sorted by most recent first
    var sortedConversations: [Conversation] {
        conversations.sorted { $0.lastMessageAt > $1.lastMessageAt }
    }
    
    // MARK: - Initialization
    
    init(
        chatService: ChatService,
        localDataManager: LocalDataManager,
        currentUserId: String
    ) {
        self.chatService = chatService
        self.localDataManager = localDataManager
        self.currentUserId = currentUserId
    }
    
    // MARK: - Public Methods
    
    /// Load conversations from local storage, then start real-time listener
    func loadConversations() {
        Task {
            // Step 1: Load from local (instant)
            await loadConversationsFromLocal()
            
            // Step 2: Start real-time listener
            await startRealtimeListener()
        }
    }
    
    /// Stop real-time listener when view disappears
    func stopListening() {
        firestoreTask?.cancel()
        firestoreTask = nil
        presenceService.stopAllListeners()
        print("🛑 Stopped Firestore listener and presence observers")
    }
    
    /// Refresh conversations manually
    func refresh() async {
        await startRealtimeListener()
    }
    
    // MARK: - Private Methods
    
    /// Load conversations from Core Data (instant display)
    private func loadConversationsFromLocal() async {
        do {
            let allConversations = try localDataManager.fetchConversations()
            
            // Filter to only conversations where current user is a participant
            conversations = allConversations.filter { conversation in
                conversation.participants.contains(currentUserId)
            }
            
            print("✅ Loaded \(conversations.count) conversations from local storage")
        } catch {
            print("⚠️ Failed to load local conversations: \(error)")
            errorMessage = "Failed to load conversations from local storage"
            showError = true
        }
    }
    
    /// Start Firestore real-time listener
    private func startRealtimeListener() async {
        // Cancel existing listener
        firestoreTask?.cancel()
        
        isLoading = true
        
        firestoreTask = Task {
            do {
                // Get async stream of conversations
                let stream = chatService.fetchConversations(userId: currentUserId)
                
                for try await firestoreConversations in stream {
                    // PR#17.1: Check for new messages and trigger toasts
                    await checkForNewMessagesAndNotify(newConversations: firestoreConversations)
                    
                    // Update UI on main thread
                    await MainActor.run {
                        self.conversations = firestoreConversations
                        self.isLoading = false
                        print("✅ Updated \(firestoreConversations.count) conversations from Firestore")
                    }
                    
                    // Observe presence for all participants
                    await observePresenceForConversations(firestoreConversations)
                    
                    // Save to local storage in background
                    Task.detached { [weak self] in
                        guard let self = self else { return }
                        try? await self.saveConversationsToLocal(firestoreConversations)
                    }
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = "Failed to sync conversations: \(error.localizedDescription)"
                    self.showError = true
                    print("❌ Firestore listener error: \(error)")
                }
            }
        }
    }
    
    /// PR#17.1: Check for new messages and trigger toast notifications
    private func checkForNewMessagesAndNotify(newConversations: [Conversation]) async {
        print("🔍 [Toast Debug] Checking \(newConversations.count) conversations for new messages")
        print("🔍 [Toast Debug] Current conversations count: \(conversations.count)")
        
        for newConv in newConversations {
            print("🔍 [Toast Debug] Checking conversation: \(newConv.id)")
            
            // Find corresponding old conversation
            guard let oldConv = conversations.first(where: { $0.id == newConv.id }) else {
                print("   ⏭️  No old version found (first load or new conversation), skipping")
                continue
            }
            
            print("   📅 Old timestamp: \(oldConv.lastMessageAt)")
            print("   📅 New timestamp: \(newConv.lastMessageAt)")
            
            // Check if last message changed (new message arrived)
            guard newConv.lastMessageAt > oldConv.lastMessageAt else {
                print("   ⏭️  No new message (timestamp unchanged)")
                continue
            }
            
            print("   ✅ New message detected!")
            
            // Check if we have sender ID
            guard let senderId = newConv.lastMessageSenderId else {
                print("   ❌ No sender ID in conversation")
                continue
            }
            
            print("   👤 Sender ID: \(senderId), Current user: \(currentUserId)")
            
            // Don't show toast for our own messages
            guard senderId != currentUserId else {
                print("   ⏭️  Skipping our own message")
                continue
            }
            
            print("   🔔 Message from other user, checking if should show toast...")
            
            // Check if we should show toast (not for active conversation)
            guard ToastNotificationManager.shared.shouldShowToast(conversationId: newConv.id) else {
                print("   ⏭️  Toast manager says no (active conversation)")
                continue
            }
            
            print("   🚀 All checks passed, triggering toast!")
            
            // Show toast for this new message
            await showToastForMessage(
                messageText: newConv.lastMessage,
                senderId: senderId,
                conversationId: newConv.id,
                timestamp: newConv.lastMessageAt
            )
        }
        
        print("🔍 [Toast Debug] Check complete\n")
    }
    
    /// Show toast notification for a message
    private func showToastForMessage(
        messageText: String,
        senderId: String,
        conversationId: String,
        timestamp: Date
    ) async {
        print("   📨 [Toast Debug] showToastForMessage called")
        print("   📨 Message: \(messageText)")
        print("   📨 Sender ID: \(senderId)")
        
        do {
            // Fetch sender information
            print("   🔄 Fetching sender info...")
            let sender = try await chatService.fetchUser(userId: senderId)
            print("   ✅ Sender fetched: \(sender?.displayName ?? "Unknown")")
            
            // Create toast
            let toast = ToastMessage(
                id: UUID().uuidString,
                conversationId: conversationId,
                senderId: senderId,
                senderName: sender?.displayName ?? "Unknown",
                senderPhotoURL: sender?.photoURL,
                messageText: messageText,
                isImageMessage: false, // We don't have image info from conversation, assume text
                timestamp: timestamp
            )
            
            print("   🎯 Toast created: \(toast.senderName) - \(toast.displayText)")
            
            // Show toast
            await MainActor.run {
                print("   🚀 Calling ToastNotificationManager.showToast()")
                ToastNotificationManager.shared.showToast(toast)
            }
        } catch {
            print("   ❌ Failed to fetch sender info for toast: \(error)")
        }
    }
    
    /// Save conversations to Core Data for offline access
    private func saveConversationsToLocal(_ conversations: [Conversation]) async throws {
        for conversation in conversations {
            try localDataManager.saveConversation(conversation)
        }
        print("💾 Saved \(conversations.count) conversations to local storage")
    }
    
    /// Observe presence for all conversation participants
    private func observePresenceForConversations(_ conversations: [Conversation]) async {
        // Get all unique participant IDs (excluding current user)
        let allParticipants = Set(
            conversations.flatMap { $0.participants }
                .filter { $0 != currentUserId }
        )
        
        // Start observing presence for each unique participant
        for userId in allParticipants {
            presenceService.observePresence(userId)
        }
        
        // Subscribe to presence updates
        Task { @MainActor in
            // Mirror PresenceService.userPresence to our local copy
            // This allows the UI to update reactively
            self.userPresence = presenceService.userPresence
        }
        
        print("👀 Observing presence for \(allParticipants.count) users")
    }
    
    // MARK: - Helper Methods
    
    /// Get display name for conversation
    func getConversationName(_ conversation: Conversation) -> String {
        if conversation.isGroup {
            return conversation.groupName ?? "Unnamed Group"
        } else {
            // Get other participant's name
            let otherUserId = conversation.participants.first { $0 != currentUserId }
            // TODO: Fetch user name from UserService (PR #8)
            return otherUserId ?? "Unknown User"
        }
    }
    
    /// Get profile picture URL for conversation
    func getConversationPhotoURL(_ conversation: Conversation) -> String? {
        if conversation.isGroup {
            return nil // Group icon instead
        } else {
            // Get other participant's photo
            // TODO: Fetch user photo from UserService (PR #8)
            return nil
        }
    }
    
    /// Calculate unread count for conversation
    func getUnreadCount(_ conversation: Conversation) -> Int {
        // TODO: Implement unread count from message status (PR #11)
        return 0
    }
    
    /// Get presence for conversation (1-on-1 chats only)
    func getPresence(_ conversation: Conversation) -> Presence? {
        guard !conversation.isGroup else { return nil }
        
        // Find other participant
        guard let otherUserId = conversation.participants.first(where: { $0 != currentUserId }) else {
            return nil
        }
        
        return userPresence[otherUserId]
    }
    
    // MARK: - Conversation Creation (PR #8)
    
    /// Start conversation with selected user
    /// Checks for existing conversation first, creates new if none exists
    /// - Parameter user: The user to start conversation with
    /// - Returns: Existing or newly created Conversation
    func startConversation(with user: User) async throws -> Conversation {
        print("[ChatListViewModel] Starting conversation with: \(user.displayName)")
        
        // Check for existing conversation
        if let existing = try await chatService.findExistingConversation(
            participants: [currentUserId, user.id]
        ) {
            print("[ChatListViewModel] Found existing conversation: \(existing.id)")
            return existing
        }
        
        // Create new conversation
        print("[ChatListViewModel] Creating new conversation with: \(user.displayName)")
        let newConversation = try await chatService.createConversation(
            participants: [currentUserId, user.id],
            isGroup: false
        )
        
        // Save to local storage
        try localDataManager.saveConversation(newConversation)
        
        // Add to conversations list
        conversations.append(newConversation)
        
        print("[ChatListViewModel] Created and saved conversation: \(newConversation.id)")
        return newConversation
    }
}

