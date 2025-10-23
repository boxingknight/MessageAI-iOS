import Foundation
import SwiftUI

/**
 * PR#19: Deadline Model for Task Tracking
 * 
 * Represents a deadline extracted from conversation messages.
 * Includes smart status computation (upcoming/due-soon/overdue) and countdown timers.
 * Used to track commitments and prevent missed deadlines.
 */

// MARK: - Deadline Model

/// Represents a deadline with due date, priority, and status tracking
struct Deadline: Identifiable, Codable, Equatable, Hashable {
    let id: String                      // Firestore document ID
    let conversationId: String          // Parent conversation
    let messageId: String               // Source message containing deadline
    let createdBy: String               // User ID who created the deadline
    let createdAt: Date                 // When deadline was extracted
    
    // Deadline Details
    let title: String                   // Short title (e.g., "Permission slip")
    let description: String?            // Optional additional details
    let dueDate: Date                   // When the deadline is (raw from Firestore)
    let isAllDay: Bool                  // All-day vs specific time
    let priority: Priority              // High/medium/low urgency
    let category: Category?             // Optional category (school/work/etc)
    
    // TEMP FIX (PR#19.2): Display date with timezone adjustment
    // Deadlines are stored with wrong UTC time (GPT-4 interprets local time as UTC)
    // This adds +5 hours for Central timezone to display correctly
    // TODO (Future PR): Fix server-side timezone conversion, then remove this workaround
    // Options: (1) Improve GPT-4 prompts, (2) Post-process on iOS, (3) Store local time + offset
    var displayDate: Date {
        // Add 5 hours to compensate for timezone bug (works for Central timezone)
        return dueDate.addingTimeInterval(5 * 60 * 60)
    }
    
    // Status Tracking
    var status: Status                  // Active/completed/cancelled
    var completedAt: Date?              // When marked complete
    var completedBy: String?            // Who completed it
    var updatedAt: Date                 // Last update timestamp
    
    // MARK: - Nested Types
    
    /// Priority level based on urgency
    enum Priority: String, Codable, CaseIterable {
        case high = "high"       // Urgent (today/tomorrow)
        case medium = "medium"   // This week
        case low = "low"         // Later
        
        var displayName: String {
            switch self {
            case .high:     return "High"
            case .medium:   return "Medium"
            case .low:      return "Low"
            }
        }
        
        var icon: String {
            switch self {
            case .high:     return "exclamationmark.circle.fill"
            case .medium:   return "exclamationmark.circle"
            case .low:      return "circle"
            }
        }
        
        var color: Color {
            switch self {
            case .high:     return .red
            case .medium:   return .orange
            case .low:      return .blue
            }
        }
    }
    
    /// Deadline category for organization
    enum Category: String, Codable, CaseIterable {
        case school = "school"
        case work = "work"
        case personal = "personal"
        case event = "event"
        case payment = "payment"
        case other = "other"
        
        var displayName: String {
            switch self {
            case .school:   return "School"
            case .work:     return "Work"
            case .personal: return "Personal"
            case .event:    return "Event"
            case .payment:  return "Payment"
            case .other:    return "Other"
            }
        }
        
        var icon: String {
            switch self {
            case .school:   return "book.fill"
            case .work:     return "briefcase.fill"
            case .personal: return "person.fill"
            case .event:    return "calendar"
            case .payment:  return "dollarsign.circle.fill"
            case .other:    return "questionmark.circle.fill"
            }
        }
    }
    
    /// Deadline status (lifecycle)
    enum Status: String, Codable, CaseIterable {
        case active = "active"
        case completed = "completed"
        case cancelled = "cancelled"
        
        var displayName: String {
            switch self {
            case .active:       return "Active"
            case .completed:    return "Completed"
            case .cancelled:    return "Cancelled"
            }
        }
    }
    
    // MARK: - Computed Properties
    
    /// Time until/since deadline (computed based on current time)
    var timeStatus: TimeStatus {
        let now = Date()
        let timeInterval = displayDate.timeIntervalSince(now)
        let hours = timeInterval / 3600
        let days = timeInterval / 86400
        
        if timeInterval < 0 {
            return .overdue
        } else if hours <= 1 {
            return .critical  // Due within 1 hour
        } else if hours <= 24 {
            return .dueSoon   // Due within 24 hours
        } else if days <= 3 {
            return .approaching  // Due within 3 days
        } else {
            return .upcoming  // More than 3 days away
        }
    }
    
    /// Time status for UI display and urgency
    enum TimeStatus: String {
        case overdue = "overdue"
        case critical = "critical"   // < 1 hour
        case dueSoon = "due_soon"    // < 24 hours
        case approaching = "approaching"  // < 3 days
        case upcoming = "upcoming"   // > 3 days
        
