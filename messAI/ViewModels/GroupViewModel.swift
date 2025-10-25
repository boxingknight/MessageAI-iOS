//
//  GroupViewModel.swift
//  messAI
//
//  Created for PR #13: Group Chat Functionality
//

import Foundation
import FirebaseAuth
import Combine

/// ViewModel for group creation and management
@MainActor
class GroupViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Selected participants for new group
    @Published var selectedParticipants: Set<String> = []
    
    /// Group name (optional)
    @Published var groupName: String = ""
    
    /// Loading states
    @Published var isCreating: Bool = false
    @Published var isLoading: Bool = false
    
    /// Error handling
    @Published var error: String?
    
    /// Success state
    @Published var createdConversation: Conversation?
    
    // MARK: - Properties
    
    private let chatService: ChatService
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    nonisolated init(chatService: ChatService = ChatService()) {
        self.chatService = chatService
    }
    
    // MARK: - Participant Selection
    
    /// Toggle participant selection
    func toggleParticipant(_ userId: String) {
        if selectedParticipants.contains(userId) {
            selectedParticipants.remove(userId)
        } else {
            selectedParticipants.insert(userId)
        }
    }
    
    /// Check if participant is selected
    func isSelected(_ userId: String) -> Bool {
        selectedParticipants.contains(userId)
    }
    
    /// Get count of selected participants (including current user)
    var participantCount: Int {
        selectedParticipants.count + 1 // +1 for current user
    }
    
    /// Check if can create group (3-50 participants)
    var canCreateGroup: Bool {
        participantCount >= 3 && participantCount <= 50
    }
    
    /// Clear selection
    func clearSelection() {
        selectedParticipants.removeAll()
        groupName = ""
        error = nil
    }
    
    // MARK: - Group Creation
    
    /// Create a new group
    func createGroup() async {
        guard canCreateGroup else {
            error = "Groups must have 3-50 participants"
            return
        }
        
        isCreating = true
        error = nil
        
        do {
            // Create group using ChatService
            let conversation = try await chatService.createGroup(
                participants: Array(selectedParticipants),
                groupName: groupName.isEmpty ? nil : groupName
            )
            
            print("[GroupViewModel] ✅ Created group: \(conversation.id)")
            createdConversation = conversation
            
            // Clear state after success
            clearSelection()
            
        } catch {
            print("[GroupViewModel] ❌ Failed to create group: \(error)")
            self.error = "Failed to create group: \(error.localizedDescription)"
        }
        
        isCreating = false
    }
    
    // MARK: - Group Management
    
    /// Add participants to an existing group
    func addParticipants(to conversationId: String, userIds: [String]) async {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            error = "Not authenticated"
            return
        }
        
        isLoading = true
        error = nil
        
        do {
            try await chatService.addParticipants(
                to: conversationId,
                userIds: userIds,
                currentUserId: currentUserId
            )
            print("[GroupViewModel] ✅ Added participants")
        } catch {
            print("[GroupViewModel] ❌ Failed to add participants: \(error)")
            self.error = "Failed to add participants: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    /// Remove a participant from a group
    func removeParticipant(from conversationId: String, userId: String) async {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            error = "Not authenticated"
            return
        }
        
        isLoading = true
        error = nil
        
        do {
            try await chatService.removeParticipant(
                from: conversationId,
                userId: userId,
                currentUserId: currentUserId
            )
            print("[GroupViewModel] ✅ Removed participant")
        } catch {
            print("[GroupViewModel] ❌ Failed to remove participant: \(error)")
            self.error = "Failed to remove participant: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    /// Leave a group
    func leaveGroup(conversationId: String) async {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            error = "Not authenticated"
            return
        }
        
        isLoading = true
        error = nil
        
        do {
            try await chatService.leaveGroup(
                conversationId: conversationId,
                userId: currentUserId
            )
            print("[GroupViewModel] ✅ Left group")
        } catch {
            print("[GroupViewModel] ❌ Failed to leave group: \(error)")
            self.error = "Failed to leave group: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    /// Update group name
    func updateGroupName(conversationId: String, newName: String) async {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            error = "Not authenticated"
            return
        }
        
        isLoading = true
        error = nil
        
        do {
            try await chatService.updateGroupName(
                conversationId: conversationId,
                groupName: newName,
                currentUserId: currentUserId
            )
            print("[GroupViewModel] ✅ Updated group name")
        } catch {
            print("[GroupViewModel] ❌ Failed to update group name: \(error)")
            self.error = "Failed to update name: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    /// Update group photo
    func updateGroupPhoto(conversationId: String, photoURL: String) async {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            error = "Not authenticated"
            return
        }
        
        isLoading = true
        error = nil
        
        do {
            try await chatService.updateGroupPhoto(
                conversationId: conversationId,
                photoURL: photoURL,
                currentUserId: currentUserId
            )
            print("[GroupViewModel] ✅ Updated group photo")
        } catch {
            print("[GroupViewModel] ❌ Failed to update group photo: \(error)")
            self.error = "Failed to update photo: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    /// Promote participant to admin
    func promoteToAdmin(conversationId: String, userId: String) async {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            error = "Not authenticated"
            return
        }
        
        isLoading = true
        error = nil
        
        do {
            try await chatService.promoteToAdmin(
                conversationId: conversationId,
                userId: userId,
                currentUserId: currentUserId
            )
            print("[GroupViewModel] ✅ Promoted to admin")
        } catch {
            print("[GroupViewModel] ❌ Failed to promote: \(error)")
            self.error = "Failed to promote: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    /// Demote admin to participant
    func demoteFromAdmin(conversationId: String, userId: String) async {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            error = "Not authenticated"
            return
        }
        
        isLoading = true
        error = nil
        
        do {
            try await chatService.demoteFromAdmin(
                conversationId: conversationId,
                userId: userId,
                currentUserId: currentUserId
            )
            print("[GroupViewModel] ✅ Demoted from admin")
        } catch {
            print("[GroupViewModel] ❌ Failed to demote: \(error)")
            self.error = "Failed to demote: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
}

