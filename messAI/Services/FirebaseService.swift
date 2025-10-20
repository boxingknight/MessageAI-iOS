import Foundation
import FirebaseFirestore

/// Base service providing common Firebase Firestore utilities
class FirebaseService {
    
    // MARK: - Properties
    
    /// Shared Firestore instance
    let db = Firestore.firestore()
    
    // MARK: - Collection References
    
    /// Users collection reference
    var usersCollection: CollectionReference {
        db.collection("users")
    }
    
    /// Conversations collection reference
    var conversationsCollection: CollectionReference {
        db.collection("conversations")
    }
    
    // MARK: - Helper Methods
    
    /// Generate a new document ID
    func generateDocumentId(in collection: CollectionReference) -> String {
        collection.document().documentID
    }
    
    /// Create server timestamp
    func serverTimestamp() -> FieldValue {
        FieldValue.serverTimestamp()
    }
    
    /// Convert Firestore timestamp to Date
    func dateFromTimestamp(_ timestamp: Timestamp?) -> Date? {
        timestamp?.dateValue()
    }
}

