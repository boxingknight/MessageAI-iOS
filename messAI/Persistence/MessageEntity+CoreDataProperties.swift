//
//  MessageEntity+CoreDataProperties.swift
//  messAI
//
//  Created by Isaac Jaramillo on October 20, 2025.
//

import Foundation
import CoreData

extension MessageEntity {
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<MessageEntity> {
        return NSFetchRequest<MessageEntity>(entityName: "MessageEntity")
    }
    
    // MARK: - Attributes
    
    @NSManaged public var id: String
    @NSManaged public var conversationId: String
    @NSManaged public var senderId: String
    @NSManaged public var text: String
    @NSManaged public var imageURL: String?
    @NSManaged public var sentAt: Date
    @NSManaged public var deliveredAt: Date?
    @NSManaged public var readAt: Date?
    @NSManaged public var status: String
    
    // Sync metadata
    @NSManaged public var isSynced: Bool
    @NSManaged public var syncAttempts: Int16
    @NSManaged public var lastSyncError: String?
    @NSManaged public var needsSync: Bool
    
    // MARK: - Relationships
    
    @NSManaged public var conversation: ConversationEntity?
}

extension MessageEntity: Identifiable {
}

