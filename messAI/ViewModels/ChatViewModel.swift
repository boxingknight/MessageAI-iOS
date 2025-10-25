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
import FirebaseFirestore
import EventKit

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
    
    // Cleanup when view model is destroyed
    deinit {
        // Clean up RSVP listeners
        for (_, listener) in rsvpListeners {
            listener.remove()
        }
        print("🧹 ChatViewModel deinitialized - cleaned up \(rsvpListeners.count) RSVP listeners")
        
        // Clean up deadline listener
        deadlineListener?.remove()
        print("🧹 ChatViewModel deinitialized - cleaned up deadline listener")
        
        // Stop proactive monitoring (PR #20.1)
        Task { @MainActor in
            stopProactiveMonitoring()
        }
        print("🧹 ChatViewModel deinitialized - stopped proactive monitoring")
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
            
            // Start Firestore real-time listener (PR #10)
            startRealtimeSync()
            
            // PR#20.2 Phase 6: Start event count listener
            startEventCountListener()
            
            // Mark conversation as viewed (PR #11)
            await markConversationAsViewed()
            
            // Observe other user's presence (PR #12)
            observeOtherUserPresence()
            
            // Observe typing indicators (PR #12)
            observeTypingIndicators()
            
            // Start proactive AI monitoring (PR #20.1)
            startProactiveMonitoring()
            
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
                
                // PR #17: Priority detection now handled server-side via Firestore trigger
                // This prevents race conditions where multiple users detect priority for the same message
                // The aiMetadata.priorityLevel will be automatically updated by the Cloud Function
                
                // PR #18: Automatically track RSVP for new messages (async, non-blocking)
                // Only detects RSVPs (yes/no/maybe responses), doesn't trigger on all messages
                Task {
                    await trackMessageRSVP(for: firebaseMessage.id, message: firebaseMessage)
                }
                
                // PR #19: Automatically extract deadlines from new messages (async, non-blocking)
                // TEMP FIX: Extract for ALL messages (testing/solo use)
                // TODO: Re-enable sender-only policy for production group chats
                // Detects dates, times, and deadline-related keywords in message text
                print("🚨 DEADLINE: 📨 Message received: '\(firebaseMessage.text)'")
                
                Task {
                    await extractDeadlineFromMessage(
                        messageId: firebaseMessage.id,
                        messageText: firebaseMessage.text,
                        senderId: firebaseMessage.senderId,
                        senderName: firebaseMessage.senderName ?? "Unknown User"
                    )
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
            
            print("✅ Extracted \(events.count) calendar event(s)")
            
            // Update message with extracted events
            await updateMessageWithCalendarEvents(message: message, events: events)
            
            isExtractingCalendar = false
            
        } catch {
            print("❌ Calendar extraction failed: \(error.localizedDescription)")
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
            
            // PR#18 Fix: Create event documents in Firestore
            for event in events {
                await createEventDocument(from: event, message: message)
            }
            
        } catch {
            print("❌ Failed to update message with calendar events: \(error)")
            calendarExtractionError = "Failed to save calendar events: \(error.localizedDescription)"
        }
    }
    
    /// Fetch conversation participants from Firestore
    /// Used when creating event documents to include all members
    /// Handles both 'participantIds' (new) and 'participants' (legacy) field names
    private func fetchParticipants(_ conversationId: String) async throws -> [String] {
        let doc = try await Firestore.firestore()
            .collection("conversations")
            .document(conversationId)
            .getDocument()
        
        guard doc.exists, let data = doc.data() else {
            print("❌ Conversation not found: \(conversationId)")
            throw NSError(domain: "ChatViewModel", code: 404, userInfo: [
                NSLocalizedDescriptionKey: "Conversation not found"
            ])
        }
        
        // Try new field name first
        if let participantIds = data["participantIds"] as? [String] {
            print("✅ Fetched \(participantIds.count) participants")
            return participantIds
        }
        
        // Fallback to legacy field name
        if let participants = data["participants"] as? [String] {
            print("✅ Fetched \(participants.count) participants (legacy field)")
            return participants
        }
        
        print("❌ No participant list found in conversation")
        throw NSError(domain: "ChatViewModel", code: 400, userInfo: [
            NSLocalizedDescriptionKey: "Conversation missing participant data"
        ])
    }
    
    /// Fetch sender's display name from Firestore (fallback if message.senderName is nil)
    /// Returns the sender's name or "Unknown" if not found
    private func fetchSenderName(for message: Message) async -> String {
        // If message already has senderName, use it
        if let senderName = message.senderName, !senderName.isEmpty {
            return senderName
        }
        
        // Otherwise, fetch from Firestore users collection
        do {
            let userDoc = try await Firestore.firestore()
                .collection("users")
                .document(message.senderId)
                .getDocument()
            
            guard let data = userDoc.data() else {
                print("⚠️ User document not found for: \(message.senderId)")
                return "Unknown"
            }
            
            // Try common display name fields
            if let displayName = data["displayName"] as? String, !displayName.isEmpty {
                return displayName
            }
            if let name = data["name"] as? String, !name.isEmpty {
                return name
            }
            if let firstName = data["firstName"] as? String, !firstName.isEmpty {
                return firstName
            }
            
            print("⚠️ No display name found in user document")
            return "Unknown"
            
        } catch {
            print("❌ Failed to fetch sender name: \(error.localizedDescription)")
            return "Unknown"
        }
    }
    
    /// Create Firestore event document from CalendarEvent (PR#18 Fix)
    /// Enables RSVP subcollections to properly nest under /events/{eventId}
    private func createEventDocument(from event: CalendarEvent, message: Message) async {
        print("📅 Creating event document: \(event.title)")
        
        do {
            // Fetch participants
            let participantIds = try await fetchParticipants(conversationId)
            
            // Fetch organizer name (with fallback if nil)
            let organizerName = await fetchSenderName(for: message)
            
            // Create EventDocument with organizer info
            let eventDoc = EventDocument(
                from: event,
                conversationId: conversationId,
                createdBy: currentUserId,
                sourceMessageId: message.id,
                participantIds: participantIds,
                organizerId: message.senderId,
                organizerName: organizerName
            )
            
            // Write to Firestore
            try await Firestore.firestore()
                .collection("events")
                .document(event.id)
                .setData(eventDoc.toDictionary())
            
            print("✅ Event created: /events/\(event.id)")
            print("   Organizer: \(organizerName) (\(participantIds.count) participants)")
            
            // Auto-create organizer RSVP
            await createOrganizerRSVP(
                eventId: event.id,
                organizerId: message.senderId,
                organizerName: organizerName,
                messageId: message.id
            )
            
        } catch let error as NSError {
            print("❌ Failed to create event document: \(error.localizedDescription)")
            
            // Log detailed error info for debugging
            if error.domain == "FIRFirestoreErrorDomain" {
                switch error.code {
                case 7:
                    print("   🔒 Permission denied - check Firestore security rules")
                case 3:
                    print("   ⚠️ Invalid argument - check document field types")
                case 5:
                    print("   ⚠️ Not found - check document path")
                default:
                    print("   Error code: \(error.code)")
                }
            }
        }
    }
    
    /// Auto-create RSVP for event organizer (PR#18 Enhancement)
    /// Called when event document is created to ensure organizer is included in tracking
    private func createOrganizerRSVP(
        eventId: String,
        organizerId: String,
        organizerName: String,
        messageId: String
    ) async {
        do {
            let organizerRSVP: [String: Any] = [
                "userId": organizerId,
                "userName": organizerName,
                "status": RSVPStatus.organizer.rawValue,
                "isOrganizer": true,
                "respondedAt": Timestamp(date: Date()),
                "messageId": messageId
            ]
            
            // Use merge: true to avoid overwriting if organizer already RSVP'd
            try await Firestore.firestore()
                .collection("events")
                .document(eventId)
                .collection("rsvps")
                .document(organizerId)
                .setData(organizerRSVP, merge: true)
            
            print("✅ Organizer RSVP created: \(organizerName)")
            
        } catch {
            print("❌ Failed to create organizer RSVP: \(error.localizedDescription)")
            // Non-fatal: event still works, just missing organizer RSVP
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
    
    // MARK: - RSVP Tracking (PR #18)
    
    /// RSVP data for each event (eventId → RSVPData)
    @Published var eventRSVPs: [String: RSVPData] = [:]
    
    /// Firestore listeners for real-time RSVP updates (eventId → ListenerRegistration)
    private var rsvpListeners: [String: ListenerRegistration] = [:]
    
    /// Stores RSVP summary and participants for an event
    struct RSVPData {
        var summary: RSVPSummary
        var participants: [RSVPParticipant]
    }
    
    // MARK: - Deadline Tracking (PR #19)
    
    /// Active deadlines for this conversation
    @Published var conversationDeadlines: [Deadline] = []
    
    /// Firestore listener for real-time deadline updates
    private var deadlineListener: ListenerRegistration?
    
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
    
    // MARK: - RSVP Fetching (PR #18)
    
    /// Set up real-time listener for RSVP updates
    func loadRSVPsForEvent(_ eventId: String) async {
        // Skip if already listening
        if rsvpListeners[eventId] != nil {
            return
        }
        
        print("📋 Setting up real-time RSVP listener for event: \(eventId)")
        
        // Set up real-time listener
        let listener = Firestore.firestore()
            .collection("events")
            .document(eventId)
            .collection("rsvps")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ RSVP listener error: \(error.localizedDescription)")
                    return
                }
                
                guard let snapshot = snapshot else {
                    print("⚠️ RSVP snapshot is nil")
                    return
                }
                
                print("🔄 RSVP update received for event: \(eventId) - \(snapshot.documents.count) RSVPs")
                
                var participants: [RSVPParticipant] = []
                var statusCounts: [RSVPStatus: Int] = [:]
                
                for doc in snapshot.documents {
                    let data = doc.data()
                    
                    guard let userId = data["userId"] as? String,
                          let userName = data["userName"] as? String,
                          let statusRaw = data["status"] as? String,
                          let status = RSVPStatus(rawValue: statusRaw) else {
                        continue
                    }
                    
                    let isOrganizer = data["isOrganizer"] as? Bool ?? false
                    
                    // Create participant
                    let participant = RSVPParticipant(
                        id: userId,
                        name: userName,
                        status: status,
                        respondedAt: (data["respondedAt"] as? Timestamp)?.dateValue(),
                        messageId: data["messageId"] as? String,
                        isOrganizer: isOrganizer
                    )
                    
                    participants.append(participant)
                    statusCounts[status, default: 0] += 1
                }
                
                // Build summary
                let summary = RSVPSummary(
                    eventId: eventId,
                    totalParticipants: participants.count,
                    organizerCount: statusCounts[.organizer] ?? 0,
                    yesCount: statusCounts[.yes] ?? 0,
                    noCount: statusCounts[.no] ?? 0,
                    maybeCount: statusCounts[.maybe] ?? 0,
                    pendingCount: statusCounts[.pending] ?? 0
                )
                
                // Update state on main thread
                Task { @MainActor in
                    self.eventRSVPs[eventId] = RSVPData(
                        summary: summary,
                        participants: participants.sorted { $0.status.sortOrder < $1.status.sortOrder }
                    )
                    print("✅ Updated RSVPs for event: \(eventId) - \(summary.summaryText)")
                }
            }
        
        // Store listener for cleanup
        rsvpListeners[eventId] = listener
    }
    
    /// Remove all RSVP listeners (called on cleanup)
    func cleanupRSVPListeners() {
        print("🧹 Cleaning up \(rsvpListeners.count) RSVP listeners")
        for (eventId, listener) in rsvpListeners {
            listener.remove()
            print("   - Removed listener for event: \(eventId)")
        }
        rsvpListeners.removeAll()
        eventRSVPs.removeAll()
    }
    
    // MARK: - Deadline Tracking (PR #19)
    
    /// Load deadlines for this conversation with real-time updates
    func loadDeadlines() async {
        print("📋 Setting up real-time deadline listener for conversation: \(conversationId)")
        
        // Set up real-time listener
        deadlineListener = Firestore.firestore()
            .collection("conversations")
            .document(conversationId)
            .collection("deadlines")
            .whereField("status", isEqualTo: "active")
            .order(by: "dueDate", descending: false)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("🚨 DEADLINE: ❌ Listener error: \(error.localizedDescription)")
                    return
                }
                
                guard let snapshot = snapshot else {
                    print("🚨 DEADLINE: ⚠️ Snapshot is nil")
                    return
                }
                
                print("🚨 DEADLINE: 🔄 Update received - \(snapshot.documents.count) documents from Firestore")
                
                var deadlines: [Deadline] = []
                
                for doc in snapshot.documents {
                    print("🚨 DEADLINE: 📄 Parsing document \(doc.documentID)")
                    print("🚨 DEADLINE:    Raw data: \(doc.data())")
                    
                    if let deadline = Deadline.fromFirestore(doc.data(), id: doc.documentID) {
                        deadlines.append(deadline)
                        print("🚨 DEADLINE:    ✅ Parsed: \(deadline.title) - Due: \(deadline.dueDate)")
                    } else {
                        print("🚨 DEADLINE:    ❌ Failed to parse document")
                    }
                }
                
                // Update state on main thread
                Task { @MainActor in
                    self.conversationDeadlines = deadlines
                    print("🚨 DEADLINE: ✅ Updated UI state - \(deadlines.count) active deadlines")
                    print("🚨 DEADLINE:    Array contents: \(deadlines.map { $0.title })")
                }
            }
    }
    
    /// Extract deadline from a message (called automatically when new messages arrive)
    @discardableResult
    func extractDeadlineFromMessage(
        messageId: String,
        messageText: String,
        senderId: String,
        senderName: String
    ) async -> DeadlineDetection? {
        print("🚨 DEADLINE: Extracting deadline from message: \(messageId)")
        
        do {
            // Call AI service to extract deadline
            let deadlineDetection = try await AIService.shared.extractDeadline(
                messageText: messageText,
                messageId: messageId,
                senderId: senderId,
                senderName: senderName,
                conversationId: conversationId,
                storeInFirestore: true
            )
            
            if let deadlineDetection = deadlineDetection {
                print("🚨 DEADLINE: ✅ Extracted: \(deadlineDetection.title)")
                print("🚨 DEADLINE:    - Due: \(deadlineDetection.dueDate)")
                print("🚨 DEADLINE:    - Priority: \(deadlineDetection.priority)")
                print("🚨 DEADLINE:    - Confidence: \(String(format: "%.2f", deadlineDetection.confidence))")
                
                // Update message's AIMetadata in Firestore
                await updateMessageDeadline(messageId: messageId, detection: deadlineDetection)
                
                // Update local message object
                if let index = messages.firstIndex(where: { $0.id == messageId }) {
                    var updatedMessage = messages[index]
                    
                    // Create or update AIMetadata
                    if updatedMessage.aiMetadata == nil {
                        updatedMessage.aiMetadata = AIMetadata()
                    }
                    
                    updatedMessage.aiMetadata?.deadlineDetection = deadlineDetection
                    updatedMessage.aiMetadata?.hasDeadline = true
                    
                    messages[index] = updatedMessage
                    
                    print("🚨 DEADLINE: ✅ Updated local message with deadline detection")
                }
                
                return deadlineDetection
            } else {
                print("🚨 DEADLINE: ℹ️ No deadline detected in message")
                return nil
            }
            
        } catch let error as AIError {
            print("🚨 DEADLINE: ❌ Extraction failed: \(error.localizedDescription)")
            return nil
        } catch {
            print("🚨 DEADLINE: ❌ Extraction failed: \(error)")
            return nil
        }
    }
    
    /// Update message's AIMetadata with deadline detection in Firestore
    private func updateMessageDeadline(messageId: String, detection: DeadlineDetection) async {
        do {
            let messageRef = Firestore.firestore()
                .collection("conversations")
                .document(conversationId)
                .collection("messages")
                .document(messageId)
            
            // Convert dates to ISO8601 strings for aiMetadata (not Firestore Timestamps)
            // Firestore Timestamps can't be JSON-serialized and will crash Message.init
            let iso8601Formatter = ISO8601DateFormatter()
            let dueDateString = iso8601Formatter.string(from: detection.dueDate)
            let processedAtString = iso8601Formatter.string(from: Date())
            
            try await messageRef.updateData([
                "aiMetadata.deadlineDetection": [
                    "deadlineId": detection.deadlineId as Any,
                    "title": detection.title,
                    "dueDate": dueDateString,  // ISO8601 string, not Firestore Timestamp
                    "isAllDay": detection.isAllDay,
                    "priority": detection.priority,
                    "confidence": detection.confidence,
                    "method": detection.method,
                    "reasoning": detection.reasoning as Any
                ],
                "aiMetadata.hasDeadline": true,
                "aiMetadata.processedAt": processedAtString  // ISO8601 string, not Firestore Timestamp
            ])
            
            // print("✅ Updated message AIMetadata with deadline in Firestore")
            
        } catch {
            print("🚨 DEADLINE: ❌ Failed to update message AIMetadata: \(error)")
        }
    }
    
    /// Mark deadline as completed
    func completeDeadline(_ deadline: Deadline) async {
        print("🚨 DEADLINE: ✅ Completing deadline: \(deadline.title)")
        
        do {
            try await AIService.shared.completeDeadline(
                conversationId: conversationId,
                deadlineId: deadline.id,
                userId: currentUserId
            )
            
            print("🚨 DEADLINE: ✅ Marked as completed")
            
        } catch {
            print("🚨 DEADLINE: ❌ Failed to complete deadline: \(error)")
        }
    }
    
    // MARK: - Priority Highlighting (PR #17)
    
    /// Detect priority level for a message (MANUAL CALLS ONLY - auto-detection moved to server-side)
    /// Priority is now automatically handled via Firestore trigger to prevent race conditions
    /// Updates the message's AIMetadata with priority information
    @discardableResult
    func detectMessagePriority(for messageId: String, messageText: String) async -> PriorityDetectionResult? {
        // print("🎯 Detecting priority for message: \(messageId)")
        
        do {
            // Call AI service to detect priority
            let result = try await AIService.shared.detectPriority(
                messageText: messageText,
                conversationId: conversationId
            )
            
            // print("✅ Priority detected: \(result.level.rawValue)")
            // print("   - Confidence: \(String(format: "%.2f", result.confidence))")
            // print("   - Method: \(result.method.rawValue)")
            // print("   - Used GPT-4: \(result.usedGPT4)")
            
            // Update message's AIMetadata in Firestore
            await updateMessagePriority(messageId: messageId, result: result)
            
            // Update local message object
            if let index = messages.firstIndex(where: { $0.id == messageId }) {
                var updatedMessage = messages[index]
                
                // Create or update AIMetadata
                if updatedMessage.aiMetadata == nil {
                    updatedMessage.aiMetadata = AIMetadata()
                }
                
                updatedMessage.aiMetadata?.priorityLevel = result.level
                updatedMessage.aiMetadata?.priorityConfidence = result.confidence
                updatedMessage.aiMetadata?.priorityMethod = result.method.rawValue
                updatedMessage.aiMetadata?.priorityKeywords = result.keywords
                updatedMessage.aiMetadata?.priorityReasoning = result.reasoning
                
                messages[index] = updatedMessage
                
                // print("✅ Updated local message with priority: \(result.level.rawValue)")
            }
            
            return result
            
        } catch {
            // Silenced: Priority detection failed
            return nil
        }
    }
    
    /// Update message priority in Firestore
    private func updateMessagePriority(messageId: String, result: PriorityDetectionResult) async {
        do {
            // Update aiMetadata field in Firestore
            let aiMetadata: [String: Any] = [
                "priorityLevel": result.level.rawValue,
                "priorityConfidence": result.confidence,
                "priorityMethod": result.method.rawValue,
                "priorityKeywords": result.keywords ?? [],
                "priorityReasoning": result.reasoning
            ]
            
            // Directly update Firestore document
            try await Firestore.firestore()
                .collection("conversations")
                .document(conversationId)
                .collection("messages")
                .document(messageId)
                .updateData(["aiMetadata": aiMetadata])
            
            // print("✅ Updated Firestore with priority metadata")
            
        } catch {
            // print("❌ Failed to update message priority in Firestore: \(error)")
        }
    }
    
    // MARK: - RSVP Tracking (PR #18)
    
    /// Track RSVP responses in a message (called automatically on new messages)
    /// Updates the message's AIMetadata with RSVP information if detected
    @discardableResult
    func trackMessageRSVP(for messageId: String, message: Message) async -> RSVPResponse? {
        print("🎯 Tracking RSVP for message: \(messageId)")
        
        // Get sender info
        let senderId = message.senderId
        let senderName = message.senderName ?? "Unknown"
        
        // Get recent event IDs from messages with calendar events (last 5)
        let recentEventIds = messages
            .compactMap { $0.aiMetadata?.calendarEvents }
            .flatMap { $0 }
            .suffix(5)
            .map { $0.id }
        
        do {
            // Call AI service to track RSVP
            let result = try await AIService.shared.trackRSVP(
                messageText: message.text,
                messageId: messageId,
                senderId: senderId,
                senderName: senderName,
                conversationId: conversationId,
                recentEventIds: Array(recentEventIds)
            )
            
            // If no RSVP detected, return nil
            guard let rsvp = result else {
                print("✅ No RSVP detected in message")
                return nil
            }
            
            print("✅ RSVP detected: \(rsvp.status.rawValue)")
            print("   - Confidence: \(String(format: "%.2f", rsvp.confidence))")
            print("   - Event ID: \(rsvp.eventId ?? "none")")
            print("   - Method: \(rsvp.method.rawValue)")
            
            // Update message's AIMetadata in Firestore
            await updateMessageRSVP(messageId: messageId, rsvp: rsvp)
            
            // Update local message object
            if let index = messages.firstIndex(where: { $0.id == messageId }) {
                var updatedMessage = messages[index]
                
                // Create or update AIMetadata
                if updatedMessage.aiMetadata == nil {
                    updatedMessage.aiMetadata = AIMetadata()
                }
                
                updatedMessage.aiMetadata?.rsvpResponse = rsvp
                updatedMessage.aiMetadata?.rsvpStatus = rsvp.status
                updatedMessage.aiMetadata?.rsvpEventId = rsvp.eventId
                updatedMessage.aiMetadata?.rsvpConfidence = rsvp.confidence
                updatedMessage.aiMetadata?.rsvpMethod = rsvp.method.rawValue
                updatedMessage.aiMetadata?.rsvpReasoning = rsvp.reasoning
                
                messages[index] = updatedMessage
                
                print("✅ Updated local message with RSVP: \(rsvp.status.rawValue)")
            }
            
            // If linked to an event, update event RSVP tracking in Firestore
            if let eventId = rsvp.eventId {
                print("🔄 Attempting to update event RSVP for eventId: \(eventId)")
                await updateEventRSVP(
                    eventId: eventId,
                    userId: senderId,
                    userName: senderName,
                    status: rsvp.status,
                    messageId: messageId
                )
            } else {
                print("⚠️ No eventId found in RSVP, skipping event RSVP tracking")
            }
            
            return rsvp
            
        } catch let error as AIError {
            print("❌ RSVP tracking failed: \(error.localizedDescription)")
            return nil
        } catch {
            print("❌ RSVP tracking failed: \(error)")
            return nil
        }
    }
    
    /// Update message RSVP metadata in Firestore
    private func updateMessageRSVP(messageId: String, rsvp: RSVPResponse) async {
        do {
            // Update aiMetadata field in Firestore
            var aiMetadata: [String: Any] = [
                "rsvpStatus": rsvp.status.rawValue,
                "rsvpConfidence": rsvp.confidence,
                "rsvpMethod": rsvp.method.rawValue
            ]
            
            if let eventId = rsvp.eventId {
                aiMetadata["rsvpEventId"] = eventId
            }
            
            if let reasoning = rsvp.reasoning {
                aiMetadata["rsvpReasoning"] = reasoning
            }
            
            // Directly update Firestore document
            try await Firestore.firestore()
                .collection("conversations")
                .document(conversationId)
                .collection("messages")
                .document(messageId)
                .updateData(["aiMetadata": aiMetadata])
            
            print("✅ Updated Firestore with RSVP metadata")
            
        } catch {
            print("❌ Failed to update message RSVP in Firestore: \(error)")
        }
    }
    
    /// Update event RSVP tracking in Firestore (subcollection pattern)
    /// Stores RSVP in /events/{eventId}/rsvps/{userId} for scalability
    private func updateEventRSVP(
        eventId: String,
        userId: String,
        userName: String,
        status: RSVPStatus,
        messageId: String
    ) async {
        do {
            let rsvpData: [String: Any] = [
                "userId": userId,
                "userName": userName,
                "status": status.rawValue,
                "respondedAt": Timestamp(date: Date()),
                "messageId": messageId
            ]
            
            // Store RSVP in subcollection
            try await Firestore.firestore()
                .collection("events")
                .document(eventId)
                .collection("rsvps")
                .document(userId)
                .setData(rsvpData, merge: true)
            
            print("✅ Updated event RSVP tracking: \(eventId) → \(status.rawValue)")
            
        } catch {
            print("❌ Failed to update event RSVP: \(error)")
        }
    }
    
    // MARK: - Proactive Agent (PR #20.1)
    
    // Multiple opportunities - vertical stacking
    @Published var activeOpportunities: [Opportunity] = []
    @Published var showAmbientBar: Bool = false
    @Published var inlineChips: [String: Opportunity] = [:] // messageId -> opportunity
    @Published var pendingSuggestions: [Opportunity] = []
    @Published var suggestionsCount: Int = 0
    @Published var agentIsProcessing: Bool = false
    
    // PR#20.2 Phase 6: Event count for badge
    @Published var activeEventCount: Int = 0
    @Published var agentError: String?
    
    // Collapsed/Expanded state for each opportunity (opportunityId -> isCollapsed)
    @Published var opportunityCollapsedStates: [String: Bool] = [:]
    
    // Maximum number of stacked opportunities to show (prevents UI overflow)
    private let maxStackedOpportunities = 5
    
    private var opportunityListener: AnyCancellable?
    private var eventListener: ListenerRegistration?
    
    /**
     * Start proactive monitoring for this conversation
     * Called when chat view appears
     */
    func startProactiveMonitoring() {
        print("🤖 ChatViewModel: Starting proactive monitoring for conversation: \(conversationId)")

        // Start monitoring service
        ProactiveAgentService.shared.startMonitoring(conversationId: conversationId)

        // Subscribe to opportunities
        opportunityListener = ProactiveAgentService.shared.$currentOpportunities
            .sink { [weak self] opportunities in
                print("🎯 OpportunityListener: Received \(opportunities.count) opportunities from service")
                guard let self = self else { return }

                // Spawn structured task to handle async detection
                Task { @MainActor in
                    await self.handleOpportunitiesDetected(opportunities)
                }
            }
        
        // Listen for new events in this conversation (for RSVP opportunities)
        startEventListener()
    }
    
    /**
     * Stop proactive monitoring
     * Called when chat view disappears
     */
    func stopProactiveMonitoring() {
        print("🤖 ChatViewModel: Stopping proactive monitoring")

        ProactiveAgentService.shared.stopMonitoring()
        opportunityListener?.cancel()
        opportunityListener = nil
        
        // Stop event listener
        eventListener?.remove()
        eventListener = nil

        // Clear state
        activeOpportunities = []
        showAmbientBar = false
        inlineChips = [:]
        pendingSuggestions = []
        suggestionsCount = 0
    }
    
    /**
     * Start listening for new events in this conversation
     * When a new event is created, show RSVP Ambient Bar to receivers
     */
    private func startEventListener() {
        let db = Firestore.firestore()
        
        // Listen for events created in this conversation
        eventListener = db.collection("events")
            .whereField("conversationId", isEqualTo: conversationId)
            .order(by: "createdAt", descending: true)
            .limit(to: 1)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ Event listener error: \(error.localizedDescription)")
                    return
                }
                
                guard let documents = snapshot?.documents, !documents.isEmpty else {
                    return
                }
                
                Task { @MainActor in
                    for document in documents {
                        let data = document.data()
                        guard let createdBy = data["createdBy"] as? String else { continue }
                        
                        // Only show RSVP Ambient Bar to receivers (not the creator)
                        if createdBy != self.currentUserId {
                            print("📅 New event detected! Creating RSVP opportunity for receiver")
                            self.createRSVPOpportunity(from: data, eventId: document.documentID)
                        }
                    }
                }
            }
        
        print("🎧 Event listener started for conversation: \(conversationId)")
    }
    
    /**
     * Create an RSVP opportunity from a new event
     * Checks if user already responded - if yes, shows collapsed bar with their status
     * If no, shows full RSVP prompt
     */
    private func createRSVPOpportunity(from eventData: [String: Any], eventId: String) {
        let title = eventData["title"] as? String ?? "Event"
        let date = eventData["date"] as? String ?? ""
        let time = eventData["time"] as? String ?? ""
        let location = eventData["location"] as? String ?? ""
        
        // Check if user already RSVP'd
        let rsvps = eventData["rsvps"] as? [String: String] ?? [:]
        let userResponse = rsvps[currentUserId]
        
        // Create opportunity
        var opportunityData = OpportunityData(
            title: title,
            date: date,
            time: time,
            location: location,
            eventReference: eventId,
            needsRSVP: userResponse == nil // Only needs RSVP if user hasn't responded
        )
        
        // If user already responded, include their response and all RSVPs
        if let userResponse = userResponse {
            opportunityData.userResponse = userResponse
            opportunityData.rsvps = rsvps
            
            // Fetch display names asynchronously
            Task {
                await self.fetchRSVPDisplayNames(for: rsvps, opportunityId: "rsvp-\(eventId)")
            }
        }
        
        let opportunity = Opportunity(
            id: "rsvp-\(eventId)",
            type: .rsvpManagement,
            confidence: 1.0,
            data: opportunityData,
            suggestedActions: ["rsvp_yes", "rsvp_no", "rsvp_maybe"],
            reasoning: userResponse == nil ? "New event - RSVP requested" : "You RSVP'd \(userResponse ?? "")",
            timestamp: Date()
        )
        
        // Add to active opportunities (vertical stacking)
        // Check if this event is already in the array
        if let existingIndex = activeOpportunities.firstIndex(where: { $0.id == opportunity.id }) {
            // Update existing opportunity with fresh data
            activeOpportunities[existingIndex] = opportunity
            print("🔄 Updated existing opportunity: \(title)")
        } else {
            // Add new opportunity
            activeOpportunities.append(opportunity)
            
            // Limit to max stacked opportunities
            if activeOpportunities.count > maxStackedOpportunities {
                // Remove oldest opportunities
                let removed = activeOpportunities.removeFirst()
                opportunityCollapsedStates.removeValue(forKey: removed.id)
                print("🗑️ Removed oldest opportunity to stay under limit")
            }
            
            print("➕ Added new opportunity: \(title) (Total: \(activeOpportunities.count))")
        }
        
        showAmbientBar = !activeOpportunities.isEmpty
        
        // Set collapsed state based on whether user already responded
        opportunityCollapsedStates["rsvp-\(eventId)"] = (userResponse != nil)
        
        if userResponse != nil {
            print("✅ RSVP Ambient Bar shown (collapsed) - User already RSVP'd: \(userResponse ?? "")")
        } else {
            print("✅ RSVP Ambient Bar shown (expanded) - Awaiting user response")
        }
    }
    
    /**
     * Fetch display names for RSVP participants and update the opportunity
     */
    private func fetchRSVPDisplayNames(for rsvps: [String: String], opportunityId: String) async {
        let db = Firestore.firestore()
        var displayNames: [String: String] = [:]
        
        for userId in rsvps.keys {
            do {
                let userDoc = try await db.collection("users").document(userId).getDocument()
                if let userData = userDoc.data(),
                   let displayName = userData["displayName"] as? String {
                    displayNames[userId] = displayName
                } else {
                    displayNames[userId] = "Unknown User"
                }
            } catch {
                displayNames[userId] = "Unknown User"
            }
        }
        
        // Update opportunity with display names in the array
        guard let opportunityIndex = activeOpportunities.firstIndex(where: { $0.id == opportunityId }) else {
            print("⚠️ Opportunity \(opportunityId) not found in active opportunities")
            return
        }
        
        var opportunity = activeOpportunities[opportunityIndex]
        var updatedData = opportunity.data
        updatedData.rsvpDisplayNames = displayNames
        
        let updatedOpportunity = Opportunity(
            id: opportunity.id,
            type: opportunity.type,
            confidence: opportunity.confidence,
            data: updatedData,
            suggestedActions: opportunity.suggestedActions,
            reasoning: opportunity.reasoning,
            timestamp: opportunity.timestamp
        )
        
        // Update on main thread
        await MainActor.run {
            self.activeOpportunities[opportunityIndex] = updatedOpportunity
        }
    }
    
    /**
     * Handle opportunities detected by the service
     * Route to appropriate UI based on confidence
     * 
     * IMPORTANT: Only show suggestions to the MESSAGE SENDER (event creator)
     * Other users will receive RSVP requests after the event is created
     * 
     * HYBRID APPROACH: Try local array first (fast), query Firestore as backup (accurate)
     */
    @MainActor
    private func handleOpportunitiesDetected(_ opportunities: [Opportunity]) async {
        print("🤖 ChatViewModel: Handling \(opportunities.count) opportunities")
        print("   Current activeOpportunities count: \(activeOpportunities.count)")
        print("   showAmbientBar: \(showAmbientBar)")
        
        guard let topOpportunity = opportunities.first else {
            // No opportunities detected
            print("   ⚠️ No opportunities in array, skipping")
            return
        }
        
        print("   Top opportunity: \(topOpportunity.displayTitle) (confidence: \(topOpportunity.confidencePercentage)%)")
        
        // HYBRID APPROACH: Check sender using both local array and Firestore
        // Step 1: Try local array first (fast path - no network request)
        let localMessage = messages.last
        var latestMessage: Message?
        var usedFirestore = false
        
        if let local = localMessage {
            print("🤖 Checking local messages.last: '\(local.text)' (sender: \(local.senderId))")
            
            // If local sender matches current user, use it (fast path!)
            if local.senderId == currentUserId {
                print("   ✅ Local message sender matches current user (fast path)")
                latestMessage = local
            } else {
                // Local sender doesn't match - might be race condition
                // Query Firestore as backup (accurate path)
                print("   ⚠️ Local message sender doesn't match, querying Firestore as backup...")
                latestMessage = await fetchLatestMessage()
                usedFirestore = true
            }
        } else {
            // No local messages, query Firestore
            print("🤖 No local messages, querying Firestore...")
            latestMessage = await fetchLatestMessage()
            usedFirestore = true
        }
        
        // Validate we got a message
        guard let message = latestMessage else {
            print("🤖 No recent message found (local or Firestore), skipping opportunity display")
            return
        }
        
        print("🤖 Using \(usedFirestore ? "Firestore" : "local") message: '\(message.text)'")
        print("   Sender: \(message.senderId)")
        print("   Current user: \(currentUserId)")
        
        // Only show suggestions to the MESSAGE SENDER (event creator)
        // Other users are receivers and will get RSVP requests later
        guard message.senderId == currentUserId else {
            print("🤖 Current user is NOT the sender of the triggering message")
            print("   → Skipping Ambient Bar (user will receive RSVP instead)")
            return
        }
        
        print("🤖 Current user IS the sender → Checking for duplicates")
        
        // Check if this event already exists in Firestore (prevent duplicates)
        // Only check for EVENT PLANNING opportunities (not RSVP, not other types)
        if topOpportunity.type == .eventPlanning {
            let isDuplicate = await checkIfEventExists(
                title: topOpportunity.data.title,
                date: topOpportunity.data.date
            )
            
            if isDuplicate {
                print("🔄 DUPLICATE DETECTED: Event '\(topOpportunity.displayTitle)' already exists")
                print("   → Skipping opportunity to prevent re-prompting")
                return
            }
            
            // Not a duplicate, proceed with normal flow
            routeOpportunityByConfidence(topOpportunity)
        } else {
            // Non-event opportunities (priority, deadline, etc.) - process immediately
            routeOpportunityByConfidence(topOpportunity)
        }
    }
    
    /**
     * Fetch the latest message from Firestore
     * Used to avoid race conditions with the local messages array
     * 
     * Returns the most recent message, or nil if none found
     */
    private func fetchLatestMessage() async -> Message? {
        let db = Firestore.firestore()
        
        do {
            let snapshot = try await db.collection("conversations/\(conversationId)/messages")
                .order(by: "sentAt", descending: true)
                .limit(to: 1)
                .getDocuments()
            
            guard let doc = snapshot.documents.first else {
                print("⚠️ No messages found in Firestore")
                return nil
            }
            
            // Parse the message
            let message = try doc.data(as: Message.self)
            print("✅ Fetched latest message from Firestore: '\(message.text)' (ID: \(message.id))")
            return message
            
        } catch {
            print("❌ Failed to fetch latest message from Firestore: \(error.localizedDescription)")
            return nil
        }
    }
    
    /**
     * Route opportunity to appropriate UI based on confidence level
     * Extracted to separate method for clarity
     */
    private func routeOpportunityByConfidence(_ topOpportunity: Opportunity) {
        print("🤖 Routing opportunity: \(topOpportunity.displayTitle)")
        
        // Route based on confidence level
        if topOpportunity.isHighConfidence {
            // High confidence (>0.8) → Add to ambient bar (vertical stacking)
            print("🤖 High confidence (\(topOpportunity.confidencePercentage)%): Adding to ambient bar")
            
            // Check if this opportunity already exists in the array
            if let existingIndex = activeOpportunities.firstIndex(where: { $0.id == topOpportunity.id }) {
                // Update existing opportunity
                activeOpportunities[existingIndex] = topOpportunity
                print("🔄 Updated existing opportunity: \(topOpportunity.displayTitle)")
            } else {
                // Add new opportunity
                activeOpportunities.append(topOpportunity)
                
                // Limit to max stacked opportunities
                if activeOpportunities.count > maxStackedOpportunities {
                    let removed = activeOpportunities.removeFirst()
                    opportunityCollapsedStates.removeValue(forKey: removed.id)
                    print("🗑️ Removed oldest opportunity to stay under limit")
                }
                
                print("➕ Added new opportunity: \(topOpportunity.displayTitle) (Total: \(activeOpportunities.count))")
            }
            
            showAmbientBar = !activeOpportunities.isEmpty
            
            print("   ✅ Ambient bar updated:")
            print("      activeOpportunities count: \(activeOpportunities.count)")
            print("      showAmbientBar: \(showAmbientBar)")
            print("      Opportunities in array:")
            for (index, opp) in activeOpportunities.enumerated() {
                print("         \(index + 1). \(opp.displayTitle) (\(opp.id))")
            }
            
        } else if topOpportunity.isMediumConfidence {
            // Medium confidence (>0.6) → Show as inline chip
            print("🤖 Medium confidence (\(topOpportunity.confidencePercentage)%): Showing inline chip")
            
            // Find most recent message to attach chip to
            if let recentMessage = messages.last {
                inlineChips[recentMessage.id] = topOpportunity
            }
            
        } else {
            // Low confidence (>0.5) → Add to suggestions list
            print("🤖 Low confidence (\(topOpportunity.confidencePercentage)%): Adding to suggestions")
            
            // Add to pending suggestions if not already there
            if !pendingSuggestions.contains(where: { $0.id == topOpportunity.id }) {
                pendingSuggestions.append(topOpportunity)
                suggestionsCount = pendingSuggestions.count
            }
        }
    }
    
    /**
     * Check if an event already exists in Firestore
     * Prevents duplicate "Create & Organize" prompts for the same event
     * 
     * Uses fuzzy matching on title and exact matching on date
     * to account for slight variations in how events are described
     */
    private func checkIfEventExists(title: String?, date: String?) async -> Bool {
        guard let eventTitle = title, !eventTitle.isEmpty else {
            print("🔍 No title provided, cannot check for duplicates")
            return false
        }
        
        print("🔍 Checking for duplicate event: '\(eventTitle)' on '\(date ?? "unknown date")'")
        
        do {
            let db = Firestore.firestore()
            
            // Query events in this conversation
            let eventsSnapshot = try await db.collection("events")
                .whereField("conversationId", isEqualTo: conversationId)
                .limit(to: 50) // Check recent events
                .getDocuments()
            
            print("   Found \(eventsSnapshot.documents.count) existing events in conversation")
            
            // Normalize the opportunity title for comparison
            let normalizedOpportunityTitle = eventTitle.lowercased().trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            
            // Check each event for a match
            for eventDoc in eventsSnapshot.documents {
                let eventData = eventDoc.data()
                guard let existingTitle = eventData["title"] as? String else { continue }
                
                let normalizedExistingTitle = existingTitle.lowercased().trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                
                // Check for title match (fuzzy matching - contains or is contained)
                let titleMatches = normalizedOpportunityTitle.contains(normalizedExistingTitle) ||
                                   normalizedExistingTitle.contains(normalizedOpportunityTitle) ||
                                   normalizedOpportunityTitle == normalizedExistingTitle
                
                if titleMatches {
                    // If titles match, also check date if provided
                    if let opportunityDate = date, !opportunityDate.isEmpty {
                        // Get existing event date
                        let existingDate = eventData["date"] as? String ?? ""
                        
                        // Normalize dates for comparison
                        let normalizedOpportunityDate = opportunityDate.lowercased().trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                        let normalizedExistingDate = existingDate.lowercased().trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                        
                        // Check for date match (fuzzy matching)
                        let dateMatches = normalizedOpportunityDate.contains(normalizedExistingDate) ||
                                          normalizedExistingDate.contains(normalizedOpportunityDate) ||
                                          normalizedOpportunityDate == normalizedExistingDate
                        
                        if dateMatches {
                            print("   ✅ MATCH FOUND: '\(existingTitle)' on '\(existingDate)' (ID: \(eventDoc.documentID))")
                            return true
                        }
                    } else {
                        // No date provided in opportunity, just match on title
                        print("   ✅ MATCH FOUND (title only): '\(existingTitle)' (ID: \(eventDoc.documentID))")
                        return true
                    }
                }
            }
            
            print("   ❌ No duplicate found - this is a new event")
            return false
            
        } catch {
            print("   ⚠️ Error checking for duplicates: \(error.localizedDescription)")
            // If check fails, allow the opportunity through (fail open)
            return false
        }
    }
    
    /**
     * Approve an opportunity (execute workflow)
     * Creates the event in Firestore - receivers will see RSVP Ambient Bar
     */
    func approveOpportunity(_ opportunity: Opportunity) async {
        print("🤖 ChatViewModel: Approving opportunity: \(opportunity.displayTitle)")
        
        agentIsProcessing = true
        
        do {
            // Extract event details from opportunity
            let title = opportunity.data.title ?? opportunity.displayTitle
            let dateStr = opportunity.data.date ?? ""
            let timeStr = opportunity.data.time ?? ""
            let location = opportunity.data.location ?? ""
            let participants = opportunity.data.participants ?? []
            
            // Create event in Firestore
            let db = Firestore.firestore()
            let eventRef = db.collection("events").document()
            
            let eventData: [String: Any] = [
                "id": eventRef.documentID,
                "title": title,
                "conversationId": conversationId,
                "createdBy": currentUserId,
                "date": dateStr,
                "time": timeStr,
                "location": location,
                "participants": participants,
                "createdAt": FieldValue.serverTimestamp(),
                "updatedAt": FieldValue.serverTimestamp(),
                "status": "pending" // pending, confirmed, cancelled
            ]
            
            try await eventRef.setData(eventData)
            
            print("✅ Event created in Firestore: \(eventRef.documentID)")
            print("   Receivers will automatically see RSVP Ambient Bar")
            
            agentIsProcessing = false
            
            // Dismiss the opportunity
            dismissOpportunity(opportunity)
            
            print("✅ ChatViewModel: Opportunity approved and event created")
            
        } catch {
            print("❌ ChatViewModel: Failed to create event: \(error.localizedDescription)")
            agentError = "Failed to create event: \(error.localizedDescription)"
            agentIsProcessing = false
        }
    }
    
    /**
     * Handle RSVP Yes response
     * Keeps bar visible in collapsed state after responding
     */
    func rsvpYes(_ opportunity: Opportunity) async {
        print("✅ ChatViewModel: User RSVP'd YES to event")
        
        guard let eventId = opportunity.data.eventReference else {
            print("❌ No event reference found")
            return
        }
        
        agentIsProcessing = true
        
        do {
            // Update event RSVP in Firestore
            let db = Firestore.firestore()
            try await db.collection("events").document(eventId).updateData([
                "rsvps.\(currentUserId)": "yes",
                "updatedAt": FieldValue.serverTimestamp()
            ])
            
            print("✅ RSVP Yes recorded in Firestore")
            
            agentIsProcessing = false
            
            // Update opportunity to show RSVP list + Add to Calendar button
            await refreshOpportunityWithRSVPs(opportunity, eventId: eventId, userResponse: "yes")
            
            // Collapse the bar (keep it visible but minimal)
            opportunityCollapsedStates[opportunity.id] = true
            
            print("✅ Ambient Bar collapsed - User can still access details")
            
        } catch {
            print("❌ Failed to record RSVP: \(error.localizedDescription)")
            agentError = "Failed to record RSVP"
            agentIsProcessing = false
        }
    }
    
    /**
     * Handle RSVP No response
     * Keeps bar visible in collapsed state after responding
     */
    func rsvpNo(_ opportunity: Opportunity) async {
        print("❌ ChatViewModel: User RSVP'd NO to event")
        
        guard let eventId = opportunity.data.eventReference else {
            print("❌ No event reference found")
            return
        }
        
        agentIsProcessing = true
        
        do {
            // Update event RSVP in Firestore
            let db = Firestore.firestore()
            try await db.collection("events").document(eventId).updateData([
                "rsvps.\(currentUserId)": "no",
                "updatedAt": FieldValue.serverTimestamp()
            ])
            
            print("✅ RSVP No recorded in Firestore")
            
            agentIsProcessing = false
            
            // Update opportunity to show RSVP list
            await refreshOpportunityWithRSVPs(opportunity, eventId: eventId, userResponse: "no")
            
            // Collapse the bar (keep it visible but minimal)
            opportunityCollapsedStates[opportunity.id] = true
            
            print("✅ Ambient Bar collapsed - User declined, bar remains visible")
            
        } catch {
            print("❌ Failed to record RSVP: \(error.localizedDescription)")
            agentError = "Failed to record RSVP"
            agentIsProcessing = false
        }
    }
    
    /**
     * Refresh opportunity with updated RSVP list and display names
     */
    private func refreshOpportunityWithRSVPs(_ opportunity: Opportunity, eventId: String, userResponse: String) async {
        do {
            let db = Firestore.firestore()
            let eventDoc = try await db.collection("events").document(eventId).getDocument()
            
            guard let data = eventDoc.data() else {
                print("❌ Event not found")
                return
            }
            
            let rsvps = data["rsvps"] as? [String: String] ?? [:]
            
            // Fetch display names for all users who RSVP'd
            var displayNames: [String: String] = [:]
            for userId in rsvps.keys {
                let userDoc = try await db.collection("users").document(userId).getDocument()
                if let userData = userDoc.data(),
                   let displayName = userData["displayName"] as? String {
                    displayNames[userId] = displayName
                } else {
                    displayNames[userId] = "Unknown User"
                }
            }
            
            // Update the opportunity with RSVP data and display names
            var updatedData = opportunity.data
            updatedData.rsvps = rsvps
            updatedData.userResponse = userResponse
            updatedData.rsvpDisplayNames = displayNames
            
            let updatedOpportunity = Opportunity(
                id: opportunity.id,
                type: opportunity.type,
                confidence: opportunity.confidence,
                data: updatedData,
                suggestedActions: opportunity.suggestedActions,
                reasoning: opportunity.reasoning,
                timestamp: opportunity.timestamp
            )
            
            // Update the opportunity in the active opportunities array
            if let opportunityIndex = activeOpportunities.firstIndex(where: { $0.id == opportunity.id }) {
                activeOpportunities[opportunityIndex] = updatedOpportunity
                print("✅ Opportunity refreshed with RSVP data: \(rsvps.count) responses")
            } else {
                print("⚠️ Opportunity \(opportunity.id) not found in active opportunities")
            }
            
        } catch {
            print("❌ Failed to refresh RSVP data: \(error.localizedDescription)")
        }
    }
    
    /**
     * Parse event date from natural language string
     * Supports: "October 31", "Monday", "tomorrow", "today"
     */
    private func parseEventDate(from dateStr: String) -> Date {
        let calendar = Calendar.current
        let today = Date()
        let dateStrLower = dateStr.lowercased()
        
        // Handle "tomorrow" (check first to avoid "tomorrow" containing weekday names)
        if dateStrLower.contains("tomorrow") {
            return calendar.date(byAdding: .day, value: 1, to: today) ?? today
        }
        
        // Handle "today"
        if dateStrLower.contains("today") {
            return today
        }
        
        // Handle specific dates like "October 31" or "Oct 31"
        // Format: "Month Day" (e.g., "October 31", "Oct 31", "November 5")
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        
        // Try full month name (October 31)
        dateFormatter.dateFormat = "MMMM d"
        if let parsedDate = dateFormatter.date(from: dateStr) {
            // Set the year to current year or next year if date has passed
            var components = calendar.dateComponents([.month, .day], from: parsedDate)
            components.year = calendar.component(.year, from: today)
            
            if let dateThisYear = calendar.date(from: components) {
                // If the date has already passed this year, use next year
                if dateThisYear < today {
                    components.year = (components.year ?? 0) + 1
                    if let dateNextYear = calendar.date(from: components) {
                        print("📅 Parsed '\(dateStr)' as \(dateFormatter.string(from: dateNextYear)) (next year)")
                        return dateNextYear
                    }
                }
                print("📅 Parsed '\(dateStr)' as \(dateFormatter.string(from: dateThisYear))")
                return dateThisYear
            }
        }
        
        // Try abbreviated month name (Oct 31)
        dateFormatter.dateFormat = "MMM d"
        if let parsedDate = dateFormatter.date(from: dateStr) {
            var components = calendar.dateComponents([.month, .day], from: parsedDate)
            components.year = calendar.component(.year, from: today)
            
            if let dateThisYear = calendar.date(from: components) {
                if dateThisYear < today {
                    components.year = (components.year ?? 0) + 1
                    if let dateNextYear = calendar.date(from: components) {
                        print("📅 Parsed '\(dateStr)' as \(dateFormatter.string(from: dateNextYear)) (next year)")
                        return dateNextYear
                    }
                }
                print("📅 Parsed '\(dateStr)' as \(dateFormatter.string(from: dateThisYear))")
                return dateThisYear
            }
        }
        
        // Handle day names (Monday, Tuesday, etc.)
        let weekdays = ["sunday": 1, "monday": 2, "tuesday": 3, "wednesday": 4, 
                        "thursday": 5, "friday": 6, "saturday": 7]
        
        for (dayName, targetWeekday) in weekdays {
            if dateStrLower.contains(dayName) {
                // Get current weekday (1 = Sunday, 2 = Monday, etc.)
                let currentWeekday = calendar.component(.weekday, from: today)
                
                // Calculate days until target weekday
                var daysToAdd = targetWeekday - currentWeekday
                
                // If target day is today or already passed this week, go to next week
                if daysToAdd <= 0 {
                    daysToAdd += 7
                }
                
                // Add the calculated days to today
                if let date = calendar.date(byAdding: .day, value: daysToAdd, to: today) {
                    print("📅 Parsed '\(dayName)' as \(daysToAdd) days from now")
                    return date
                }
            }
        }
        
        // Default to tomorrow if can't parse
        print("⚠️ Could not parse date '\(dateStr)', defaulting to tomorrow")
        return calendar.date(byAdding: .day, value: 1, to: today) ?? today
    }
    
    /**
     * Parse event time from string (e.g., "2PM", "14:00", "3pm")
     */
    private func parseEventTime(from timeStr: String, baseDate: Date) -> Date {
        let calendar = Calendar.current
        let timeStrLower = timeStr.lowercased().trimmingCharacters(in: .whitespaces)
        
        var hour = 12
        var minute = 0
        
        // Parse formats like "2PM", "3pm", "2:30PM"
        if let regex = try? NSRegularExpression(pattern: "(\\d{1,2})(?::(\\d{2}))?\\s*(am|pm)?", options: .caseInsensitive),
           let match = regex.firstMatch(in: timeStrLower, range: NSRange(timeStrLower.startIndex..., in: timeStrLower)) {
            
            // Extract hour
            if let hourRange = Range(match.range(at: 1), in: timeStrLower) {
                hour = Int(timeStrLower[hourRange]) ?? 12
            }
            
            // Extract minute (optional)
            if match.range(at: 2).location != NSNotFound,
               let minuteRange = Range(match.range(at: 2), in: timeStrLower) {
                minute = Int(timeStrLower[minuteRange]) ?? 0
            }
            
            // Handle AM/PM
            if match.range(at: 3).location != NSNotFound,
               let ampmRange = Range(match.range(at: 3), in: timeStrLower) {
                let ampm = String(timeStrLower[ampmRange])
                if ampm == "pm" && hour < 12 {
                    hour += 12
                } else if ampm == "am" && hour == 12 {
                    hour = 0
                }
            }
        }
        
        // Create date with parsed time
        var components = calendar.dateComponents([.year, .month, .day], from: baseDate)
        components.hour = hour
        components.minute = minute
        components.second = 0
        
        return calendar.date(from: components) ?? baseDate
    }
    
    /**
     * Add event to iOS Calendar
     */
    func addToCalendar(_ opportunity: Opportunity) async {
        print("📅 ChatViewModel: Adding event to calendar")
        
        let eventStore = EKEventStore()
        
        do {
            // Request calendar access (iOS 17+)
            let granted = try await eventStore.requestFullAccessToEvents()
            
            guard granted else {
                print("❌ Calendar access denied")
                agentError = "Calendar access denied. Please enable in Settings."
                return
            }
            
            // Create calendar event
            let event = EKEvent(eventStore: eventStore)
            event.title = opportunity.data.title ?? "Event"
            event.notes = "Created from messAI"
            
            // Parse date and time
            if let dateStr = opportunity.data.date, !dateStr.isEmpty {
                var eventDate = parseEventDate(from: dateStr)
                
                // Parse time if available
                if let timeStr = opportunity.data.time, !timeStr.isEmpty {
                    eventDate = parseEventTime(from: timeStr, baseDate: eventDate)
                    event.startDate = eventDate
                    event.endDate = eventDate.addingTimeInterval(3600) // 1 hour duration
                    event.isAllDay = false
                } else {
                    // All-day event
                    event.startDate = eventDate
                    event.endDate = eventDate
                    event.isAllDay = true
                }
            } else {
                // No date provided, use tomorrow
                let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
                event.startDate = tomorrow
                event.endDate = tomorrow
                event.isAllDay = true
            }
            
            // Set location if available
            if let location = opportunity.data.location, !location.isEmpty {
                event.location = location
            }
            
            // Set calendar (use default)
            event.calendar = eventStore.defaultCalendarForNewEvents
            
            // Save event
            try eventStore.save(event, span: .thisEvent)
            
            print("✅ Event added to calendar: \(event.title ?? "")")
            
            // Dismiss the Ambient Bar
            dismissOpportunity(opportunity)
            
        } catch {
            print("❌ Failed to add to calendar: \(error.localizedDescription)")
            agentError = "Failed to add event to calendar"
        }
    }
    
    /**
     * Toggle collapsed/expanded state for an opportunity
     */
    func toggleOpportunityCollapsed(_ opportunityId: String) {
        let currentState = opportunityCollapsedStates[opportunityId] ?? false
        opportunityCollapsedStates[opportunityId] = !currentState
        
        print("🤖 ChatViewModel: Toggled opportunity \(opportunityId) - Collapsed: \(!currentState)")
    }
    
    /**
     * Check if an opportunity is collapsed
     */
    func isOpportunityCollapsed(_ opportunityId: String) -> Bool {
        return opportunityCollapsedStates[opportunityId] ?? false
    }
    
    /**
     * Dismiss an opportunity
     * Removes it from the active opportunities array
     */
    func dismissOpportunity(_ opportunity: Opportunity) {
        print("🤖 ChatViewModel: Dismissing opportunity: \(opportunity.displayTitle)")
        
        // Remove from active opportunities array
        activeOpportunities.removeAll { $0.id == opportunity.id }
        
        // Update showAmbientBar based on remaining opportunities
        showAmbientBar = !activeOpportunities.isEmpty

        // Remove from inline chips
        inlineChips = inlineChips.filter { $0.value.id != opportunity.id }

        // Remove from pending suggestions
        pendingSuggestions.removeAll { $0.id == opportunity.id }
        suggestionsCount = pendingSuggestions.count
        
        // Remove collapsed state
        opportunityCollapsedStates.removeValue(forKey: opportunity.id)
        
        print("   → Removed opportunity. Remaining: \(activeOpportunities.count)")
    }
    
    /**
     * Dismiss all pending suggestions
     */
    func dismissAllSuggestions() {
        print("🤖 ChatViewModel: Dismissing all suggestions")
        
        pendingSuggestions = []
        suggestionsCount = 0
    }
    
    // MARK: - PR#20.2 Phase 6: Event Count Badge
    
    /**
     * Start listening to event count for badge display
     * Counts only upcoming, non-cancelled events
     */
    private func startEventCountListener() {
        print("📊 ChatViewModel: Starting event count listener")
        
        let db = Firestore.firestore()
        
        db.collection("events")
            .whereField("conversationId", isEqualTo: conversationId)
            .whereField("status", isNotEqualTo: "cancelled")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ Event count listener error: \(error.localizedDescription)")
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    print("⚠️ No documents in event count snapshot")
                    return
                }
                
                // Count only upcoming, non-cancelled events
                let upcomingCount = documents.compactMap { doc -> EventDocument? in
                    return EventDocument(from: doc)
                }.filter { event in
                    return event.isUpcoming // Uses computed property (checks date >= now && status != "cancelled")
                }.count
                
                Task { @MainActor in
                    self.activeEventCount = upcomingCount
                    print("📊 Active event count updated: \(upcomingCount)")
                }
            }
    }
}

