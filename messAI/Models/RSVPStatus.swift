import Foundation
import SwiftUI

/**
 * PR#18: RSVP Status for Event Tracking
 * 
 * Represents a user's response to an event invitation (yes/no/maybe/pending).
 * Used to track attendance and display participant lists grouped by status.
 */

/// RSVP response status for event attendance
enum RSVPStatus: String, Codable, CaseIterable {
    case yes = "yes"            // Confirmed attendance
    case no = "no"              // Declined attendance
    case maybe = "maybe"        // Tentative attendance
    case pending = "pending"    // No response yet (default)
    
    // MARK: - Display Properties
    
    /// Display name for UI
    var displayName: String {
        switch self {
        case .yes:
            return "Going"
        case .no:
            return "Not Going"
        case .maybe:
            return "Maybe"
        case .pending:
            return "Pending"
        }
    }
    
    /// Short display label
    var shortName: String {
        switch self {
        case .yes:
            return "Yes"
        case .no:
            return "No"
        case .maybe:
            return "Maybe"
        case .pending:
            return "—"
        }
    }
    
    // MARK: - Visual Properties
    
    /// Icon (SF Symbol) for status
    var icon: String {
        switch self {
        case .yes:
            return "checkmark.circle.fill"
        case .no:
            return "xmark.circle.fill"
        case .maybe:
            return "questionmark.circle.fill"
        case .pending:
            return "clock.fill"
        }
    }
    
    /// Icon color
    var iconColor: Color {
        switch self {
        case .yes:
            return .green
        case .no:
            return .red
        case .maybe:
            return .orange
        case .pending:
            return .gray
        }
    }
    
    /// Text color for participant names
    var textColor: Color {
        switch self {
        case .yes:
            return .primary
        case .no:
            return .secondary
        case .maybe:
            return .primary
        case .pending:
            return .secondary
        }
    }
    
    /// Background color for status badge
    var backgroundColor: Color {
        switch self {
        case .yes:
            return Color.green.opacity(0.1)
        case .no:
            return Color.red.opacity(0.1)
        case .maybe:
            return Color.orange.opacity(0.1)
        case .pending:
            return Color.gray.opacity(0.1)
        }
    }
    
    // MARK: - Emoji Representation
    
    /// Emoji representation (for quick visual reference)
    var emoji: String {
        switch self {
        case .yes:
            return "✅"
        case .no:
            return "❌"
        case .maybe:
            return "❓"
        case .pending:
            return "⏳"
        }
    }
    
    // MARK: - Sorting Priority
    
    /// Sort order for displaying participant lists (yes → maybe → no → pending)
    var sortOrder: Int {
        switch self {
        case .yes:
            return 1
        case .maybe:
            return 2
        case .no:
            return 3
        case .pending:
            return 4
        }
    }
    
    // MARK: - Utility Methods
    
    /// Whether this status counts as "confirmed" for attendance tracking
    var isConfirmed: Bool {
        return self == .yes
    }
    
    /// Whether this status counts as "declined"
    var isDeclined: Bool {
        return self == .no
    }
    
    /// Whether this status is uncertain
    var isUncertain: Bool {
        return self == .maybe || self == .pending
    }
    
    /// Accessibility label
    var accessibilityLabel: String {
        switch self {
        case .yes:
            return "Confirmed attendance. Going to the event."
        case .no:
            return "Declined attendance. Not going to the event."
        case .maybe:
            return "Tentative attendance. Maybe going to the event."
        case .pending:
            return "No response yet. Pending RSVP."
        }
    }
}

// MARK: - Comparable for Sorting

extension RSVPStatus: Comparable {
    static func < (lhs: RSVPStatus, rhs: RSVPStatus) -> Bool {
        return lhs.sortOrder < rhs.sortOrder
    }
}

// MARK: - RSVP Response Model

/// Complete RSVP response data (detected from message)
struct RSVPResponse: Codable, Equatable, Hashable {
    let status: RSVPStatus          // User's RSVP status
    let eventId: String?            // Linked event ID (if detected)
    let confidence: Double          // 0.0-1.0 confidence score
    let reasoning: String?          // Why this classification was made
    let detectedAt: Date            // When RSVP was detected
    let method: DetectionMethod     // How it was detected
    
