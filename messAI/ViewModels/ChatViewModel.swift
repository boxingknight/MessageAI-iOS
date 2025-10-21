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
    
    // MARK: - Listener Management (PR #10)
    private var listenerTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    
    // Message ID mapping for deduplication (temp UUID → server ID)
    private var messageIdMap: [String: String] = [:]
    
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
    
    // Note: No deinit needed - Task is automatically cancelled when ChatViewModel is deallocated
    
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
            
            // Start Firestore real-time listener (PR #10)
            startRealtimeSync()
            
        } catch {
            print("❌ Error loading messages: \(error)")
            errorMessage = "Failed to load messages: \(error.localizedDescription)"
            showError = true
            isLoading = false
        }
    }
    
    /// Send a message with optimistic UI (PR #10)
    func sendMessage() {
        guard canSendMessage else { return }
        
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        messageText = "" // Clear input immediately (optimistic UI)
        
        // Step 1: Create optimistic message with temp ID
        let tempId = UUID().uuidString
        let optimisticMessage = Message(
            id: tempId,
            conversationId: conversationId,
            senderId: currentUserId,
            text: text,
            sentAt: Date(),
            status: .sending
        )
        
        // Step 2: Add to messages array immediately (UI updates instantly!)
        messages.append(optimisticMessage)
        print("📤 Optimistic message added: \(tempId)")
        
        // Step 3: Save to Core Data (not synced yet)
        do {
            try localDataManager.saveMessage(optimisticMessage, isSynced: false)
        } catch {
            print("⚠️ Failed to save optimistic message locally: \(error)")
        }
        
        // Step 4: Store ID mapping BEFORE upload (prevents race condition!)
        // This ensures the listener can deduplicate when it fires
        messageIdMap[tempId] = tempId // Maps to itself since ChatService will use same ID
        print("🗺️ ID mapping stored BEFORE upload: \(tempId) → \(tempId)")
        
        // Step 5: Upload to Firestore (async)
        Task {
            do {
                let serverMessage = try await chatService.sendMessage(
                    conversationId: conversationId,
                    text: text,
                    messageId: tempId // Pass our ID so ChatService uses it!
                )
                
                // Success! Message should now have .sent status
                print("✅ Message sent successfully with ID: \(serverMessage.id)")
                
                // The real-time listener will pick this up and deduplicate it!
                // Since we stored the mapping before upload, deduplication will work
                
            } catch {
                // Step 5b: Failure! Update status to .failed
                print("❌ Failed to send message: \(error)")
                
                if let index = messages.firstIndex(where: { $0.id == tempId }) {
                    messages[index].status = .failed
                    
                    // Update Core Data
                    do {
                        try localDataManager.updateMessageStatus(
                            id: tempId,
                            status: .failed
                        )
                    } catch {
                        print("⚠️ Failed to update message status in Core Data: \(error)")
                    }
                }
                
                // Show error to user
                errorMessage = "Failed to send message: \(error.localizedDescription)"
                showError = true
            }
        }
    }
    
    // MARK: - Real-Time Sync (PR #10)
    
    /// Start Firestore real-time listener for new messages
    func startRealtimeSync() {
        print("🎧 Starting real-time listener for conversation: \(conversationId)")
        
        listenerTask = Task {
            do {
                let messagesStream = try await chatService.fetchMessagesRealtime(
                    conversationId: conversationId
                )
                
                for try await firebaseMessages in messagesStream {
                    await handleFirestoreMessages(firebaseMessages)
                }
            } catch {
                print("❌ Real-time sync failed: \(error)")
                errorMessage = "Real-time sync failed: \(error.localizedDescription)"
                showError = true
            }
        }
    }
    
    /// Stop Firestore real-time listener
    func stopRealtimeSync() {
        print("🛑 Stopping real-time listener")
        listenerTask?.cancel()
        listenerTask = nil
    }
    
    /// Handle new messages from Firestore (deduplication logic)
    private func handleFirestoreMessages(_ firebaseMessages: [Message]) async {
        for firebaseMessage in firebaseMessages {
            // Check 1: Is this our optimistic message coming back from server?
            if let tempId = messageIdMap.first(where: { $0.value == firebaseMessage.id })?.key {
                print("🔄 Deduplicating: replacing temp ID \(tempId) with server ID \(firebaseMessage.id)")
                updateOptimisticMessage(tempId: tempId, serverMessage: firebaseMessage)
            }
            // Check 2: Does message already exist locally?
            else if let existingIndex = messages.firstIndex(where: { $0.id == firebaseMessage.id }) {
                print("🔄 Updating existing message: \(firebaseMessage.id)")
                messages[existingIndex] = firebaseMessage
                
                // Update Core Data
                do {
                    try localDataManager.updateMessageStatus(
                        id: firebaseMessage.id,
                        status: firebaseMessage.status
                    )
                } catch {
                    print("⚠️ Failed to update message in Core Data: \(error)")
                }
            }
            // Check 3: Brand new message from other user
            else {
                print("📨 New message received: \(firebaseMessage.id)")
                messages.append(firebaseMessage)
                
                // Save to Core Data
                do {
                    try localDataManager.saveMessage(firebaseMessage, isSynced: true)
                } catch {
                    print("⚠️ Failed to save message to Core Data: \(error)")
                }
            }
        }
        
        // Always sort by timestamp (Firestore doesn't guarantee order)
        messages.sort { $0.sentAt < $1.sentAt }
    }
    
    /// Update optimistic message with server data
    private func updateOptimisticMessage(tempId: String, serverMessage: Message) {
        guard let index = messages.firstIndex(where: { $0.id == tempId }) else {
            return
        }
        
        // Replace optimistic message with server version
        messages[index] = serverMessage
        
        // Update Core Data: replace temp ID with server ID
        Task {
            do {
                try localDataManager.replaceMessageId(
                    tempId: tempId,
                    serverId: serverMessage.id
                )
                try localDataManager.markMessageAsSynced(id: serverMessage.id)
                print("✅ Optimistic message updated: \(tempId) → \(serverMessage.id)")
            } catch {
                print("⚠️ Failed to update message in Core Data: \(error)")
            }
        }
        
        // Clean up mapping
        messageIdMap.removeValue(forKey: tempId)
    }
}

