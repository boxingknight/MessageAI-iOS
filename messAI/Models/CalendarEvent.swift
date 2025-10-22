import Foundation
import EventKit

/// Confidence level for extracted calendar events
enum CalendarConfidence: String, Codable, Hashable {
    case high   // Date and time both explicit (e.g., "Thursday at 4pm")
    case medium // Date clear but time vague or missing
    case low    // Date or time ambiguous (e.g., "sometime next week")
}

/// Calendar event extracted from a message by AI
struct CalendarEvent: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let title: String
    let date: Date
    let time: Date?
    let endTime: Date?
    let location: String?
    let isAllDay: Bool
    let confidence: CalendarConfidence
    let rawText: String
    
    /// Initialize from dictionary (Firestore/Cloud Function response)
    init(id: String, title: String, date: Date, time: Date?, endTime: Date?, location: String?, isAllDay: Bool, confidence: CalendarConfidence, rawText: String) {
        self.id = id
        self.title = title
        self.date = date
        self.time = time
        self.endTime = endTime
        self.location = location
        self.isAllDay = isAllDay
        self.confidence = confidence
        self.rawText = rawText
    }
    
    /// Initialize from Cloud Function response dictionary
    init?(from dictionary: [String: Any]) {
        guard let id = dictionary["id"] as? String,
              let title = dictionary["title"] as? String,
              let dateString = dictionary["date"] as? String,
              let isAllDay = dictionary["isAllDay"] as? Bool,
              let confidenceString = dictionary["confidence"] as? String,
              let confidence = CalendarConfidence(rawValue: confidenceString),
              let rawText = dictionary["rawText"] as? String else {
            return nil
        }
        
        // Parse ISO 8601 date
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withFullDate]
        guard let date = dateFormatter.date(from: dateString) else {
            return nil
        }
        
        // Parse optional time with robust handling
        var time: Date?
        if let timeString = dictionary["time"] as? String,
           !timeString.isEmpty,
           timeString != "null" {
            
            print("🕒 [CalendarEvent] Attempting to parse time: '\(timeString)' for date: '\(dateString)'")
            
            // Strategy 1: Try ISO8601 format (e.g., "16:00:00")
            let fullDateTimeString = "\(dateString)T\(timeString)"
            let fullFormatter = ISO8601DateFormatter()
            fullFormatter.formatOptions = [.withFullDate, .withTime, .withColonSeparatorInTime]
            time = fullFormatter.date(from: fullDateTimeString)
            
            // Strategy 2: Manual parsing if ISO8601 fails
            if time == nil {
                print("⚠️ [CalendarEvent] ISO8601 parsing failed, trying manual parsing")
                let timeComponents = timeString.split(separator: ":")
                if timeComponents.count >= 2,
                   let hour = Int(timeComponents[0]),
                   let minute = Int(timeComponents[1]) {
                    var calendar = Calendar.current
                    calendar.timeZone = TimeZone.current
                    var dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
                    dateComponents.hour = hour
                    dateComponents.minute = minute
                    dateComponents.second = timeComponents.count > 2 ? Int(timeComponents[2]) : 0
                    time = calendar.date(from: dateComponents)
                }
            }
            
            if time != nil {
                print("✅ [CalendarEvent] Successfully parsed time: \(time!)")
            } else {
                print("❌ [CalendarEvent] Failed to parse time: '\(timeString)'")
            }
        }
        
        // Parse optional end time
        var endTime: Date?
        if let endTimeString = dictionary["endTime"] as? String,
           !endTimeString.isEmpty,
           endTimeString != "null" {
            let fullDateTimeString = "\(dateString)T\(endTimeString)"
            let fullFormatter = ISO8601DateFormatter()
            fullFormatter.formatOptions = [.withFullDate, .withTime, .withColonSeparatorInTime]
            endTime = fullFormatter.date(from: fullDateTimeString)
        }
        
        let location = dictionary["location"] as? String
        
        // CRITICAL FIX: Override isAllDay based on whether we successfully parsed time
        // This ensures consistency between time field and isAllDay flag
        let finalIsAllDay: Bool
        if time != nil {
            // Successfully parsed time → NOT all-day
            finalIsAllDay = false
            print("✅ [CalendarEvent] Time parsed successfully → isAllDay = false")
        } else if dictionary["time"] != nil && dictionary["time"] as? String != "null" {
            // Backend said there's a time but we couldn't parse it → all-day fallback
            print("⚠️ [CalendarEvent] Time parsing failed, falling back to all-day event")
            finalIsAllDay = true
        } else {
            // No time provided at all → use backend's isAllDay value
            finalIsAllDay = isAllDay
            print("ℹ️ [CalendarEvent] No time provided, using backend isAllDay: \(isAllDay)")
        }
        
        self.init(
            id: id,
            title: title,
            date: date,
            time: time,
            endTime: endTime,
            location: location,
            isAllDay: finalIsAllDay, // ← Use computed value instead of backend value
            confidence: confidence,
            rawText: rawText
        )
    }
    
    /// Convert to EventKit EKEvent for adding to iOS Calendar
    func toEKEvent(eventStore: EKEventStore) -> EKEvent {
        let event = EKEvent(eventStore: eventStore)
        event.title = title
        event.location = location
        event.isAllDay = isAllDay
        
        if isAllDay {
            // All-day event
            event.startDate = date
            event.endDate = date
        } else if let time = time {
            // Timed event
            event.startDate = time
            if let endTime = endTime {
                event.endDate = endTime
            } else {
                // Default to 1 hour duration if no end time
                event.endDate = time.addingTimeInterval(3600)
            }
        } else {
            // Fallback to all-day if time parsing failed
            event.startDate = date
            event.endDate = date
            event.isAllDay = true
        }
        
        // Add notes with confidence and source
        let confidenceText = confidence == .high ? "High confidence" : 
                             confidence == .medium ? "Medium confidence" : "Low confidence"
        event.notes = "Extracted from message: \"\(rawText)\"\n\nConfidence: \(confidenceText)"
        
        return event
    }
    
    /// Formatted date string for display
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    /// Formatted time string for display
    var formattedTime: String? {
        guard let time = time else { return nil }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: time)
    }
    
    /// Formatted time range string for display
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
    
    /// Human-readable confidence description
    var confidenceDescription: String {
        switch confidence {
        case .high:
            return "High confidence"
        case .medium:
            return "Medium confidence"
        case .low:
            return "Low confidence - please verify"
        }
    }
    
    /// Color for confidence indicator
    var confidenceColor: String {
        switch confidence {
        case .high:
            return "green"
        case .medium:
            return "orange"
        case .low:
            return "red"
        }
    }
}