        var displayName: String {
            switch self {
            case .overdue:      return "OVERDUE"
            case .critical:     return "DUE SOON"
            case .dueSoon:      return "DUE TODAY"
            case .approaching:  return "DUE THIS WEEK"
            case .upcoming:     return "UPCOMING"
            }
        }
        
        var icon: String {
            switch self {
            case .overdue:      return "exclamationmark.triangle.fill"
            case .critical:     return "clock.badge.exclamationmark.fill"
            case .dueSoon:      return "clock.fill"
            case .approaching:  return "calendar.badge.exclamationmark"
            case .upcoming:     return "calendar"
            }
        }
        
        var color: Color {
            switch self {
            case .overdue:      return .red
            case .critical:     return .red
            case .dueSoon:      return .orange
            case .approaching:  return .orange
            case .upcoming:     return .blue
            }
        }
        
        var backgroundColor: Color {
            switch self {
            case .overdue:      return Color.red.opacity(0.1)
            case .critical:     return Color.red.opacity(0.1)
            case .dueSoon:      return Color.orange.opacity(0.1)
            case .approaching:  return Color.orange.opacity(0.1)
            case .upcoming:     return Color.blue.opacity(0.1)
            }
        }
    }
    
    /// Countdown text (e.g., "Due in 2 days", "Due in 3 hours", "OVERDUE")
    var countdownText: String {
        let now = Date()
        let timeInterval = displayDate.timeIntervalSince(now)
        
        if timeInterval < 0 {
            // Overdue
            let absoluteInterval = abs(timeInterval)
            if absoluteInterval < 3600 {
                return "OVERDUE"
            } else if absoluteInterval < 86400 {
                let hours = Int(absoluteInterval / 3600)
                return "Overdue by \(hours)h"
            } else {
                let days = Int(absoluteInterval / 86400)
                return "Overdue by \(days)d"
            }
        } else {
            // Upcoming
            if timeInterval < 3600 {
                let minutes = Int(timeInterval / 60)
                return "Due in \(minutes)m"
            } else if timeInterval < 86400 {
                let hours = Int(timeInterval / 3600)
                return "Due in \(hours)h"
            } else {
                let days = Int(timeInterval / 86400)
                return "Due in \(days)d"
            }
        }
    }
    
    /// Formatted due date for display
    var formattedDueDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        
        if isAllDay {
            formatter.timeStyle = .none
            return formatter.string(from: displayDate)
        } else {
            formatter.timeStyle = .short
            return formatter.string(from: displayDate)
        }
    }
    
    /// Relative due date (e.g., "Today at 5pm", "Tomorrow", "Next Friday")
    var relativeDueDate: String {
        let calendar = Calendar.current
        let now = Date()
        
        if calendar.isDateInToday(displayDate) {
            if isAllDay {
                return "Today"
            } else {
                let timeFormatter = DateFormatter()
                timeFormatter.timeStyle = .short
                return "Today at \(timeFormatter.string(from: displayDate))"
            }
        } else if calendar.isDateInTomorrow(displayDate) {
            if isAllDay {
                return "Tomorrow"
            } else {
                let timeFormatter = DateFormatter()
                timeFormatter.timeStyle = .short
                return "Tomorrow at \(timeFormatter.string(from: displayDate))"
            }
        } else if let daysUntil = calendar.dateComponents([.day], from: now, to: displayDate).day, daysUntil <= 7 {
            // Within 1 week
            let dayFormatter = DateFormatter()
            dayFormatter.dateFormat = "EEEE"  // Day name
            let dayName = dayFormatter.string(from: displayDate)
            
            if isAllDay {
                return dayName
            } else {
                let timeFormatter = DateFormatter()
                timeFormatter.timeStyle = .short
                return "\(dayName) at \(timeFormatter.string(from: displayDate))"
            }
        } else {
            // More than 1 week away
            return formattedDueDate
        }
    }
    
    /// Whether deadline is overdue
    var isOverdue: Bool {
        return Date() > displayDate && status == .active
    }
    
    /// Whether deadline is completed
    var isCompleted: Bool {
        return status == .completed
    }
    
    /// Whether deadline is active (not completed or cancelled)
    var isActive: Bool {
        return status == .active
    }
    
    // MARK: - Firestore Conversion
    
    /// Convert from Firestore document
    static func fromFirestore(_ data: [String: Any], id: String) -> Deadline? {
        guard let conversationId = data["conversationId"] as? String,
              let messageId = data["messageId"] as? String,
              let createdBy = data["createdBy"] as? String,
              let createdAtTimestamp = data["createdAt"] as? Timestamp,
              let title = data["title"] as? String,
              let dueDateTimestamp = data["dueDate"] as? Timestamp,
              let isAllDay = data["isAllDay"] as? Bool,
              let priorityString = data["priority"] as? String,
              let priority = Priority(rawValue: priorityString),
              let statusString = data["status"] as? String,
              let status = Status(rawValue: statusString),
              let updatedAtTimestamp = data["updatedAt"] as? Timestamp
        else {
            print("❌ Failed to parse Deadline from Firestore (missing required fields)")
            return nil
        }
        
        let description = data["description"] as? String
        
        let categoryString = data["category"] as? String
        let category = categoryString != nil ? Category(rawValue: categoryString!) : nil
        
        let completedAtTimestamp = data["completedAt"] as? Timestamp
        let completedAt = completedAtTimestamp?.dateValue()
        
        let completedBy = data["completedBy"] as? String
        
        return Deadline(
            id: id,
            conversationId: conversationId,
            messageId: messageId,
            createdBy: createdBy,
            createdAt: createdAtTimestamp.dateValue(),
            title: title,
            description: description,
            dueDate: dueDateTimestamp.dateValue(),
            isAllDay: isAllDay,
            priority: priority,
            category: category,
            status: status,
            completedAt: completedAt,
            completedBy: completedBy,
            updatedAt: updatedAtTimestamp.dateValue()
        )
    }
    
    /// Convert to Firestore document
    func toFirestore() -> [String: Any] {
        var data: [String: Any] = [
            "conversationId": conversationId,
            "messageId": messageId,
            "createdBy": createdBy,
            "createdAt": Timestamp(date: createdAt),
            "title": title,
            "dueDate": Timestamp(date: dueDate),
            "isAllDay": isAllDay,
            "priority": priority.rawValue,
            "status": status.rawValue,
            "updatedAt": Timestamp(date: updatedAt)
        ]
        
        if let description = description {
            data["description"] = description
        }
        
        if let category = category {
            data["category"] = category.rawValue
        }
        
        if let completedAt = completedAt {
            data["completedAt"] = Timestamp(date: completedAt)
        }
        
        if let completedBy = completedBy {
            data["completedBy"] = completedBy
        }
        
        return data
    }
}

