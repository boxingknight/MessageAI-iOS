//
//  GroupSetupView.swift
//  messAI
//
//  Created for PR #13: Group Chat Functionality
//

import SwiftUI

/// View for setting up a new group (name, photo, etc.)
struct GroupSetupView: View {
    
    // MARK: - Environment
    
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - ViewModels
    
    @ObservedObject var groupViewModel: GroupViewModel
    
    // MARK: - State
    
    @State private var showCreatedGroup: Bool = false
    @FocusState private var isGroupNameFocused: Bool
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Group icon placeholder
                groupIcon
                
                // Group name input
                groupNameField
                
                // Participant count
                participantInfo
                
                Spacer()
                
                // Create button
                createButton
                
                // Error message
                if let error = groupViewModel.error {
                    errorView(error)
                }
            }
            .padding()
            .navigationTitle("New Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back") {
                        dismiss()
                    }
                }
            }
            .onChange(of: groupViewModel.createdConversation) { _, newConversation in
                if newConversation != nil {
                    // Group created successfully!
                    showCreatedGroup = true
                    // Dismiss this sheet and parent sheet
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Components
    
    /// Group icon placeholder
    private var groupIcon: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [.blue.opacity(0.7), .purple.opacity(0.7)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 100, height: 100)
            .overlay(
                Image(systemName: "person.3.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.white)
            )
            .padding(.top, 20)
    }
    
    /// Group name field
    private var groupNameField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Group Name")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            TextField("Enter group name (optional)", text: $groupViewModel.groupName)
                .textFieldStyle(.roundedBorder)
                .focused($isGroupNameFocused)
                .submitLabel(.done)
                .onAppear {
                    isGroupNameFocused = true
                }
            
            Text("Leave blank for auto-generated name")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    /// Participant info
    private var participantInfo: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "person.2.fill")
                    .foregroundColor(.blue)
                
                Text("\(groupViewModel.participantCount) participants")
                    .font(.body)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
            
            Text("You and \(groupViewModel.selectedParticipants.count) others")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    /// Create button
    private var createButton: some View {
        Button(action: {
            Task {
                await groupViewModel.createGroup()
            }
        }) {
            if groupViewModel.isCreating {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
            } else {
                Text("Create Group")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
            }
        }
        .background(
            groupViewModel.canCreateGroup ? Color.blue : Color.gray
        )
        .cornerRadius(12)
        .disabled(!groupViewModel.canCreateGroup || groupViewModel.isCreating)
    }
    
    /// Error view
    private func errorView(_ error: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
            
            Text(error)
                .font(.caption)
                .foregroundColor(.red)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.red.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Preview

#Preview {
    GroupSetupView(groupViewModel: GroupViewModel())
}

