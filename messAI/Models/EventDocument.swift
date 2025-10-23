import Foundation
import FirebaseFirestore

/**
 * PR#18 Architecture Fix: Event Document Model
 * 
 * Represents a calendar event stored in Firestore /events collection.
 * Created when calendar events are extracted (PR#15), enables RSVP tracking (PR#18).
 * 
 * Purpose:
 * - Single source of truth for event details
 * - Parent document for /events/{id}/rsvps/{userId} subcollections
 * - Enables querying all events independently of messages
 * - Supports future features (reminders, notifications, search)
 */

struct EventDocument: Identifiable, Codable, Equatable, Hashable {
    // MARK: - Core Event Fields (from CalendarEvent)
    
    let id: String                  // Event ID (matches CalendarEvent.id)
    let title: String               // Event title (e.g., "Soccer practice")
    let date: Date                  // Event date
    let time: Date?                 // Start time (nil if all-day)
    let endTime: Date?              // End time (nil if not specified)
    let location: String?           // Location (e.g., "Central Park")
    let isAllDay: Bool              // Whether this is an all-day event
    let confidence: Double          // AI confidence score (0.0-1.0)
    
    // MARK: - Firestore Relationship Fields
    
    let conversationId: String      // Source conversation ID
    let createdBy: String           // User ID who created the event (who did extraction)
    let createdAt: Date             // When event document was created
    let sourceMessageId: String     // Original message containing event
    let participantIds: [String]    // All conversation participants at creation
    
    // MARK: - Organizer Tracking (PR#18 Enhancement)
    
    let organizerId: String         // User who sent the original message (event organizer)
    let organizerName: String       // Display name of organizer
    let sourceMessageSenderId: String // Same as organizerId (for query consistency)
    
    // MARK: - Initialization
    
    /// Initialize from CalendarEvent and message context
    init(
        from event: CalendarEvent,
        conversationId: String,
        createdBy: String,
        sourceMessageId: String,
        participantIds: [String],
        organizerId: String,
        organizerName: String
    ) {
        self.id = event.id
        self.title = event.title
        self.date = event.date
        self.time = event.time
        self.endTime = event.endTime
        self.location = event.location
        self.isAllDay = event.isAllDay
        // Convert CalendarConfidence enum to numeric score
        self.confidence = event.confidence == .high ? 0.9 : (event.confidence == .medium ? 0.7 : 0.5)
        self.conversationId = conversationId
        self.createdBy = createdBy
        self.createdAt = Date()
        self.sourceMessageId = sourceMessageId
        self.participantIds = participantIds
        self.organizerId = organizerId
        self.organizerName = organizerName
        self.sourceMessageSenderId = organizerId // Same as organizerId for consistency
    }
    
    /// Initialize from Firestore document data
    init(id: String, data: [String: Any]) throws {
        self.id = id
        
        guard let title = data["title"] as? String,
              let dateTimestamp = data["date"] as? Timestamp,
              let isAllDay = data["isAllDay"] as? Bool,
              let confidence = data["confidence"] as? Double,
              let conversationId = data["conversationId"] as? String,
              let createdBy = data["createdBy"] as? String,
              let createdAtTimestamp = data["createdAt"] as? Timestamp,
              let sourceMessageId = data["sourceMessageId"] as? String,
              let participantIds = data["participantIds"] as? [String],
              let organizerId = data["organizerId"] as? String,
              let organizerName = data["organizerName"] as? String,
              let sourceMessageSenderId = data["sourceMessageSenderId"] as? String else {
            throw FirestoreError.invalidData
        }
        
        self.title = title
        self.date = dateTimestamp.dateValue()
        self.isAllDay = isAllDay
        self.confidence = confidence
        self.conversationId = conversationId
        self.createdBy = createdBy
        self.createdAt = createdAtTimestamp.dateValue()
        self.sourceMessageId = sourceMessageId
        self.participantIds = participantIds
        self.organizerId = organizerId
        self.organizerName = organizerName
        self.sourceMessageSenderId = sourceMessageSenderId
        
        // Optional fields
        if let timeTimestamp = data["time"] as? Timestamp {
            self.time = timeTimestamp.dateValue()
        } else {
            self.time = nil
        }
        
        if let endTimeTimestamp = data["endTime"] as? Timestamp {
            self.endTime = endTimeTimestamp.dateValue()
        } else {
            self.endTime = nil
        }
        
        self.location = data["location"] as? String
    }
    
    // MARK: - Firestore Conversion
    
    /// Convert to Firestore document data
    func toDictionary() -> [String: Any] {
        var data: [String: Any] = [
            "id": id,
            "title": title,
            "date": Timestamp(date: date),
            "isAllDay": isAllDay,
            "confidence": confidence,
            "conversationId": conversationId,
            "createdBy": createdBy,
            "createdAt": Timestamp(date: createdAt),
            "sourceMessageId": sourceMessageId,
            "participantIds": participantIds,
            "organizerId": organizerId,
            "organizerName": organizerName,
            "sourceMessageSenderId": sourceMessageSenderId
        ]
        
        // Add optional fields if present
        if let time = time {
            data["time"] = Timestamp(date: time)
        }
        
        if let endTime = endTime {
            data["endTime"] = Timestamp(date: endTime)
        }
        
        if let location = location {
            data["location"] = location
        }
        
        return data
    }
    
    /// Create EventDocument from Firestore document snapshot
    static func fromSnapshot(_ snapshot: DocumentSnapshot) throws -> EventDocument {
        guard let data = snapshot.data() else {
            throw FirestoreError.documentDoesNotExist
        }
        return try EventDocument(id: snapshot.documentID, data: data)
    }
    
    // MARK: - Computed Properties
    
    /// Formatted date string for display
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    /// Formatted time range for display
    var formattedTimeRange: String? {
        guard let startTime = time else { return nil }
        
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        
        if let endTime = endTime {
            return "\(formatter.string(from: startTime)) - \(formatter.string(from: endTime))"
        } else {
            return formatter.string(from: startTime)
        }
    }
    
    /// Whether this event is in the past
    var isPast: Bool {
        if let time = time {
            return time < Date()
        } else {
            // For all-day events, compare date only
            return date < Calendar.current.startOfDay(for: Date())
        }
    }
    
    /// Whether this event is today
    var isToday: Bool {
        return Calendar.current.isDateInToday(date)
    }
}

// MARK: - Firestore Error

enum FirestoreError: LocalizedError {
    case invalidData
    case documentDoesNotExist
    case conversionFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidData:
            return "Invalid Firestore document data"
        case .documentDoesNotExist:
            return "Firestore document does not exist"
        case .conversionFailed:
            return "Failed to convert Firestore data"
        }
    }
}

// MARK: - Preview Helpers

#if DEBUG
extension EventDocument {
    /// Sample event for SwiftUI previews
    static let preview = EventDocument(
        from: CalendarEvent(
            id: "event_preview",
            title: "Soccer Practice",
            date: Date().addingTimeInterval(86400), // Tomorrow
            time: Date().addingTimeInterval(86400 + 14400), // Tomorrow at 4pm
            endTime: Date().addingTimeInterval(86400 + 18000), // Tomorrow at 5pm
            location: "Central Park",
            isAllDay: false,
            confidence: .high,
            rawText: "Soccer practice tomorrow at 4pm at Central Park"
        ),
        conversationId: "conv123",
        createdBy: "user2", // User2 did the extraction
        sourceMessageId: "msg789",
        participantIds: ["user1", "user2", "user3", "user4"],
        organizerId: "user1", // User1 sent the original message
        organizerName: "Alice"
    )
}
#endif

