//
//  ContactsViewModel.swift
//  messAI
//
//  Created by Isaac Jaramillo on October 21, 2025.
//  Purpose: Manages contact list state, search functionality, and conversation creation
//           for the contact picker interface (PR #8)
//

import Foundation
import Combine

@MainActor
class ContactsViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    /// All users fetched from Firestore (excluding current user)
    @Published var allUsers: [User] = []
    
    /// Current search query text
    @Published var searchQuery: String = ""
    
    /// Loading state indicator
    @Published var isLoading: Bool = false
    
    /// Error message to display
    @Published var errorMessage: String?
    
    /// Whether to show error alert
    @Published var showError: Bool = false
    
    // MARK: - Dependencies
    
    private let chatService: ChatService
    private let currentUserId: String
    
    // MARK: - Computed Properties
    
    /// Filtered users based on search query
    /// Searches both displayName and email (case-insensitive)
    var filteredUsers: [User] {
        if searchQuery.isEmpty {
            return allUsers
        }
        return allUsers.filter { user in
            user.displayName.localizedCaseInsensitiveContains(searchQuery) ||
            user.email.localizedCaseInsensitiveContains(searchQuery)
        }
    }
    
    /// Whether the contact list is empty (no users fetched)
    var isEmpty: Bool {
        allUsers.isEmpty && !isLoading
    }
    
    // MARK: - Initialization
    
    /// Initialize ContactsViewModel
    /// - Parameters:
    ///   - chatService: Service for Firestore operations
    ///   - currentUserId: Current user's ID (will be excluded from list)
    init(chatService: ChatService, currentUserId: String) {
        self.chatService = chatService
        self.currentUserId = currentUserId
        print("[ContactsViewModel] Initialized for user: \(currentUserId)")
    }
    
    // MARK: - Methods
    
    /// Load all users from Firestore (excluding current user)
    func loadUsers() async {
        isLoading = true
        errorMessage = nil
        
        do {
            allUsers = try await chatService.fetchAllUsers(
                excludingUserId: currentUserId
            )
            isLoading = false
            print("[ContactsViewModel] Loaded \(allUsers.count) users")
        } catch {
            errorMessage = "Failed to load contacts: \(error.localizedDescription)"
            showError = true
            isLoading = false
            print("[ContactsViewModel] Error loading users: \(error)")
        }
    }
    
    /// Start conversation with selected user
    /// Checks for existing conversation first, creates new if none exists
    /// - Parameter user: The user to start conversation with
    /// - Returns: Existing or newly created Conversation
    func startConversation(with user: User) async throws -> Conversation {
        print("[ContactsViewModel] Starting conversation with: \(user.displayName)")
        
        // Check for existing conversation first
        if let existing = try await chatService.findExistingConversation(
            participants: [currentUserId, user.id]
        ) {
            print("[ContactsViewModel] Found existing conversation: \(existing.id)")
            return existing
        }
        
        // Create new conversation if none exists
        print("[ContactsViewModel] Creating new conversation with: \(user.displayName)")
        let newConversation = try await chatService.createConversation(
            participants: [currentUserId, user.id],
            isGroup: false
        )
        
        print("[ContactsViewModel] Created conversation: \(newConversation.id)")
        return newConversation
    }
}

