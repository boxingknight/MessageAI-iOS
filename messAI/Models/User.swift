import Foundation
import FirebaseFirestore

/// Represents a user in the MessageAI app
struct User: Codable, Identifiable, Equatable {
    
    // MARK: - Properties
    
    /// Unique identifier (matches Firebase Auth UID)
    let id: String
    
    /// User's email address
    let email: String
    
    /// User's display name (editable)
    var displayName: String
    
    /// URL to profile picture in Firebase Storage (optional)
    var photoURL: String?
    
    /// Firebase Cloud Messaging token for push notifications (optional)
    var fcmToken: String?
    
    /// Whether user is currently online
    var isOnline: Bool
    
    /// Last time user was active (for "last seen" display)
    var lastSeen: Date
    
    /// Account creation timestamp
    let createdAt: Date
    
    // MARK: - Initializers
    
    /// Initialize a new user (typically for signup)
    init(
        id: String,
        email: String,
        displayName: String,
        photoURL: String? = nil,
        fcmToken: String? = nil,
        isOnline: Bool = true,
        lastSeen: Date = Date(),
        createdAt: Date = Date()
    ) {
        self.id = id
        self.email = email
        self.displayName = displayName
        self.photoURL = photoURL
        self.fcmToken = fcmToken
        self.isOnline = isOnline
        self.lastSeen = lastSeen
        self.createdAt = createdAt
    }
    
    /// Initialize from Firestore document
    init?(from dictionary: [String: Any]) {
        guard 
            let id = dictionary["id"] as? String,
            let email = dictionary["email"] as? String,
            let displayName = dictionary["displayName"] as? String,
            let isOnline = dictionary["isOnline"] as? Bool,
            let lastSeenTimestamp = dictionary["lastSeen"] as? Timestamp,
            let createdAtTimestamp = dictionary["createdAt"] as? Timestamp
        else {
            return nil
        }
        
        self.id = id
        self.email = email
        self.displayName = displayName
        self.photoURL = dictionary["photoURL"] as? String
        self.fcmToken = dictionary["fcmToken"] as? String
        self.isOnline = isOnline
        self.lastSeen = lastSeenTimestamp.dateValue()
        self.createdAt = createdAtTimestamp.dateValue()
    }
    
    // MARK: - Firestore Conversion
    
    /// Convert to dictionary for Firestore
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "email": email,
            "displayName": displayName,
            "isOnline": isOnline,
            "lastSeen": Timestamp(date: lastSeen),
            "createdAt": Timestamp(date: createdAt)
        ]
        
        if let photoURL = photoURL {
            dict["photoURL"] = photoURL
        }
        
        if let fcmToken = fcmToken {
            dict["fcmToken"] = fcmToken
        }
        
        return dict
    }
}

