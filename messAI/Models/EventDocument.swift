import Foundation
import FirebaseFirestore

/**
 * PR#20.2: Event Document Model (Updated for Event Management)
 * 
 * Represents a calendar event stored in Firestore /events collection.
 * Created when users approve events from Ambient Bar (PR#20.1).
 * 
 * Schema (from PR#20.1):
 * - id: String
 * - title: String
 * - conversationId: String
 * - createdBy: String (user ID)
 * - date: String (e.g., "October 31" or "Monday")
 * - time: String (e.g., "7PM" or "2:30PM")
 * - location: String?
 * - participants: [String]
 * - createdAt: Timestamp
 * - updatedAt: Timestamp
 * - status: String ("pending", "confirmed", "cancelled")
 * - rsvps: [String: String]? (userId -> "yes"/"no"/"maybe")
 */

struct EventDocument: Identifiable, Codable, Equatable, Hashable {
    // MARK: - Core Event Fields
    
    let id: String
    let title: String
    let conversationId: String
    let createdBy: String
    let date: String               // "October 31" or "Monday" or "tomorrow"
    let time: String               // "7PM" or "2:30PM"
    let location: String?
    let participants: [String]
    let createdAt: Date
    var updatedAt: Date
    var status: String             // "pending", "confirmed", "cancelled"
    var rsvps: [String: String]?   // userId -> "yes"/"no"/"maybe"
    var notes: String?             // Additional event details
    var cancelledAt: Date?         // When event was cancelled
    var cancelledBy: String?       // Who cancelled the event
    
    // MARK: - Initialization
    
    /// Initialize from CalendarEvent (PR#15/18 compatibility)
    /// This initializer supports the OLD calendar extraction workflow
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
        self.conversationId = conversationId
        self.createdBy = createdBy
        self.participants = participantIds
        
        // Convert Date objects to Strings for new schema
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM d"
        self.date = dateFormatter.string(from: event.date)
        
        if let time = event.time {
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "h:mma"
            self.time = timeFormatter.string(from: time).lowercased()
        } else {
            self.time = "All day"
        }
        
