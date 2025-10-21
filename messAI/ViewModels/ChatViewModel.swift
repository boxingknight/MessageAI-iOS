//
//  ChatViewModel.swift
//  messAI
//
//  Created for PR #9 - Chat View UI Components
//  State management for chat interface
//

import Foundation
import Combine
import FirebaseAuth

@MainActor
class ChatViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var messages: [Message] = []
    @Published var messageText: String = ""
    @Published var isLoading: Bool = false
    @Published var isTyping: Bool = false
    @Published var otherUserTyping: Bool = false
    @Published var errorMessage: String?
    @Published var showError: Bool = false
    
    // MARK: - Dependencies
    private let chatService: ChatService
    private let localDataManager: LocalDataManager
    let conversationId: String
    let currentUserId: String
    
    // MARK: - Computed Properties
    var canSendMessage: Bool {
        !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    // MARK: - Initialization
    init(
        conversationId: String,
        chatService: ChatService,
        localDataManager: LocalDataManager
    ) {
        self.conversationId = conversationId
        self.chatService = chatService
        self.localDataManager = localDataManager
        self.currentUserId = Auth.auth().currentUser?.uid ?? ""
    }
    
    // MARK: - Methods
    
    /// Load messages from local storage (Core Data)
    /// TODO (PR #10): Add Firestore real-time listener for new messages
    func loadMessages() async {
        isLoading = true
        
        do {
            // Load from local storage (Core Data) - instant!
            messages = try localDataManager.fetchMessages(
                conversationId: conversationId
            )
            
            print("📥 Loaded \(messages.count) messages from Core Data")
            isLoading = false
            
            // TODO (PR #10): Start Firestore real-time listener
            // This will add new messages as they arrive from other users
            
        } catch {
            print("❌ Error loading messages: \(error)")
            errorMessage = "Failed to load messages: \(error.localizedDescription)"
            showError = true
            isLoading = false
        }
    }
    
    /// Send a message (placeholder for PR #9)
    /// TODO (PR #10): Implement actual message sending to Firestore
    func sendMessage() {
        guard canSendMessage else { return }
        
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        messageText = "" // Clear input immediately (optimistic UI)
        
        // TODO (PR #10): Implement actual message sending
        print("📤 Sending message: \(text)")
        
        // PR #10 will add:
        // 1. Create optimistic Message object with status: .sending
        // 2. Append to messages array (UI updates instantly)
        // 3. Save to Core Data (isSynced: false)
        // 4. Upload to Firestore
        // 5. Update status on success (.sent) or failure (.failed)
    }
}

