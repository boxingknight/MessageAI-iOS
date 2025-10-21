//
//  MessageBubbleView.swift
//  messAI
//
//  Created for PR #9 - Chat View UI Components
//  Individual message bubble display
//

import SwiftUI

struct MessageBubbleView: View {
    let message: Message
    let isFromCurrentUser: Bool
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isFromCurrentUser {
                Spacer(minLength: 60)
            }
            
            VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                // Message text bubble
                Text(message.text)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(bubbleColor)
                    .foregroundColor(textColor)
                    .cornerRadius(18)
                    .textSelection(.enabled)
                
                // Timestamp + Status (bottom of bubble)
                HStack(spacing: 4) {
                    Text(formatTime(message.sentAt))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    // Status indicator (sent/delivered/read) - only for sent messages
                    if isFromCurrentUser {
                        statusIcon
                    }
                }
            }
            
            if !isFromCurrentUser {
                Spacer(minLength: 60)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 2)
    }
    
    // MARK: - Computed Properties
    
    private var bubbleColor: Color {
        isFromCurrentUser ? Color.blue : Color(.systemGray5)
    }
    
    private var textColor: Color {
        isFromCurrentUser ? .white : .primary
    }
    
    private var statusIcon: some View {
        Group {
            switch message.status {
            case .sending:
                Image(systemName: "clock.fill")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            case .sent:
                Image(systemName: "checkmark")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            case .delivered:
                HStack(spacing: -2) {
                    Image(systemName: "checkmark")
                    Image(systemName: "checkmark")
                }
                .font(.caption2)
                .foregroundColor(.secondary)
            case .read:
                HStack(spacing: -2) {
                    Image(systemName: "checkmark")
                    Image(systemName: "checkmark")
                }
                .font(.caption2)
                .foregroundColor(.blue)
            case .failed:
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.caption2)
                    .foregroundColor(.red)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview("Sent and Received Messages") {
    VStack(spacing: 12) {
        MessageBubbleView(
            message: Message(
                id: "1",
                conversationId: "conv1",
                senderId: "user1",
                text: "Hey, how are you doing today?",
                sentAt: Date(),
                status: .delivered
            ),
            isFromCurrentUser: false
        )
        
        MessageBubbleView(
            message: Message(
                id: "2",
                conversationId: "conv1",
                senderId: "user2",
                text: "I'm great! Thanks for asking. How about you?",
                sentAt: Date(),
                status: .read
            ),
            isFromCurrentUser: true
        )
        
        MessageBubbleView(
            message: Message(
                id: "3",
                conversationId: "conv1",
                senderId: "user1",
                text: "Doing well! Just working on some projects.",
                sentAt: Date(),
                status: .sent
            ),
            isFromCurrentUser: false
        )
        
        MessageBubbleView(
            message: Message(
                id: "4",
                conversationId: "conv1",
                senderId: "user2",
                text: "That's awesome! Keep up the good work!",
                sentAt: Date(),
                status: .sending
            ),
            isFromCurrentUser: true
        )
    }
    .padding()
}

