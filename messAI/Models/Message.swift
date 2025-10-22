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
    
    // MARK: - AI Metadata (PR #14)
    var aiMetadata: AIMetadata?
    
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
        senderPhotoURL: String? = nil,
        aiMetadata: AIMetadata? = nil
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
        self.aiMetadata = aiMetadata
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
        print("🔍 [Message] statusForSender called for message: \(id)")
        print("   Current status: \(status)")
        print("   deliveredTo: \(deliveredTo)")
        print("   readBy: \(readBy)")
        print("   senderId: \(senderId)")
        print("   conversation participants: \(conversation.participants)")
        
        // If failed or sending, show that status regardless
        if status == .failed || status == .sending {
            print("   ⏱ Returning \(status) (failed or sending)")
            return status
        }
        
        // For both 1-on-1 and group chats: check recipient status
        let otherParticipants = conversation.participants.filter { $0 != senderId }
        print("   Other participants: \(otherParticipants)")
        
        // Check if all recipients have read
        let allRead = otherParticipants.allSatisfy { readBy.contains($0) }
        print("   All read? \(allRead)")
        if allRead { 
            print("   ✅ Returning .read")
            return .read 
        }
        
        // Check if all recipients have received
        let allDelivered = otherParticipants.allSatisfy { deliveredTo.contains($0) }
        print("   All delivered? \(allDelivered)")
        if allDelivered { 
            print("   ✅ Returning .delivered")
            return .delivered 
        }
        
        // At least sent to server
        print("   ✅ Returning .sent (default)")
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
    
    // MARK: - Group Chat Helpers (PR #13)
    
    /// Should show sender name (for group chats from other users)
    func shouldShowSenderName(in conversation: Conversation) -> Bool {
        guard conversation.isGroup else { return false }
        return !isFromCurrentUser
    }
    
    /// Get display name for sender in group context
    func senderDisplayName(users: [String: User]) -> String {
        if let senderName = senderName {
            return senderName
        }
        return users[senderId]?.displayName ?? "Unknown"
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
        
        // PR #14: AI metadata
        if let aiMetadata = aiMetadata {
            if let data = try? JSONEncoder().encode(aiMetadata),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                dict["aiMetadata"] = json
            }
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
        
        // PR #14: AI metadata
        if let aiMetadataDict = dictionary["aiMetadata"] as? [String: Any],
           let jsonData = try? JSONSerialization.data(withJSONObject: aiMetadataDict),
           let metadata = try? JSONDecoder().decode(AIMetadata.self, from: jsonData) {
            self.aiMetadata = metadata
        } else {
            self.aiMetadata = nil
        }
    }
}

