//
//  Message.swift
//  messAI
//
//  Created by Isaac Jaramillo on 10/20/25.
//

import Foundation
import SwiftUI
import FirebaseFirestore
import FirebaseAuth

/// Represents a single message in a conversation
struct Message: Identifiable, Codable, Equatable, Hashable {
    // MARK: - Identity
    let id: String
    let conversationId: String
    let senderId: String
    
    // MARK: - Content
    let text: String
    let imageURL: String?
    
    // MARK: - Timestamps
    let sentAt: Date
    var deliveredAt: Date?
    var readAt: Date?
    
    // MARK: - State
    var status: MessageStatus
    
    // MARK: - Recipient Tracking (PR #11)
    var deliveredTo: [String] = []  // Array of user IDs who received message
    var readBy: [String] = []       // Array of user IDs who read message
    
    // MARK: - Metadata (cached for convenience)
    let senderName: String?
    let senderPhotoURL: String?
    
    // MARK: - Initializers
    
    /// Full initializer with all properties
    init(
        id: String,
        conversationId: String,
        senderId: String,
        text: String,
        imageURL: String? = nil,
        sentAt: Date = Date(),
        deliveredAt: Date? = nil,
        readAt: Date? = nil,
        status: MessageStatus = .sending,
        deliveredTo: [String] = [],
        readBy: [String] = [],
        senderName: String? = nil,
        senderPhotoURL: String? = nil
    ) {
        self.id = id
        self.conversationId = conversationId
        self.senderId = senderId
        self.text = text
        self.imageURL = imageURL
        self.sentAt = sentAt
        self.deliveredAt = deliveredAt
        self.readAt = readAt
        self.status = status
        self.deliveredTo = deliveredTo
        self.readBy = readBy
        self.senderName = senderName
        self.senderPhotoURL = senderPhotoURL
    }
    
    /// Convenience initializer for creating new messages
    init(
        conversationId: String,
        senderId: String,
        text: String,
        senderName: String? = nil,
        senderPhotoURL: String? = nil
    ) {
        self.init(
            id: UUID().uuidString,
            conversationId: conversationId,
            senderId: senderId,
            text: text,
            imageURL: nil,
            sentAt: Date(),
            deliveredAt: nil,
            readAt: nil,
            status: .sending,
            senderName: senderName,
            senderPhotoURL: senderPhotoURL
        )
    }
}

// MARK: - Computed Properties

extension Message {
    /// Check if message is from the current user
    var isFromCurrentUser: Bool {
        senderId == (Auth.auth().currentUser?.uid ?? "")
    }
    
    /// Check if message has been delivered
    var isDelivered: Bool {
        status == .delivered || status == .read
    }
    
    /// Check if message has been read
    var isRead: Bool {
        status == .read
    }
    
    /// Time since sent (for UI display)
    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: sentAt, relativeTo: Date())
    }
    
    // MARK: - Status Display Helpers (PR #11)
    
    /// Returns status from sender's perspective (handles group aggregation)
    func statusForSender(in conversation: Conversation) -> MessageStatus {
        // If failed or sending, show that status regardless
        if status == .failed || status == .sending {
            return status
        }
        
        // For 1-on-1 chats, return actual status
        if !conversation.isGroup {
            return status
        }
        
        // For group chats: aggregate based on recipients (show worst status)
        let otherParticipants = conversation.participants.filter { $0 != senderId }
        
        // Check if all recipients have read
        let allRead = otherParticipants.allSatisfy { readBy.contains($0) }
        if allRead { return .read }
        
        // Check if all recipients have received
        let allDelivered = otherParticipants.allSatisfy { deliveredTo.contains($0) }
        if allDelivered { return .delivered }
        
        // At least sent to server
        return .sent
    }
    
    /// Returns SF Symbol name for status icon
    func statusIcon() -> String {
        switch status {
        case .sending:
            return "clock"
        case .sent:
            return "checkmark"
        case .delivered:
            return "checkmark.circle"
        case .read:
            return "checkmark.circle.fill"
        case .failed:
            return "exclamationmark.triangle.fill"
        }
    }
    
    /// Returns color for status icon
    func statusColor() -> Color {
        switch status {
        case .sending:
            return .gray.opacity(0.6)
        case .sent:
            return .gray
        case .delivered:
            return .gray
        case .read:
            return .blue
        case .failed:
            return .red
        }
    }
    
    /// Returns accessibility label for status
    func statusText() -> String {
        switch status {
        case .sending: return "Sending"
        case .sent: return "Sent"
        case .delivered: return "Delivered"
        case .read: return "Read"
        case .failed: return "Failed to send"
        }
    }
}

// MARK: - Firestore Conversion

extension Message {
    /// Convert message to Firestore-compatible dictionary
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "conversationId": conversationId,
            "senderId": senderId,
            "text": text,
            "sentAt": Timestamp(date: sentAt),
            "status": status.rawValue,
            "deliveredTo": deliveredTo,  // PR #11: Recipient tracking
            "readBy": readBy              // PR #11: Recipient tracking
        ]
        
        // Optional fields
        if let imageURL = imageURL {
            dict["imageURL"] = imageURL
        }
        if let deliveredAt = deliveredAt {
            dict["deliveredAt"] = Timestamp(date: deliveredAt)
        }
        if let readAt = readAt {
            dict["readAt"] = Timestamp(date: readAt)
        }
        if let senderName = senderName {
            dict["senderName"] = senderName
        }
        if let senderPhotoURL = senderPhotoURL {
            dict["senderPhotoURL"] = senderPhotoURL
        }
        
        return dict
    }
    
    /// Create message from Firestore dictionary
    init?(dictionary: [String: Any]) {
        guard
            let id = dictionary["id"] as? String,
            let conversationId = dictionary["conversationId"] as? String,
            let senderId = dictionary["senderId"] as? String,
            let text = dictionary["text"] as? String,
            let sentAtTimestamp = dictionary["sentAt"] as? Timestamp,
            let statusString = dictionary["status"] as? String,
            let status = MessageStatus(rawValue: statusString)
        else {
            return nil
        }
        
        self.id = id
        self.conversationId = conversationId
        self.senderId = senderId
        self.text = text
        self.sentAt = sentAtTimestamp.dateValue()
        self.status = status
        
        // PR #11: Parse recipient tracking arrays
        self.deliveredTo = dictionary["deliveredTo"] as? [String] ?? []
        self.readBy = dictionary["readBy"] as? [String] ?? []
        
        // Optional fields
        self.imageURL = dictionary["imageURL"] as? String
        self.deliveredAt = (dictionary["deliveredAt"] as? Timestamp)?.dateValue()
        self.readAt = (dictionary["readAt"] as? Timestamp)?.dateValue()
        self.senderName = dictionary["senderName"] as? String
        self.senderPhotoURL = dictionary["senderPhotoURL"] as? String
    }
}