// MARK: - Timestamp Helper

import FirebaseFirestore

extension Deadline {
    typealias Timestamp = FirebaseFirestore.Timestamp
}

// MARK: - Preview Helpers

#if DEBUG
extension Deadline {
    /// Sample deadline for previews (upcoming)
    static let previewUpcoming = Deadline(
        id: "deadline1",
        conversationId: "conv123",
        messageId: "msg123",
        createdBy: "user1",
        createdAt: Date(),
        title: "Permission slip due",
        description: "Return signed permission slip for field trip",
        dueDate: Date().addingTimeInterval(5 * 86400),  // 5 days from now
        isAllDay: false,
        priority: .medium,
        category: .school,
        status: .active,
        completedAt: nil,
        completedBy: nil,
        updatedAt: Date()
    )
    
    /// Sample deadline for previews (due soon)
    static let previewDueSoon = Deadline(
        id: "deadline2",
        conversationId: "conv123",
        messageId: "msg124",
        createdBy: "user1",
        createdAt: Date(),
        title: "RSVP to party",
        description: "Let Sarah know if we're coming to the birthday party",
        dueDate: Date().addingTimeInterval(18 * 3600),  // 18 hours from now
        isAllDay: false,
        priority: .high,
        category: .event,
        status: .active,
        completedAt: nil,
        completedBy: nil,
        updatedAt: Date()
    )
    
    /// Sample deadline for previews (overdue)
    static let previewOverdue = Deadline(
        id: "deadline3",
        conversationId: "conv123",
        messageId: "msg125",
        createdBy: "user1",
        createdAt: Date().addingTimeInterval(-7 * 86400),  // 7 days ago
        title: "Submit report",
        description: "Annual financial report for tax filing",
        dueDate: Date().addingTimeInterval(-2 * 86400),  // 2 days ago
        isAllDay: true,
        priority: .high,
        category: .work,
        status: .active,
        completedAt: nil,
        completedBy: nil,
        updatedAt: Date()
    )
    
    /// Sample completed deadline
    static let previewCompleted = Deadline(
        id: "deadline4",
        conversationId: "conv123",
        messageId: "msg126",
        createdBy: "user1",
        createdAt: Date().addingTimeInterval(-3 * 86400),
        title: "Pay utility bill",
        description: "Monthly electric bill payment",
        dueDate: Date().addingTimeInterval(-1 * 86400),  // Yesterday
        isAllDay: false,
        priority: .medium,
        category: .payment,
        status: .completed,
        completedAt: Date().addingTimeInterval(-2 * 86400),  // Completed 2 days ago
        completedBy: "user1",
        updatedAt: Date().addingTimeInterval(-2 * 86400)
    )
}
#endif

