//
//  LocalDataManager.swift
//  messAI
//
//  Created by Isaac Jaramillo on October 20, 2025.
//  Purpose: CRUD operations for local Core Data storage
//

import CoreData
import Foundation

class LocalDataManager {
    
    // MARK: - Properties
    
    private let context: NSManagedObjectContext
    
    // MARK: - Singleton
    
    static let shared = LocalDataManager()
    
    // MARK: - Initialization
    
    init(context: NSManagedObjectContext = PersistenceController.shared.container.viewContext) {
        self.context = context
    }
    
    // MARK: - Message Operations
    
    /// Saves a message to local storage
    /// - Parameters:
    ///   - message: The message to save
    ///   - isSynced: Whether the message has been synced to Firebase
    func saveMessage(_ message: Message, isSynced: Bool = true) throws {
        // Check if message already exists
        let fetchRequest: NSFetchRequest<MessageEntity> = MessageEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", message.id)
        
        do {
            let results = try context.fetch(fetchRequest)
            let entity: MessageEntity
            
            if let existing = results.first {
                // Update existing message
                entity = existing
            } else {
                // Create new message
                entity = MessageEntity(context: context, from: message)
            }
            
            // Update fields (in case of update)
            entity.conversationId = message.conversationId
            entity.senderId = message.senderId
            entity.text = message.text
            entity.imageURL = message.imageURL
            entity.sentAt = message.sentAt
            entity.deliveredAt = message.deliveredAt
            entity.readAt = message.readAt
            entity.status = message.status.rawValue
            entity.isSynced = isSynced
            entity.needsSync = !isSynced
            
            // Save context
            try context.save()
            
        } catch {
            throw PersistenceError.saveFailed(error)
        }
    }
    
