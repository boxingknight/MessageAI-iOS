//
//  ContactsListView.swift
//  messAI
//
//  Created by Isaac Jaramillo on October 21, 2025.
//  Purpose: Main contact selection interface for starting new conversations (PR #8)
//           Displays all registered users with search, handles conversation creation
//

import SwiftUI

struct ContactsListView: View {
    @StateObject private var viewModel: ContactsViewModel
    @Environment(\.dismiss) var dismiss
    
    let onContactSelected: (User) -> Void
    
    // MARK: - Initialization
    
    init(
        chatService: ChatService,
        currentUserId: String,
        onContactSelected: @escaping (User) -> Void
    ) {
        _viewModel = StateObject(wrappedValue: ContactsViewModel(
            chatService: chatService,
            currentUserId: currentUserId
        ))
        self.onContactSelected = onContactSelected
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ZStack {
                if viewModel.isLoading {
                    loadingView
                } else if viewModel.isEmpty {
                    emptyStateView
                } else {
                    contactListView
                }
            }
            .navigationTitle("New Chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .searchable(text: $viewModel.searchQuery, prompt: "Search contacts")
            .task {
                await viewModel.loadUsers()
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK") {
                    viewModel.showError = false
                }
            } message: {
                if let error = viewModel.errorMessage {
                    Text(error)
                }
            }
        }
    }
    
    // MARK: - Subviews
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading contacts...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.5))
            
            Text("No Contacts Found")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("No other users are registered yet.\nInvite friends to join!")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
    
    private var contactListView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.filteredUsers) { user in
                    Button {
                        handleContactTap(user)
                    } label: {
                        ContactRowView(user: user)
                            .padding(.horizontal)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    if user.id != viewModel.filteredUsers.last?.id {
                        Divider()
                            .padding(.leading, 74)
                    }
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func handleContactTap(_ user: User) {
        print("[ContactsListView] Contact tapped: \(user.displayName)")
        onContactSelected(user)
    }
}

// MARK: - Preview

#Preview {
    ContactsListView(
        chatService: ChatService(),
        currentUserId: "test-user-id"
    ) { user in
        print("Selected: \(user.displayName)")
    }
}

