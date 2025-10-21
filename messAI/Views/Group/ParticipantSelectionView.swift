//
//  ParticipantSelectionView.swift
//  messAI
//
//  Created for PR #13: Group Chat Functionality
//

import SwiftUI

/// View for selecting participants to create a group chat
struct ParticipantSelectionView: View {
    
    // MARK: - Environment
    
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - ViewModels
    
    @StateObject private var groupViewModel: GroupViewModel
    @StateObject private var contactsViewModel: ContactsViewModel
    
    // MARK: - State
    
    @State private var searchText: String = ""
    @State private var showGroupSetup: Bool = false
    
    // MARK: - Computed Properties
    
    private var filteredUsers: [User] {
        if searchText.isEmpty {
            return contactsViewModel.allUsers
        } else {
            return contactsViewModel.allUsers.filter {
                $0.displayName.lowercased().contains(searchText.lowercased()) ||
                $0.email.lowercased().contains(searchText.lowercased())
            }
        }
    }
    
    // MARK: - Initialization
    
    init(chatService: ChatService = ChatService(), currentUserId: String) {
        _groupViewModel = StateObject(wrappedValue: GroupViewModel(chatService: chatService))
        _contactsViewModel = StateObject(wrappedValue: ContactsViewModel(chatService: chatService, currentUserId: currentUserId))
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Selection count header
                if groupViewModel.participantCount > 1 {
                    selectionHeader
                }
                
                // Search bar
                searchBar
                
                // Participant list
                participantList
            }
            .navigationTitle("New Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Next") {
                        showGroupSetup = true
                    }
                    .disabled(!groupViewModel.canCreateGroup)
                    .bold()
                }
            }
            .sheet(isPresented: $showGroupSetup) {
                GroupSetupView(groupViewModel: groupViewModel)
            }
            .task {
                // Users are already loaded by ContactsViewModel
            }
        }
    }
    
    // MARK: - Components
    
    /// Selection count header
    private var selectionHeader: some View {
        HStack {
            Text("\(groupViewModel.participantCount) participants selected")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            if groupViewModel.canCreateGroup {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else if groupViewModel.participantCount < 3 {
                Text("Select at least 3")
                    .font(.caption)
                    .foregroundColor(.orange)
            } else if groupViewModel.participantCount > 50 {
                Text("Max 50 participants")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
    }
    
    /// Search bar
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            TextField("Search", text: $searchText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            
            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(8)
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
    
    /// Participant list
    private var participantList: some View {
        Group {
            if contactsViewModel.isLoading {
                ProgressView("Loading contacts...")
                    .frame(maxHeight: .infinity)
            } else if filteredUsers.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(filteredUsers) { user in
                        ParticipantRowView(
                            user: user,
                            isSelected: groupViewModel.isSelected(user.id)
                        ) {
                            groupViewModel.toggleParticipant(user.id)
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
    }
    
    /// Empty state
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            
            Text("No contacts found")
                .font(.headline)
            
            if !searchText.isEmpty {
                Text("Try a different search")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                Text("Add contacts to create groups")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxHeight: .infinity)
    }
}

// MARK: - Participant Row View

/// Individual participant row with selection checkbox
struct ParticipantRowView: View {
    let user: User
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Profile photo
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Text(user.displayName.prefix(1))
                            .font(.title2)
                            .bold()
                            .foregroundColor(.blue)
                    )
                
                // User info
                VStack(alignment: .leading, spacing: 4) {
                    Text(user.displayName)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(user.email)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Selection indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(isSelected ? .blue : .gray.opacity(0.3))
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    ParticipantSelectionView(currentUserId: "preview-user")
}

