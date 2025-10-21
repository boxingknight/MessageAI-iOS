//
//  ConversationRowView.swift
//  messAI
//
//  Created by Isaac Jaramillo on 10/20/25.
//

import SwiftUI

struct ConversationRowView: View {
    let conversation: Conversation
    let conversationName: String
    let photoURL: String?
    let unreadCount: Int
    let isOnline: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Profile Picture
            profilePicture
            
            // Conversation Info
            VStack(alignment: .leading, spacing: 4) {
                // Name
                Text(conversationName)
                    .font(.headline)
                    .lineLimit(1)
                
                // Last Message
                Text(conversation.lastMessage)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            // Timestamp + Badge
            VStack(alignment: .trailing, spacing: 4) {
                // Timestamp
                Text(conversation.lastMessageAt.relativeDateString())
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                // Unread Badge
                if unreadCount > 0 {
                    unreadBadge
                }
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle()) // Make entire row tappable
    }
    
    // MARK: - Subviews
    
    private var profilePicture: some View {
        ZStack(alignment: .bottomTrailing) {
            // Profile Image
            Group {
                if let photoURL = photoURL, let url = URL(string: photoURL) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        case .failure:
                            placeholderImage
                        @unknown default:
                            placeholderImage
                        }
                    }
                } else {
                    placeholderImage
                }
            }
            .frame(width: 56, height: 56)
            .clipShape(Circle())
            
            // Online Indicator
            if isOnline && !conversation.isGroup {
                Circle()
                    .fill(Color.green)
                    .frame(width: 16, height: 16)
                    .overlay(
                        Circle()
                            .stroke(Color(.systemBackground), lineWidth: 2)
                    )
            }
        }
    }
    
    private var placeholderImage: some View {
        ZStack {
            Circle()
                .fill(Color.gray.opacity(0.3))
            
            Image(systemName: conversation.isGroup ? "person.3.fill" : "person.fill")
                .font(.title2)
                .foregroundColor(.gray)
        }
    }
    
    private var unreadBadge: some View {
        Text("\(unreadCount)")
            .font(.caption2)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.blue)
            .clipShape(Capsule())
    }
}

// MARK: - Preview

struct ConversationRowView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // One-on-one chat
            ConversationRowView(
                conversation: Conversation(
                    id: "1",
                    participants: ["user1", "user2"],
                    isGroup: false,
                    groupName: nil,
                    lastMessage: "Hey! How are you doing today?",
                    lastMessageAt: Date().addingTimeInterval(-300), // 5 min ago
                    createdBy: "user1",
                    createdAt: Date()
                ),
                conversationName: "Jane Doe",
                photoURL: nil,
                unreadCount: 3,
                isOnline: true
            )
            .previewLayout(.sizeThatFits)
            .padding()
            .previewDisplayName("One-on-One Chat")
            
            // Group chat
            ConversationRowView(
                conversation: Conversation(
                    id: "2",
                    participants: ["user1", "user2", "user3"],
                    isGroup: true,
                    groupName: "Weekend Plans",
                    lastMessage: "John: Sounds good!",
                    lastMessageAt: Date().addingTimeInterval(-3600), // 1 hour ago
                    createdBy: "user1",
                    createdAt: Date()
                ),
                conversationName: "Weekend Plans",
                photoURL: nil,
                unreadCount: 0,
                isOnline: false
            )
            .previewLayout(.sizeThatFits)
            .padding()
            .previewDisplayName("Group Chat")
        }
    }
}

