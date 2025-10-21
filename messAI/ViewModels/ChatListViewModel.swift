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
    
    // MARK: - Private Properties
    
    private let chatService: ChatService
    private let localDataManager: LocalDataManager
    let currentUserId: String  // Internal access for ContactsListView integration (PR #8)
    private var firestoreTask: Task<Void, Never>?
    
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
        print("🛑 Stopped Firestore listener")
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
                    // Update UI on main thread
                    await MainActor.run {
                        self.conversations = firestoreConversations
                        self.isLoading = false
                        print("✅ Updated \(firestoreConversations.count) conversations from Firestore")
                    }
                    
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
    
    /// Save conversations to Core Data for offline access
    private func saveConversationsToLocal(_ conversations: [Conversation]) async throws {
        for conversation in conversations {
            try localDataManager.saveConversation(conversation)
        }
        print("💾 Saved \(conversations.count) conversations to local storage")
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

