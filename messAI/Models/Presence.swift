//
//  Presence.swift
//  messAI
//
//  Created for PR #12: Presence & Typing Indicators
//

import Foundation
import FirebaseFirestore

/// Represents a user's online/offline presence status
struct Presence: Codable, Equatable, Identifiable {
    let id: String        // userId
    let userId: String
    var isOnline: Bool
    var lastSeen: Date
    var updatedAt: Date
    
    init(userId: String, isOnline: Bool, lastSeen: Date, updatedAt: Date) {
        self.id = userId
        self.userId = userId
        self.isOnline = isOnline
        self.lastSeen = lastSeen
        self.updatedAt = updatedAt
    }
    
    // MARK: - Computed Properties
    
    /// Returns formatted presence text: "Active now", "5m ago", etc.
    var presenceText: String {
        if isOnline {
            return "Active now"
        } else {
            return lastSeen.presenceText()
        }
    }
    
    /// Returns status color: "green" for online, "gray" for offline
    var statusColor: String {
        isOnline ? "green" : "gray"
    }
    
    // MARK: - Firestore Conversion
    
    /// Convert Presence to Firestore dictionary
    func toFirestore() -> [String: Any] {
        return [
            "isOnline": isOnline,
            "lastSeen": Timestamp(date: lastSeen),
            "updatedAt": Timestamp(date: updatedAt)
        ]
    }
    
    /// Create Presence from Firestore dictionary
    static func fromFirestore(_ data: [String: Any], userId: String) -> Presence? {
        guard let isOnline = data["isOnline"] as? Bool,
              let lastSeenTimestamp = data["lastSeen"] as? Timestamp,
              let updatedAtTimestamp = data["updatedAt"] as? Timestamp else {
            return nil
        }
        
        return Presence(
            userId: userId,
            isOnline: isOnline,
            lastSeen: lastSeenTimestamp.dateValue(),
            updatedAt: updatedAtTimestamp.dateValue()
        )
    }
}

