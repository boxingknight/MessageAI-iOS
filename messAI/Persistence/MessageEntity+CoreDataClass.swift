//
//  MessageEntity+CoreDataClass.swift
//  messAI
//
//  Created by Isaac Jaramillo on October 20, 2025.
//

import Foundation
import CoreData

@objc(MessageEntity)
public class MessageEntity: NSManagedObject {
    
    // MARK: - Convenience Initializer
    
    /// Creates a MessageEntity from a Message model
    convenience init(context: NSManagedObjectContext, from message: Message) {
        self.init(context: context)
        self.id = message.id
        self.conversationId = message.conversationId
        self.senderId = message.senderId
        self.text = message.text
        self.imageURL = message.imageURL
        self.sentAt = message.sentAt
        self.deliveredAt = message.deliveredAt
        self.readAt = message.readAt
        self.status = message.status.rawValue
        self.isSynced = false
        self.syncAttempts = 0
        self.needsSync = true
        self.lastSyncError = nil
    }
    
    // MARK: - Conversion to Swift Model
    
    /// Converts Core Data entity to Swift Message model
    func toMessage() -> Message {
        Message(
            id: self.id,
            conversationId: self.conversationId,
            senderId: self.senderId,
            text: self.text,
            imageURL: self.imageURL,
            sentAt: self.sentAt,
            deliveredAt: self.deliveredAt,
            readAt: self.readAt,
            status: MessageStatus(rawValue: self.status) ?? .sending
        )
    }
}

