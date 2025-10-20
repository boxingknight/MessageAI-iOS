//
//  Message.swift
//  messAI
//
//  Created by Isaac Jaramillo on 10/20/25.
//

import Foundation
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
            "status": status.rawValue
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
        
        // Optional fields
        self.imageURL = dictionary["imageURL"] as? String
        self.deliveredAt = (dictionary["deliveredAt"] as? Timestamp)?.dateValue()
        self.readAt = (dictionary["readAt"] as? Timestamp)?.dateValue()
        self.senderName = dictionary["senderName"] as? String
        self.senderPhotoURL = dictionary["senderPhotoURL"] as? String
    }
}

