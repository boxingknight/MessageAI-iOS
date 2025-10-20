//
//  TypingStatus.swift
//  messAI
//
//  Created by Isaac Jaramillo on 10/20/25.
//

import Foundation
import FirebaseFirestore

/// Represents a user's typing status in a conversation
struct TypingStatus: Identifiable, Codable, Equatable {
    // MARK: - Properties
    let id: String              // User ID
    let conversationId: String
    let isTyping: Bool
    let startedAt: Date
    
    // MARK: - Computed Properties
    
    /// Check if typing status is stale (>3 seconds old)
    var isStale: Bool {
        Date().timeIntervalSince(startedAt) > 3
    }
    
    // MARK: - Initializers
    
    /// Full initializer
    init(id: String, conversationId: String, isTyping: Bool, startedAt: Date) {
        self.id = id
        self.conversationId = conversationId
        self.isTyping = isTyping
        self.startedAt = startedAt
    }
    
    /// Convenience initializer for creating new typing status
    init(userId: String, conversationId: String, isTyping: Bool = true) {
        self.id = userId
        self.conversationId = conversationId
        self.isTyping = isTyping
        self.startedAt = Date()
    }
}

// MARK: - Firestore Conversion

extension TypingStatus {
    /// Convert typing status to Firestore-compatible dictionary
    func toDictionary() -> [String: Any] {
        return [
            "userId": id,
            "conversationId": conversationId,
            "isTyping": isTyping,
            "startedAt": Timestamp(date: startedAt)
        ]
    }
    
    /// Create typing status from Firestore dictionary
    init?(dictionary: [String: Any]) {
        guard
            let userId = dictionary["userId"] as? String,
            let conversationId = dictionary["conversationId"] as? String,
            let isTyping = dictionary["isTyping"] as? Bool,
            let startedAtTimestamp = dictionary["startedAt"] as? Timestamp
        else {
            return nil
        }
        
        self.id = userId
        self.conversationId = conversationId
        self.isTyping = isTyping
        self.startedAt = startedAtTimestamp.dateValue()
    }
}

