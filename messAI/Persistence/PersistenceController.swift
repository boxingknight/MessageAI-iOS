//
//  PersistenceController.swift
//  messAI
//
//  Created by Isaac Jaramillo on October 20, 2025.
//  Purpose: Core Data stack setup and management
//

import CoreData
import Foundation

class PersistenceController {
    
    // MARK: - Singleton
    
    static let shared = PersistenceController()
    
    // MARK: - Preview Instance
    
    /// For SwiftUI previews and testing
    static var preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.viewContext
        
        // Add sample data for previews
        let conversation = ConversationEntity(context: context)
        conversation.id = "preview-conversation"
        conversation.participantIds = ["user1", "user2"]
        conversation.isGroup = false
        conversation.lastMessage = "Hello!"
        conversation.lastMessageAt = Date()
        conversation.createdBy = "user1"
        conversation.createdAt = Date()
        conversation.unreadCount = 0
        
        for i in 0..<10 {
            let message = MessageEntity(context: context)
            message.id = UUID().uuidString
            message.text = "Sample message \(i)"
            message.conversationId = "preview-conversation"
            message.senderId = i % 2 == 0 ? "user1" : "user2"
            message.sentAt = Date().addingTimeInterval(TimeInterval(-600 * (10 - i)))
            message.status = "sent"
            message.isSynced = true
            message.syncAttempts = 0
            message.needsSync = false
            message.conversation = conversation
        }
        
        do {
            try context.save()
        } catch {
            print("❌ Preview data creation failed: \(error)")
        }
        
        return controller
    }()
    
    // MARK: - Properties
    
    let container: NSPersistentContainer
    
    // MARK: - Initialization
    
    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "MessageAI")
        
        if inMemory {
            // Use in-memory store for testing
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }
        
        container.loadPersistentStores { description, error in
            if let error = error {
                // In production, handle this more gracefully
                fatalError("❌ Core Data failed to load: \(error.localizedDescription)")
            }
            print("✅ Core Data loaded: \(description.url?.absoluteString ?? "unknown")")
        }
        
        // Configure merge policy
        // Property-level merge: newer values win for individual properties
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
    
    // MARK: - Save
    
    /// Saves the view context if there are changes
    func save() {
        let context = container.viewContext
        
        if context.hasChanges {
            do {
                try context.save()
                print("✅ Context saved successfully")
            } catch {
                print("❌ Failed to save context: \(error)")
            }
        }
    }
    
    // MARK: - Delete All Data
    
    /// Deletes all data (for testing/logout)
    func deleteAllData() {
        let context = container.viewContext
        
        // Delete all messages
        let messageFetch = NSFetchRequest<NSFetchRequestResult>(entityName: "MessageEntity")
        let messageDelete = NSBatchDeleteRequest(fetchRequest: messageFetch)
        
        // Delete all conversations
        let conversationFetch = NSFetchRequest<NSFetchRequestResult>(entityName: "ConversationEntity")
        let conversationDelete = NSBatchDeleteRequest(fetchRequest: conversationFetch)
        
        do {
            try context.execute(messageDelete)
            try context.execute(conversationDelete)
            try context.save()
            print("✅ All data deleted")
        } catch {
            print("❌ Failed to delete data: \(error)")
        }
    }
}