    /// Fetches messages for a conversation
    /// - Parameter conversationId: The conversation ID
    /// - Returns: Array of messages sorted by sentAt
    func fetchMessages(conversationId: String) throws -> [Message] {
        let fetchRequest: NSFetchRequest<MessageEntity> = MessageEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "conversationId == %@", conversationId)
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \MessageEntity.sentAt, ascending: true)]
        
        do {
            let entities = try context.fetch(fetchRequest)
            return entities.map { $0.toMessage() }
        } catch {
            throw PersistenceError.fetchFailed(error)
        }
    }
    
    /// Updates message status
    /// - Parameters:
    ///   - id: Message ID
    ///   - status: New status
    func updateMessageStatus(id: String, status: MessageStatus) throws {
        let fetchRequest: NSFetchRequest<MessageEntity> = MessageEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", id)
        
        do {
            guard let entity = try context.fetch(fetchRequest).first else {
                throw PersistenceError.messageNotFound
            }
            
            entity.status = status.rawValue
            
            // Update delivered/read timestamps
            switch status {
            case .delivered:
                entity.deliveredAt = Date()
            case .read:
                entity.readAt = Date()
            default:
                break
            }
            
            try context.save()
            
        } catch let error as PersistenceError {
            throw error
        } catch {
            throw PersistenceError.saveFailed(error)
        }
    }
    
    /// Deletes a message
    /// - Parameter id: Message ID
    func deleteMessage(id: String) throws {
        let fetchRequest: NSFetchRequest<MessageEntity> = MessageEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", id)
        
        do {
            guard let entity = try context.fetch(fetchRequest).first else {
                throw PersistenceError.messageNotFound
            }
            
            context.delete(entity)
            try context.save()
            
        } catch let error as PersistenceError {
            throw error
        } catch {
            throw PersistenceError.deleteFailed(error)
        }
    }
    
    // MARK: - Conversation Operations
    
    /// Saves a conversation to local storage
    /// - Parameter conversation: The conversation to save
    func saveConversation(_ conversation: Conversation) throws {
        let fetchRequest: NSFetchRequest<ConversationEntity> = ConversationEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", conversation.id)
        
        do {
            let results = try context.fetch(fetchRequest)
            let entity: ConversationEntity
            
            if let existing = results.first {
                entity = existing
            } else {
                entity = ConversationEntity(context: context, from: conversation)
            }
            
            // Update fields
            entity.participantIds = conversation.participants
            entity.isGroup = conversation.isGroup
            entity.groupName = conversation.groupName
            entity.lastMessage = conversation.lastMessage
            entity.lastMessageAt = conversation.lastMessageAt
            entity.createdBy = conversation.createdBy
            entity.createdAt = conversation.createdAt
            
            try context.save()
            
        } catch {
            throw PersistenceError.saveFailed(error)
        }
    }
    
    /// Fetches all conversations
    /// - Returns: Array of conversations sorted by lastMessageAt
    func fetchConversations() throws -> [Conversation] {
        let fetchRequest: NSFetchRequest<ConversationEntity> = ConversationEntity.fetchRequest()
        fetchRequest.sortDescriptors = [
            NSSortDescriptor(keyPath: \ConversationEntity.lastMessageAt, ascending: false)
        ]
        
        do {
            let entities = try context.fetch(fetchRequest)
            return entities.map { $0.toConversation() }
        } catch {
            throw PersistenceError.fetchFailed(error)
        }
    }
    
    /// Deletes a conversation (messages will cascade delete)
    /// - Parameter id: Conversation ID
    func deleteConversation(id: String) throws {
        let fetchRequest: NSFetchRequest<ConversationEntity> = ConversationEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", id)
        
        do {
            guard let entity = try context.fetch(fetchRequest).first else {
                throw PersistenceError.conversationNotFound
            }
            
            // Messages will cascade delete automatically
            context.delete(entity)
            try context.save()
            
        } catch let error as PersistenceError {
            throw error
        } catch {
            throw PersistenceError.deleteFailed(error)
        }
    }
    
    // MARK: - Sync Operations
    
    /// Fetches all unsynced messages
    /// - Returns: Array of messages that need to be synced
    func fetchUnsyncedMessages() throws -> [Message] {
        let fetchRequest: NSFetchRequest<MessageEntity> = MessageEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "isSynced == NO")
        fetchRequest.sortDescriptors = [
            NSSortDescriptor(keyPath: \MessageEntity.sentAt, ascending: true)
        ]
        
        do {
            let entities = try context.fetch(fetchRequest)
            return entities.map { $0.toMessage() }
        } catch {
            throw PersistenceError.fetchFailed(error)
        }
    }
    
    /// Marks a message as synced
    /// - Parameter messageId: The message ID
    func markAsSynced(messageId: String) throws {
        let fetchRequest: NSFetchRequest<MessageEntity> = MessageEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", messageId)
        
        do {
            guard let entity = try context.fetch(fetchRequest).first else {
                throw PersistenceError.messageNotFound
            }
            
            entity.isSynced = true
            entity.needsSync = false
            entity.syncAttempts = 0
            entity.lastSyncError = nil
            
            try context.save()
            
        } catch let error as PersistenceError {
            throw error
        } catch {
            throw PersistenceError.saveFailed(error)
        }
    }
    
    /// Increments sync attempts for a message
    /// - Parameters:
    ///   - messageId: The message ID
    ///   - error: Optional error message
    func incrementSyncAttempts(messageId: String, error: String? = nil) throws {
        let fetchRequest: NSFetchRequest<MessageEntity> = MessageEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", messageId)
        
        do {
            guard let entity = try context.fetch(fetchRequest).first else {
                throw PersistenceError.messageNotFound
            }
            
            entity.syncAttempts += 1
            entity.lastSyncError = error
            
            // If max attempts reached, stop trying
            if entity.syncAttempts >= 5 {
                entity.needsSync = false
                print("⚠️ Message \(messageId) failed after 5 attempts")
            }
            
            try context.save()
            
        } catch let error as PersistenceError {
            throw error
        } catch {
            throw PersistenceError.saveFailed(error)
        }
    }
    
    /// Batch saves multiple messages
    /// - Parameter messages: Array of messages to save
    func batchSaveMessages(_ messages: [Message]) throws {
        do {
            for message in messages {
                try saveMessage(message, isSynced: true)
            }
            print("✅ Batch saved \(messages.count) messages")
        } catch {
            throw PersistenceError.saveFailed(error)
        }
    }
}

// MARK: - Errors

enum PersistenceError: LocalizedError {
    case messageNotFound
    case conversationNotFound
    case saveFailed(Error)
    case fetchFailed(Error)
    case deleteFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .messageNotFound:
            return "Message not found in local storage"
        case .conversationNotFound:
            return "Conversation not found in local storage"
        case .saveFailed(let error):
            return "Failed to save: \(error.localizedDescription)"
        case .fetchFailed(let error):
            return "Failed to fetch: \(error.localizedDescription)"
        case .deleteFailed(let error):
            return "Failed to delete: \(error.localizedDescription)"
        }
    }
}

