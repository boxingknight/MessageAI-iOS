//
//  ToastMessage.swift
//  messAI
//
//  Created for PR#17.1: In-App Toast Notifications
//

import Foundation

/// Model for in-app toast notifications
/// Displays when user receives message in a different conversation than currently active
struct ToastMessage: Identifiable, Equatable {
    /// Unique identifier for the toast
    let id: String
    
    /// ID of the conversation this message belongs to
    let conversationId: String
    
    /// ID of the user who sent the message
    let senderId: String
    
    /// Display name of the sender
    let senderName: String
    
    /// Optional profile photo URL of the sender
    let senderPhotoURL: String?
    
    /// The message text (can be nil for image messages)
    let messageText: String?
    
    /// Whether this is an image message
    let isImageMessage: Bool
    
    /// When the message was sent
    let timestamp: Date
    
    // MARK: - Computed Properties
    
    /// Text to display in the toast (truncated to 50 characters)
    var displayText: String {
        if isImageMessage {
            return "📷 Image"
        }
        
        guard let text = messageText, !text.isEmpty else {
            return "New message"
        }
        
        // Truncate at 50 characters
        if text.count > 50 {
            let truncated = String(text.prefix(50))
            return truncated + "..."
        }
        
        return text
    }
    
    /// Initials from sender name (for profile picture fallback)
    var senderInitials: String {
        let components = senderName.split(separator: " ")
        if components.count >= 2 {
            // First name + Last name
            let first = components[0].prefix(1)
            let last = components[1].prefix(1)
            return "\(first)\(last)".uppercased()
        } else if let first = components.first {
            // Just first name
            return String(first.prefix(1)).uppercased()
        } else {
            return "?"
        }
    }
    
    // MARK: - Equatable
    
    static func == (lhs: ToastMessage, rhs: ToastMessage) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Preview Helpers

#if DEBUG
extension ToastMessage {
    /// Sample toast for previews
    static var sample: ToastMessage {
        ToastMessage(
            id: "toast-1",
            conversationId: "conv-1",
            senderId: "user-1",
            senderName: "Bob Test",
            senderPhotoURL: nil,
            messageText: "Hey, are you there? I wanted to ask you something about the project.",
            isImageMessage: false,
            timestamp: Date()
        )
    }
    
    /// Sample toast with image
    static var sampleImage: ToastMessage {
        ToastMessage(
            id: "toast-2",
            conversationId: "conv-2",
            senderId: "user-2",
            senderName: "Alice Johnson",
            senderPhotoURL: nil,
            messageText: nil,
            isImageMessage: true,
            timestamp: Date()
        )
    }
    
    /// Sample toast with short message
    static var sampleShort: ToastMessage {
        ToastMessage(
            id: "toast-3",
            conversationId: "conv-3",
            senderId: "user-3",
            senderName: "Charlie",
            senderPhotoURL: nil,
            messageText: "👍",
            isImageMessage: false,
            timestamp: Date()
        )
    }
}
#endif

