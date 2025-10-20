//
//  Conversation.swift
//  messAI
//
//  Created by Isaac Jaramillo on 10/20/25.
//

import Foundation
import FirebaseFirestore

/// Represents a chat conversation (one-on-one or group)
struct Conversation: Identifiable, Codable, Equatable, Hashable {
    // MARK: - Identity
    let id: String
    
    // MARK: - Participants
    let participants: [String]
    let isGroup: Bool
    let groupName: String?
    let groupPhotoURL: String?
    
    // MARK: - Last Message (for preview)
    var lastMessage: String
    var lastMessageAt: Date
    var lastMessageSenderId: String?
    
    // MARK: - Metadata
    let createdBy: String
    let createdAt: Date
    
    // MARK: - Read Status (per user)
    var unreadCount: [String: Int]
    
    // MARK: - Group Settings (for group chats)
    var admins: [String]?
    
    // MARK: - Initializers
    
    /// Full initializer with all properties
    init(
        id: String,
        participants: [String],
        isGroup: Bool,
        groupName: String?,
        groupPhotoURL: String?,
        lastMessage: String,
        lastMessageAt: Date,
        lastMessageSenderId: String?,
        createdBy: String,
        createdAt: Date,
        unreadCount: [String: Int],
        admins: [String]?
    ) {
        self.id = id
        self.participants = participants
        self.isGroup = isGroup
        self.groupName = groupName
        self.groupPhotoURL = groupPhotoURL
        self.lastMessage = lastMessage
        self.lastMessageAt = lastMessageAt
        self.lastMessageSenderId = lastMessageSenderId
        self.createdBy = createdBy
        self.createdAt = createdAt
        self.unreadCount = unreadCount
        self.admins = admins
    }
    
    /// Initializer for new 1-on-1 conversation
    init(participant1: String, participant2: String, createdBy: String) {
        self.id = UUID().uuidString
        self.participants = [participant1, participant2]
        self.isGroup = false
        self.groupName = nil
        self.groupPhotoURL = nil
        self.lastMessage = ""
        self.lastMessageAt = Date()
        self.lastMessageSenderId = nil
        self.createdBy = createdBy
        self.createdAt = Date()
        self.unreadCount = [:]
        self.admins = nil
    }
    
    /// Initializer for new group conversation
    init(participants: [String], groupName: String, createdBy: String) {
        self.id = UUID().uuidString
        self.participants = participants
        self.isGroup = true
        self.groupName = groupName
        self.groupPhotoURL = nil
        self.lastMessage = ""
        self.lastMessageAt = Date()
        self.lastMessageSenderId = nil
        self.createdBy = createdBy
        self.createdAt = Date()
        self.unreadCount = [:]
        self.admins = [createdBy] // Creator is admin by default
    }
}

// MARK: - Computed Properties

extension Conversation {
    /// Get the other participant in a 1-on-1 chat
    func otherParticipant(currentUserId: String) -> String? {
        guard !isGroup else { return nil }
        return participants.first { $0 != currentUserId }
    }
    
    /// Get display name for the conversation
    func displayName(currentUserId: String, users: [String: User]) -> String {
        if isGroup {
            return groupName ?? "Group Chat"
        } else if let otherUserId = otherParticipant(currentUserId: currentUserId),
                  let user = users[otherUserId] {
            return user.displayName
        } else {
            return "Unknown"
        }
    }
    
    /// Get display photo URL for the conversation
    func displayPhotoURL(currentUserId: String, users: [String: User]) -> String? {
        if isGroup {
            return groupPhotoURL
        } else if let otherUserId = otherParticipant(currentUserId: currentUserId),
                  let user = users[otherUserId] {
            return user.photoURL
        }
        return nil
    }
    
    /// Get unread count for a specific user
    func unreadCountFor(userId: String) -> Int {
        unreadCount[userId] ?? 0
    }
    
    /// Check if a user is an admin (for group chats)
    func isAdmin(userId: String) -> Bool {
        admins?.contains(userId) ?? false
    }
}

// MARK: - Firestore Conversion

extension Conversation {
    /// Convert conversation to Firestore-compatible dictionary
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "participants": participants,
            "isGroup": isGroup,
            "lastMessage": lastMessage,
            "lastMessageAt": Timestamp(date: lastMessageAt),
            "createdBy": createdBy,
            "createdAt": Timestamp(date: createdAt),
            "unreadCount": unreadCount
        ]
        
        // Optional fields
        if let groupName = groupName {
            dict["groupName"] = groupName
        }
        if let groupPhotoURL = groupPhotoURL {
            dict["groupPhotoURL"] = groupPhotoURL
        }
        if let lastMessageSenderId = lastMessageSenderId {
            dict["lastMessageSenderId"] = lastMessageSenderId
        }
        if let admins = admins {
            dict["admins"] = admins
        }
        
        return dict
    }
    
    /// Create conversation from Firestore dictionary
    init?(dictionary: [String: Any]) {
        guard
            let id = dictionary["id"] as? String,
            let participants = dictionary["participants"] as? [String],
            let isGroup = dictionary["isGroup"] as? Bool,
            let lastMessage = dictionary["lastMessage"] as? String,
            let lastMessageAtTimestamp = dictionary["lastMessageAt"] as? Timestamp,
            let createdBy = dictionary["createdBy"] as? String,
            let createdAtTimestamp = dictionary["createdAt"] as? Timestamp
        else {
            return nil
        }
        
        self.id = id
        self.participants = participants
        self.isGroup = isGroup
        self.lastMessage = lastMessage
        self.lastMessageAt = lastMessageAtTimestamp.dateValue()
        self.createdBy = createdBy
        self.createdAt = createdAtTimestamp.dateValue()
        
        // Optional fields
        self.unreadCount = dictionary["unreadCount"] as? [String: Int] ?? [:]
        self.groupName = dictionary["groupName"] as? String
        self.groupPhotoURL = dictionary["groupPhotoURL"] as? String
        self.lastMessageSenderId = dictionary["lastMessageSenderId"] as? String
        self.admins = dictionary["admins"] as? [String]
    }
}

