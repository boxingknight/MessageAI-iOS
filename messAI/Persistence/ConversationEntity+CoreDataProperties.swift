//
//  ConversationEntity+CoreDataProperties.swift
//  messAI
//
//  Created by Isaac Jaramillo on October 20, 2025.
//

import Foundation
import CoreData

extension ConversationEntity {
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<ConversationEntity> {
        return NSFetchRequest<ConversationEntity>(entityName: "ConversationEntity")
    }
    
    // MARK: - Attributes
    
    @NSManaged public var id: String
    @NSManaged public var participantIds: [String]
    @NSManaged public var isGroup: Bool
    @NSManaged public var groupName: String?
    @NSManaged public var lastMessage: String
    @NSManaged public var lastMessageAt: Date
    @NSManaged public var createdBy: String
    @NSManaged public var createdAt: Date
    @NSManaged public var unreadCount: Int16
    
    // MARK: - Relationships
    
    @NSManaged public var messages: NSSet?
}

// MARK: - Generated Accessors for Messages

extension ConversationEntity {
    
    @objc(addMessagesObject:)
    @NSManaged public func addToMessages(_ value: MessageEntity)
    
    @objc(removeMessagesObject:)
    @NSManaged public func removeFromMessages(_ value: MessageEntity)
    
    @objc(addMessages:)
    @NSManaged public func addToMessages(_ values: NSSet)
    
    @objc(removeMessages:)
    @NSManaged public func removeFromMessages(_ values: NSSet)
}

extension ConversationEntity: Identifiable {
}

