//
//  GroupInfoView.swift
//  messAI
//
//  Created for PR #13: Group Chat Functionality
//

import SwiftUI
import FirebaseAuth

/// View for displaying and managing group information
struct GroupInfoView: View {
    
    // MARK: - Environment
    
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Properties
    
    let conversation: Conversation
    let users: [String: User]
    
    // MARK: - ViewModels
    
    @StateObject private var groupViewModel = GroupViewModel()
    
    // MARK: - State
    
    @State private var showEditName: Bool = false
    @State private var showAddParticipants: Bool = false
    @State private var showLeaveConfirmation: Bool = false
    @State private var editedGroupName: String = ""
    @State private var selectedParticipantForAction: String?
    
    // MARK: - Computed Properties
    
    private var currentUserId: String {
        Auth.auth().currentUser?.uid ?? ""
    }
    
    private var isCurrentUserAdmin: Bool {
        conversation.isAdmin(userId: currentUserId)
    }
    
    private var isCurrentUserCreator: Bool {
        conversation.createdBy == currentUserId
    }
    
    private var sortedParticipants: [(id: String, user: User?)] {
        conversation.participants.map { participantId in
            (id: participantId, user: users[participantId])
        }.sorted { lhs, rhs in
            // Creator first, then admins, then by name
            if lhs.id == conversation.createdBy { return true }
            if rhs.id == conversation.createdBy { return false }
            
            let lhsIsAdmin = conversation.isAdmin(userId: lhs.id)
            let rhsIsAdmin = conversation.isAdmin(userId: rhs.id)
            
            if lhsIsAdmin != rhsIsAdmin {
                return lhsIsAdmin
            }
            
            let lhsName = lhs.user?.displayName ?? ""
            let rhsName = rhs.user?.displayName ?? ""
            return lhsName < rhsName
        }
    }
    
    // MARK: - Initialization
    
    init(conversation: Conversation, users: [String: User]) {
        self.conversation = conversation
        self.users = users
        _editedGroupName = State(initialValue: conversation.groupName ?? "")
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            List {
                // Group header section
                groupHeaderSection
                
                // Group settings (admin only)
                if isCurrentUserAdmin {
                    groupSettingsSection
                }
                
                // Participants section
                participantsSection
                
                // Leave group section
                leaveGroupSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Group Info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .bold()
                }
            }
            .alert("Edit Group Name", isPresented: $showEditName) {
                TextField("Group Name", text: $editedGroupName)
                Button("Cancel", role: .cancel) { }
                Button("Save") {
                    Task {
                        await groupViewModel.updateGroupName(
                            conversationId: conversation.id,
                            newName: editedGroupName
                        )
                    }
                }
            }
            .alert("Leave Group?", isPresented: $showLeaveConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Leave", role: .destructive) {
                    Task {
                        await groupViewModel.leaveGroup(conversationId: conversation.id)
                        dismiss()
                    }
                }
            } message: {
                Text("Are you sure you want to leave this group?")
            }
        }
    }
    
    // MARK: - Sections
    
    /// Group header section
    private var groupHeaderSection: some View {
        Section {
            VStack(spacing: 12) {
                // Group icon
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.blue.opacity(0.7), .purple.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                    .overlay(
                        Image(systemName: "person.3.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.white)
                    )
                
                // Group name
                Text(conversation.formattedGroupName(users: users, currentUserId: currentUserId))
                    .font(.title3)
                    .fontWeight(.bold)
                
                // Participant count
                Text("\(conversation.participantCount) participants")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical)
        }
    }
    
    /// Group settings section (admin only)
    private var groupSettingsSection: some View {
        Section("Group Settings") {
            // Edit group name
            Button(action: { showEditName = true }) {
                HStack {
                    Image(systemName: "pencil")
                        .foregroundColor(.blue)
                    Text("Edit Group Name")
                        .foregroundColor(.primary)
                }
            }
            
            // Add participants
            Button(action: { showAddParticipants = true }) {
                HStack {
                    Image(systemName: "person.badge.plus")
                        .foregroundColor(.green)
                    Text("Add Participants")
                        .foregroundColor(.primary)
                }
            }
        }
    }
    
    /// Participants section
    private var participantsSection: some View {
        Section("Participants") {
            ForEach(sortedParticipants, id: \.id) { participantId, user in
                participantRow(participantId: participantId, user: user)
            }
        }
    }
    
    /// Individual participant row
    private func participantRow(participantId: String, user: User?) -> some View {
        HStack(spacing: 12) {
            // Profile photo
            Circle()
                .fill(Color.blue.opacity(0.2))
                .frame(width: 40, height: 40)
                .overlay(
                    Text(user?.displayName.prefix(1) ?? "?")
                        .font(.body)
                        .bold()
                        .foregroundColor(.blue)
                )
            
            // User info
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(user?.displayName ?? "Unknown")
                        .font(.body)
                        .fontWeight(.medium)
                    
                    // Badges
                    if participantId == conversation.createdBy {
                        Text("Creator")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.purple.opacity(0.2))
                            .foregroundColor(.purple)
                            .cornerRadius(4)
                    } else if conversation.isAdmin(userId: participantId) {
                        Text("Admin")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.2))
                            .foregroundColor(.blue)
                            .cornerRadius(4)
                    }
                    
                    if participantId == currentUserId {
                        Text("You")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.2))
                            .foregroundColor(.green)
                            .cornerRadius(4)
                    }
                }
                
                Text(user?.email ?? "")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Admin actions
            if isCurrentUserAdmin && participantId != currentUserId && participantId != conversation.createdBy {
                Menu {
                    // Promote/Demote
                    if conversation.isAdmin(userId: participantId) {
                        Button(role: .destructive) {
                            Task {
                                await groupViewModel.demoteFromAdmin(
                                    conversationId: conversation.id,
                                    userId: participantId
                                )
                            }
                        } label: {
                            Label("Remove Admin", systemImage: "person.badge.minus")
                        }
                    } else {
                        Button {
                            Task {
                                await groupViewModel.promoteToAdmin(
                                    conversationId: conversation.id,
                                    userId: participantId
                                )
                            }
                        } label: {
                            Label("Make Admin", systemImage: "person.badge.plus")
                        }
                    }
                    
                    // Remove participant
                    Button(role: .destructive) {
                        Task {
                            await groupViewModel.removeParticipant(
                                from: conversation.id,
                                userId: participantId
                            )
                        }
                    } label: {
                        Label("Remove", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(.blue)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    /// Leave group section
    private var leaveGroupSection: some View {
        Section {
            Button(role: .destructive, action: {
                if isCurrentUserCreator {
                    // Creator cannot leave
                    groupViewModel.error = "Creator cannot leave the group"
                } else {
                    showLeaveConfirmation = true
                }
            }) {
                HStack {
                    Spacer()
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                    Text(isCurrentUserCreator ? "Transfer Ownership to Leave" : "Leave Group")
                    Spacer()
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    let sampleConversation = Conversation(
        participants: ["user1", "user2", "user3", "user4"],
        groupName: "Sample Group",
        createdBy: "user1"
    )
    
    let sampleUsers: [String: User] = [
        "user1": User(id: "user1", email: "alice@example.com", displayName: "Alice", photoURL: nil),
        "user2": User(id: "user2", email: "bob@example.com", displayName: "Bob", photoURL: nil),
        "user3": User(id: "user3", email: "charlie@example.com", displayName: "Charlie", photoURL: nil),
        "user4": User(id: "user4", email: "diana@example.com", displayName: "Diana", photoURL: nil)
    ]
    
    return GroupInfoView(conversation: sampleConversation, users: sampleUsers)
}

