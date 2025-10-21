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
    
    var body: some View {
        NavigationStack {
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
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingNewChat = true
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .font(.title3)
                    }
                }
            }
            .sheet(isPresented: $showingNewChat) {
                ContactsListView(
                    chatService: ChatService(),
                    currentUserId: viewModel.currentUserId
                ) { selectedUser in
                    handleContactSelected(selectedUser)
                }
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
            .onAppear {
                viewModel.loadConversations()
            }
            .onDisappear {
                viewModel.stopListening()
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
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.sortedConversations) { conversation in
                    NavigationLink(value: conversation) {
                        ConversationRowView(
                            conversation: conversation,
                            conversationName: viewModel.getConversationName(conversation),
                            photoURL: viewModel.getConversationPhotoURL(conversation),
                            unreadCount: viewModel.getUnreadCount(conversation),
                            isOnline: false // TODO: PresenceService (PR #12)
                        )
                        .padding(.horizontal)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Divider()
                        .padding(.leading, 80)
                }
            }
        }
        .navigationDestination(for: Conversation.self) { conversation in
            // TODO: ChatView (PR #9)
            VStack(spacing: 20) {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.blue)
                
                Text("Chat View")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Coming in PR #9")
                    .font(.body)
                    .foregroundColor(.secondary)
                
                Text("Conversation ID: \(conversation.id)")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding()
            .navigationTitle(viewModel.getConversationName(conversation))
            .navigationBarTitleDisplayMode(.inline)
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

