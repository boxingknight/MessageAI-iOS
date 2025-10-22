import Foundation

/// Urgency level for messages
enum UrgencyLevel: String, Codable {
    case low      // "FYI", "when you can"
    case normal   // Regular messages
    case high     // "important", "need by tomorrow"
    case urgent   // "ASAP", "NOW", "TODAY"
}

/// Extracted date/time from message
struct ExtractedDate: Codable, Equatable, Identifiable {
    let id: String
    let date: Date
    let time: Date?
    let eventDescription: String
    let confidence: Double  // 0.0-1.0
    
    init(id: String = UUID().uuidString, date: Date, time: Date? = nil, eventDescription: String, confidence: Double) {
        self.id = id
        self.date = date
        self.time = time
        self.eventDescription = eventDescription
        self.confidence = confidence
    }
}

/// Group decision summary
struct Decision: Codable, Equatable {
    let summary: String
    let participants: [String]
    let timestamp: Date
}

/// RSVP response status
enum RSVPStatus: String, Codable {
    case yes, no, maybe, pending
}

/// RSVP response info
struct RSVPResponse: Codable, Equatable {
    let eventId: String
    let response: RSVPStatus
    let respondedAt: Date
}

/// Deadline extracted from message
struct Deadline: Codable, Equatable, Identifiable {
    let id: String
    let description: String
    let dueDate: Date
    let priority: UrgencyLevel
    
    init(id: String = UUID().uuidString, description: String, dueDate: Date, priority: UrgencyLevel) {
        self.id = id
        self.description = description
        self.dueDate = dueDate
        self.priority = priority
    }
}

/// AI metadata attached to messages
struct AIMetadata: Codable, Equatable {
    // Calendar Extraction (PR #15)
    var extractedDates: [ExtractedDate]?
    
    // Decision Summarization (PR #16)
    var isDecision: Bool?
    var decision: Decision?
    
    // Priority Highlighting (PR #17)
    var isUrgent: Bool?
    var urgencyLevel: UrgencyLevel?
    
    // RSVP Tracking (PR #18)
    var rsvpInfo: RSVPResponse?
    
    // Deadline Extraction (PR #19)
    var deadlines: [Deadline]?
    
    // Common metadata
    var processedAt: Date
    var processingTimeMs: Int?
    var modelUsed: String?
    
    init(processedAt: Date = Date()) {
        self.processedAt = processedAt
    }
}

