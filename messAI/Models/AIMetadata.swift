import Foundation

/// Urgency level for messages
enum UrgencyLevel: String, Codable {
    case low      // "FYI", "when you can"
    case normal   // Regular messages
    case high     // "important", "need by tomorrow"
    case urgent   // "ASAP", "NOW", "TODAY"
}

/// Extracted date/time from message
struct ExtractedDate: Codable, Equatable, Identifiable, Hashable {
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
struct Decision: Codable, Equatable, Hashable {
    let summary: String
    let participants: [String]
    let timestamp: Date
}

/// Deadline detection result (stored in message metadata)
struct DeadlineDetection: Codable, Equatable, Hashable {
    let deadlineId: String?         // Reference to /conversations/{id}/deadlines/{deadlineId}
    let title: String               // Short title
    let dueDate: Date               // When the deadline is
    let isAllDay: Bool              // All-day vs specific time
    let priority: String            // "high", "medium", "low"
    let confidence: Double          // 0.0-1.0
    let method: String              // "keyword_filter", "gpt4", "hybrid"
    let reasoning: String?          // Why this was extracted
}

/// AI metadata attached to messages
struct AIMetadata: Codable, Equatable, Hashable {
    // Calendar Extraction (PR #15)
    var extractedDates: [ExtractedDate]?
    var calendarEvents: [CalendarEvent]? // New structured calendar events
    
    // Decision Summarization (PR #16)
    var isDecision: Bool?
    var decision: Decision?
    
    // Priority Highlighting (PR #17)
    var isUrgent: Bool?
    var urgencyLevel: UrgencyLevel?
    var priorityLevel: PriorityLevel?  // New priority system
    var priorityConfidence: Double?    // 0.0-1.0 confidence score
    var priorityMethod: String?        // Detection method: keyword, gpt4, hybrid
    var priorityKeywords: [String]?    // Keywords that triggered detection
    var priorityReasoning: String?     // Why this priority was assigned
    
    // RSVP Tracking (PR #18)
    var rsvpResponse: RSVPResponse?     // Detected RSVP response
    var rsvpStatus: RSVPStatus?         // Quick access to status
    var rsvpEventId: String?            // Linked event ID
    var rsvpConfidence: Double?         // 0.0-1.0 confidence score
    var rsvpMethod: String?             // Detection method: keyword, gpt4, hybrid
    var rsvpReasoning: String?          // Why this classification was made
    
    // Deadline Extraction (PR #19)
    var deadlineDetection: DeadlineDetection?  // Detected deadline info
    var hasDeadline: Bool?              // Quick check if message contains deadline
    
    // Common metadata
    var processedAt: Date?  // Made optional to handle Firebase Timestamps
    var processingTimeMs: Int?
    var modelUsed: String?
    
    init(processedAt: Date? = Date()) {
        self.processedAt = processedAt
    }
}

