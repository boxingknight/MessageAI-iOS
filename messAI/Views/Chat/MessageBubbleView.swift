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
    
    // Message grouping (for iMessage-style spacing)
    let isFirstInGroup: Bool
    let isLastInGroup: Bool
    
    // PR #11: Conversation for group status aggregation
    let conversation: Conversation?
    
    // PR #13: Users for group sender names
    let users: [String: User]?
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isFromCurrentUser {
                Spacer(minLength: 60)
            }
            
            VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                // PR #13: Sender name for group chats (show above first message from others)
                if let conversation = conversation,
                   conversation.isGroup,
                   !isFromCurrentUser,
                   isFirstInGroup,
                   let users = users {
                    Text(message.senderDisplayName(users: users))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.leading, 12)
                }
                
                // Message text bubble with priority border/badge (PR #17)
                ZStack(alignment: .topTrailing) {
                    Text(message.text)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(priorityBackgroundColor)
                        .foregroundColor(textColor)
                        .clipShape(messageBubbleShape)
                        .textSelection(.enabled)
                        .overlay(
                            messageBubbleShape
                                .stroke(priorityBorderColor, lineWidth: priorityBorderWidth)
                        )
                    
                    // Priority badge (PR #17)
                    if let priority = message.aiMetadata?.priorityLevel,
                       priority.shouldHighlight {
                        Image(systemName: priority.icon)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(priority.iconColor)
                            .padding(4)
                            .background(Color(.systemBackground))
                            .clipShape(Circle())
                            .offset(x: -4, y: 4)
                    }
                }
                
                // Timestamp + Status (only show on last message in group)
                if isLastInGroup {
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
            }
            
            if !isFromCurrentUser {
                Spacer(minLength: 60)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, verticalPadding)
    }
    
    // MARK: - Computed Properties
    
    private var bubbleColor: Color {
        isFromCurrentUser ? Color.blue : Color(.systemGray5)
    }
    
    private var textColor: Color {
        isFromCurrentUser ? .white : .primary
    }
    
    // MARK: - Priority Styling (PR #17)
    
    /// Priority border color based on message priority level
    private var priorityBorderColor: Color {
        guard let priority = message.aiMetadata?.priorityLevel else {
            return .clear
        }
        return priority.borderColor
    }
    
    /// Priority border width
    private var priorityBorderWidth: CGFloat {
        guard let priority = message.aiMetadata?.priorityLevel else {
            return 0
        }
        return priority.borderWidth
    }
    
    /// Priority background overlay color
    private var priorityBackgroundColor: Color {
        // Just return the normal bubble color
        // The priority background is already included in the PriorityLevel definition
        return bubbleColor
    }
    
    /// Dynamic spacing: tight for grouped messages, normal for separate messages
    private var verticalPadding: CGFloat {
        // First message in group or standalone: normal spacing
        if isFirstInGroup && isLastInGroup {
            return 6 // Standalone message
        } else if isFirstInGroup {
            return 6 // First in group: normal spacing above
        } else {
            return 1 // Grouped message: tight spacing
        }
    }
    
    /// iMessage-style bubble shape with dynamic corners
    private var messageBubbleShape: UnevenRoundedRectangle {
        let radius: CGFloat = 18
        let tightRadius: CGFloat = 6
        
        // Determine which corners should be tight based on grouping
        if isFromCurrentUser {
            // Sent messages (right side)
            if isFirstInGroup && isLastInGroup {
                // Standalone: all corners rounded
                return UnevenRoundedRectangle(
                    topLeadingRadius: radius,
                    bottomLeadingRadius: radius,
                    bottomTrailingRadius: radius,
                    topTrailingRadius: radius
                )
            } else if isFirstInGroup {
                // First in group: tight bottom-right
                return UnevenRoundedRectangle(
                    topLeadingRadius: radius,
                    bottomLeadingRadius: radius,
                    bottomTrailingRadius: tightRadius,
                    topTrailingRadius: radius
                )
            } else if isLastInGroup {
                // Last in group: tight top-right
                return UnevenRoundedRectangle(
                    topLeadingRadius: radius,
                    bottomLeadingRadius: radius,
                    bottomTrailingRadius: radius,
                    topTrailingRadius: tightRadius
                )
            } else {
                // Middle: tight top-right and bottom-right
                return UnevenRoundedRectangle(
                    topLeadingRadius: radius,
                    bottomLeadingRadius: radius,
                    bottomTrailingRadius: tightRadius,
                    topTrailingRadius: tightRadius
                )
            }
        } else {
            // Received messages (left side)
            if isFirstInGroup && isLastInGroup {
                // Standalone: all corners rounded
                return UnevenRoundedRectangle(
                    topLeadingRadius: radius,
                    bottomLeadingRadius: radius,
                    bottomTrailingRadius: radius,
                    topTrailingRadius: radius
                )
            } else if isFirstInGroup {
                // First in group: tight bottom-left
                return UnevenRoundedRectangle(
                    topLeadingRadius: radius,
                    bottomLeadingRadius: tightRadius,
                    bottomTrailingRadius: radius,
                    topTrailingRadius: radius
                )
            } else if isLastInGroup {
                // Last in group: tight top-left
                return UnevenRoundedRectangle(
                    topLeadingRadius: tightRadius,
                    bottomLeadingRadius: radius,
                    bottomTrailingRadius: radius,
                    topTrailingRadius: radius
                )
            } else {
                // Middle: tight top-left and bottom-left
                return UnevenRoundedRectangle(
                    topLeadingRadius: tightRadius,
                    bottomLeadingRadius: tightRadius,
                    bottomTrailingRadius: radius,
                    topTrailingRadius: radius
                )
            }
        }
    }
    
    // PR #11: Enhanced status icon with group aggregation
    private var statusIcon: some View {
        Group {
            // Determine status (with group aggregation if conversation provided)
            let displayStatus: MessageStatus = {
                if let conversation = conversation {
                    return message.statusForSender(in: conversation)
                } else {
                    return message.status
                }
            }()
            
            // Display appropriate icon based on status
            switch displayStatus {
            case .sending:
                Image(systemName: "clock.fill")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .accessibilityLabel(message.statusText())
            case .sent:
                Image(systemName: "checkmark")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .accessibilityLabel(message.statusText())
            case .delivered:
                HStack(spacing: -2) {
                    Image(systemName: "checkmark")
                    Image(systemName: "checkmark")
                }
                .font(.caption2)
                .foregroundColor(.secondary)
                .accessibilityLabel(message.statusText())
            case .read:
                HStack(spacing: -2) {
                    Image(systemName: "checkmark")
                    Image(systemName: "checkmark")
                }
                .font(.caption2)
                .foregroundColor(.blue)
                .accessibilityLabel(message.statusText())
            case .failed:
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.caption2)
                    .foregroundColor(.red)
                    .accessibilityLabel(message.statusText())
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

#Preview("Message Grouping") {
    ScrollView {
        VStack(spacing: 0) {
            // Standalone message
            MessageBubbleView(
                message: Message(
                    id: "1",
                    conversationId: "conv1",
                    senderId: "user1",
                    text: "Hey there!",
                    sentAt: Date(),
                    status: .delivered
                ),
                isFromCurrentUser: false,
                isFirstInGroup: true,
                isLastInGroup: true,
                conversation: nil,
                users: nil
            )
            
            // Grouped messages from same sender
            MessageBubbleView(
                message: Message(
                    id: "2",
                    conversationId: "conv1",
                    senderId: "user2",
                    text: "I'm great!",
                    sentAt: Date(),
                    status: .sent
                ),
                isFromCurrentUser: true,
                isFirstInGroup: true,
                isLastInGroup: false,
                conversation: nil,
                users: nil
            )
            
            MessageBubbleView(
                message: Message(
                    id: "3",
                    conversationId: "conv1",
                    senderId: "user2",
                    text: "Thanks for asking",
                    sentAt: Date(),
                    status: .sent
                ),
                isFromCurrentUser: true,
                isFirstInGroup: false,
                isLastInGroup: false,
                conversation: nil,
                users: nil
            )
            
            MessageBubbleView(
                message: Message(
                    id: "4",
                    conversationId: "conv1",
                    senderId: "user2",
                    text: "How about you?",
                    sentAt: Date(),
                    status: .read
                ),
                isFromCurrentUser: true,
                isFirstInGroup: false,
                isLastInGroup: true,
                conversation: nil,
                users: nil
            )
            
            // Another standalone
            MessageBubbleView(
                message: Message(
                    id: "5",
                    conversationId: "conv1",
                    senderId: "user1",
                    text: "Doing well!",
                    sentAt: Date(),
                    status: .sent
                ),
                isFromCurrentUser: false,
                isFirstInGroup: true,
                isLastInGroup: true,
                conversation: nil,
                users: nil
            )
        }
        .padding()
    }
}

