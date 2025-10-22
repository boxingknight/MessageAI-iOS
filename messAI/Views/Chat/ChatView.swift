//
//  ChatView.swift
//  messAI
//
//  Created for PR #9 - Chat View UI Components
//  Main chat interface with messages and input
//

import SwiftUI
import FirebaseAuth

struct ChatView: View {
    @StateObject private var viewModel: ChatViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isInputFocused: Bool
    @State private var showGroupInfo = false
    
    let conversation: Conversation
    
    // PR #13: User cache for group sender names (TODO: populate from ChatViewModel)
    private let userCache: [String: User] = [:]
    
    // MARK: - Computed Properties
    
    /// Display title for the conversation (simplified for PR #9)
    /// TODO (PR #10+): Add user lookup for proper names
    private var conversationTitle: String {
        if conversation.isGroup {
            return conversation.groupName ?? "Group Chat"
        } else {
            // For now, just show "Chat" - will add user lookup in future PR
            return "Chat"
        }
    }
    
    // MARK: - Initialization
    
    init(conversation: Conversation) {
        self.conversation = conversation
        
        // Initialize ViewModel with dependencies
        let chatService = ChatService()
        let localDataManager = LocalDataManager.shared
        
        // Get other user ID for 1-on-1 chats (for presence)
        let currentUserId = FirebaseAuth.Auth.auth().currentUser?.uid ?? ""
        let otherUserId = conversation.isGroup ? nil : conversation.participants.first { $0 != currentUserId }
        
        _viewModel = StateObject(wrappedValue: ChatViewModel(
            conversationId: conversation.id,
            chatService: chatService,
            localDataManager: localDataManager,
            otherUserId: otherUserId
        ))
    }
    
    // MARK: - Message Grouping Helpers
    
    /// Check if message is first in a group (iMessage-style grouping)
    /// Messages are grouped if they're from the same sender and within 2 minutes
    private func isFirstInGroup(at index: Int) -> Bool {
        guard index > 0 else { return true } // First message is always first in group
        
        let currentMessage = viewModel.messages[index]
        let previousMessage = viewModel.messages[index - 1]
        
        // Different sender = start new group
        if currentMessage.senderId != previousMessage.senderId {
            return true
        }
        
        // Same sender but more than 2 minutes apart = start new group
        let timeDifference = currentMessage.sentAt.timeIntervalSince(previousMessage.sentAt)
        return timeDifference > 120 // 2 minutes
    }
    
    /// Check if message is last in a group
    private func isLastInGroup(at index: Int) -> Bool {
        guard index < viewModel.messages.count - 1 else { return true } // Last message is always last in group
        
        let currentMessage = viewModel.messages[index]
        let nextMessage = viewModel.messages[index + 1]
        
        // Different sender = end group
        if currentMessage.senderId != nextMessage.senderId {
            return true
        }
        
        // Same sender but more than 2 minutes apart = end group
        let timeDifference = nextMessage.sentAt.timeIntervalSince(currentMessage.sentAt)
        return timeDifference > 120 // 2 minutes
    }
    
    // MARK: - Toolbar Components
    
    @ViewBuilder
    private var toolbarTitle: some View {
        VStack(spacing: 2) {
            Text(conversationTitle)
                .font(.headline)
            
            // Show presence text if available
            if let presence = viewModel.otherUserPresence {
                Text(presence.presenceText)
                    .font(.caption)
                    .foregroundColor(presence.isOnline ? .green : .secondary)
            }
        }
    }
    
