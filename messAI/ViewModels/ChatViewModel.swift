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
    @Published var otherUserPresence: Presence?
    @Published var errorMessage: String?
    @Published var showError: Bool = false
    
    // Read Receipt State (PR #11 Fix): Track if chat is visible for real-time read receipts
    @Published var isChatVisible: Bool = false
    
    // MARK: - Dependencies
    private let chatService: ChatService
    private let localDataManager: LocalDataManager
    private let presenceService = PresenceService.shared
    private let typingService = TypingService.shared
    let conversationId: String
    let currentUserId: String
    var otherUserId: String?  // For 1-on-1 chats
    
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
        localDataManager: LocalDataManager,
        otherUserId: String? = nil
    ) {
        self.conversationId = conversationId
        self.chatService = chatService
        self.localDataManager = localDataManager
        self.currentUserId = Auth.auth().currentUser?.uid ?? ""
        self.otherUserId = otherUserId
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
            
            // Mark conversation as viewed (PR #11)
            await markConversationAsViewed()
            
            // Observe other user's presence (PR #12)
            observeOtherUserPresence()
            
            // Observe typing indicators (PR #12)
            observeTypingIndicators()
            
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
        
        // Stop typing indicator when message sent
        Task {
            try? await typingService.stopTyping(userId: currentUserId, conversationId: conversationId)
        }
        
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
        
        // Stop presence observer if active
        if let otherUserId = otherUserId {
            presenceService.stopObservingPresence(otherUserId)
        }
        
        // Stop typing observer
        typingService.stopObservingTyping(conversationId: conversationId)
        
        // Stop our own typing status
        Task {
            try? await typingService.stopTyping(userId: currentUserId, conversationId: conversationId)
        }
    }
    
    /// Observe other user's presence (for 1-on-1 chats)
    private func observeOtherUserPresence() {
        guard let otherUserId = otherUserId else {
            print("⚠️ No other user ID, skipping presence observer")
            return
        }
        
        print("👀 Starting presence observer for: \(otherUserId)")
        presenceService.observePresence(otherUserId)
        
        // Subscribe to presence updates
        presenceService.$userPresence
            .map { $0[otherUserId] }
            .assign(to: &$otherUserPresence)
    }
    
    /// Observe typing indicators for this conversation
    private func observeTypingIndicators() {
        print("👀 Starting typing observer for conversation: \(conversationId)")
        typingService.observeTyping(conversationId: conversationId, currentUserId: currentUserId)
        
        // Subscribe to typing updates
        typingService.$typingUsers
            .map { $0[self.conversationId]?.isEmpty == false }
            .assign(to: &$otherUserTyping)
    }
    
    /// Handle text input changes (trigger typing indicator)
    func handleTextChange() {
        // Only send typing indicator if text is non-empty
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            // Text cleared - stop typing
            Task {
                try? await typingService.stopTyping(userId: currentUserId, conversationId: conversationId)
            }
            return
        }
        
        // User is typing
        Task {
            try? await typingService.startTyping(userId: currentUserId, conversationId: conversationId)
        }
    }
    
    /// Handle new messages from Firestore (deduplication logic)
    private func handleFirestoreMessages(_ firebaseMessages: [Message]) async {
        print("🔄 [ChatViewModel] handleFirestoreMessages called with \(firebaseMessages.count) messages")
        print("   isChatVisible: \(isChatVisible)")
        
        var messagesToMarkAsDelivered: [String] = []
        var messagesToMarkAsRead: [String] = []
        
        for firebaseMessage in firebaseMessages {
            print("   Processing message: \(firebaseMessage.id)")
            print("   deliveredTo: \(firebaseMessage.deliveredTo)")
            print("   readBy: \(firebaseMessage.readBy)")
            print("   status: \(firebaseMessage.status)")
            
            // Check 1: Is this our optimistic message coming back from server?
            if let tempId = messageIdMap.first(where: { $0.value == firebaseMessage.id })?.key {
                print("🔄 Deduplicating: replacing temp ID \(tempId) with server ID \(firebaseMessage.id)")
                updateOptimisticMessage(tempId: tempId, serverMessage: firebaseMessage)
            }
            // Check 2: Does message already exist locally?
            else if let existingIndex = messages.firstIndex(where: { $0.id == firebaseMessage.id }) {
                print("🔄 Updating existing message: \(firebaseMessage.id)")
                print("   OLD deliveredTo: \(messages[existingIndex].deliveredTo)")
                print("   NEW deliveredTo: \(firebaseMessage.deliveredTo)")
                print("   OLD readBy: \(messages[existingIndex].readBy)")
                print("   NEW readBy: \(firebaseMessage.readBy)")
                
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
                
                // PR #11 Fix: WhatsApp-style delivery tracking
                if firebaseMessage.senderId != currentUserId {
                    // Step 1: ALWAYS mark as delivered (message arrived on device)
                    print("   📦 Message from other user - will mark as delivered")
                    messagesToMarkAsDelivered.append(firebaseMessage.id)
                    
                    // Step 2: ONLY mark as read if chat is currently visible
                    if isChatVisible {
                        print("   👁️ Chat is visible - will ALSO mark as read")
                        messagesToMarkAsRead.append(firebaseMessage.id)
                    }
                }
            }
        }
        
        // Always sort by timestamp (Firestore doesn't guarantee order)
        messages.sort { $0.sentAt < $1.sentAt }
        print("✅ [ChatViewModel] Finished processing, total messages: \(messages.count)")
        
        // PR #11 Fix: Mark new messages as delivered (device-level receipt)
        if !messagesToMarkAsDelivered.isEmpty {
            print("📦 [ChatViewModel] Marking \(messagesToMarkAsDelivered.count) messages as DELIVERED")
            await markNewMessagesAsDelivered(messageIds: messagesToMarkAsDelivered)
        }
        
        // PR #11 Fix: Mark new messages as read (only if chat was visible)
        if !messagesToMarkAsRead.isEmpty && isChatVisible {
            print("📖 [ChatViewModel] Marking \(messagesToMarkAsRead.count) messages as READ")
            await markNewMessagesAsRead(messageIds: messagesToMarkAsRead)
        }
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
    
    // MARK: - Status Tracking (PR #11)
    
    /// Mark conversation as viewed (marks messages as delivered and read)
    /// Called when chat first loads or user returns to it
    func markConversationAsViewed() async {
        do {
            // PR #11 Fix: Simplified to single call that marks both delivered + read
            // (markMessagesAsDelivered is now redundant as markAllMessagesAsRead does both)
            try await chatService.markAllMessagesAsRead(
                conversationId: conversationId,
                userId: currentUserId
            )
            
            print("✅ Conversation marked as viewed (delivered + read)")
            
        } catch {
            print("⚠️ Failed to mark conversation as viewed: \(error)")
            // Don't show error to user (non-critical operation)
        }
    }
    
    /// Mark specific new messages as delivered (device-level receipt)
    /// Called when messages arrive on device (even if chat is closed)
    private func markNewMessagesAsDelivered(messageIds: [String]) async {
        do {
            print("📦 [ChatViewModel] markNewMessagesAsDelivered called for \(messageIds.count) messages")
            
            // Mark as delivered (double gray checks)
            try await chatService.markSpecificMessagesAsDelivered(
                conversationId: conversationId,
                messageIds: messageIds,
                userId: currentUserId
            )
            
            print("✅ [ChatViewModel] Marked \(messageIds.count) messages as delivered")
            
        } catch {
            print("⚠️ [ChatViewModel] Failed to mark messages as delivered: \(error)")
            // Don't show error to user (non-critical operation)
        }
    }
    
    /// Mark specific new messages as read (chat-level receipt)
    /// Called when messages arrive while chat is visible
    private func markNewMessagesAsRead(messageIds: [String]) async {
        do {
            print("📖 [ChatViewModel] markNewMessagesAsRead called for \(messageIds.count) messages")
            
            // Mark as read (blue checks)
            try await chatService.markSpecificMessagesAsRead(
                conversationId: conversationId,
                messageIds: messageIds,
                userId: currentUserId
            )
            
            print("✅ [ChatViewModel] Marked \(messageIds.count) messages as read")
            
        } catch {
            print("⚠️ [ChatViewModel] Failed to mark messages as read: \(error)")
            // Don't show error to user (non-critical operation)
        }
    }
    
    // MARK: - Calendar Extraction (PR #15)
    
    @Published var isExtractingCalendar = false
    @Published var calendarExtractionError: String?
    
    /// Extract calendar events from a message using AI
    func extractCalendarEvents(from message: Message) async {
        guard !isExtractingCalendar else { return }
        
        isExtractingCalendar = true
        calendarExtractionError = nil
        
        do {
            print("📅 Extracting calendar events from message: \(message.id)")
            
            // Call AI service to extract calendar events
            let events = try await AIService.shared.extractCalendarEvents(from: message.text)
            
            if events.isEmpty {
                print("⚠️ No calendar events found in message")
                calendarExtractionError = "No calendar events detected in this message."
                isExtractingCalendar = false
                return
            }
            
            print("✅ Extracted \(events.count) calendar events")
            
            // Update message with extracted events
            await updateMessageWithCalendarEvents(message: message, events: events)
            
            isExtractingCalendar = false
            
        } catch {
            print("❌ Calendar extraction failed: \(error)")
            calendarExtractionError = error.localizedDescription
            isExtractingCalendar = false
        }
    }
    
    /// Update message with extracted calendar events
    private func updateMessageWithCalendarEvents(message: Message, events: [CalendarEvent]) async {
        do {
            // Create or update AI metadata
            var aiMetadata = message.aiMetadata ?? AIMetadata()
            aiMetadata.calendarEvents = events
            
            // Update message in Firestore
            try await chatService.updateMessageAIMetadata(
                conversationId: conversationId,
                messageId: message.id,
                aiMetadata: aiMetadata
            )
            
            // Update local message
            if let index = messages.firstIndex(where: { $0.id == message.id }) {
                var updatedMessage = messages[index]
                updatedMessage.aiMetadata = aiMetadata
                messages[index] = updatedMessage
                
                // Save to local storage
                try? localDataManager.saveMessage(updatedMessage)
            }
            
            print("✅ Updated message with calendar events")
            
        } catch {
            print("❌ Failed to update message with calendar events: \(error)")
            calendarExtractionError = "Failed to save calendar events: \(error.localizedDescription)"
        }
    }
    
    /// Add calendar event to iOS Calendar
    func addEventToCalendar(_ event: CalendarEvent) async -> Bool {
        do {
            let eventId = try await CalendarManager.shared.addEvent(event)
            print("✅ Added event to calendar: \(eventId)")
            return true
        } catch {
            print("❌ Failed to add event to calendar: \(error)")
            calendarExtractionError = error.localizedDescription
            return false
        }
    }
    
    // MARK: - Decision Summarization (PR #16)
    
    @Published var conversationSummary: ConversationSummary?
    @Published var isSummarizing = false
    @Published var summarizationError: String?
    @Published var showSummary = false
    
    /// Request AI summary of the conversation
    /// Analyzes last 50 messages and extracts decisions, action items, and key points
    func requestSummary() async {
        guard !isSummarizing else {
            print("⚠️ Already summarizing, ignoring duplicate request")
            return
        }
        
        isSummarizing = true
        summarizationError = nil
        
        do {
            print("📝 Requesting conversation summary for: \(conversationId)")
            
            // Call AI service to generate summary
            let summary = try await AIService.shared.summarizeConversation(conversationId: conversationId)
            
            // Update state
            conversationSummary = summary
            showSummary = true
            
            print("✅ Summary generated successfully:")
            print("   - Overview: \(summary.overview)")
            print("   - Decisions: \(summary.decisions.count)")
            print("   - Action Items: \(summary.actionItems.count)")
            print("   - Key Points: \(summary.keyPoints.count)")
            
            isSummarizing = false
            
        } catch let error as AIError {
            print("❌ Summarization failed: \(error.localizedDescription)")
            summarizationError = error.localizedDescription
            isSummarizing = false
        } catch {
            print("❌ Summarization failed: \(error)")
            summarizationError = "Failed to generate summary. Please try again."
            isSummarizing = false
        }
    }
    
    /// Dismiss the summary card
    func dismissSummary() {
        print("🗑️ Dismissing summary card")
        showSummary = false
        conversationSummary = nil
        summarizationError = nil
    }
}

