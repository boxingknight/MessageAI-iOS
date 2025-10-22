//
//  ChatListView.swift
//  messAI
//
//  Created by Isaac Jaramillo on 10/20/25.
//

import SwiftUI

struct ChatListView: View {
    @StateObject var viewModel: ChatListViewModel
    @State private var showingNewChat = false
    @State private var showingNewGroup = false
    @State private var showActionSheet = false
    @State private var navigationPath = NavigationPath() // PR#17.1: For programmatic navigation
    @State private var aiTestResult: String? = nil
    @State private var showAITestResult = false
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                // Main Content
                content
                
                // Loading Overlay (first load only)
                if viewModel.isLoading && viewModel.conversations.isEmpty {
                    ProgressView("Loading conversations...")
                }
            }
            .navigationTitle("Messages")
            .toolbar {
                #if DEBUG
                // Debug: Test toast button
                ToolbarItem(placement: .navigationBarLeading) {
                    HStack(spacing: 12) {
                        Button {
                            // Trigger a test toast
                            let testToast = ToastMessage(
                                id: UUID().uuidString,
                                conversationId: "test-conv-123",
                                senderId: "test-user",
                                senderName: "Test User",
                                senderPhotoURL: nil,
                                messageText: "This is a test toast notification! Tap to see if navigation works.",
                                isImageMessage: false,
                                timestamp: Date()
                            )
                            ToastNotificationManager.shared.showToast(testToast)
                            print("🧪 DEBUG: Manually triggered test toast")
                        } label: {
                            Image(systemName: "bell.badge.fill")
                                .foregroundColor(.orange)
                        }
                        
                        // PR#14: Test AI Infrastructure button
                        Button {
                            Task {
                                await testAIInfrastructure()
                            }
                        } label: {
                            Image(systemName: "cpu")
                                .foregroundColor(.purple)
                        }
                    }
                }
                #endif
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showActionSheet = true
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .font(.title3)
                    }
                }
            }
            .confirmationDialog("New Conversation", isPresented: $showActionSheet) {
                Button("New Chat") {
                    showingNewChat = true
                }
                Button("New Group") {
                    showingNewGroup = true
                }
                Button("Cancel", role: .cancel) { }
            }
            .sheet(isPresented: $showingNewChat) {
                ContactsListView(
                    chatService: ChatService(),
                    currentUserId: viewModel.currentUserId
                ) { selectedUser in
                    handleContactSelected(selectedUser)
                }
            }
            .sheet(isPresented: $showingNewGroup) {
                ParticipantSelectionView(currentUserId: viewModel.currentUserId)
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK") {
                    viewModel.showError = false
                }
            } message: {
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                }
            }
            // PR#14: AI Test Result Alert
            .alert("🤖 AI Test Result", isPresented: $showAITestResult) {
                Button("OK") {
                    aiTestResult = nil
                }
            } message: {
                if let result = aiTestResult {
                    Text(result)
                }
            }
            .onAppear {
                viewModel.loadConversations()
            }
            .onDisappear {
                viewModel.stopListening()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OpenConversationFromToast"))) { notification in
                // PR#17.1: Handle toast tap navigation
                guard let userInfo = notification.userInfo,
                      let conversationId = userInfo["conversationId"] as? String else {
                    return
                }
                
                // Find conversation and navigate to it
                if let conversation = viewModel.conversations.first(where: { $0.id == conversationId }) {
                    print("📱 Opening conversation from toast: \(conversationId)")
                    navigationPath.append(conversation)
                }
            }
        }
    }
    
    // MARK: - Content
    
    @ViewBuilder
    private var content: some View {
        if viewModel.sortedConversations.isEmpty && !viewModel.isLoading {
            emptyState
        } else {
            conversationList
        }
    }
    
    private var conversationList: some View {
        List {
            ForEach(viewModel.sortedConversations) { conversation in
                NavigationLink(value: conversation) {
                    ConversationRowView(
                        conversation: conversation,
                        conversationName: viewModel.getConversationName(conversation),
                        photoURL: viewModel.getConversationPhotoURL(conversation),
                        unreadCount: viewModel.getUnreadCount(conversation),
                        isOnline: viewModel.getPresence(conversation)?.isOnline ?? false
                    )
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        deleteConversation(conversation)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
            }
        }
        .listStyle(.plain)
        .navigationDestination(for: Conversation.self) { conversation in
            ChatView(conversation: conversation)
        }
        .refreshable {
            await viewModel.refresh()
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "message.fill")
                .font(.system(size: 64))
                .foregroundColor(.gray)
            
            Text("No Conversations Yet")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Tap the compose button to start a new chat")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button {
                showingNewChat = true
            } label: {
                Label("New Chat", systemImage: "square.and.pencil")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
            }
        }
        .padding()
    }
    
    // MARK: - Actions
    
    /// Handles contact selection from contact picker
    /// Creates or finds conversation, then dismisses sheet
    private func handleContactSelected(_ user: User) {
        Task {
            do {
                print("[ChatListView] Contact selected: \(user.displayName)")
                let conversation = try await viewModel.startConversation(with: user)
                showingNewChat = false
                print("[ChatListView] ✅ Conversation ready: \(conversation.id)")
                // TODO (PR #9): Navigate to chat view with conversation
            } catch {
                print("[ChatListView] ❌ Error starting conversation: \(error)")
                // TODO (PR #19): Show error alert to user
            }
        }
    }
    
    /// Deletes a conversation from both Firebase and local storage
    private func deleteConversation(_ conversation: Conversation) {
        Task {
            await viewModel.deleteConversation(conversation)
        }
    }
    
    // MARK: - PR#14: AI Testing
    
    /// Test AI Infrastructure - Calls Cloud Function to verify end-to-end setup
    private func testAIInfrastructure() async {
        print("🧪 [AI Test] Starting AI infrastructure test...")
        
        do {
            // Call AI service with test message
            let result = try await AIService.shared.processMessage(
                "Soccer practice Thursday at 4pm",
                feature: .calendar
            )
            
            // Extract result details
            let processingTime = result["processingTimeMs"] as? Int ?? 0
            let modelUsed = result["modelUsed"] as? String ?? "unknown"
            let message = result["message"] as? String ?? "No message"
            
            // Format success message
            let successMessage = """
            ✅ AI Infrastructure Working!
            
            📊 Processing Time: \(processingTime)ms
            🤖 Model: \(modelUsed)
            💬 Response: \(message)
            
            Test: Calendar extraction placeholder
            """
            
            print("✅ [AI Test] Success:", result)
            
            // Show result in alert
            await MainActor.run {
                aiTestResult = successMessage
                showAITestResult = true
            }
            
        } catch let error as AIError {
            // Handle specific AI errors
            let errorMessage = """
            ❌ AI Test Failed
            
            Error: \(error.localizedDescription)
            
            Possible causes:
            - Not logged in
            - Rate limit exceeded
            - Network issue
            - Cloud Function not deployed
            """
            
            print("❌ [AI Test] Error:", error.localizedDescription)
            
            await MainActor.run {
                aiTestResult = errorMessage
                showAITestResult = true
            }
            
        } catch {
            // Handle generic errors
            let errorMessage = """
            ❌ AI Test Failed
            
            Error: \(error.localizedDescription)
            """
            
            print("❌ [AI Test] Unexpected error:", error)
            
            await MainActor.run {
                aiTestResult = errorMessage
                showAITestResult = true
            }
        }
    }
}

// MARK: - Preview

struct ChatListView_Previews: PreviewProvider {
    static var previews: some View {
        // Mock preview
        ChatListView(viewModel: ChatListViewModel(
            chatService: ChatService(),
            localDataManager: LocalDataManager.shared,
            currentUserId: "preview-user"
        ))
    }
}