    @ViewBuilder
    private var toolbarTrailing: some View {
        if conversation.isGroup {
            // Group chat: Show group info button
            Button(action: {
                showGroupInfo = true
            }) {
                Image(systemName: "info.circle")
            }
        } else {
            // 1-on-1 chat: Show menu
            Menu {
                Button(action: {
                    print("View info tapped")
                }) {
                    Label("Chat Info", systemImage: "info.circle")
                }
                
                Button(action: {
                    print("Mute tapped")
                }) {
                    Label("Mute", systemImage: "bell.slash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
    }
    
    // MARK: - Message List
    
    @ViewBuilder
    private func messagesList(proxy: ScrollViewProxy) -> some View {
                ScrollView {
                    LazyVStack(spacing: 0) { // No fixed spacing - dynamic per message!
                        // Loading indicator at top
                        if viewModel.isLoading {
                            ProgressView()
                                .padding()
                        }
                        
                        // Messages with grouping
                        ForEach(0..<viewModel.messages.count, id: \.self) { index in
                            let message = viewModel.messages[index]
                            let isFirst = isFirstInGroup(at: index)
                            let isLast = isLastInGroup(at: index)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                MessageBubbleView(
                                    message: message,
                                    isFromCurrentUser: message.senderId == viewModel.currentUserId,
                                    isFirstInGroup: isFirst,
                                    isLastInGroup: isLast,
                                    conversation: conversation, // PR #13: Pass conversation for group support
                                    users: userCache // PR #13: Pass users for sender names
                                )
                                .contextMenu {
                                    // PR #15: Calendar extraction context menu
                                    Button {
                                        Task {
                                            await viewModel.extractCalendarEvents(from: message)
                                        }
                                    } label: {
                                        Label("Extract Calendar Event", systemImage: "calendar.badge.plus")
                                    }
                                }
                                
                                // PR #15: Display calendar cards if events exist
                                if let calendarEvents = message.aiMetadata?.calendarEvents,
                                   !calendarEvents.isEmpty {
                                    ForEach(calendarEvents) { event in
                                        CalendarCardView(event: event) { event in
                                            Task {
                                                let success = await viewModel.addEventToCalendar(event)
                                                if !success {
                                                    // Show error if needed
                                                }
                                            }
                                        }
                                        .padding(.horizontal, message.senderId == viewModel.currentUserId ? 60 : 16)
                                    }
                                }
                            }
                            .id(message.id)
                        }
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 16)
                }
                .onChange(of: viewModel.messages.count) { oldValue, newValue in
                    // Auto-scroll to bottom when new message arrives
                    if let lastMessage = viewModel.messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
                .onAppear {
                    // Scroll to bottom on first load
                    if let lastMessage = viewModel.messages.last {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Messages ScrollView
            ScrollViewReader { proxy in
                messagesList(proxy: proxy)
            }
            
            // Typing indicator
            if viewModel.otherUserTyping {
                HStack {
                    Text("Someone is typing...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                    
                    Spacer()
                }
                .padding(.vertical, 4)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            // Divider
            Divider()
            
            // Input view
            MessageInputView(
                text: $viewModel.messageText,
                onSend: {
                    viewModel.sendMessage()
                }
            )
        }
        .onChange(of: viewModel.messageText) { oldValue, newValue in
            // Trigger typing indicator when text changes
            viewModel.handleTextChange()
        }
        .navigationTitle(conversationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                toolbarTitle
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                toolbarTrailing
            }
        }
        .sheet(isPresented: $showGroupInfo) {
            GroupInfoView(
                conversation: conversation,
                users: userCache
            )
        }
        .task {
            // Load messages when view appears
            await viewModel.loadMessages()
        }
        .onAppear {
            // PR#17.1: Track active conversation for toast notifications
            ToastNotificationManager.shared.activeConversationId = conversation.id
            print("📍 Set active conversation: \(conversation.id)")
            
            // PR#11 Fix: Track chat visibility for real-time read receipts
            viewModel.isChatVisible = true
            print("👁️ Chat is now VISIBLE - read receipts will be instant")
        }
        .onDisappear {
            // PR#17.1: Clear active conversation when leaving chat
            ToastNotificationManager.shared.activeConversationId = nil
            print("📍 Cleared active conversation")
            
            // PR#11 Fix: Clear chat visibility
            viewModel.isChatVisible = false
            print("👁️ Chat is now HIDDEN - read receipts paused")
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {
                viewModel.showError = false
            }
        } message: {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
            }
        }
    }
}

#Preview("Chat with Messages") {
    NavigationStack {
        ChatView(
            conversation: Conversation(
                participant1: "user1",
                participant2: "user2",
                createdBy: "user1"
            )
        )
    }
}

#Preview("Group Chat") {
    NavigationStack {
        ChatView(
            conversation: Conversation(
                participants: ["user1", "user2", "user3"],
                groupName: "Team Chat",
                createdBy: "user1"
            )
        )
    }
}

