//
//  ConversationEntity+CoreDataClass.swift
//  messAI
//
//  Created by Isaac Jaramillo on October 20, 2025.
//

import Foundation
import CoreData

@objc(ConversationEntity)
public class ConversationEntity: NSManagedObject {
    
    // MARK: - Convenience Initializer
    
    /// Creates a ConversationEntity from a Conversation model
    convenience init(context: NSManagedObjectContext, from conversation: Conversation) {
        self.init(context: context)
        self.id = conversation.id
        self.participantIds = conversation.participants  // Changed from participantIds
        self.isGroup = conversation.isGroup
        self.groupName = conversation.groupName
        self.lastMessage = conversation.lastMessage
        self.lastMessageAt = conversation.lastMessageAt
        self.createdBy = conversation.createdBy
        self.createdAt = conversation.createdAt
        self.unreadCount = 0
    }
    
    // MARK: - Conversion to Swift Model
    
    /// Converts Core Data entity to Swift Conversation model
    /// Note: Creates simplified Conversation with essential fields only
    func toConversation() -> Conversation {
        Conversation(
            id: self.id,
            participants: self.participantIds,  // Changed from participantIds
            isGroup: self.isGroup,
            groupName: self.groupName,
            groupPhotoURL: nil,  // Not stored locally for simplicity
            lastMessage: self.lastMessage,
            lastMessageAt: self.lastMessageAt,
            lastMessageSenderId: nil,  // Not stored locally
            createdBy: self.createdBy,
            createdAt: self.createdAt,
            unreadCount: [:],  // Not stored locally (complex dictionary)
            admins: nil  // Not stored locally
        )
    }
}