    enum DetectionMethod: String, Codable {
        case keyword = "keyword"    // Fast keyword filter only
        case gpt4 = "gpt4"         // GPT-4 analysis only
        case hybrid = "hybrid"     // Keyword + GPT-4 combined
        case manual = "manual"     // User manually set
    }
    
    init(
        status: RSVPStatus,
        eventId: String? = nil,
        confidence: Double = 1.0,
        reasoning: String? = nil,
        detectedAt: Date = Date(),
        method: DetectionMethod = .hybrid
    ) {
        self.status = status
        self.eventId = eventId
        self.confidence = confidence
        self.reasoning = reasoning
        self.detectedAt = detectedAt
        self.method = method
    }
}

// MARK: - RSVP Participant Model

/// Participant RSVP info (for event tracking)
struct RSVPParticipant: Identifiable, Codable, Equatable, Hashable {
    let id: String                  // User ID
    let name: String                // Display name
    let status: RSVPStatus          // RSVP status
    let respondedAt: Date?          // When they responded (nil if pending)
    let messageId: String?          // Message ID containing RSVP
    
    init(
        id: String,
        name: String,
        status: RSVPStatus = .pending,
        respondedAt: Date? = nil,
        messageId: String? = nil
    ) {
        self.id = id
        self.name = name
        self.status = status
        self.respondedAt = respondedAt
        self.messageId = messageId
    }
}

// MARK: - RSVP Summary Model

/// Summary of RSVPs for an event
struct RSVPSummary: Codable, Equatable, Hashable {
    let eventId: String
    let totalParticipants: Int
    let yesCount: Int
    let noCount: Int
    let maybeCount: Int
    let pendingCount: Int
    
    /// Formatted summary text (e.g., "5 of 12 confirmed")
    var summaryText: String {
        return "\(yesCount) of \(totalParticipants) confirmed"
    }
    
    /// Formatted detailed text (e.g., "5 yes, 3 no, 2 maybe, 2 pending")
    var detailedText: String {
        var parts: [String] = []
        if yesCount > 0 {
            parts.append("\(yesCount) yes")
        }
        if maybeCount > 0 {
            parts.append("\(maybeCount) maybe")
        }
        if noCount > 0 {
            parts.append("\(noCount) no")
        }
        if pendingCount > 0 {
            parts.append("\(pendingCount) pending")
        }
        return parts.joined(separator: ", ")
    }
    
    /// Percentage of confirmed attendees (0.0-1.0)
    var confirmationRate: Double {
        guard totalParticipants > 0 else { return 0.0 }
        return Double(yesCount) / Double(totalParticipants)
    }
    
    /// Whether all participants have responded
    var allResponded: Bool {
        return pendingCount == 0
    }
}

// MARK: - Preview Helpers

#if DEBUG
extension RSVPStatus {
    /// Sample data for SwiftUI previews
    static let previewYes = RSVPStatus.yes
    static let previewNo = RSVPStatus.no
    static let previewMaybe = RSVPStatus.maybe
    static let previewPending = RSVPStatus.pending
}

extension RSVPResponse {
    /// Sample RSVP response for previews
    static let previewYes = RSVPResponse(
        status: .yes,
        eventId: "event123",
        confidence: 0.95,
        reasoning: "Clear affirmative response",
        detectedAt: Date(),
        method: .hybrid
    )
    
    static let previewMaybe = RSVPResponse(
        status: .maybe,
        eventId: "event123",
        confidence: 0.82,
        reasoning: "Uncertain response with tentative language",
        detectedAt: Date(),
        method: .gpt4
    )
}

extension RSVPParticipant {
    /// Sample participants for previews
    static let previewYes = RSVPParticipant(
        id: "user1",
        name: "Sarah Johnson",
        status: .yes,
        respondedAt: Date(),
        messageId: "msg123"
    )
    
    static let previewPending = RSVPParticipant(
        id: "user2",
        name: "Mike Chen",
        status: .pending,
        respondedAt: nil,
        messageId: nil
    )
}

extension RSVPSummary {
    /// Sample summary for previews
    static let preview = RSVPSummary(
        eventId: "event123",
        totalParticipants: 12,
        yesCount: 5,
        noCount: 3,
        maybeCount: 2,
        pendingCount: 2
    )
}
#endif