        self.location = event.location
        self.createdAt = Date()
        self.updatedAt = Date()
        self.status = "pending"
        self.rsvps = nil
        self.notes = nil
        self.cancelledAt = nil
        self.cancelledBy = nil
    }
    
    /// Initialize from Firestore document snapshot
    init?(from snapshot: DocumentSnapshot) {
        guard let data = snapshot.data(),
              let title = data["title"] as? String,
              let conversationId = data["conversationId"] as? String,
              let createdBy = data["createdBy"] as? String,
              let date = data["date"] as? String,
              let time = data["time"] as? String,
              let participants = data["participants"] as? [String],
              let status = data["status"] as? String else {
            return nil
        }
        
        self.id = snapshot.documentID
        self.title = title
        self.conversationId = conversationId
        self.createdBy = createdBy
        self.date = date
        self.time = time
        self.participants = participants
        self.status = status
        
        // Optional fields
        self.location = data["location"] as? String
        self.rsvps = data["rsvps"] as? [String: String]
        self.notes = data["notes"] as? String
        
        // Timestamps
        if let createdAtTimestamp = data["createdAt"] as? Timestamp {
            self.createdAt = createdAtTimestamp.dateValue()
        } else {
            self.createdAt = Date()
        }
        
        if let updatedAtTimestamp = data["updatedAt"] as? Timestamp {
            self.updatedAt = updatedAtTimestamp.dateValue()
        } else {
            self.updatedAt = Date()
        }
        
        if let cancelledAtTimestamp = data["cancelledAt"] as? Timestamp {
            self.cancelledAt = cancelledAtTimestamp.dateValue()
        } else {
            self.cancelledAt = nil
        }
        
        self.cancelledBy = data["cancelledBy"] as? String
    }
    
    // MARK: - Firestore Conversion
    
    /// Convert to Firestore document data
    func toDictionary() -> [String: Any] {
        var data: [String: Any] = [
            "id": id,
            "title": title,
            "conversationId": conversationId,
            "createdBy": createdBy,
            "date": date,
            "time": time,
            "participants": participants,
            "createdAt": Timestamp(date: createdAt),
            "updatedAt": Timestamp(date: updatedAt),
            "status": status
        ]
        
        // Add optional fields if present
        if let location = location {
            data["location"] = location
        }
        
        if let rsvps = rsvps {
            data["rsvps"] = rsvps
        }
        
        if let notes = notes {
            data["notes"] = notes
        }
        
        if let cancelledAt = cancelledAt {
            data["cancelledAt"] = Timestamp(date: cancelledAt)
        }
        
        if let cancelledBy = cancelledBy {
            data["cancelledBy"] = cancelledBy
        }
        
        return data
    }
    
    // MARK: - Computed Properties for UI (PR#20.2)
    
    /// Event icon (emoji) based on title or type
    var icon: String {
        let lowercaseTitle = title.lowercased()
        
        // Birthday
        if lowercaseTitle.contains("birthday") || lowercaseTitle.contains("bday") {
            return "🎂"
        }
        // Party
        if lowercaseTitle.contains("party") {
            return "🎉"
        }
        // Swimming
        if lowercaseTitle.contains("swim") || lowercaseTitle.contains("pool") {
            return "🏊"
        }
        // Soccer
        if lowercaseTitle.contains("soccer") || lowercaseTitle.contains("football") {
            return "⚽"
        }
        // Baseball/Softball
        if lowercaseTitle.contains("baseball") || lowercaseTitle.contains("softball") {
            return "⚾"
        }
        // Basketball
        if lowercaseTitle.contains("basketball") || lowercaseTitle.contains("hoops") {
            return "🏀"
        }
        // Tennis
        if lowercaseTitle.contains("tennis") {
            return "🎾"
        }
        // Playdate
        if lowercaseTitle.contains("playdate") || lowercaseTitle.contains("play date") {
            return "🎨"
        }
        // School
        if lowercaseTitle.contains("school") || lowercaseTitle.contains("class") {
            return "🏫"
        }
        // Picnic
        if lowercaseTitle.contains("picnic") {
            return "🧺"
        }
        // Dinner/Lunch
        if lowercaseTitle.contains("dinner") || lowercaseTitle.contains("lunch") {
            return "🍽️"
        }
        // Games/Gaming
        if lowercaseTitle.contains("game") || lowercaseTitle.contains("poker") || lowercaseTitle.contains("cards") {
            return "🎮"
        }
        
        // Default
        return "📅"
    }
    
    /// Formatted date for display (e.g., "October 31, 2025")
    var formattedDate: String {
        // If date is a day name (Monday, Tuesday, etc.)
        let dayNames = ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"]
        if dayNames.contains(date.lowercased()) {
            return date.capitalized
        }
        
        // If date is "tomorrow" or "today"
        if date.lowercased() == "tomorrow" {
            return "Tomorrow"
        }
        if date.lowercased() == "today" {
            return "Today"
        }
        
        // If date includes a month (e.g., "October 31")
        if date.contains(" ") {
            // Add current year if not specified
            let currentYear = Calendar.current.component(.year, from: Date())
            return "\(date), \(currentYear)"
        }
        
        // Fallback: return as-is
        return date
    }
    
    /// Formatted time for display (e.g., "7:00 PM")
    var formattedTime: String {
        // Already in display format (e.g., "7PM", "2:30PM")
        // Add colon and space for consistency
        let uppercased = time.uppercased()
        
        // If time is like "7PM", convert to "7:00 PM"
        if uppercased.hasSuffix("PM") || uppercased.hasSuffix("AM") {
            let suffix = uppercased.hasSuffix("PM") ? "PM" : "AM"
            let timePart = uppercased.replacingOccurrences(of: suffix, with: "").trimmingCharacters(in: .whitespaces)
            
            // If already has colon, just add space
            if timePart.contains(":") {
                return "\(timePart) \(suffix)"
            }
            
            // Add ":00" if no minutes specified
            return "\(timePart):00 \(suffix)"
        }
        
        // Fallback: return as-is
        return time
    }
    
    /// Combined date and time for parsing (attempts to create Date object)
    var eventDate: Date {
        // Attempt to parse the date and time strings into a Date object
        // This is best-effort; may return current date + offset for relative dates
        
        let calendar = Calendar.current
        let now = Date()
        
        // Handle "today"
        if date.lowercased() == "today" {
            return parseTimeToday(time) ?? now
        }
        
        // Handle "tomorrow"
        if date.lowercased() == "tomorrow" {
            if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) {
                return parseTimeOn(tomorrow, time: time) ?? tomorrow
            }
            return now
        }
        
        // Handle day names (Monday, Tuesday, etc.)
        let dayNames = ["sunday": 1, "monday": 2, "tuesday": 3, "wednesday": 4, "thursday": 5, "friday": 6, "saturday": 7]
        if let targetWeekday = dayNames[date.lowercased()] {
            if let nextDate = calendar.nextDate(after: now, matching: DateComponents(weekday: targetWeekday), matchingPolicy: .nextTime) {
                return parseTimeOn(nextDate, time: time) ?? nextDate
            }
            return now
        }
        
        // Handle month + day (e.g., "October 31")
        if date.contains(" ") {
            let parts = date.components(separatedBy: " ")
            if parts.count == 2, let day = Int(parts[1]) {
                let monthStr = parts[0]
                let currentYear = calendar.component(.year, from: now)
                
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "MMMM d, yyyy"
                if let parsedDate = dateFormatter.date(from: "\(monthStr) \(day), \(currentYear)") {
                    return parseTimeOn(parsedDate, time: time) ?? parsedDate
                }
            }
        }
        
        // Fallback: return current date (will sort to bottom of list)
        return Date.distantPast
    }
    
    /// Helper: Parse time on a specific date
    private func parseTimeOn(_ date: Date, time: String) -> Date? {
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mma"
        timeFormatter.defaultDate = date
        
        // Try parsing time string (e.g., "7PM", "2:30PM")
        let uppercased = time.uppercased()
        if let timeDate = timeFormatter.date(from: uppercased) {
            return timeDate
        }
        
        return nil
    }
    
    /// Helper: Parse time as today
    private func parseTimeToday(_ time: String) -> Date? {
        return parseTimeOn(Date(), time: time)
    }
    
    /// Whether this event is upcoming (in the future)
    var isUpcoming: Bool {
        return eventDate >= Date() && status != "cancelled"
    }
    
    /// Whether this event is cancelled
    var isCancelled: Bool {
        return status == "cancelled"
    }
    
    /// RSVP summary text (e.g., "3 going, 1 can't, 2 pending")
    var rsvpSummary: String {
        guard let rsvps = rsvps, !rsvps.isEmpty else {
            let pending = participants.count
            return "\(pending) pending"
        }
        
        let yes = rsvps.values.filter { $0 == "yes" }.count
        let no = rsvps.values.filter { $0 == "no" }.count
        let maybe = rsvps.values.filter { $0 == "maybe" }.count
        let pending = participants.count - rsvps.count
        
        var parts: [String] = []
        if yes > 0 { parts.append("✅ \(yes) going") }
        if no > 0 { parts.append("❌ \(no) no") }
        if maybe > 0 { parts.append("⏳ \(maybe) maybe") }
        if pending > 0 { parts.append("⏳ \(pending) pending") }
        
        return parts.isEmpty ? "No responses" : parts.joined(separator: "  ")
    }
    
    /// Creator text for UI
    func creatorText(currentUserId: String) -> String {
        if createdBy == currentUserId {
            return "You created this event"
        } else {
            // Display name will be fetched separately
            return "Created by User"
        }
    }
}

// MARK: - RSVP Response Helper
// (Using RSVPStatus from RSVPStatus.swift)

// MARK: - Preview Helpers
// TODO: Add preview helpers if needed (requires mock DocumentSnapshot)
